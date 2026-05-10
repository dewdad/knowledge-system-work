#!/usr/bin/env bash
set -euo pipefail

# configure-gitlab.sh — Create labels, protect branch, set up board
# Run from instance root directory after bootstrap.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SYSTEM_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
LABELS_FILE="${SYSTEM_DIR}/coordination/labels.yaml"

echo "=== GitLab Configuration ==="
echo ""

# --- Create Standard Labels ---
echo "[1/3] Creating standard labels..."

# States
glab label create "state:inbox" --color "#E4E669" --description "New, untriaged" 2>/dev/null || true
glab label create "state:ready" --color "#0E8A16" --description "Triaged, available for pickup" 2>/dev/null || true
glab label create "state:wip" --color "#D93F0B" --description "Claimed, in progress" 2>/dev/null || true
glab label create "state:review" --color "#0052CC" --description "MR open, awaiting merge" 2>/dev/null || true
glab label create "state:blocked" --color "#B60205" --description "Waiting on dependency" 2>/dev/null || true

# Priority
glab label create "P0:critical" --color "#B60205" --description "Must be done immediately" 2>/dev/null || true
glab label create "P1:high" --color "#D93F0B" --description "Do this week" 2>/dev/null || true
glab label create "P2:medium" --color "#FBCA04" --description "Do this sprint" 2>/dev/null || true
glab label create "P3:low" --color "#0E8A16" --description "Backlog" 2>/dev/null || true

# Type
glab label create "type:task" --color "#FBCA04" --description "Actionable work" 2>/dev/null || true
glab label create "type:research" --color "#5319E7" --description "Investigation" 2>/dev/null || true
glab label create "type:decision" --color "#D93F0B" --description "Requires decision" 2>/dev/null || true
glab label create "type:maintenance" --color "#C5DEF5" --description "Housekeeping" 2>/dev/null || true
glab label create "type:source-item" --color "#BFD4F2" --description "From source pull" 2>/dev/null || true
glab label create "type:bug" --color "#B60205" --description "Something broken" 2>/dev/null || true

echo "  ✓ Standard labels created"

# --- Create Domain Labels (from lifeos.yaml) ---
echo "[2/3] Creating domain labels..."

if command -v yq &> /dev/null; then
  DOMAINS=$(yq '.domains[]' lifeos.yaml 2>/dev/null || echo "")
else
  # Fallback: grep-based parsing
  DOMAINS=$(grep -A 100 '^domains:' lifeos.yaml | grep '^\s*-\s' | sed 's/.*-\s*//' | tr -d ' ')
fi

COLORS=("#0052CC" "#5319E7" "#0E8A16" "#D93F0B" "#FBCA04" "#B60205" "#C5DEF5" "#BFD4F2")
COLOR_IDX=0

for DOMAIN in $DOMAINS; do
  COLOR=${COLORS[$COLOR_IDX % ${#COLORS[@]}]}
  glab label create "domain:${DOMAIN}" --color "${COLOR}" --description "Domain: ${DOMAIN}" 2>/dev/null || true
  echo "  ✓ domain:${DOMAIN}"
  COLOR_IDX=$((COLOR_IDX + 1))
done

# --- Protect Main Branch ---
echo "[3/3] Configuring branch protection..."

echo "  Note: Branch protection must be configured via GitLab UI or API."
echo "  Recommended settings for 'main':"
echo "    - No direct push allowed"
echo "    - Merge requests required"
echo "    - CI must pass before merge"
echo ""
echo "  Configure at: https://gitlab.com/<project>/-/settings/repository#js-protected-branches-settings"

echo ""
echo "=== Configuration Complete ==="
echo ""
echo "Labels created. Configure branch protection in GitLab UI."
echo "Create a board at: https://gitlab.com/<project>/-/boards"
echo "  Add lists for: state:inbox, state:ready, state:wip, state:review"
