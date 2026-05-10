#!/usr/bin/env bash
set -euo pipefail

# stale-lock-recovery.sh — Detect and reclaim stale WIP locks
# Run from instance root directory

# Default timeout (can be overridden from lifeos.yaml)
TIMEOUT_MINUTES=${1:-30}

echo "=== Stale Lock Recovery (timeout: ${TIMEOUT_MINUTES}min) ==="
echo ""

# Get WIP issues
WIP_ISSUES=$(glab issue list --label "state:wip" --output json 2>/dev/null || echo "[]")

if [ "$WIP_ISSUES" = "[]" ] || [ -z "$WIP_ISSUES" ]; then
  echo "No WIP issues found. All clear."
  exit 0
fi

CUTOFF=$(date -u -d "${TIMEOUT_MINUTES} minutes ago" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || \
         date -u -v-${TIMEOUT_MINUTES}M +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || \
         echo "")

if [ -z "$CUTOFF" ]; then
  echo "WARNING: Could not compute cutoff time. Listing WIP issues for manual review."
  echo "$WIP_ISSUES" | jq -r '.[] | "  #\(.iid) \(.title) (updated: \(.updated_at))"'
  exit 0
fi

echo "Cutoff time: ${CUTOFF}"
echo ""

# Check each WIP issue
STALE_COUNT=0
echo "$WIP_ISSUES" | jq -c '.[]' | while read -r issue; do
  IID=$(echo "$issue" | jq -r '.iid')
  TITLE=$(echo "$issue" | jq -r '.title')
  UPDATED=$(echo "$issue" | jq -r '.updated_at')
  ASSIGNEE=$(echo "$issue" | jq -r '.assignees[0].username // "unassigned"')

  if [[ "$UPDATED" < "$CUTOFF" ]]; then
    echo "STALE: #${IID} \"${TITLE}\" (assigned: ${ASSIGNEE}, updated: ${UPDATED})"
    
    # Reclaim
    glab issue update "${IID}" \
      --unlabel "state:wip" \
      --label "state:ready" 2>/dev/null || true
    
    if [ "$ASSIGNEE" != "unassigned" ]; then
      glab issue update "${IID}" --unassignee "${ASSIGNEE}" 2>/dev/null || true
    fi
    
    glab issue note "${IID}" \
      --message "Auto-recovered stale lock (inactive >${TIMEOUT_MINUTES}min). Moved back to state:ready." \
      2>/dev/null || true
    
    echo "  → Released to state:ready"
    STALE_COUNT=$((STALE_COUNT + 1))
  else
    echo "ACTIVE: #${IID} \"${TITLE}\" (assigned: ${ASSIGNEE}, updated: ${UPDATED})"
  fi
done

echo ""
echo "Recovery complete. ${STALE_COUNT:-0} stale locks reclaimed."
