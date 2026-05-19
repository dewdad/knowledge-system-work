# Agent Coordination Protocol — Operational Guide

> **Authoritative source.** The state machine is normatively defined in [`states.yaml`](states.yaml); the label catalogue is normatively defined in [`labels.yaml`](labels.yaml). When this document disagrees with either YAML, the YAML wins — fix this document.
>
> This file is the operational guide: how an agent _uses_ the state machine in practice.
>
> **Platform-agnostic.** All shell commands referenced here must be resolved against [`PLATFORM-OPS.md`](../../PLATFORM-OPS.md). KSW supports `gitlab` (`glab`), `github` (`gh`), and `local` (filesystem queue, hub-only). This document never embeds platform-specific shell forms — only action names that map to rows in the platform table.
>
> **Prerequisite.** The platform CLI is authenticated (or, for `local`, the workspace is a hub with a populated `.ksw/queue/` tree).

---

## 1. Issue State Machine

Every unit of work is a tracked item — a platform issue (`gitlab` / `github`) or a local queue file (`local`). Items move through states via labels (or directory location, for `local`):

```
state:inbox → state:ready → state:wip → state:review → (closed/done)
                              ↓
                       state:blocked (optional)
```

Canonical mapping:

| State | Label | Local-mode location | Meaning | Who Moves It |
|-------|-------|---------------------|---------|--------------|
| Inbox | `state:inbox` | `.ksw/queue/inbox/` | New, untriaged | Source pull / `/sat new` / manual create |
| Ready | `state:ready` | `.ksw/queue/ready/` | Triaged, available | Triage workflow or human |
| WIP | `state:wip` | `.ksw/queue/wip/` | Claimed, in progress | Claiming agent |
| Review | `state:review` | `.ksw/queue/done/` (with reviewer note) | MR/PR open or completion review pending | Working agent on completion |
| Blocked | `state:blocked` | `.ksw/queue/blocked/` | Awaiting input | Any agent |
| Done | _(closure)_ | `.ksw/queue/done/` (closed) | Resolved | Agent or human |

Closure is platform-native (close issue / close PR / move file with closed timestamp). KSW does not define a `state:done` label.

---

## 2. Claiming Work (Lock Acquisition)

### 2.1 Pre-claim check

1. **List available work**: `<list-ready>` action against [PLATFORM-OPS.md](../../PLATFORM-OPS.md). Filter to unassigned items.
2. **Re-fetch the specific issue** before claiming. Inspect `assignees` count and `labels`. If the issue already has an assignee or `state:wip`, abort — another agent is on it.

### 2.2 Claim sequence (verify-after-write)

