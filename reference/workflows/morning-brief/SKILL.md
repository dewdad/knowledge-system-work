# Skill: Morning Brief

> Generate a daily summary of system state, due items, and recommendations.

## When to Use

- Scheduled daily (per `ksw.yaml` scheduling.morning_brief)
- On-demand "what's the status?" requests

## Steps

### 1. Gather Data

```bash
# Due issues this week
glab issue list --milestone "$(date +%Y)-W$(date +%V)" --state opened

# In-flight work
glab issue list --label "state:wip"

# Completed yesterday
glab issue list --state closed --updated-after "$(date -d yesterday +%Y-%m-%d)"

# Blocked items
glab issue list --label "state:blocked"

# Ready queue depth
glab issue list --label "state:ready" --assignee "" | wc -l
```

### 2. Check Source Pull Status

```bash
# For each domain, check last pull vs schedule
for dir in domains/*/; do
  DOMAIN=$(basename "$dir")
  LAST_PULL=$(jq -r '.[].last_pull' "domains/${DOMAIN}/.state/pulls.json" 2>/dev/null | sort | tail -1)
  echo "${DOMAIN}: last pulled ${LAST_PULL:-never}"
done
```

### 3. Wiki Activity

```bash
# Pages modified in last 24 hours
git log --since="24 hours ago" --name-only --format="" -- wiki/ | sort -u
```

### 4. Compose Brief

Format as a concise summary:

```markdown
# Morning Brief — YYYY-MM-DD

## Priority Work
- [P0/P1 issues due soon]

## In Flight
- [Currently claimed issues, by whom]

## Completed (24h)
- [Issues closed yesterday]

## Blocked
- [Issues waiting on dependencies]

## Queue Depth
- X items in state:ready (Y high priority)

## Sources
- [Domains with overdue pulls]
- [New items from last pull]

## Recommendations
- [Suggested next actions based on priority + deadlines]
```

### 5. Deliver

Options:
- Write to `wiki/_meta/briefs/YYYY-MM-DD.md`
- Create a GitLab issue with label `type:brief`
- Output to stdout (for agent to relay to user)

## Notes

- Keep brief under 50 lines — scannable, not exhaustive
- Flag anomalies (stale locks, overdue pulls, priority inversions)
- Don't repeat information available via `glab issue list`
