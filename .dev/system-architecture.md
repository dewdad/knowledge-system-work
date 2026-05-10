# Knowledge Work System (KWS) — Architecture

> **Repo**: `dewdad/knowledge-system-work`  
> **Consumption**: Git submodule at `.system/` in any LifeOS instance  
> **Version**: 0.1.0  

---

## 1. System Overview

KWS is a **reusable orchestration substrate** that AI coding agents pull into project workspaces. It provides:

- **Coordination Protocol** — Work-locking via GitLab so agents never collide
- **Skills Library** — Reusable agent skills (markdown instructions)
- **Scripts** — Setup, maintenance, source-pulling automation
- **Schemas** — Structured formats for sources, domains, and state
- **Templates** — GitLab issue/MR templates, CI pipeline fragments

A **LifeOS instance** is a parent project that pulls `.system/` and adds project-specific configuration (domains, sources, wiki content).

---

## 2. Separation of Concerns

```
┌─────────────────────────────────────────────────────────────────┐
│  LifeOS Instance (parent repo: dewdad/lifeos-{instance})        │
│                                                                  │
│  lifeos.yaml              ← Instance config (domains, identity) │
│  domains/                 ← Per-domain sources & config          │
│  wiki/                    ← Knowledge base (Obsidian vault)      │
│  raw/                     ← Immutable source material            │
│  .gitlab-ci.yml           ← Instance CI (imports .system/ frags)│
│                                                                  │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  .system/ (submodule: dewdad/knowledge-system-work)       │  │
│  │                                                            │  │
│  │  AGENT_BOOTSTRAP.md    ← Entry point for all agents        │  │
│  │  coordination/         ← Locking protocol, parallel rules  │  │
│  │  skills/               ← Reusable agent skills             │  │
│  │  scripts/              ← Setup, maintenance, source-pull   │  │
│  │  schemas/              ← YAML/JSON schemas                 │  │
│  │  templates/            ← GitLab templates, CI fragments    │  │
│  │  system-architecture.md ← This file                        │  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

### Boundary Rules

| Belongs in `.system/` (KWS repo) | Belongs in parent (LifeOS instance) |
|---|---|
| Generic skills any instance can use | Domain definitions & source lists |
| Coordination protocol & lock mechanics | Wiki content & knowledge pages |
| Setup scripts & upgrade scripts | Instance identity (`lifeos.yaml`) |
| Schema definitions (source, domain, issue) | Raw ingested materials |
| CI pipeline fragments (reusable stages) | `.gitlab-ci.yml` (composed from fragments) |
| GitLab label/milestone templates | Actual labels/milestones (created per-instance) |
| Agent bootstrap instructions | Agent-specific overrides (if any) |

---

## 3. Agent Coordination Protocol

### 3.1 The Problem

Multiple agents (on different machines, in different sessions) work on the same LifeOS instance. Without coordination:
- Two agents edit the same file → merge conflicts
- Two agents work the same issue → duplicate effort
- An agent crashes mid-task → work is orphaned

### 3.2 Work-Locking via GitLab (glab CLI)

Every unit of work is a **GitLab issue**. Coordination uses three mechanisms:

#### Mechanism 1: Assignment Lock

```bash
# Agent claims an issue by self-assigning
glab issue update <ID> --assignee "@me"

# Before starting, agent verifies no one else is assigned
glab issue view <ID> --output json | jq '.assignees'
# If assignees is non-empty AND not me → SKIP, already claimed
```

#### Mechanism 2: WIP Label

```bash
# Agent adds wip label on pickup
glab issue update <ID> --label "state:wip"

# On completion, remove wip and close
glab issue update <ID> --unlabel "state:wip"
glab issue close <ID> --comment "Completed by agent on $(hostname)"

# On failure/crash recovery, another agent can detect stale locks:
# If state:wip AND last_updated > 30 minutes ago → eligible for reclaim
```

#### Mechanism 3: Branch-Per-Task

```bash
# Every issue gets its own branch
git checkout -b issue/<ID>-<slug>

