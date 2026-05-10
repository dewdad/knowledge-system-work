# Skill: Domain Review

> Weekly health check on a specific domain — sources, issues, wiki coverage.

## When to Use

- Scheduled weekly per domain (from `domain.yaml#review_schedule`)
- On-demand "how's domain X doing?" request
- After a period of inactivity in a domain

## Steps

### 1. Identify Domain

```bash
DOMAIN="health"  # or from assignment
cat domains/${DOMAIN}/domain.yaml
```

### 2. Source Health

```bash
# Check source pull state
cat domains/${DOMAIN}/.state/pulls.json | jq '
  to_entries[] | {
    source: .key,
    last_pull: .value.last_pull,
    failures: .value.consecutive_failures
  }'
```

Flag issues:
- Sources not pulled in > 2x their schedule (stale)
- Sources with consecutive_failures > 3 (broken)
- Sources with items_pulled growing but items_triaged flat (ignored content)

### 3. Issue Health

```bash
# Open issues in this domain
glab issue list --label "domain:${DOMAIN}" --state opened

# Breakdown by state
glab issue list --label "domain:${DOMAIN},state:ready" | wc -l
glab issue list --label "domain:${DOMAIN},state:wip" | wc -l
glab issue list --label "domain:${DOMAIN},state:blocked" | wc -l

# Overdue (past milestone due date)
glab issue list --label "domain:${DOMAIN}" --state opened --output json | \
  jq '[.[] | select(.due_date != null and .due_date < now | todate)] | length'
```

Flag issues:
- More than 10 items in `state:ready` (queue growing)
- Items in `state:wip` for > 1 week (stalled)
- Blocked items with no linked blocking issue (unclear blocker)

### 4. Wiki Coverage

```bash
# Pages in this domain's wiki section
find wiki/projects/${DOMAIN}/ -name "*.md" 2>/dev/null | wc -l

# Recent updates
git log --since="30 days ago" --name-only --format="" -- wiki/projects/${DOMAIN}/ | sort -u
```

Flag issues:
- No wiki updates in 30+ days (knowledge not being captured)
- Many issues closed but no corresponding wiki pages (decisions not documented)

### 5. Generate Review Report

```markdown
# Domain Review: ${DOMAIN}
Date: YYYY-MM-DD

## Sources
- Active: N/M sources pulling successfully
- Stale: [list]
- Broken: [list]

## Work Queue
- Ready: N items
- In Flight: N items  
- Blocked: N items
- Overdue: N items

## Wiki
- Pages: N
- Last updated: YYYY-MM-DD
- Coverage gaps: [list]

## Health Score: [Good/Warning/Critical]

## Recommended Actions
1. [action]
2. [action]
```

### 6. Create Issues for Problems

If problems found, use appropriate templates:
- Broken source → `type:maintenance` issue
- Queue overflow → Consider deprioritizing or batch-closing stale items
- Wiki gap → `type:task` to document missing knowledge
