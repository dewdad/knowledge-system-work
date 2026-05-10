#!/usr/bin/env bash
set -euo pipefail

# wiki-lint.sh — Validate wiki structure, links, and frontmatter
# Run from instance root directory

WIKI_DIR="${1:-wiki}"
ERRORS=0
WARNINGS=0

echo "=== Wiki Lint ==="
echo "Directory: ${WIKI_DIR}"
echo ""

# --- Check 1: Broken Wikilinks ---
echo "[1/4] Checking wikilinks..."

find "${WIKI_DIR}" -name "*.md" -type f | while read -r file; do
  # Extract [[links]] (without aliases)
  grep -oP '\[\[([^\]|]+)' "$file" 2>/dev/null | sed 's/\[\[//' | while read -r link; do
    # Check if target exists (as file or directory)
    TARGET="${WIKI_DIR}/${link}.md"
    TARGET_DIR="${WIKI_DIR}/${link}"
    if [ ! -f "$TARGET" ] && [ ! -d "$TARGET_DIR" ] && [ ! -f "${link}.md" ]; then
      echo "  BROKEN: ${file} → [[${link}]]"
      ERRORS=$((ERRORS + 1))
    fi
  done
done

# --- Check 2: Frontmatter Validation ---
echo "[2/4] Checking frontmatter..."

find "${WIKI_DIR}" -name "*.md" -type f -not -path "${WIKI_DIR}/_*" | while read -r file; do
  # Check for frontmatter presence
  FIRST_LINE=$(head -1 "$file")
  if [ "$FIRST_LINE" != "---" ]; then
    echo "  MISSING FRONTMATTER: ${file}"
    WARNINGS=$((WARNINGS + 1))
  else
    # Check for required fields
    TITLE=$(sed -n '/^---$/,/^---$/p' "$file" | grep -c "^title:" || true)
    if [ "$TITLE" -eq 0 ]; then
      echo "  MISSING title: ${file}"
      WARNINGS=$((WARNINGS + 1))
    fi
  fi
done

# --- Check 3: Orphaned Pages ---
echo "[3/4] Checking for orphans..."

find "${WIKI_DIR}" -name "*.md" -type f \
  -not -path "${WIKI_DIR}/_*" \
  -not -name "index.md" | while read -r file; do
  BASENAME=$(basename "$file" .md)
  LINKS=$(grep -r "\[\[${BASENAME}" "${WIKI_DIR}/" --include="*.md" -l 2>/dev/null | grep -v "$file" | wc -l)
  if [ "$LINKS" -eq 0 ]; then
    echo "  ORPHAN: ${file}"
    WARNINGS=$((WARNINGS + 1))
  fi
done

# --- Check 4: Empty Pages ---
echo "[4/4] Checking for empty pages..."

find "${WIKI_DIR}" -name "*.md" -type f | while read -r file; do
  LINES=$(wc -l < "$file")
  if [ "$LINES" -lt 3 ]; then
    echo "  EMPTY: ${file} (${LINES} lines)"
    WARNINGS=$((WARNINGS + 1))
  fi
done

# --- Summary ---
echo ""
echo "=== Results ==="
echo "Errors: ${ERRORS}"
echo "Warnings: ${WARNINGS}"

if [ "$ERRORS" -gt 0 ]; then
  echo "FAILED: Fix errors before proceeding"
  exit 1
fi

if [ "$WARNINGS" -gt 0 ]; then
  echo "PASSED with warnings"
  exit 0
fi

echo "PASSED: All checks clean"