# Agent works exclusively on this branch
# Merge back via MR (enables review, CI checks)
glab mr create --source-branch "issue/<ID>-<slug>" \
  --title "Resolve #<ID>: <title>" \
  --assignee "@me"
```

### 3.3 Agent Pickup Protocol (Stateless)

```
┌─────────────────────────────────────────────────────────────┐
│  AGENT ENTERS WORKSPACE                                      │
│                                                              │
│  1. Read .system/AGENT_BOOTSTRAP.md                          │
│  2. git pull (ensure latest state)                           │
│  3. glab issue list --assignee="" --label="state:ready"      │
│     → Shows unclaimed, ready work                            │
│  4. Pick highest priority issue                              │
│  5. CLAIM:                                                   │
│     glab issue update <ID> --assignee "@me" --label "state:wip"│
│     glab issue update <ID> --unlabel "state:ready"           │
│  6. Create branch: git checkout -b issue/<ID>-<slug>         │
│  7. DO WORK                                                  │
│  8. RELEASE:                                                 │
│     git push origin issue/<ID>-<slug>                        │
│     glab mr create ...                                       │
│     glab issue update <ID> --unlabel "state:wip"             │
│     glab issue update <ID> --label "state:review"            │
│  9. Pick next issue (goto 3)                                 │
└─────────────────────────────────────────────────────────────┘
```

### 3.4 State Machine for Issues

```
            ┌──────────┐
            │  inbox   │  ← New, untriaged
            └────┬─────┘
                 │ triage (add priority, domain, type labels)
                 ▼
            ┌──────────┐
            │  ready   │  ← Triaged, unassigned, available for pickup
            └────┬─────┘
                 │ agent claims (assign + state:wip)
                 ▼
            ┌──────────┐
            │   wip    │  ← Actively being worked, branch exists
            └────┬─────┘
                 │ work done, MR created
                 ▼
            ┌──────────┐
            │  review  │  ← MR open, awaiting merge/review
            └────┬─────┘
                 │ MR merged
                 ▼
            ┌──────────┐
            │   done   │  ← Issue closed
            └──────────┘

  Crash recovery: state:wip + stale (>30min) → reclaim allowed
  Blocked: state:blocked + blocking issue linked
```

### 3.5 Parallel Safety Rules

| Rule | Mechanism |
|---|---|
| **One agent per issue** | Assignment lock (check before claim) |
| **One branch per issue** | `issue/<ID>-*` naming convention |
| **No direct main commits** | Protected branch, MR-only merges |
| **File conflict prevention** | Issues scoped to specific files/domains via labels |
| **Stale lock recovery** | 30-min timeout on `state:wip` without commit activity |
| **Graceful degradation** | If agent crashes, branch preserves partial work |

### 3.6 Domain-Scoped Parallelism

Issues are labeled by domain (`domain:health`, `domain:finance`, etc.). Two agents CAN work in parallel if they're on **different domains** (different file paths, no overlap). Same-domain parallel work requires explicit file-level scoping in the issue description.

```bash
# Agent A picks up domain:health issue
# Agent B picks up domain:finance issue
# → Safe parallel work, no file overlap

