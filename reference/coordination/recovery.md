# Crash Recovery & Stale Lock Handling

## When an Agent Crashes

If an agent disconnects or crashes while holding a lock (`state:wip` + assigned):

1. **Branch preserves partial work** — Any committed changes exist on `issue/<ID>-*`
2. **Lock becomes stale** — No further activity on the issue
3. **Another agent can reclaim** — After timeout period

## Stale Lock Detection

A lock is considered **stale** when ALL conditions are met:

- Issue has label `state:wip`
- Issue has an assignee
- `updated_at` timestamp on the issue is older than `stale_wip_timeout_minutes` (from `ksw.yaml`, default: 30)
- No new commits on the working branch within the timeout period

## Recovery Script

Run periodically or before picking up new work:

```bash
.system/scripts/maintenance/stale-lock-recovery.sh
```

This script:
1. Lists all `state:wip` issues
2. Checks `updated_at` against timeout
3. For stale issues: unassigns, moves to `state:ready`
4. Adds a comment explaining the recovery
5. Does NOT delete the working branch (preserves partial work)

## Manual Recovery

If automated recovery isn't sufficient:

```bash
# Find stale issues
glab issue list --label "state:wip"

# Check last activity
glab issue view <ID>  # Look at updated_at

# Reclaim manually
glab issue update <ID> --unassignee "<old_agent>" --assignee "@me"
glab issue note <ID> --message "Manual reclaim: previous agent inactive"

# Continue from existing branch (if any)
git fetch origin
git checkout issue/<ID>-*  # Tab-complete the branch name
```

## Preventing Stale Locks

Agents SHOULD:
1. **Commit frequently** — Even WIP commits reset the activity timestamp
2. **Release early** — If a task is taking longer than expected, release and re-scope
3. **Comment progress** — `glab issue note <ID>` updates the `updated_at`
4. **Set realistic scope** — Issues should be completable in one session (< 2 hours)

## Edge Cases

### Agent Crashed Mid-Commit
- Working directory may be dirty
- Recovery: `git stash` or `git reset` on the branch, then re-approach

### Two Agents Reclaim Simultaneously
- Same race condition as initial claim (see PROTOCOL.md §2)
- Resolution: first commenter wins, second releases

### Branch Has Conflicts with Main
- Agent rebases: `git rebase origin/main`
- If conflicts are complex: create new issue for conflict resolution, release current
