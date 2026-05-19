# KSW Coordination Protocol

> Loaded when: any command claims, releases, transitions, or recovers an issue. This is the operational guide. The normative state and label definitions live in [`reference/coordination/states.yaml`](reference/coordination/states.yaml) and [`reference/coordination/labels.yaml`](reference/coordination/labels.yaml). When this file disagrees with those YAMLs, the YAMLs win — fix this file.

## State Machine

```
state:inbox → state:ready → state:wip → state:review → (closed/done)
                               ↓
                        state:blocked
```

| State | Meaning | Entered by | Leaves to |
|-------|---------|-----------|-----------|
| `state:inbox` | New, untriaged | Source pull, manual creation, satellite `/sat new` | `state:ready` (after triage) or `needs:clarification` (ambiguous) |
| `state:ready` | Triaged, available to claim | Triage workflow, release | `state:wip` |
| `state:wip` | In progress, single owner | Claim (assign + label) | `state:review`, `state:blocked`, or `state:ready` (release) |
| `state:review` | Work complete, MR/PR or review pending | `/sat done`, hub completion path | Closed or back to `state:wip` |
| `state:blocked` | Stuck, awaiting input | Manual block | `state:ready` (after unblock) |

Closure is platform-native (`glab issue close` / `gh issue close` / move to `.ksw/queue/done/`). KSW does not define a `state:done` label — closure plus the platform's closed timestamp is the signal.

## Coordination Modes

Set in `ksw.yaml#coordination.mode`. Hub only — satellites inherit team semantics over the hub.

### Solo Mode

1. Move files between queue directories (or apply labels) to transition state.
2. No locking — single agent.
3. Branch workflow optional; direct commits to `default_branch` are acceptable.
4. Stale-lock recovery is a no-op.

### Team Mode

1. Never push directly to `default_branch`. Always branch + MR/PR.
2. One issue → one branch, named `ksw/<ID>-<slug>` (lowercase, hyphenated, ≤40 chars; see [Branch Convention](#branch-convention)).
3. Claim before working: assign-to-self **and** transition `state:ready` → `state:wip` in a single call where the platform supports it.
4. After claiming, **re-read** the issue (see [PLATFORM-OPS.md](PLATFORM-OPS.md#verification-rule)). If assignment or label did not stick, release immediately and stop.
5. Release if stuck: unassign + label `state:ready`. Branch is preserved on the remote.
6. WIP locks expire after `coordination.stale_wip_timeout_minutes` minutes of no activity (no commits, no comments, no label change).

## Stale Lock Recovery

WIP items past their idle timeout auto-release back to `state:ready`. Partial work stays on the branch. Recovery is performed by the hub — satellites do not auto-release their own claims.

The recovery procedure is documented in detail at [`reference/coordination/recovery.md`](reference/coordination/recovery.md). At a high level:

1. List `state:wip` issues; for each, compute `now - max(updated_at, last_comment_at, branch_last_commit_at)`.
2. If above timeout: unassign, swap `state:wip` → `state:ready`, post a comment `Auto-released after N minutes idle. Branch preserved at <branch_name>.`
3. Never delete branches during recovery. The releasing agent or a successor can resume.

## Branch Convention

All KSW issue branches — hub and satellite — use the same prefix:

```
ksw/<ID>-<slug>
```

`<slug>` is lowercase, alphanumeric + hyphens, ≤40 chars. Do not invent a new prefix; every git hook keys off this regex.

**Grace period (0.6.x):** the legacy satellite prefix `issue/<ID>-<slug>` is still recognised by all hooks. Existing branches keep working. Removal is targeted for the next minor release; new branches should always use `ksw/`.

## Where this protocol is enforced

- Hub agent hook (`reference/hooks/hub/agents/`) — surfaces stale WIP at session start.
- Hub git hooks (`reference/hooks/hub/git/`) — `prepare-commit-msg` injects `(KSW #ID)` on issue branches; `post-commit` reports batched progress on `ksw/<ID>-*` branches; `post-merge` transitions `state:wip` → `state:review`; `pre-push` warns on broken wikilinks; `post-checkout` displays issue context.
- Satellite git hooks (`reference/hooks/satellite/git/`) — `prepare-commit-msg` injects `(KSW #ID)`; `post-commit` reports progress; `post-merge` transitions `state:wip` → `state:review` and removes from `active_claims`.
- `/triage`, `/sat claim`, `/sat done`, `/sat blocked`, `/sat release` — explicit transitions documented in [HUB-COMMANDS.md](HUB-COMMANDS.md), [SATELLITE-COMMANDS.md](SATELLITE-COMMANDS.md), and [WORKFLOWS.md](WORKFLOWS.md).

## Coordination labels (canonical list)

| Label | Color | Purpose |
|-------|-------|---------|
| `state:inbox` | `#E4E669` | New, untriaged |
| `state:ready` | `#0E8A16` | Triaged, available |
| `state:wip` | `#D93F0B` | In progress |
| `state:review` | `#0052CC` | MR/PR open or completion review |
| `state:blocked` | `#B60205` | Blocked, awaiting input |
| `P0:critical` | `#B60205` | Immediate |
| `P1:high` | `#D93F0B` | This week |
| `P2:medium` | `#FBCA04` | This sprint |
| `P3:low` | `#0E8A16` | Backlog |
| `type:task` | `#FBCA04` | Actionable work |
| `type:research` | `#5319E7` | Investigation |
| `type:decision` | `#D93F0B` | Needs decision |
| `type:maintenance` | `#C5DEF5` | Housekeeping |
| `type:source-item` | `#BFD4F2` | Created by source pull |
| `type:bug` | `#EE0701` | Defect |
| `needs:clarification` | `#F9D0C4` | Triage couldn't classify, awaits user |
| `domain:<name>` | per-domain palette | Semantic context |
| `satellite:<name>` | `#1D76DB` | Routed to a satellite workspace |

`domain:<name>` and `satellite:<name>` are templated — a hub creates one per domain and one per registered satellite. The state/priority/type labels are fixed; hub `/init` creates every entry above.