# Agent C wants domain:health too?
# → Must check: are files disjoint from Agent A's issue?
# → If yes: safe. If no: wait for Agent A to finish.
```

---

## 4. Source & Feed System

### 4.1 Concept

Each domain in LifeOS has **sources** — external inputs that agents pull from regularly to establish work, surface opportunities, and enable decision-making.

### 4.2 Source Types

| Type | Examples | Pull Mechanism |
|---|---|---|
| `rss` | Blogs, news sites, newsletters | RSS/Atom parser |
| `youtube` | Channels, playlists | yt-dlp metadata / API |
| `api` | GitHub notifications, weather, finance | HTTP requests |
| `email` | Filtered inbox rules | IMAP/API |
| `chat` | Telegram, Matrix, Slack | Bot/webhook |
| `git` | Watched repos (commits, releases) | GitLab/GitHub API |
| `calendar` | Google Calendar, Outlook | CalDAV/API |
| `manual` | Drop-folder for files | Filesystem watch |

### 4.3 Domain Source Configuration

Lives in the **parent LifeOS instance** (not in `.system/`):

```yaml
# domains/health/sources.yaml
domain: health
sources:
  - id: huberman-podcast
    type: youtube
    channel_id: UC2D2CMWXMOVWx7giW1n3LIg
    pull_schedule: "daily"
    extract: [titles, descriptions, timestamps]
    auto_triage: true  # Create issues from new content

  - id: examine-com
    type: rss
    url: https://examine.com/feed/
    pull_schedule: "weekly"
    filter_keywords: [sleep, nutrition, supplement]

  - id: fitbit-api
    type: api
    endpoint: https://api.fitbit.com/1/user/-/activities.json
    auth_ref: secrets/fitbit_token  # Reference, not inline
    pull_schedule: "daily"
    transform: scripts/fitbit-to-issue.sh
```

### 4.4 Source Pull Protocol

```bash
# Agent runs source-pull for a domain
.system/scripts/source-pull.sh --domain health

# What it does:
# 1. Reads domains/health/sources.yaml
# 2. For each source:
#    a. Check last_pull timestamp in domains/health/.state/pulls.json
#    b. If schedule says it's due: pull new items
#    c. Apply filters/transforms
#    d. Create GitLab issues for actionable items (label: source:<id>, domain:health)
#    e. Update pull state
# 3. Commit state changes
```

### 4.5 Source State Tracking

```json
// domains/health/.state/pulls.json
{
  "huberman-podcast": {
    "last_pull": "2026-05-09T03:00:00Z",
    "last_item_id": "dQw4w9WgXcQ",
    "items_pulled": 142,
    "items_triaged": 89
  },
  "examine-com": {
    "last_pull": "2026-05-05T03:00:00Z",
    "last_item_id": "https://examine.com/article/xyz",
    "items_pulled": 23,
    "items_triaged": 12
  }
}
```

---

## 5. `.system/` Repository Structure

```
.system/                              ← dewdad/knowledge-system-work repo
├── system-architecture.md            ← This document
├── AGENT_BOOTSTRAP.md                ← Agent entry point (read first)
├── VERSION                           ← Semver for upgrade tracking
├── CHANGELOG.md                      ← What changed between versions
│
├── coordination/
│   ├── PROTOCOL.md                   ← Full coordination rules
│   ├── labels.yaml                   ← Standard label definitions
│   ├── states.yaml                   ← Issue state machine definition
│   └── recovery.md                   ← Stale lock & crash recovery
│
├── skills/
│   ├── README.md                     ← Skill index & usage guide
│   ├── source-pull/SKILL.md          ← Pull from domain sources
│   ├── issue-triage/SKILL.md         ← Auto-label and prioritize issues
│   ├── wiki-ingest/SKILL.md          ← Ingest raw material into wiki
│   ├── wiki-synthesize/SKILL.md      ← Cross-domain pattern finding
│   ├── domain-review/SKILL.md        ← Weekly domain health check
│   ├── issue-to-wiki/SKILL.md        ← Close issue → decision record
│   ├── wiki-to-issue/SKILL.md        ← Wiki insight → actionable issue
│   └── morning-brief/SKILL.md        ← Daily summary generation
│
├── scripts/
│   ├── README.md                     ← Script index
│   ├── setup/
│   │   ├── bootstrap.sh              ← New LifeOS instance setup
│   │   ├── bootstrap.ps1             ← Windows variant
│   │   ├── install-glab.sh           ← Install glab CLI
│   │   └── configure-gitlab.sh       ← Auth, remotes, webhooks
│   ├── maintenance/
│   │   ├── source-pull.sh            ← Pull sources for a domain
│   │   ├── stale-lock-recovery.sh    ← Reclaim abandoned work
│   │   ├── wiki-lint.sh              ← Validate wiki structure
│   │   └── upgrade-system.sh         ← Pull latest .system from remote
│   └── ci/
│       ├── lint-wiki.sh              ← CI job: wiki validation
│       ├── validate-sources.sh       ← CI job: source config check
│       └── publish-wiki.sh           ← CI job: build public wiki
│
├── schemas/
│   ├── lifeos.schema.yaml            ← Instance config schema
│   ├── domain.schema.yaml            ← Domain definition schema
│   ├── sources.schema.yaml           ← Source list schema
│   ├── pull-state.schema.yaml        ← Source pull state schema
│   └── issue-template.schema.yaml    ← Issue body structure
│
└── templates/
    ├── gitlab/
    │   ├── issue_templates/
    │   │   ├── task.md
    │   │   ├── research.md
    │   │   ├── decision.md
    │   │   ├── source-item.md        ← Auto-created from source pull
    │   │   └── bug.md
    │   └── merge_request_templates/
    │       └── default.md
    ├── ci/
    │   ├── wiki-pipeline.yml         ← Reusable CI fragment
    │   ├── source-pipeline.yml       ← Reusable CI fragment
    │   └── maintenance-pipeline.yml  ← Reusable CI fragment
    └── instance/
        ├── lifeos.yaml.template      ← Starting instance config
        ├── domains/                   ← Example domain configs
        │   ├── _example/
        │   │   ├── domain.yaml
        │   │   └── sources.yaml
        │   └── _template/
        │       ├── domain.yaml
        │       └── sources.yaml
        └── wiki/                      ← Starter wiki structure
            ├── index.md
            └── _meta/
                └── taxonomy.md
