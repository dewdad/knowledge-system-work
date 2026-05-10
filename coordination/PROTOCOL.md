# Agent Coordination Protocol

> **Purpose**: Prevent duplicate work, enable safe parallelism, recover from crashes.  
> **Interface**: GitLab issues + labels + assignments via `glab` CLI.  
> **Prerequisite**: `glab auth login` completed on the machine.

---

## 1. Issue State Machine

Every unit of work is a GitLab issue. Issues move through states via labels:

```
state:inbox → state:ready → state:wip → state:review → (closed)
                                ↓
                         state:blocked (optional)
```

| State | Label | Meaning | Who Moves It |
|-------|-------|---------|--------------|
| Inbox | `state:inbox` | New, untriaged | Auto-applied on create |
| Ready | `state:ready` | Triaged, available for pickup | Triage agent or human |
| WIP | `state:wip` | Claimed, actively being worked | Claiming agent |
| Review | `state:review` | MR open, awaiting merge | Working agent (on completion) |
| Blocked | `state:blocked` | Waiting on external dependency | Any agent |
| Done | _(closed)_ | Issue resolved and closed | Agent or human |

---

## 2. Claiming Work (Lock Acquisition)

### Pre-Claim Check

```bash
# List available work (unclaimed, ready)
glab issue list --label "state:ready" --assignee ""

# Verify specific issue is still unclaimed
ISSUE_JSON=$(glab issue view <ID> --output json)
ASSIGNEES=$(echo "$ISSUE_JSON" | jq -r '.assignees | length')
STATE_WIP=$(echo "$ISSUE_JSON" | jq -r '.labels[] | select(. == "state:wip")')

if [ "$ASSIGNEES" -gt 0 ] || [ -n "$STATE_WIP" ]; then
  echo "SKIP: Issue already claimed"
  exit 0
fi
```

### Claim Sequence (Atomic-ish)

```bash
# 1. Assign to self + transition to WIP
glab issue update <ID> \
  --assignee "@me" \
  --unlabel "state:ready" \
  --label "state:wip"

# 2. Create working branch
SLUG=$(echo "<title>" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | head -c 30)
git checkout -b "issue/<ID>-${SLUG}"

# 3. Add claim comment (traceability)
glab issue note <ID> --message "Claimed by agent on $(hostname) at $(date -u +%Y-%m-%dT%H:%M:%SZ)"
```

### Race Condition Mitigation

GitLab label/assignment updates are NOT atomic. Two agents could claim simultaneously. Mitigation:

1. **After claiming**, re-read the issue and verify YOUR assignment stuck
2. If multiple assignees: the **first commenter** keeps the claim, others release
3. In practice, with ≤3 agents and distinct domain focus, races are rare

```bash
# Post-claim verification (paranoia check)
sleep 2  # Brief delay for GitLab propagation
CURRENT=$(glab issue view <ID> --output json | jq -r '.assignees[0].username')
if [ "$CURRENT" != "$(glab auth status --show-token 2>&1 | grep -oP 'Logged in as \K\w+')" ]; then
  echo "RACE LOST: Releasing claim"
  glab issue update <ID> --unassignee "@me"
  exit 0
fi
```

---

## 3. Releasing Work (Lock Release)

### On Successful Completion

```bash
# 1. Push branch
git push origin "issue/<ID>-${SLUG}"

# 2. Create MR
glab mr create \
  --source-branch "issue/<ID>-${SLUG}" \
  --target-branch main \
  --title "Resolve #<ID>: <title>" \
  --description "Closes #<ID>" \
  --assignee "@me"

# 3. Transition state
glab issue update <ID> \
  --unlabel "state:wip" \
  --label "state:review"

# 4. Completion note
glab issue note <ID> --message "Work complete. MR created. Awaiting merge."
```

### On Failure / Inability to Complete

```bash
# 1. Push partial work (preserve progress)
git add . && git commit -m "wip: partial progress on #<ID>" && git push origin "issue/<ID>-${SLUG}"

# 2. Release lock but DON'T close
glab issue update <ID> \
  --unlabel "state:wip" \
  --label "state:ready" \
  --unassignee "@me"

# 3. Document what was attempted
glab issue note <ID> --message "Released: <reason>. Partial work on branch issue/<ID>-${SLUG}."
```

