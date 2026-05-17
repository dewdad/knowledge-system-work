# Skill: Source Pull

> Pull new items from domain sources and create actionable platform issues.

## When to Use

- Scheduled daily/weekly source pulls
- Manual "check for new content" requests
- After adding a new source to a domain

## Prerequisites

- Platform CLI authenticated (`glab` for GitLab, `gh` for GitHub)
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

Before pulling, create a short-lived domain lock so two agents do not ingest the same source concurrently:

```bash
LOCK="domains/${DOMAIN}/.state/pull.lock"
if [ -f "$LOCK" ] && [ "$(find "$LOCK" -mmin -30 -print)" ]; then
  echo "Pull already running for ${DOMAIN}; skip."
  exit 0
fi
printf '%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ) $$" > "$LOCK"
trap 'rm -f "$LOCK"' EXIT
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

### 4.5 Normalize and De-Duplicate Items

For every pulled item, derive a stable `source_item_id` before creating an issue:

```text
source_item_id = sha256("<source_id>\n<canonical_url_or_external_id>\n<published_at_or_version>")
```

Dedup checks, in order:
1. Skip if `source_item_id` is already present in `pulls.json`.
2. Search open and closed issues for `source_item_id: <hash>`.
3. If no platform issue exists, create exactly one issue and include the hash in the body.

Title matching is only a fallback. Feeds often retitle items; URLs and external IDs are more stable.

### 5. Create Issues for New Items

For each new item (if `auto_triage: true`):

```bash
# GitLab
glab issue create \
  --title "[${DOMAIN}] ${ITEM_TITLE}" \
  --label "state:inbox,domain:${DOMAIN},type:source-item,source:${SOURCE_ID}" \
  --description "## Source Item

**Source**: ${SOURCE_ID}
**Type**: ${SOURCE_TYPE}
**URL**: ${ITEM_URL}
**Date**: ${ITEM_DATE}
**source_item_id**: ${SOURCE_ITEM_ID}

## Summary
${ITEM_SUMMARY}

---
_Auto-created by source-pull skill_"

# GitHub
gh issue create \
  --title "[${DOMAIN}] ${ITEM_TITLE}" \
  --label "state:inbox,domain:${DOMAIN},type:source-item,source:${SOURCE_ID}" \
  --body-file <body.md>
```

### 6. Update Pull State

```json
{
  "<source_id>": {
    "last_pull": "<current_timestamp>",
    "last_item_id": "<newest_item_id>",
    "seen_item_ids": ["<source_item_id>"],
    "items_pulled": "<total + new>",
    "items_triaged": "<total + new_issues_created>",
    "consecutive_failures": 0,
    "last_error": null
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

- **Source unreachable**: Skip, record `last_error` and increment `consecutive_failures`, try next source
- **Auth expired**: Create issue `type:maintenance` to refresh credentials
- **Duplicate detection**: Compare `source_item_id` against pull state and issue bodies before creating issues
- **Rate limits**: Respect source-specific rate limits, back off exponentially

## Notes

- Never store secrets in source config — use `auth_ref` pointing to `secrets/`
- Pull state is git-tracked so all agents see the same last-pull timestamps
- If a lock is stale, remove it only after checking no active pull process or recent commit exists for the same domain