```

---

## 6. LifeOS Instance Structure

The parent project (e.g., `dewdad/lifeos-personal`):

```
lifeos-personal/
├── .system/                    ← Git submodule → dewdad/knowledge-system-work
├── .gitlab-ci.yml              ← Instance CI (includes .system/templates/ci/*.yml)
├── lifeos.yaml                 ← Instance configuration
│
├── domains/
│   ├── health/
│   │   ├── domain.yaml         ← Domain metadata
│   │   ├── sources.yaml        ← Feeds, APIs, channels for this domain
│   │   └── .state/
│   │       └── pulls.json      ← Source pull state (git-tracked)
│   ├── finance/
│   │   ├── domain.yaml
│   │   ├── sources.yaml
│   │   └── .state/
│   │       └── pulls.json
│   ├── career/
│   │   ├── domain.yaml
│   │   ├── sources.yaml
│   │   └── .state/
│   │       └── pulls.json
│   └── learning/
│       ├── domain.yaml
│       ├── sources.yaml
│       └── .state/
│           └── pulls.json
│
├── wiki/
│   ├── index.md
│   ├── _meta/
│   │   ├── taxonomy.md
│   │   └── .manifest.json
│   ├── _raw/                   ← Staging area for unprocessed notes
│   ├── concepts/               ← Global concepts
│   ├── entities/               ← People, tools, orgs
│   ├── decisions/              ← ADRs, decision records
│   ├── projects/               ← Per-project knowledge
│   │   ├── project-alpha/
│   │   └── project-beta/
│   └── synthesis/              ← Cross-domain analyses
│
├── raw/                        ← Immutable source material
│   ├── papers/
│   ├── transcripts/
│   ├── exports/
│   └── screenshots/
│
└── secrets/                    ← .gitignore'd, local-only
    ├── .gitkeep
    └── README.md               ← Instructions for secrets setup
```

### Instance Configuration (`lifeos.yaml`)

```yaml
# lifeos.yaml — Instance-specific configuration
instance:
  name: "Personal LifeOS"
  owner: "dewdad"
  gitlab_project: "dewdad/lifeos-personal"
  system_version: "0.1.0"  # Expected .system/ version

identity:
  timezone: "Asia/Jerusalem"
  locale: "en-US"
  
domains:
  - health
  - finance
  - career
  - learning

agent_config:
  # How agents should behave in THIS instance
  default_branch: main
  mr_required: true           # Force MR workflow (no direct push)
  auto_merge: false           # Require human approval on MRs
  stale_wip_timeout_minutes: 30
  max_parallel_agents: 3

scheduling:
  source_pull: "0 3 * * *"   # Daily 3am
  wiki_lint: "0 4 * * *"     # Daily 4am
  morning_brief: "0 7 * * *" # Daily 7am
  weekly_review: "0 20 * * 0" # Sunday 8pm
```

---

## 7. Agent Bootstrap Flow

When ANY agent enters a LifeOS workspace, it follows this sequence:

```
1. READ .system/AGENT_BOOTSTRAP.md
   └─ Contains: Quick-start protocol, pointer to full docs

2. READ lifeos.yaml
   └─ Contains: Instance identity, domains, agent config

3. SYNC: git pull --recurse-submodules
   └─ Ensures latest code AND latest .system/

4. CHECK WORK QUEUE:
   glab issue list --label "state:ready" --sort priority
   └─ Shows available work ordered by priority

5. CLAIM & EXECUTE (per coordination protocol)
   └─ See Section 3.3

6. ON COMPLETION: Update state, create MR, pick next
```

---

## 8. Upgrade Path

LifeOS instances upgrade their `.system/` by pulling from the source repo:

```bash
# Check current version
cat .system/VERSION

# Pull latest
cd .system && git fetch origin && git checkout main && git pull && cd ..

# Or via submodule command
git submodule update --remote .system

# Commit the submodule pointer update
git add .system
git commit -m "chore: upgrade .system to $(cat .system/VERSION)"
git push
```

The `scripts/maintenance/upgrade-system.sh` automates this with:
- Version comparison (skip if already latest)
- Changelog display (show what's new)
- Compatibility check (against `lifeos.yaml#instance.system_version`)
- Automatic commit & push

---

## 9. GitLab Project Configuration

### Labels (Standard Set — Created by Bootstrap)

```bash
# States (mutually exclusive, managed by protocol)
glab label create "state:inbox" --color "#E4E669" --description "New, untriaged"
glab label create "state:ready" --color "#0E8A16" --description "Triaged, available"
glab label create "state:wip" --color "#D93F0B" --description "Claimed, in progress"
glab label create "state:review" --color "#0052CC" --description "MR open"
glab label create "state:blocked" --color "#B60205" --description "Waiting on dependency"

# Priority (P0-P3)
glab label create "P0:critical" --color "#B60205"
glab label create "P1:high" --color "#D93F0B"
glab label create "P2:medium" --color "#FBCA04"
glab label create "P3:low" --color "#0E8A16"

# Type
glab label create "type:task" --color "#FBCA04"
glab label create "type:research" --color "#5319E7"
glab label create "type:decision" --color "#D93F0B"
glab label create "type:maintenance" --color "#C5DEF5"
glab label create "type:source-item" --color "#BFD4F2"

# Domain (created per-instance from lifeos.yaml)
# glab label create "domain:health" --color "#0E8A16"
# glab label create "domain:finance" --color "#0052CC"
# ... etc

# Source (auto-created by source-pull)
# glab label create "source:huberman-podcast" --color "#BFD4F2"
# ... etc

# Agent tracking
glab label create "agent:claimed" --color "#E4E669" --description "Lock indicator"
```

### Protected Branch Rules

```
main:
  - No direct push (MR required)
  - Minimum 0 approvals (auto-merge allowed if agent_config.auto_merge=true)
  - CI must pass
```

### Board Configuration

```
Default Board: "Work Pipeline"
  Lists (by label):
    1. state:inbox
    2. state:ready
    3. state:wip
    4. state:review
    5. Closed (done)
```

---

## 10. CI/CD Pipeline (Instance Level)

The instance `.gitlab-ci.yml` includes fragments from `.system/`:

```yaml
# .gitlab-ci.yml (in LifeOS instance root)
include:
  - local: '.system/templates/ci/wiki-pipeline.yml'
  - local: '.system/templates/ci/source-pipeline.yml'
  - local: '.system/templates/ci/maintenance-pipeline.yml'

stages:
  - validate
  - maintain
  - publish

# Instance-specific overrides
variables:
  WIKI_DIR: "wiki"
  DOMAINS_DIR: "domains"
  PUBLISH_BRANCH: "main"
```

---

## 11. Multi-Machine Operation

Because all coordination flows through GitLab (remote state), agents on different machines work seamlessly:

```
Machine A (Windows, OpenCode)          Machine B (WSL, Claude Code)
    │                                       │
    │ glab issue list → picks #42           │ glab issue list → sees #42 is wip
    │ git checkout -b issue/42-auth         │ picks #43 instead
    │ ...works...                           │ git checkout -b issue/43-feeds
    │ git push                              │ ...works...
    │ glab mr create                        │ git push
    │                                       │ glab mr create
    ▼                                       ▼
┌─────────────────────────────────────────────────────────────┐
│  GitLab (dewdad/lifeos-personal)                             │
│  • Issue #42: state:review, assigned:agent-A                 │
│  • Issue #43: state:review, assigned:agent-B                 │
│  • MR !7: issue/42-auth → main                              │
│  • MR !8: issue/43-feeds → main                             │
└─────────────────────────────────────────────────────────────┘
```

---

## 12. Setup Sequence (New Instance)

```bash
# 1. Install prerequisites
.system/scripts/setup/install-glab.sh   # Or winget install glab

# 2. Authenticate with GitLab
glab auth login --hostname gitlab.com

# 3. Create LifeOS GitLab project
glab repo create lifeos-personal --private \
  --description "Personal LifeOS instance"

# 4. Initialize local repo with .system submodule
git init lifeos-personal && cd lifeos-personal
git submodule add https://gitlab.com/dewdad/knowledge-system-work.git .system

# 5. Run bootstrap (creates folder structure, labels, board)
.system/scripts/setup/bootstrap.sh

# 6. Configure domains (interactive or from template)
cp .system/templates/instance/domains/_example/* domains/health/
# Edit domains/health/sources.yaml with your sources

# 7. Initial commit & push
git add . && git commit -m "feat: initialize LifeOS instance"
git push -u origin main

# 8. Verify
glab issue list  # Should show any auto-created issues from bootstrap
```

---

## 13. Design Principles

| Principle | Implementation |
|---|---|
| **Stateless agents** | All state in GitLab (issues, labels) + git. No daemon required. |
| **Graceful degradation** | Agent crash → branch preserves work, lock times out, another agent reclaims. |
| **Single source of truth** | GitLab issues = work state. Git = content state. No local-only state that matters. |
| **Domain isolation** | Domains scope both sources AND work, enabling safe parallelism. |
| **Upgrade without breaking** | Submodule pinning + semver + compatibility checks. |
| **Machine-agnostic** | glab CLI + git = works on Windows, WSL, macOS, Linux. |
| **Observable** | `glab issue list`, `glab mr list`, git log = full visibility into system state. |
| **Pull-based intake** | Sources are pulled on schedule, creating issues. No push/webhook dependency. |

---

## 14. Comparison with Previous Architecture

| Aspect | Previous (v0) | Current (v1) |
|---|---|---|
| Orchestrator | Hermes Agent (doesn't exist) | Any AI agent following protocol |
| Coordination | None specified | GitLab labels + assignment + branches |
| Reusability | Single-repo monolith | Submodule, versionable, upgradeable |
| Sources | Vague "ingest pipeline" | Structured per-domain source configs |
| Multi-machine | Not addressed | First-class via GitLab remote state |
| Crash recovery | Not addressed | Stale-lock timeout + branch preservation |
| Setup | Manual | Scripted bootstrap |
| Agent entry | Assumed Hermes | AGENT_BOOTSTRAP.md protocol |