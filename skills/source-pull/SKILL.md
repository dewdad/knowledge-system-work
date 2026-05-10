# Skill: Source Pull

> Pull new items from domain sources and create actionable GitLab issues.

## When to Use

- Scheduled daily/weekly source pulls
- Manual "check for new content" requests
- After adding a new source to a domain

## Prerequisites

- `glab` authenticated
- Domain exists in `domains/<name>/sources.yaml`
- Source pull state exists at `domains/<name>/.state/pulls.json` (created on first run)

## Steps

### 1. Identify Target Domain

```bash
# Pull all domains
for dir in domains/*/; do
  DOMAIN=$(basename "$dir")
  echo "Processing domain: $DOMAIN"
done

# Or specific domain
DOMAIN="health"
```

### 2. Read Source Configuration

```bash
cat domains/${DOMAIN}/sources.yaml
```

Parse each source entry. Required fields:
- `id`: Unique identifier
- `type`: rss | youtube | api | email | chat | git | calendar | manual
- `pull_schedule`: daily | weekly | hourly | manual

### 3. Check Pull State

```bash
cat domains/${DOMAIN}/.state/pulls.json
```

For each source, check `last_pull` against `pull_schedule`. Skip if not due.

### 4. Pull New Items (Per Source Type)

#### RSS Sources
```bash
# Fetch feed, extract items newer than last_pull
# Parse XML/Atom, extract: title, url, date, summary
# Filter by filter_keywords if specified
```

#### YouTube Sources
```bash
# Use yt-dlp to get channel metadata
yt-dlp --flat-playlist --dump-json \
  "https://www.youtube.com/channel/${CHANNEL_ID}/videos" \
  | jq 'select(.upload_date > "YYYYMMDD")'
```

#### API Sources
```bash
# HTTP GET to endpoint with auth from auth_ref
# Apply transform script if specified
```

### 5. Create Issues for New Items

For each new item (if `auto_triage: true`):

```bash
glab issue create \
  --title "[${DOMAIN}] ${ITEM_TITLE}" \
  --label "state:inbox,domain:${DOMAIN},type:source-item,source:${SOURCE_ID}" \
  --description "## Source Item

**Source**: ${SOURCE_ID}
**Type**: ${SOURCE_TYPE}
**URL**: ${ITEM_URL}
**Date**: ${ITEM_DATE}

## Summary
${ITEM_SUMMARY}

---
_Auto-created by source-pull skill_"
```

### 6. Update Pull State

```json
{
  "<source_id>": {
    "last_pull": "<current_timestamp>",
    "last_item_id": "<newest_item_id>",
    "items_pulled": "<total + new>",
    "items_triaged": "<total + new_issues_created>"
  }
}
```

### 7. Commit State Changes

```bash
git add domains/${DOMAIN}/.state/pulls.json
git commit -m "chore(${DOMAIN}): source pull $(date +%Y-%m-%d)"
git push
```

## Error Handling

- **Source unreachable**: Skip, log warning in issue note, try next source
- **Auth expired**: Create issue `type:maintenance` to refresh credentials
- **Duplicate detection**: Compare `last_item_id` to avoid re-creating issues
- **Rate limits**: Respect source-specific rate limits, back off exponentially

## Notes

- Never store secrets in source config — use `auth_ref` pointing to `secrets/`
- Pull state is git-tracked so all agents see the same last-pull timestamps
- If two agents run source-pull simultaneously for the same domain, duplicates may occur (mitigate via issue dedup by title)
