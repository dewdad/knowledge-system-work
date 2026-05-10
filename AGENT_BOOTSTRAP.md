# Agent Bootstrap

> **Read this first when entering any LifeOS workspace.**

---

## Quick Start (30-second version)

```bash
# 1. Sync
git pull --recurse-submodules

# 2. Find work
glab issue list --label "state:ready" --assignee ""

# 3. Claim (replace <ID> with issue number)
glab issue update <ID> --assignee "@me" --unlabel "state:ready" --label "state:wip"
git checkout -b issue/<ID>-<slug>

# 4. Do work, then release
git push origin issue/<ID>-<slug>
glab mr create --source-branch "issue/<ID>-<slug>" --title "Resolve #<ID>: <title>"
glab issue update <ID> --unlabel "state:wip" --label "state:review"
```

---

## System Layout

```
.system/                  ← You are here (KWS submodule)
├── AGENT_BOOTSTRAP.md    ← This file
├── coordination/         ← HOW to coordinate with other agents
│   ├── PROTOCOL.md       ← Full locking/claiming rules
│   ├── labels.yaml       ← Standard label set
│   ├── states.yaml       ← Issue state machine
│   └── recovery.md       ← Crash recovery procedures
├── skills/               ← WHAT you can do (reusable instructions)
├── scripts/              ← HOW to automate (shell scripts)
├── schemas/              ← WHAT data looks like (validation)
└── templates/            ← STARTING POINTS (issues, CI, configs)
```

---

## Before You Start Working

### 1. Check Prerequisites

```bash
# Git configured?
git config user.name && git config user.email

# glab authenticated?
glab auth status

# On correct project?
glab repo view  # Should show the LifeOS instance project
```

### 2. Read Instance Config

```bash
cat lifeos.yaml
```

Key fields:
- `agent_config.mr_required` — Must you create MRs? (usually yes)
- `agent_config.stale_wip_timeout_minutes` — How long before locks expire
- `domains` — What domains exist in this instance

### 3. Understand the Work Queue

```bash
# All available work, sorted by priority
glab issue list --label "state:ready" --assignee "" --sort priority

# Work in a specific domain
glab issue list --label "state:ready,domain:health" --assignee ""

# Currently in-flight work (avoid collisions)
glab issue list --label "state:wip"
```

---

## Core Rules

1. **Never push directly to `main`** — Always use branches + MRs
2. **One issue = one branch** — Named `issue/<ID>-<short-slug>`
3. **Claim before working** — Assign yourself + add `state:wip`
4. **Release if you can't finish** — Unassign + move back to `state:ready`
5. **Respect domain boundaries** — Check if your files overlap with in-flight work
6. **Commit often** — Prevents stale-lock false positives

---

## Available Skills

Skills are detailed instructions for specific tasks. Read the relevant skill before executing:

| Skill | When to Use |
|-------|-------------|
| `skills/source-pull/` | Pulling new items from domain sources |
| `skills/issue-triage/` | Auto-labeling and prioritizing new issues |
| `skills/wiki-ingest/` | Processing raw material into wiki pages |
| `skills/wiki-synthesize/` | Finding cross-domain patterns |
| `skills/domain-review/` | Weekly health check on a domain |
| `skills/issue-to-wiki/` | Converting closed issues to decision records |
| `skills/wiki-to-issue/` | Converting wiki insights to actionable issues |
| `skills/morning-brief/` | Generating daily summary |

---

## Available Scripts

```bash
# Setup (run once)
.system/scripts/setup/bootstrap.sh          # Initialize instance structure
.system/scripts/setup/configure-gitlab.sh    # Set up labels, board, protection

# Maintenance (run periodically)
.system/scripts/maintenance/source-pull.sh --domain <name>   # Pull feeds
.system/scripts/maintenance/stale-lock-recovery.sh           # Reclaim stale locks
.system/scripts/maintenance/wiki-lint.sh                     # Validate wiki
.system/scripts/maintenance/upgrade-system.sh                # Update .system/
```

---

## Decision Tree: What Should I Do?

```
Am I given a specific issue to work on?
├─ YES → Claim it, create branch, do the work
└─ NO → Check the work queue
         ├─ Issues available? → Pick highest priority, claim it
         └─ No issues? → Check if maintenance is due
              ├─ Source pull due? → Run source-pull for each domain
              ├─ Stale locks? → Run recovery
              └─ Nothing to do → Report "No work available"
```

---

## Coordination Deep-Dive

For full details on:
- Lock acquisition/release mechanics
- Race condition handling
- Domain-scoped parallelism
- Crash recovery

→ Read `.system/coordination/PROTOCOL.md`

---

## Upgrading the System

```bash
# Pull latest .system from dewdad/knowledge-system-work
.system/scripts/maintenance/upgrade-system.sh

# Or manually:
git submodule update --remote .system
git add .system && git commit -m "chore: upgrade .system" && git push
```