1. **Apply** the `claim` action: assign to self **and** swap `state:ready` → `state:wip`. Where the platform supports both in one call, use it; where it does not, sequence them and tolerate transient inconsistency between the two writes.
2. **Create a working branch** named `ksw/<ID>-<slug>` (slug: lowercase, alphanumeric + hyphens, ≤40 chars). Legacy `issue/<ID>-<slug>` is still recognised by hooks during the 0.6.x grace period — see [COORDINATION.md § Branch Convention](../../COORDINATION.md#branch-convention).
3. **Add a claim comment** for traceability — host + UTC timestamp.
4. **Re-read the issue** ([PLATFORM-OPS.md § Verification rule](../../PLATFORM-OPS.md#verification-rule)). Confirm: exactly one assignee (you) and `state:wip` is set.

### 2.3 Race-condition mitigation

Platform label/assignment writes are not atomic. Two agents can hit the same `state:ready` issue simultaneously.

If the post-claim verification shows multiple assignees, conflicting labels, or a competing claim comment that pre-dates yours:

1. **Release** immediately — `release` action: unassign + revert label to `state:ready`.
2. Do **not** create or push branches, do **not** edit files, do **not** record in local active-claim state until verification passes.
3. If two consecutive claim attempts fail verification, apply `needs:coordination` and walk away. A human or a different agent will resolve.

For `local` mode, races cannot occur (single-process queue), so this section degrades to a no-op.

---

## 3. Releasing Work (Lock Release)

### 3.1 Successful completion

1. **Push** the working branch to the platform remote (skip for `local`).
2. **Open an MR/PR** referencing the issue (skip for `local`; instead move the queue file to `.ksw/queue/done/`).
3. **Transition** `state:wip` → `state:review` via the `complete` action.
4. **Comment** on the issue: "Work complete. MR/PR open."

### 3.2 Failure / inability to complete

1. **Push partial work** under a `wip:` commit so it is preserved on the remote (skip for `local`; the queue file already holds progress).
2. **Release** — unassign + swap `state:wip` → `state:ready`.
3. **Comment** with the reason and the branch name so a successor can resume.

The branch is **never deleted** during a release. Partial work is durable.

---

## 4. Stale-Lock Recovery

A WIP item is **stale** when ALL of:

- It is labelled `state:wip` (or sits in `.ksw/queue/wip/`).
- It has an assignee.
- The maximum of `updated_at`, last-comment-at, and last-commit-on-branch-at is older than `coordination.stale_wip_timeout_minutes` (from `ksw.yaml`; default 240).

Detection and recovery are performed by the hub via `/reap` (see [HUB-COMMANDS.md § /reap](../../HUB-COMMANDS.md#reap)). Satellites do **not** auto-release their own claims.

The recovery action is: unassign, swap `state:wip` → `state:ready`, post a comment naming the timeout and preserved branch. Branches are **never deleted** during recovery — partial work belongs to whichever agent picks the issue up next.

Detailed recovery procedure including manual fallbacks lives in [`recovery.md`](recovery.md).

---

## 5. Domain-Based Parallelism

### 5.1 Safe parallel work — no coordination needed

Two agents working on **different domains** can proceed without checking each other. File scopes do not overlap by definition: `domains/<a>/*` and `wiki/projects/<a>/*` vs `domains/<b>/*` and `wiki/projects/<b>/*`.

### 5.2 Same-domain parallel work — requires scoping

If two issues share a domain, agents MUST verify file-level non-overlap before working in parallel:

- Issues touching disjoint files within the same domain → safe (e.g. `domains/health/sources.yaml` vs `wiki/projects/health/sleep.md`).
- Issues touching shared files or sweeping the whole domain → serialize. The wider-scoped issue blocks the narrower ones.

### 5.3 Scope declaration

Issues SHOULD declare their file scope in the description so other agents can decide quickly whether parallel work is safe:

```markdown
## Scope
- `domains/health/sources.yaml`
- `domains/health/.state/pulls.json`

## Does NOT Touch
- `wiki/`
- Other domains
```

---

## 6. Conflict Resolution

### 6.1 Prevention (preferred)

1. Issues scoped to non-overlapping files (§5.3).
2. Domain isolation (different agents, different domains).
3. Branch-per-issue — conflicts surface at MR/PR time, not during work.

### 6.2 Detection at MR/PR time

The platform reports merge conflicts. Resolution is a `rebase` against the default branch (read from `coordination.default_branch`, defaulting to `main`), conflict fix, force-push with lease.

### 6.3 Last resort: manual intervention

If two MRs/PRs touch the same lines:

1. First merge wins.
2. Second author rebases and reconciles.
3. If reconciliation is non-trivial → open a fresh `type:decision` issue and proceed there.

For `local` mode, conflicts cannot occur (single-process queue) — the section degrades to a no-op.

---

## 7. Quick Reference Card

Resolve every action below against [PLATFORM-OPS.md](../../PLATFORM-OPS.md):

```
╔══════════════════════════════════════════════════════════════╗
║  AGENT COORDINATION — QUICK REFERENCE (platform-agnostic)    ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║  FIND WORK:    list-ready, filter to unassigned              ║
║  CLAIM:        assign-self + state:ready → state:wip,        ║
║                then re-read to verify                        ║
║  BRANCH:       git checkout -b ksw/<ID>-<slug>               ║
║  COMPLETE:     push branch, open MR/PR,                      ║
║                state:wip → state:review                      ║
║  RELEASE:      push partial, unassign,                       ║
║                state:wip → state:ready                       ║
║  BLOCK:        state:wip → state:blocked,                    ║
║                comment with reason                           ║
║  REAP:         hub-only; runs against stale state:wip items  ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
```
