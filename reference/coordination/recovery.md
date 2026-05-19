# Crash Recovery & Stale-Lock Handling

> **Authoritative source.** State definitions live in [`states.yaml`](states.yaml). This document is the operational guide for recovering from crashed or abandoned WIP locks. All shell forms are abstracted via [`PLATFORM-OPS.md`](../../PLATFORM-OPS.md).

## When an Agent Crashes

If an agent disconnects or crashes while holding a lock (`state:wip` + assigned, or a file in `.ksw/queue/wip/` for `local` mode):

1. **Branch preserves partial work.** Any committed changes exist on `ksw/<ID>-<slug>` (legacy `issue/<ID>-<slug>` still recognised by hooks during the 0.6.x grace period).
2. **The lock becomes stale.** No further activity on the issue or branch.
3. **Another agent can reclaim** after the timeout elapses.

## Stale-Lock Detection

A lock is **stale** when ALL of:

- The item is `state:wip` (label) or in `.ksw/queue/wip/` (local mode).
- The item has an assignee (or queue file owner field).
- The maximum of `updated_at`, last-comment-at, and last-commit-on-branch-at is older than `coordination.stale_wip_timeout_minutes` (read from `ksw.yaml`; default 240).

Detection and recovery is automated by `/reap` ([HUB-COMMANDS.md § /reap](../../HUB-COMMANDS.md#reap)). Satellites must not run recovery against their own claims — the hub is the only recovery authority.

## Recovery Procedure (automated)

`/reap` performs, for each stale item:

1. Unassign the previous owner.
2. Swap `state:wip` → `state:ready` (or move file from `.ksw/queue/wip/` to `.ksw/queue/ready/`).
3. Post a comment: `Auto-released after N minutes idle. Branch preserved at <branch_name>.`
4. **Never deletes the working branch** — partial work belongs to whichever agent picks the issue up next.

`/reap --dry-run` prints what would be released without mutating state.

## Manual Recovery

If `/reap` is unavailable or insufficient:

1. **List `state:wip` items** via the platform's `list-wip` action (see [PLATFORM-OPS.md](../../PLATFORM-OPS.md)).
2. **Inspect activity** — `updated_at` on the item, last commit on the branch, last comment.
3. **Reclaim** — unassign the previous agent, assign yourself, ensure `state:wip` is set (it should already be), comment explaining the manual reclaim.
4. **Resume from the existing branch** — fetch and check out `ksw/<ID>-*` (or legacy `issue/<ID>-*`). The branch tip holds whatever the previous agent committed.

## Preventing Stale Locks

Agents SHOULD:

1. **Commit frequently** — every WIP commit resets the activity window via `post-commit`.
2. **Release early** — if a task is taking longer than expected, `release` and rescope.
3. **Comment progress** — explicit notes update `updated_at`.
4. **Set realistic scope** — issues should be completable in one session; multi-session work should be split.

## Edge Cases

### Agent crashed mid-commit

The working tree may be dirty. Recovery: `git stash` or `git reset` on the branch, then re-approach the change.

### Two agents reclaim simultaneously

Same race condition as the initial claim ([PROTOCOL.md § 2.3](PROTOCOL.md#23-race-condition-mitigation)). First commenter wins; the loser releases.

### Branch has conflicts with the default branch

Rebase against `coordination.default_branch` (defaults to `main`). If conflicts are non-trivial, open a fresh `type:decision` issue for the conflict resolution and release the original.

### Local-mode "stale lock"

In `local` mode there is no concurrent agent, so a stale `.ksw/queue/wip/<file>` simply means the previous session ended without finishing. Move the file back to `.ksw/queue/ready/` manually — there is no remote owner to unassign.