---

## 4. Stale Lock Recovery

An agent may crash or disconnect without releasing its lock. Other agents detect this:

### Detection Criteria

A lock is **stale** when ALL of:
- Issue has `state:wip` label
- Issue has an assignee
- Last activity on the issue (comment or label change) > `stale_wip_timeout_minutes` (default: 30)
- The working branch has no commits in the last `stale_wip_timeout_minutes`

### Recovery Procedure

```bash
# 1. Check for stale locks
STALE_CUTOFF=$(date -u -d "30 minutes ago" +%Y-%m-%dT%H:%M:%SZ)
# glab doesn't natively filter by last_activity, so:
glab issue list --label "state:wip" --output json | \
  jq --arg cutoff "$STALE_CUTOFF" '.[] | select(.updated_at < $cutoff)'

# 2. For each stale issue: reclaim
glab issue update <ID> \
  --unassignee "<previous_assignee>" \
  --assignee "@me" \
  --label "state:wip"

glab issue note <ID> --message "Reclaimed stale lock (previous agent inactive >30min). Continuing work."

# 3. Check for existing branch and continue from there
git fetch origin
if git branch -r | grep "issue/<ID>"; then
  git checkout "issue/<ID>-*"  # Continue from partial work
else
  git checkout -b "issue/<ID>-${SLUG}"  # Fresh start
fi
```

---

## 5. Domain-Based Parallelism

### Safe Parallel Work (No Coordination Needed)

Two agents working on **different domains** can proceed without checking each other:

```bash
# Agent A: domain:health → touches domains/health/*, wiki/projects/health/*
# Agent B: domain:finance → touches domains/finance/*, wiki/projects/finance/*
# → No file overlap. Safe.
```

### Same-Domain Parallel Work (Requires Scoping)

If two issues share a domain, the agent MUST check for file-level overlap:

```bash
# Issue #10: "Update health sources" → touches domains/health/sources.yaml
# Issue #11: "Write health wiki page" → touches wiki/projects/health/sleep.md
# → Different files within same domain. Safe IF issue descriptions are specific.

# Issue #12: "Reorganize health domain" → touches ALL of domains/health/*
# → BLOCKS all other health work. Must complete before others start.
```

### Scope Declaration in Issues

Issues SHOULD declare their file scope in the description:

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

### Prevention (Preferred)

1. Issues scoped to non-overlapping files
2. Domain isolation (different agents, different domains)
3. Branch-per-issue (conflicts surface at MR time, not during work)

### Detection (At MR Time)

```bash
# GitLab CI will report merge conflicts
# Agent sees: "This MR has conflicts with main"

# Resolution: rebase on latest main
git fetch origin main
git rebase origin/main
# Fix conflicts
git push --force-with-lease
```

### Last Resort: Manual Intervention

If two MRs touch the same lines:
1. First MR merged wins
2. Second MR author rebases and reconciles
3. If reconciliation is non-trivial → create new issue for conflict resolution

---

## 7. Quick Reference Card

```
╔══════════════════════════════════════════════════════════════╗
║  AGENT COORDINATION — QUICK REFERENCE                       ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║  FIND WORK:                                                  ║
║    glab issue list --label "state:ready" --assignee ""       ║
║                                                              ║
║  CLAIM:                                                      ║
║    glab issue update <ID> --assignee "@me"                   ║
║      --unlabel "state:ready" --label "state:wip"             ║
║    git checkout -b issue/<ID>-<slug>                         ║
║                                                              ║
║  COMPLETE:                                                   ║
║    git push origin issue/<ID>-<slug>                         ║
║    glab mr create --source-branch "issue/<ID>-<slug>"        ║
║      --title "Resolve #<ID>: <title>"                        ║
║    glab issue update <ID> --unlabel "state:wip"              ║
║      --label "state:review"                                  ║
║                                                              ║
║  RELEASE (can't finish):                                     ║
║    glab issue update <ID> --unassignee "@me"                 ║
║      --unlabel "state:wip" --label "state:ready"             ║
║                                                              ║
║  BLOCK:                                                      ║
║    glab issue update <ID> --label "state:blocked"            ║
║      --unlabel "state:wip"                                   ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
```
