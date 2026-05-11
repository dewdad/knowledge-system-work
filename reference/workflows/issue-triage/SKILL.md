# Skill: Issue Triage

> Automatically label and prioritize issues in `state:inbox`.

## When to Use

- New issues appear without proper labels
- Batch triage after source-pull creates many items
- Periodic inbox cleanup

## Steps

### 1. List Untriaged Issues

```bash
glab issue list --label "state:inbox"
```

### 2. For Each Issue, Determine Labels

Read the issue title and description. Apply:

#### Domain Label
Match keywords to domains defined in `lifeos.yaml`:
- Health-related terms → `domain:health`
- Financial terms → `domain:finance`
- Career/work terms → `domain:career`
- Learning/skill terms → `domain:learning`

#### Type Label
- Contains action verb (build, fix, update, create) → `type:task`
- Contains question or "investigate" → `type:research`
- Contains "should we", "decide", "choose" → `type:decision`
- Contains "cleanup", "refactor", "update deps" → `type:maintenance`
- Auto-created by source-pull → `type:source-item` (already labeled)

#### Priority Label
- Explicit urgency indicators → P0 or P1
- Has a deadline → P1 or P2
- Nice-to-have / exploratory → P3
- Default → P2:medium

### 3. Apply Labels and Transition

```bash
glab issue update <ID> \
  --label "domain:<domain>,type:<type>,P<N>:<level>" \
  --unlabel "state:inbox" \
  --label "state:ready"
```

### 4. Add Triage Note

```bash
glab issue note <ID> --message "Triaged: domain=${DOMAIN}, type=${TYPE}, priority=${PRIORITY}. Reason: ${BRIEF_RATIONALE}"
```

## Ambiguous Cases

- **Multiple domains**: Apply most relevant, note the secondary in a comment
- **Unclear priority**: Default to P2, agent or human can adjust later
- **Missing context**: Add label `needs:clarification`, leave in `state:inbox`

## Batch Triage Performance

When triaging many issues (e.g., after source-pull):
1. Read all inbox issues at once
2. Group by obvious domain
3. Apply labels in batches where possible
4. Don't over-optimize — P2 default is fine for most source items
