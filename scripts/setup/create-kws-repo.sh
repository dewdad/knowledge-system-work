#!/usr/bin/env bash
set -euo pipefail

# create-kws-repo.sh — Create the dewdad/knowledge-system-work GitLab repo
# Run ONCE to establish the system repo. Requires glab auth.

echo "=== Creating KWS GitLab Repository ==="
echo ""

# Check auth
if ! glab auth status &> /dev/null; then
  echo "ERROR: Not authenticated. Run: glab auth login --hostname gitlab.com"
  exit 1
fi

# Create repo
echo "[1/4] Creating repository dewdad/knowledge-system-work..."
glab repo create knowledge-system-work \
  --private \
  --description "Knowledge Work System — Reusable agentic orchestration substrate for LifeOS instances" \
  --defaultBranch main \
  2>/dev/null || echo "  (repo may already exist)"

echo "[2/4] Initializing local repo..."
SYSTEM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$SYSTEM_DIR"

# Init git if not already
if [ ! -d ".git" ]; then
  git init
  git remote add origin git@gitlab.com:dewdad/knowledge-system-work.git
fi

echo "[3/4] Initial commit..."
git add -A
git commit -m "feat: initial Knowledge Work System (v0.1.0)

- Agent coordination protocol (work-locking via GitLab)
- AGENT_BOOTSTRAP.md entry point
- Skills: source-pull, issue-triage, wiki-ingest, wiki-synthesize,
  domain-review, issue-to-wiki, wiki-to-issue, morning-brief
- Scripts: bootstrap (sh+ps1), configure-gitlab, upgrade, recovery, wiki-lint
- Schemas: lifeos, domain, sources, pull-state
- Templates: CI fragments, GitLab issue/MR templates, instance scaffolding
- Full system architecture documentation"

echo "[4/4] Pushing to GitLab..."
git branch -M main
git push -u origin main

echo ""
echo "=== Done ==="
echo "Repository: https://gitlab.com/dewdad/knowledge-system-work"
echo ""
echo "To use in a LifeOS instance:"
echo "  git submodule add https://gitlab.com/dewdad/knowledge-system-work.git .system"
