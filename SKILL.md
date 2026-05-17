# Knowledge Work System (KSW)

> AI-native knowledge management. Domain-driven source ingestion, structured wiki, issue coordination, and synthesis — orchestrated by agents.

## When to Use

- User says "init ksw", "set up knowledge system", "bootstrap knowledge management"
- User references domains, sources, wiki pages, triage, morning brief, synthesis
- User asks to "pull sources", "triage inbox", "review domain", "generate brief"
- User wants structured knowledge capture from any input (articles, videos, notes, exports)
- User wants to connect a project workspace to their KSW hub ("link to ksw", "satellite", "bridge")
- User says "sat board", "sat claim", "sat status" or references `.ksw-link.yaml`

## Commands

### Hub Commands (full system)

| Command | Action |
|---------|--------|
| `/init` | Bootstrap KSW — choose hub or satellite mode |
| `/add-domain <name>` | Add a new knowledge domain |
| `/add-source <domain> <type> <id>` | Add source to a domain |
| `/triage` | Classify and prioritize inbox items |
| `/pull [domain]` | Pull from sources (all or specific domain) |
| `/ingest <path>` | Process raw material into wiki |
| `/synthesize` | Cross-domain pattern detection |
| `/review <domain>` | Domain health check |
| `/brief` | Generate morning/status brief |
| `/graph-build` | Rebuild wikilink graph index |
| `/status` | Show system state overview |

### Satellite Commands (bridge to hub)

| Command | Action |
|---------|--------|
| `/sat board` | Show current task board from hub (filtered by satellite label) |
| `/sat claim <ID>` | Claim a ready issue, create local branch |
| `/sat done <ID>` | Mark issue complete (→ review) |
| `/sat blocked <ID> <reason>` | Mark issue blocked |
| `/sat release <ID>` | Unclaim issue (→ ready) |
| `/sat new <title>` | Create new issue on hub (inbox) |
| `/sat log <ID> <note>` | Add progress note to issue |
| `/sat contribute <path>` | Push a wiki page/decision to hub |
| `/sat status` | Show what this workspace is working on |
| `/sat brief` | Fetch and display the latest morning brief |

---

## /init — Bootstrap Knowledge Work System

Creates the complete workspace. Supports two modes:
- **Hub**: Full KSW system — domains, sources, wiki, issue board, synthesis, scheduling
- **Satellite**: Lightweight bridge — connects a project workspace to an existing hub

### Prerequisites

```bash
# Git initialized?
git rev-parse --is-inside-work-tree

# Platform CLI available? (one of these — required for hub and satellite)
glab auth status   # GitLab
gh auth status     # GitHub
# Neither authenticated → satellite and hub modes unavailable, hub can use local mode

# Required by generated hooks/workflows when installed
yq --version
jq --version

# Optional integrations
markitdown --version  # pip install markitdown[all]
yt-dlp --version      # YouTube sources
```

### Step 0: Choose Mode

Ask user:

> **What role should this workspace play?**
> 1. **Hub** — Central KSW repository (issue board, wiki, domains, synthesis)
> 2. **Satellite** — Project workspace that bridges to an existing KSW hub

If this directory already contains `ksw.yaml` → warn "KSW hub already initialized here."
If this directory already contains `.ksw-link.yaml` → warn "Satellite already linked here."

Record choice. Proceed to Step 1.

### Step 1: Authenticate & Select Repository

#### 1a. Platform Authentication

Check available CLIs:
```bash
glab auth status 2>&1   # Check GitLab
gh auth status 2>&1     # Check GitHub
```

- If neither authenticated → satellite unavailable; hub may continue in `local` mode, or prompt: "Run `glab auth login` or `gh auth login` first"
- If both authenticated → ask which platform hosts (or will host) the KSW hub
- Record platform choice

#### 1b. Repository Selection

**Hub mode:**
```bash
# List user's repos
glab repo list --mine          # GitLab
gh repo list --limit 20        # GitHub

# Ask: Use existing repo or create new?
# If create:
glab project create --name "<name>" --description "Knowledge Work System"
gh repo create "<name>" --description "Knowledge Work System" --private

# If existing: verify it's empty or has KSW structure
```

**Satellite mode:**
```bash
# List user's repos — filter for likely KSW hubs
glab repo list --mine          # GitLab
gh repo list --limit 20        # GitHub

# Ask: Which repo is your KSW hub?
# Verify hub has KSW labels:
glab label list -R <selected_path> | grep "state:inbox"
gh label list -R <selected_path> | grep "state:inbox"

# If no KSW labels → warn: "Selected repo doesn't appear to be a KSW hub. Run /init as hub there first."
```

