#!/usr/bin/env bash
set -euo pipefail

# upgrade-system.sh — Pull latest .system from dewdad/knowledge-system-work
# Run from instance root directory

SYSTEM_DIR=".system"

echo "=== System Upgrade ==="

# Check current version
if [ -f "${SYSTEM_DIR}/VERSION" ]; then
  CURRENT=$(cat "${SYSTEM_DIR}/VERSION" | tr -d '[:space:]')
  echo "Current version: ${CURRENT}"
else
  CURRENT="unknown"
  echo "Current version: unknown"
fi

# Fetch latest
echo "Fetching latest from remote..."
cd "${SYSTEM_DIR}"
git fetch origin main --quiet

# Check remote version
REMOTE_VERSION=$(git show origin/main:VERSION 2>/dev/null | tr -d '[:space:]')
echo "Remote version: ${REMOTE_VERSION:-unknown}"

if [ "${CURRENT}" = "${REMOTE_VERSION}" ]; then
  echo "Already up to date."
  cd ..
  exit 0
fi

# Show changelog diff
echo ""
echo "--- Changes ---"
git log HEAD..origin/main --oneline 2>/dev/null || echo "(no log available)"
echo "---------------"
echo ""

# Pull
echo "Upgrading..."
git checkout main
git pull origin main --quiet

cd ..

# Update submodule pointer in parent
git add "${SYSTEM_DIR}"
NEW_VERSION=$(cat "${SYSTEM_DIR}/VERSION" | tr -d '[:space:]')

echo ""
echo "Upgraded: ${CURRENT} → ${NEW_VERSION}"
echo ""
echo "Next steps:"
echo "  git commit -m \"chore: upgrade .system to ${NEW_VERSION}\""
echo "  git push"