Record `project_path`. Proceed based on mode:
- **Hub** → Step 2 — see [Hub Init Flow](#hub-init-flow) below
- **Satellite** → Step 2 — see [Satellite Init Flow](#satellite-init-flow) below

---

## Hub Init Flow

Continues from Step 1 when mode = hub.

### Step 2: Detect Platform

Already determined in Step 1. Platform stored as:
- `gitlab` → primary supported target, uses `glab` CLI
- `github` → documented command surface, uses `gh` CLI; verify generated hooks before unattended use
- `local` → filesystem-only queue (hub only; no satellites, no remote automation)

### Step 3: Create Directory Structure

```
<project_root>/
├── .ksw/
│   ├── queue/               ← Local task queue (platform:local)
│   │   ├── inbox/
│   │   ├── ready/
│   │   ├── wip/
│   │   ├── done/
│   │   └── blocked/
│   ├── workflows/           ← Generated workflow docs (agent reads these)
│   ├── state/
│   └── cache/
├── domains/
├── wiki/
│   ├── _meta/
│   │   └── briefs/
│   ├── concepts/
│   ├── entities/
│   ├── decisions/
│   ├── projects/
│   ├── synthesis/
│   └── _graph/
├── raw/
│   ├── papers/
│   ├── transcripts/
│   ├── exports/
│   └── screenshots/
├── ksw.yaml
└── AGENTS.md
```

Create ALL directories with `mkdir -p` (bash) or `New-Item -Force` (PowerShell).

### Step 4: Generate ksw.yaml

```yaml
# ksw.yaml — Knowledge Work System Configuration
# Generated by /init (hub mode) on <TIMESTAMP>

instance:
  name: "<project_name>"
  owner: "<detected_username>"
  platform: "<gitlab|github|local>"
  project_path: "<owner/repo or local path>"
  mode: "hub"

identity:
  timezone: "<detected_or_ask>"
  locale: "en-US"

domains: []

satellites: []          # Populated when satellites register via /init satellite

coordination:
  mode: "<solo|team>"
  default_branch: main
  mr_required: true
  stale_wip_timeout_minutes: 30
  max_parallel_agents: 3

scheduling:
  source_pull: "0 3 * * *"
  wiki_lint: "0 4 * * *"
  morning_brief: "0 7 * * *"
  weekly_review: "0 20 * * 0"

wiki:
  format: obsidian
  wikilinks: true
  frontmatter: true
  graph: true

tools:
  markitdown: auto    # auto | path | disabled
```

### Step 5: Generate AGENTS.md

Write `AGENTS.md` to project root containing:

1. **System Overview** — "This project uses KSW. Flow: Sources → Issues/Queue → Wiki → Synthesis"
2. **Quick Start** — Read ksw.yaml, check for work, claim+branch+do+review
3. **Structure** — Directory tree with descriptions (from Step 2)
4. **Domains** — Auto-list from ksw.yaml
5. **Workflows Table** — Command/trigger/description for all workflows
6. **Coordination Rules** — Platform, mode, branch naming (`ksw/<ID>-<slug>`), lock rules
7. **Wiki Format** — Obsidian markdown, wikilinks, frontmatter, one-concept-per-page
8. **Reference** — "Read `.ksw/workflows/<name>.md` for detailed execution steps"

### Step 6: Create .gitignore entries

Append to `.gitignore`:
```
# KSW internals
.ksw/cache/
.ksw/state/
secrets/
```

### Step 7: Platform Setup

Create all coordination labels:

| Label | Color | Description |
|-------|-------|-------------|
| `state:inbox` | `#E4E669` | New, untriaged |
| `state:ready` | `#0E8A16` | Triaged, available |
| `state:wip` | `#D93F0B` | In progress |
| `state:review` | `#0052CC` | MR/PR open |
| `state:blocked` | `#B60205` | Blocked |
| `P0:critical` | `#B60205` | Immediate |
| `P1:high` | `#D93F0B` | This week |
| `P2:medium` | `#FBCA04` | This sprint |
| `P3:low` | `#0E8A16` | Backlog |
| `type:task` | `#FBCA04` | Actionable work |
| `type:research` | `#5319E7` | Investigation |
| `type:decision` | `#D93F0B` | Needs decision |
| `type:maintenance` | `#C5DEF5` | Housekeeping |
| `type:source-item` | `#BFD4F2` | From source pull |
| `satellite:<name>` | `#1D76DB` | Routed to satellite workspace (created per-satellite during satellite init) |

**Platform commands:**
- GitLab: `glab label create "<label>" --color "<color>" --description "<desc>"`
- GitHub: `gh label create "<label>" --color "<color without #>" --description "<desc>"`
- Local: Create `.ksw/queue/` subdirectories (done in Step 2)

For local mode, each queue item is a markdown file with frontmatter:
```yaml
---
id: "<YYYYMMDD-HHMMSS-slug>"
title: "<title>"
domain: "<domain>"
type: "<type>"
priority: "<P0-P3>"
state: "<inbox|ready|wip|blocked|done>"
created: "<ISO8601>"
---
```

### Step 8: Generate Workflow Documentation

Create `.ksw/workflows/` with these files. Each file follows the pattern:
**Trigger → Steps → Error Handling → Commit convention**.
Include platform-specific commands per the Platform Command Reference below.

| File | Purpose | Key Steps |
|------|---------|-----------|
| `source-pull.md` | Pull new items from domain sources | Select domains → read sources.yaml → check schedule against pulls.json → pull by type (RSS: fetch+parse XML, YouTube: yt-dlp --flat-playlist, API: HTTP GET, Git: API commits/releases) → create inbox items with labels → update pull state → commit |
| `issue-triage.md` | Classify and prioritize inbox items | List state:inbox items → for each: determine domain (keyword match to ksw.yaml domains), type (action verb→task, question→research, choose→decision, cleanup→maintenance), priority (urgency→P0, deadline→P1, default→P2, exploratory→P3) → apply labels + transition inbox→ready → add triage note with rationale. Ambiguous: add `needs:clarification`, leave in inbox. Batch: group by domain, apply in bulk. |
| `wiki-ingest.md` | Process raw material into wiki pages | Convert non-md files (markitdown if available) → extract knowledge units → classify (concept/entity/decision/project/synthesis) → resolve against existing wiki (merge or create) → write page with Obsidian frontmatter → cross-link with wikilinks → rebuild graph → commit |
| `wiki-synthesize.md` | Cross-domain pattern detection | Load graph index (or grep fallback) → inventory pages → detect patterns (3+ domain concepts, orphans, contradictions, inconsistent tags) → generate synthesis pages in wiki/synthesis/ → update _meta/_insights.md → create issues for actionable findings → rebuild graph |
| `graph-build.md` | Rebuild wikilink graph index | Scan wiki/*.md → extract frontmatter + outgoing [[wikilinks]] → build adjacency list → compute stats (incoming/outgoing counts, orphans, most-connected top 10, domain/category counts) → write wiki/_graph/graph.json → write wiki/_graph/orphans.md → report summary. Zero-LLM, deterministic. |
| `domain-review.md` | Weekly domain health check | Check source health (stale/broken in pulls.json) → issue health (count by state, stalled items) → wiki coverage (pages, recency) → generate report markdown → create issues for problems found |
| `issue-to-wiki.md` | Closed issues → wiki decision records | Read closed issue (type:decision or significant) → create ADR-style wiki page (Context/Decision/Rationale/Consequences) → cross-link bidirectionally → commit |
| `wiki-to-issue.md` | Wiki gaps → actionable issues | Identify gap from synthesis/orphans/review → classify (gap→research, contradiction→decision, missing→task) → create issue with wiki context → update wiki page with issue link |
| `morning-brief.md` | Daily system state summary | Gather: due items, in-flight, completed (24h), blocked, queue depth → source status (overdue pulls) → wiki activity (24h modifications) → compose brief (<50 lines) → write to wiki/_meta/briefs/YYYY-MM-DD.md |
| `hub-hooks.md` | Hook installation & maintenance | Detect AI tools → install agent hooks (opencode.yaml, CLAUDE.md) → install git hooks (post-commit, post-merge, pre-push, post-checkout) → coexistence with existing hooks (guard markers) → update procedure |
| `init-smoke-test.md` | Post-init verification | Check dependencies → validate config files → list/create/read one test issue or queue item → run graph-build on empty wiki → verify hooks are executable and platform commands resolve |

### Step 9: Install Agent Hooks

Detect AI tools in workspace (`.opencode/`, `.claude/`, `.cursor/`) and install lifecycle hooks.

**What gets installed:**
- **OpenCode**: `.opencode/hooks/ksw-hub.yaml` — session start (show inbox/stale WIP/brief status), session end (prompt graph-build, state verification, overdue pulls)
- **Claude Code**: Append to `CLAUDE.md` — equivalent on-start/on-wrap-up sections
- **No tools detected**: Skip — AGENTS.md provides equivalent guidance

Templates: `reference/hooks/hub/agents/` | Generated docs: `.ksw/workflows/hub-hooks.md`

### Step 10: Install Git Hooks

Write to `.git/hooks/` (or append with guard markers if hooks already exist):

| Hook | Purpose | Trigger |
|------|---------|---------|
| `post-commit` | Batch progress comment on issue (every 5th commit on `ksw/<ID>-*` branch) | Commit on issue branch |
| `post-merge` | Transition issue `state:wip` → `state:review` | Branch merge to main |
| `pre-push` | Warn on broken wikilinks (non-blocking) | Push |
| `post-checkout` | Display issue title/description | Switch to `ksw/<ID>-*` branch |

**Coexistence**: If hooks already exist (husky, lint-staged), append between `# [KSW-HUB-HOOK-START]` / `# [KSW-HUB-HOOK-END]` guard markers.

Make executable: `chmod +x .git/hooks/*`

Templates: `reference/hooks/hub/git/` | Generated docs: `.ksw/workflows/hub-hooks.md`

### Step 11: Completion

Output confirmation:
```
KSW Hub initialized successfully.

Platform: <platform>
Mode: <coordination_mode>
Config: ksw.yaml
Workflow docs: .ksw/workflows/

Installed:
  ✓ ksw.yaml (configuration)
  ✓ AGENTS.md (agent instructions)
  ✓ .ksw/workflows/ (9 workflow docs)
  ✓ Agent hooks (<detected_tool> lifecycle)
  ✓ Git hooks (post-commit, post-merge, pre-push, post-checkout)

Next steps:
  1. Add a domain:    /add-domain health
  2. Add a source:    /add-source health rss examine-research
  3. Pull sources:    /pull
  4. Check status:    /status
```

---

## Satellite Init Flow

Continues from Step 1 when mode = satellite. Installs persistent mechanisms so all future AI sessions and git operations automatically bridge to the hub.

### Step 2: Gather Satellite Config

1. **Workspace name**: Default to current directory name. Ask user to confirm/override.
2. **Default domain**: List available domains from hub labels:
   ```bash
   glab label list -R <hub_path> | grep "domain:"    # GitLab
   gh label list -R <hub_path> | grep "domain:"      # GitHub
   ```
   Ask user to pick a primary domain (pre-fills new issues).
3. **Satellite label**: Create `satellite:<workspace_name>` label on hub if not exists:
   ```bash
   glab label create "satellite:<name>" --color "#1D76DB" --description "Routed to <name> workspace" -R <hub_path>
   gh label create "satellite:<name>" --color "1D76DB" --description "Routed to <name> workspace" -R <hub_path>
   ```

### Step 3: Write .ksw-link.yaml

```yaml
# .ksw-link.yaml — Satellite bridge config
# Generated by /init (satellite mode) on <TIMESTAMP>

hub:
  platform: "<gitlab|github>"
  project_path: "<owner/ksw-hub>"
  default_branch: "main"

identity:
  workspace_name: "<workspace_name>"
  workspace_path: "<absolute_path>"
  satellite_label: "satellite:<workspace_name>"

preferences:
  default_domain: "<selected_domain>"
  progress_interval: 5          # Comment every N commits on issue branch
  auto_issue_ref: true          # prepare-commit-msg appends (KSW #ID)

active_claims: []               # Issue IDs currently being worked here
```

### Step 4: Update .gitignore

Append:
```
# KSW satellite (personal config, not shared)
.ksw-link.yaml
```

### Step 5: Augment AGENTS.md

Append KSW Satellite section to workspace AGENTS.md (create file if missing). This gives agents judgment heuristics for:
- Session awareness (check active claims, routed work)
- Decision detection (offer to record as wiki decision)
- Knowledge extraction (offer to contribute to hub wiki)
- Issue creation (with satellite + domain labels)
- Context linking (KSW #ID references in commits)
- What NOT to do (no trivial artifacts, no duplicates, always ask first)

Template: `reference/hooks/satellite/agents-md-section.md`

### Step 6: Install Agent Hooks

Detect AI tools (`.opencode/`, `.claude/`, `.cursor/`) and install lifecycle hooks:

**What gets installed:**
- **OpenCode**: `.opencode/hooks/ksw-satellite.yaml` — session start (show hub, active claims, routed work), session end (prompt progress logging, decision contribution)
- **Claude Code**: Append to `CLAUDE.md` — equivalent start/wrap-up sections
- **No tools detected**: Skip — AGENTS.md section provides equivalent guidance

Templates: `reference/hooks/satellite/agents/`

### Step 7: Install Git Hooks

Write to `.git/hooks/` (append with guard markers if hooks exist):

| Hook | Purpose | Trigger |
|------|---------|---------|
| `post-commit` | Comment on hub issue — explicit `KSW #ID` refs or batch every N commits on `issue/<ID>-*` branches | Commit |
| `post-merge` | Transition hub issue `state:wip` → `state:review`, remove from active_claims | Branch merge |
| `prepare-commit-msg` | Auto-append `(KSW #ID)` on issue branches | Commit message creation |

**Coexistence**: Append between `# [KSW-SAT-HOOK-START]` / `# [KSW-SAT-HOOK-END]` guard markers if hooks already exist.

Make executable: `chmod +x .git/hooks/*`

Templates: `reference/hooks/satellite/git/`

### Step 8: Register with Hub

Register satellite in the hub's `ksw.yaml` (via API or sparse checkout):

```bash
# Clone hub, update ksw.yaml, push
TMPDIR=$(mktemp -d "${TMPDIR:-/tmp}/ksw-register.XXXXXX")
trap 'rm -rf "$TMPDIR"' EXIT
git clone --no-checkout --depth 1 <hub_url> "$TMPDIR"
cd "$TMPDIR"
git sparse-checkout set ksw.yaml
git checkout
yq -i '.satellites += [{"name": "<workspace_name>", "label": "satellite:<workspace_name>", "default_domain": "<domain>", "registered_at": "<ISO8601>"}]' ksw.yaml
git add ksw.yaml
git commit -m "feat: register satellite <workspace_name>"
git push
```

If push fails (permissions, protected branch): report the failure and continue. Registration is informational — satellite works without it, but the user should know hub inventory is incomplete.

### Step 9: Verify & Complete

1. Dry-run connectivity test:
   ```bash
   glab issue list -R <hub> --label "satellite:<name>" --per-page 1
   ```
2. Display summary:

```
KSW Satellite initialized.

Hub: <project_path> (<platform>)
Workspace: <workspace_name>
Label: satellite:<workspace_name>
Domain: <default_domain>

Installed:
  ✓ .ksw-link.yaml (config)
  ✓ AGENTS.md (KSW Satellite section appended)
  ✓ <agent_tool> hooks (session lifecycle)
  ✓ .git/hooks/post-commit (progress tracking)
  ✓ .git/hooks/post-merge (completion detection)
  ✓ .git/hooks/prepare-commit-msg (issue ref injection)

This workspace is now tracked by KSW. All future AI sessions
will have KSW context, and git operations will report progress
to hub issues automatically.

On-demand: /sat board, /sat claim, /sat done, /sat new, /sat contribute
```

---

## /add-domain — Add Knowledge Domain

1. Validate name: lowercase, alphanumeric + hyphens, no spaces
2. Create structure:
   ```
   domains/<name>/
   ├── domain.yaml
   ├── sources.yaml
   └── .state/
       └── pulls.json    ← {}
   ```
3. Write `domains/<name>/domain.yaml`:
   ```yaml
   name: <name>
   description: "<ask user or infer>"
   color: "<assign from palette>"
   goals: []
   review_schedule: weekly
   wiki_path: "wiki/projects/<name>"
   related_domains: []
   ```
4. Write `domains/<name>/sources.yaml`:
   ```yaml
   domain: <name>
   sources: []
   ```
5. Create `wiki/projects/<name>/`
6. Update `ksw.yaml` → add to `domains:` list
7. Create platform label: `domain:<name>` with assigned color
8. Regenerate AGENTS.md domains section
9. Commit: `git commit -m "feat: add domain <name>"`

---

## /add-source — Add Source to Domain

1. Parse: `<domain> <type> <id>` — type: rss|youtube|api|git|email|chat|calendar|manual
2. Validate domain exists in `domains/`
3. Prompt for type-specific fields:
   - **rss**: url
   - **youtube**: channel_id or playlist_id
   - **api**: endpoint, auth_ref (optional)
   - **git**: repo (owner/repo), events (commits|releases|issues|tags)
   - **manual**: nothing extra
4. Append to `domains/<domain>/sources.yaml`:
   ```yaml
   - id: <id>
     type: <type>
     pull_schedule: daily
     auto_triage: true
     <type_specific_fields>
   ```
5. Initialize in `.state/pulls.json`: `{ "<id>": { "last_pull": null, "items_pulled": 0 } }`
6. Commit: `git commit -m "feat(<domain>): add source <id>"`

---

## Platform Command Reference

All workflows use this abstraction. Pick commands based on `ksw.yaml#instance.platform`:

### Hub Operations

| Action | GitLab (`glab`) | GitHub (`gh`) | Local |
|--------|-----------------|---------------|-------|
| List inbox | `glab issue list --label "state:inbox"` | `gh issue list --label "state:inbox"` | `ls .ksw/queue/inbox/` |
| List ready | `glab issue list --label "state:ready"` | `gh issue list --label "state:ready"` | `ls .ksw/queue/ready/` |
| Create issue | `glab issue create --title "..." --label "..."` | `gh issue create --title "..." --label "..."` | Create `.ksw/queue/inbox/<id>.md` |
| Claim (assign+wip) | `glab issue update <ID> --assignee "@me" --unlabel "state:ready" --label "state:wip"` | `gh issue edit <ID> --add-assignee "@me" --remove-label "state:ready" --add-label "state:wip"` | `mv .ksw/queue/ready/<file> .ksw/queue/wip/` |
| Complete (→review) | `glab issue update <ID> --unlabel "state:wip" --label "state:review"` | `gh issue edit <ID> --remove-label "state:wip" --add-label "state:review"` | `mv .ksw/queue/wip/<file> .ksw/queue/done/` |
| Close | `glab issue close <ID>` | `gh issue close <ID>` | `mv to done/ + add closed_at` |
| Add comment | `glab issue note <ID> --message "..."` | `gh issue comment <ID> --body "..."` | Append to `## Notes` section |
| Apply labels | `glab issue update <ID> --label "x" --unlabel "y"` | `gh issue edit <ID> --add-label "x" --remove-label "y"` | Edit frontmatter |
| List by satellite | `glab issue list --label "satellite:<name>"` | `gh issue list --label "satellite:<name>"` | N/A |
| Route to satellite | `glab issue update <ID> --label "satellite:<name>"` | `gh issue edit <ID> --add-label "satellite:<name>"` | N/A |

### Satellite Operations (remote — uses `-R <hub>`)

| Action | GitLab (`glab`) | GitHub (`gh`) |
|--------|-----------------|---------------|
| List routed work | `glab issue list -R <hub> --label "satellite:<name>,state:ready"` | `gh issue list -R <hub> --label "satellite:<name>,state:ready"` |
| List my WIP | `glab issue list -R <hub> --label "satellite:<name>,state:wip" --assignee "@me"` | `gh issue list -R <hub> --label "satellite:<name>,state:wip" --assignee "@me"` |
| Claim (remote) | `glab issue update <ID> -R <hub> --assignee "@me" --unlabel "state:ready" --label "state:wip"` | `gh issue edit <ID> -R <hub> --add-assignee "@me" --remove-label "state:ready" --add-label "state:wip"` |
| Complete (remote) | `glab issue update <ID> -R <hub> --unlabel "state:wip" --label "state:review"` | `gh issue edit <ID> -R <hub> --remove-label "state:wip" --add-label "state:review"` |
| Create (remote) | `glab issue create -R <hub> --title "..." --label "state:inbox,satellite:<name>,domain:<d>"` | `gh issue create -R <hub> --title "..." --label "state:inbox,satellite:<name>,domain:<d>"` |
| Comment (remote) | `glab issue note <ID> -R <hub> --message "..."` | `gh issue comment <ID> -R <hub> --body "..."` |

---

## Workflow Summaries

Detailed execution steps live in `.ksw/workflows/*.md` (generated by `/init`).
These summaries provide routing context for the agent.

### Source Pull (`/pull [domain]`)

Pull new items from domain sources into the inbox.
**Trigger**: Scheduled, manual, or after adding a new source.
**Flow**: For each domain → read sources.yaml → check if due (pulls.json vs schedule) → pull by source type → derive stable `source_item_id` (source id + canonical URL/external id hash) → skip if already seen or issue exists → create inbox items with `state:inbox, domain:<d>, type:source-item` → update pull state → commit.
**Error**: Source unreachable → log in pulls.json, increment failures, after 5 → create maintenance issue. Never block other sources.

### Issue Triage (`/triage`)

Classify and prioritize all inbox items.
**Trigger**: After source-pull, new items appear, or manual.
**Flow**: List all `state:inbox` items → for each, determine:
- **Domain**: Match content keywords to configured domains
- **Type**: action verb→task | question→research | choose/decide→decision | cleanup→maintenance
- **Priority**: explicit urgency→P0 | deadline→P1 | default→P2 | exploratory→P3

Apply labels, transition `state:inbox` → `state:ready`, add triage note with rationale.
**Ambiguous**: Add `needs:clarification` label, leave in inbox.
**Batch**: Group by domain, apply in bulk. Source items default to P2.

### Wiki Ingest (`/ingest <path>`)

Process raw material into structured wiki pages.
**Trigger**: File in `raw/`, manual, or after research.
**Flow**: Convert non-md (markitdown if available) → extract knowledge units → classify (concept/entity/decision/project/synthesis) → resolve against existing wiki (merge or create new) → write with Obsidian frontmatter + wikilinks → rebuild graph → commit.
**Rules**: One concept per page. Always wikilink. Every page has stable `id`, `aliases`, `domain`, `created`, `updated`, and `sources`. Claims that came from specific material include inline or section-level source references. No duplication.

### Wiki Synthesize (`/synthesize`)

Cross-domain pattern detection and insight generation.
**Trigger**: Weekly, after 10+ new wiki pages, or manual.
**Flow**: Load graph index (fallback: grep) → detect patterns (concepts in 3+ domains, orphans, contradictions, inconsistent tags) → generate synthesis pages → update `_meta/_insights.md` → create issues for actionable findings → rebuild graph.

### Graph Build (`/graph-build`)

Rebuild wikilink graph index. Zero-LLM, deterministic.
**Trigger**: After ingest, after synthesize, or manual.
**Flow**: Scan `wiki/**/*.md` → extract frontmatter + `[[wikilinks]]` → build adjacency list → compute stats (orphans, most-connected, domain/category counts) → write `wiki/_graph/graph.json` + `wiki/_graph/orphans.md`.
**Graceful degradation**: If graph.json missing, all workflows fall back to grep. Graph is optimization, never hard dependency.

### Domain Review (`/review <domain>`)

Weekly health check on a specific domain.
**Trigger**: Scheduled per domain.yaml, or manual.
**Flow**: Check source health (stale/broken) → issue health (count by state, stalled items) → wiki coverage (pages, recency) → generate report → create issues for problems.

### Issue to Wiki (automatic)

Closed issues with decisions/knowledge → wiki decision records.
**Trigger**: Issue with `type:decision` closed, or significant task closed.
**Flow**: Read closed issue → create ADR-style wiki page (Context/Decision/Rationale/Consequences) → cross-link → commit.

### Wiki to Issue (automatic)

Wiki gaps or contradictions → actionable issues.
**Trigger**: Synthesis reveals gap, contradiction found, or review identifies missing coverage.
**Flow**: Identify actionable insight → classify (gap→research, contradiction→decision, missing→task) → create issue with wiki context → update wiki with issue link.

### Morning Brief (`/brief`)

Daily system state summary.
**Trigger**: Scheduled daily, or manual.
**Flow**: Gather due items, in-flight, completed (24h), blocked, queue depth → source status → wiki activity → compose brief (<50 lines) → write to `wiki/_meta/briefs/YYYY-MM-DD.md`.

---

## Coordination Protocol

### State Machine

```
state:inbox → state:ready → state:wip → state:review → (closed/done)
                               ↓
                        state:blocked
```

### Team Mode Rules

1. Never push directly to default branch — branch + MR/PR
2. One issue = one branch — named `ksw/<ID>-<slug>`
3. Claim before working — assign + `state:wip`
4. Release if stuck — unassign + back to `state:ready`
5. After claiming, re-read the issue. If assignment/state did not stick, release and stop.
6. WIP locks expire after `stale_wip_timeout_minutes` (default 30)

### Solo Mode Rules

1. Move files between queue directories to transition state
2. No locking — single agent
3. Branch workflow optional (direct commits OK)

### Stale Lock Recovery

WIP items older than timeout → auto-release to ready. Partial work preserved on branch.

---

## /status — System State Overview

Report:
- Domains: count from `domains/`
- Queue: count per state (inbox/ready/wip/blocked)
- Wiki pages: count `.md` files in `wiki/` (excluding `_graph/`, `_meta/`)
- Last brief: most recent in `wiki/_meta/briefs/`
- Last pull: most recent `last_pull` from any `pulls.json`
- Graph: node/edge count from `graph.json` (if exists)

---

## Satellite Commands — Detail

These commands operate from a satellite workspace against the remote hub. All require `.ksw-link.yaml` present.

### /sat board

Show task board filtered to this satellite's label:

```bash
# GitLab
glab issue list -R <hub> --label "satellite:<name>" --per-page 20

# GitHub
gh issue list -R <hub> --label "satellite:<name>" --limit 20
```

Group output by state: ready → wip → blocked. Highlight items assigned to current user.

### /sat claim \<ID\>

1. Verify issue exists and is `state:ready`:
   ```bash
   glab issue view <ID> -R <hub> --output json | jq '.labels'
   ```
2. Assign + transition:
   ```bash
   # GitLab
   glab issue update <ID> -R <hub> --assignee "@me" --unlabel "state:ready" --label "state:wip"
   # GitHub
   gh issue edit <ID> -R <hub> --add-assignee "@me" --remove-label "state:ready" --add-label "state:wip"
   ```
3. Create local branch:
   ```bash
   git checkout -b issue/<ID>-<slug>
   ```
4. Update `.ksw-link.yaml`:
   ```bash
   yq -i '.active_claims += [<ID>]' .ksw-link.yaml
   ```

### /sat done \<ID\>

1. Transition issue:
   ```bash
   # GitLab
   glab issue update <ID> -R <hub> --unlabel "state:wip" --label "state:review"
   glab issue note <ID> -R <hub> --message "Work complete in `<workspace_name>`. Ready for review."
   # GitHub
   gh issue edit <ID> -R <hub> --remove-label "state:wip" --add-label "state:review"
   gh issue comment <ID> -R <hub> --body "Work complete in `<workspace_name>`. Ready for review."
   ```
2. Remove from active_claims:
   ```bash
   yq -i 'del(.active_claims[] | select(. == <ID>))' .ksw-link.yaml
   ```

### /sat blocked \<ID\> \<reason\>

```bash
# GitLab
glab issue update <ID> -R <hub> --unlabel "state:wip" --label "state:blocked"
glab issue note <ID> -R <hub> --message "Blocked: <reason> (from `<workspace_name>`)"
# GitHub
gh issue edit <ID> -R <hub> --remove-label "state:wip" --add-label "state:blocked"
gh issue comment <ID> -R <hub> --body "Blocked: <reason> (from `<workspace_name>`)"
```

### /sat release \<ID\>

Unclaim without completing — return to ready pool:

```bash
# GitLab
glab issue update <ID> -R <hub> --unassign "@me" --unlabel "state:wip" --label "state:ready"
# GitHub
gh issue edit <ID> -R <hub> --remove-assignee "@me" --remove-label "state:wip" --add-label "state:ready"
```

Remove from `active_claims` in `.ksw-link.yaml`.

### /sat new \<title\>

Create new issue on hub with satellite context:

```bash
# GitLab
glab issue create -R <hub> \
  --title "<title>" \
  --label "state:inbox,satellite:<name>,domain:<default_domain>"

# GitHub
gh issue create -R <hub> \
  --title "<title>" \
  --label "state:inbox,satellite:<name>,domain:<default_domain>"
```

Optionally add body with context from current workspace (file references, error traces, etc.).

### /sat log \<ID\> \<note\>

Add progress note to an issue:

```bash
# GitLab
glab issue note <ID> -R <hub> --message "[<workspace_name>] <note>"
# GitHub
gh issue comment <ID> -R <hub> --body "[<workspace_name>] <note>"
```

### /sat contribute \<path\>

Push a wiki page or decision record to the hub. Uses sparse checkout:

1. Create temp sparse clone of hub wiki/:
   ```bash
   TMPDIR=$(mktemp -d "${TMPDIR:-/tmp}/ksw-contribute.XXXXXX")
   trap 'rm -rf "$TMPDIR"' EXIT
   git clone --no-checkout --depth 1 <hub_url> "$TMPDIR"
   cd "$TMPDIR"
   git sparse-checkout set wiki/
   git checkout
   ```
2. Copy local file to appropriate wiki location:
   ```bash
   cp <source_path> wiki/<category>/<filename>.md
   ```
3. Add frontmatter if missing (contributed_from, date, domain)
4. Commit and push:
   ```bash
   git add wiki/
   git commit -m "feat(wiki): contribute <filename> from <workspace_name>"
   git push
   ```
5. Cleanup happens via the `trap` above.

### /sat status

Show current workspace state:

```
Satellite: <workspace_name>
Hub: <hub_path> (<platform>)
Label: satellite:<workspace_name>
Domain: <default_domain>

Active claims:
  #12 - Implement auth flow [state:wip]
  #15 - Fix database migration [state:wip]

Recent progress (last 5 commits with KSW refs):
  abc1234 Fix token refresh (KSW #12)
  def5678 Add migration script (KSW #15)
```

### /sat brief

Fetch the latest morning brief from hub:

```bash
# Find latest brief
LATEST=$(glab api projects/<hub_encoded>/repository/tree?path=wiki/_meta/briefs --per-page 1 --sort desc | jq -r '.[0].name')
# Fetch and display
glab api projects/<hub_encoded>/repository/files/wiki%2F_meta%2Fbriefs%2F${LATEST}/raw | cat
```

Or with GitHub:
```bash
LATEST=$(gh api repos/<hub>/contents/wiki/_meta/briefs --jq '.[-1].name')
gh api repos/<hub>/contents/wiki/_meta/briefs/${LATEST} --jq '.content' | base64 -d
```

---

## Schema: ksw.yaml

```yaml
instance:
  name: string
  owner: string
  platform: enum[gitlab, github, local]
  project_path: string
  mode: enum[hub, satellite]   # Determined at /init Step 0

identity:
  timezone: string       # IANA timezone
  locale: string         # xx-YY

domains: string[]

satellites: []           # Hub-only: registered satellite workspaces
  # - name: "frontend-app"
  #   label: "satellite:frontend-app"
  #   default_domain: "engineering"
  #   registered_at: "<ISO8601>"

coordination:
  mode: enum[solo, team]
  default_branch: string (default: main)
  mr_required: boolean (default: true, team only)
  stale_wip_timeout_minutes: integer (10-1440, default: 30)
  max_parallel_agents: integer (1-10, default: 3)

scheduling:              # cron expressions (advisory — agent checks if due)
  source_pull: string
  wiki_lint: string
  morning_brief: string
  weekly_review: string

wiki:
  format: enum[obsidian, markdown]
  wikilinks: boolean (default: true)
  frontmatter: boolean (default: true)
  graph: boolean (default: true)

tools:
  markitdown: enum[auto, disabled] | string
```

### Schema: .ksw-link.yaml (Satellite Only)

```yaml
hub:
  platform: enum[gitlab, github]
  project_path: string
  default_branch: string (default: main)

identity:
  workspace_name: string
  workspace_path: string
  satellite_label: string        # "satellite:<workspace_name>"

preferences:
  default_domain: string
  progress_interval: integer (1-20, default: 5)
  auto_issue_ref: boolean (default: true)

active_claims: integer[]         # Issue IDs currently claimed
```

---

## Notes

- Wiki format is Obsidian-compatible but works with any markdown viewer
- Local queue mode works without any external service (pure filesystem) — hub only
- All durable state is in git; platform issue state is remote system state and must be verified after mutation
- Scheduling fields are advisory unless you install CI schedules, cron, or an agent harness
- **Required for installed hooks**: `yq`; **required by many workflow snippets**: `jq`
- **Optional tools**: `markitdown` (converts Office/PDF/images/audio to markdown during ingest), `yt-dlp` (YouTube sources)
- **Graph**: auto-generated index, speeds up synthesize/review — never a hard dependency
- **Hub/Satellite model**: Hub is the system of record (orchestrated by autonomous agents like hermes-agent); satellites are project workspaces (developed with opencode/openwork) that bridge back via CLI commands
- **Satellite install-once**: After `/init` satellite, the workspace is permanently tracked — no skill reload needed. AGENTS.md + hooks carry behavior forward.
- **Dual-label routing**: Issues use `satellite:<name>` for workspace routing AND `domain:<name>` for semantic context. Hub can assign work to specific satellites by applying the satellite label.
- **Authentication**: Delegated entirely to platform CLI (`glab auth login` / `gh auth login`). No tokens stored in config files.
