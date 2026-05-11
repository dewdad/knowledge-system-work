# Planning: KWS Satellite Skill

> Install-once bridge that permanently connects isolated workspaces to a central KWS instance. After initialization, the workspace is reliably tracked by KWS — no skill reload required.

## Problem Statement

A user operates KWS in a dedicated GitLab repository (the "hub"). Their actual coding projects, agent sessions, and workspaces live in **separate directories/repos** that have no knowledge of KWS. Today, work done in those isolated contexts is invisible to KWS — tasks aren't tracked, decisions aren't captured, and knowledge doesn't flow back to the wiki.

### Concrete Gaps

1. Agent sessions in `~/projects/frontend-app/` can't claim or report progress on KWS issues
2. Decisions made during implementation in satellite projects aren't captured as wiki decision records
3. No way to create KWS issues from within a satellite workspace without switching context
4. Knowledge generated (patterns, learnings, ADRs) in satellite repos stays trapped there
5. Morning briefs can't report on work happening outside the KWS repo

## Proposed Solution: `kws-satellite` Skill

A skill that acts primarily as an **installer**. When invoked (`/kws-sat init`), it sets up persistent mechanisms in the workspace so that all future AI sessions and git operations automatically feed back into the central KWS hub. The skill itself is not needed after initialization — the installed artifacts carry the behavior forward.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  KWS Hub (GitLab repo)                                      │
│  ├── kws.yaml                                               │
│  ├── domains/                                               │
│  ├── wiki/                                                  │
│  └── Issue Board ← receives progress, knowledge, new issues │
└──────────────────────────┬──────────────────────────────────┘
                           │ glab/gh CLI (remote commands)
                           │
         ┌─────────────────┼─────────────────────────┐
         │                 │                          │
    ┌────▼───┐       ┌────▼───┐               ┌─────▼────┐
    │ Proj A │       │ Proj B │               │ Proj C   │
    │        │       │        │               │          │
    │ INSTALLED ARTIFACTS (persist after init):           │
    │ ├── .kws-link.yaml     (config)                    │
    │ ├── AGENTS.md section  (agent instructions)        │
    │ ├── .claude/hooks      (agent lifecycle hooks)     │
    │ └── .git/hooks/        (mechanical tracking)       │
    └────────┘       └────────┘               └──────────┘
```

### Core Principle: Install Once, Tracked Forever

The satellite skill's primary job is `/kws-sat init`. After that:
- **AGENTS.md** ensures every AI agent session starts with KWS context
- **Agent hooks** fire at session lifecycle boundaries to negotiate knowledge contribution
- **Git hooks** mechanically track progress without AI involvement

The skill also provides on-demand commands (board, claim, contribute) for explicit operations, but the default path is automatic.

---

## Three-Mechanism Architecture

### Mechanism 1: AGENTS.md Augmentation (Knowledge & Intent Negotiation)

**Purpose**: Give AI agents the *judgment* to identify what's worth capturing and how to negotiate knowledge flow with the user.

**Why AGENTS.md**: It's universal — read by Claude Code, OpenCode, Cursor, Windsurf, Gemini CLI, and any tool that respects workspace agent instructions. It persists across sessions without needing skill reloads.

**What gets installed** (appended to workspace AGENTS.md):

```markdown
## KWS Satellite — Automatic Knowledge Bridge

This workspace is connected to KWS hub: `<project_path>` (<platform>)
Config: `.kws-link.yaml`

### Your Responsibilities as an Agent in This Workspace

1. **Session Awareness**: At session start, check active claims:
   `glab issue list -R <hub> --label "state:wip" --assignee "@me"`
   If this workspace has active claims (in .kws-link.yaml#active_claims),
   orient your work around them and report progress at session end.

2. **Decision Detection**: When you help the user make an architectural,
   design, or strategic decision — offer to record it as a KWS decision
   record. Push via sparse checkout to hub wiki/decisions/.

3. **Knowledge Extraction**: When the session produces reusable knowledge
   (patterns, gotchas, how-tos, evaluations), assess whether it belongs
   in the KWS wiki. Ask the user: "This looks like knowledge worth
   capturing in KWS under [domain]. Want me to contribute it?"

4. **Issue Creation**: When you discover bugs, technical debt, or future
   work items, offer to create a KWS issue:
   `glab issue create -R <hub> --title "..." --label "state:inbox,..."`

5. **Context Linking**: When working on code that relates to a KWS issue,
   reference it in commit messages: "Fix auth flow (KWS #12)"

### What NOT to Do
- Don't push trivial session artifacts (debugging notes, scratch work)
- Don't create duplicate issues — check existing board first
- Don't auto-push without user confirmation (ask first, always)
- Don't log progress on every minor step — summarize at meaningful milestones
```

**Key design choice**: The AGENTS.md section gives agents *heuristics* for judgment, not rigid automation. It's the "smart" layer that understands intent and negotiates with the user about what's worth capturing.

---

### Mechanism 2: Agent Hooks (Session Lifecycle Automation)

**Purpose**: Trigger specific KWS-aware actions at session boundaries without relying on the agent to "remember" from AGENTS.md alone.

**Why hooks**: AGENTS.md is read once at session start and may be deprioritized as context fills. Hooks fire reliably at specific lifecycle points regardless of context pressure.

**What gets installed**:

#### For OpenCode (`.opencode/hooks/` or equivalent):

```yaml
# .opencode/hooks/kws-satellite.yaml
on_session_start:
  description: "Load KWS context"
  run: |
    echo "=== KWS Satellite Active ==="
    echo "Hub: $(yq '.hub.project_path' .kws-link.yaml)"
    echo ""
    echo "Your active claims:"
    glab issue list -R $(yq '.hub.project_path' .kws-link.yaml) --label "state:wip" --assignee "@me" 2>/dev/null || echo "  (none)"
    echo ""
    echo "Ready to pick up:"
    glab issue list -R $(yq '.hub.project_path' .kws-link.yaml) --label "state:ready" --per-page 5 2>/dev/null || echo "  (none)"

on_session_end:
  description: "KWS wrap-up prompt"
  prompt: |
    Before closing, review what was accomplished this session:
    1. If you worked on a claimed KWS issue, summarize progress and log it
    2. If significant decisions were made, offer to contribute them
    3. If new work was discovered, offer to create KWS issues
    Run: glab issue note <ID> -R <hub> --message "<summary>" for any active claims.
```

#### For Claude Code (`.claude/hooks.json` or CLAUDE.md):

```markdown
<!-- Appended to CLAUDE.md -->
## Session Hooks

### On Start
Run this silently at session start to load KWS context:
- Read .kws-link.yaml → identify hub
- List my active claims: `glab issue list -R <hub> --label "state:wip" --assignee "@me"`
- Mention active claims to the user if any exist

### On Wrap-Up (user says "done", "wrap up", "that's all", or session ends)
Before finishing:
- Summarize session accomplishments against any active KWS claims
- Ask: "Should I log this progress to KWS issue #<ID>?"
- Ask: "Any knowledge worth contributing to the hub wiki?"
```

**Key design choice**: Hooks are the "reliable trigger" layer. They don't decide *what* to capture (that's AGENTS.md's job) — they ensure the agent is *prompted* to consider KWS at the right moments.

---

### Mechanism 3: Git Hooks (Mechanical Task Tracking & State)

**Purpose**: Reliably track task progress and persist state changes without requiring AI involvement. These fire on every commit/push regardless of whether an AI agent is present.

**Why git hooks**: They're deterministic, always-on, and work even when the user is coding without an AI assistant. They handle the "bookkeeping" that should never be forgotten.

**What gets installed** (in `.git/hooks/`):

#### `post-commit` — Progress Tracking

```bash
#!/bin/bash
# .git/hooks/post-commit (installed by /kws-sat init)
# Purpose: Auto-comment on claimed KWS issues when commits reference them

KWS_LINK=".kws-link.yaml"
[ -f "$KWS_LINK" ] || exit 0

HUB=$(yq -r '.hub.project_path' "$KWS_LINK")
PLATFORM=$(yq -r '.hub.platform' "$KWS_LINK")
MSG=$(git log -1 --format=%s)
BRANCH=$(git branch --show-current)

# Strategy 1: Explicit issue reference in commit message
if [[ "$MSG" =~ KWS[[:space:]]*#([0-9]+) ]] || [[ "$MSG" =~ \(KWS\ #([0-9]+)\) ]]; then
  ID="${BASH_REMATCH[1]}"
  if [ "$PLATFORM" = "gitlab" ]; then
    glab issue note "$ID" -R "$HUB" --message "Progress from \`$(basename $PWD)\`: $MSG" &
  else
    gh issue comment "$ID" -R "$HUB" --body "Progress from \`$(basename $PWD)\`: $MSG" &
  fi
fi

# Strategy 2: Branch name matches issue/<ID>-* pattern
if [[ "$BRANCH" =~ ^issue/([0-9]+)- ]]; then
  ID="${BASH_REMATCH[1]}"
  # Only comment on milestones (every 5th commit on this branch), not every commit
  COMMIT_COUNT=$(git rev-list --count main.."$BRANCH" 2>/dev/null || echo "0")
  if (( COMMIT_COUNT % 5 == 0 )) && (( COMMIT_COUNT > 0 )); then
    SUMMARY=$(git log --oneline main.."$BRANCH" | tail -5 | head -5)
    if [ "$PLATFORM" = "gitlab" ]; then
      glab issue note "$ID" -R "$HUB" --message "Batch progress from \`$(basename $PWD)\` (${COMMIT_COUNT} commits):\n\`\`\`\n${SUMMARY}\n\`\`\`" &
    else
      gh issue comment "$ID" -R "$HUB" --body "Batch progress from \`$(basename $PWD)\` (${COMMIT_COUNT} commits):\n\`\`\`\n${SUMMARY}\n\`\`\`" &
    fi
  fi
fi
```

#### `post-merge` — Completion Detection

```bash
#!/bin/bash
# .git/hooks/post-merge (installed by /kws-sat init)
# Purpose: When an issue branch merges into main, transition issue to review

KWS_LINK=".kws-link.yaml"
[ -f "$KWS_LINK" ] || exit 0

HUB=$(yq -r '.hub.project_path' "$KWS_LINK")
PLATFORM=$(yq -r '.hub.platform' "$KWS_LINK")
BRANCH=$(git log -1 --format=%s | grep -oP 'issue/\K[0-9]+' || true)

if [ -n "$BRANCH" ]; then
  if [ "$PLATFORM" = "gitlab" ]; then
    glab issue update "$BRANCH" -R "$HUB" --unlabel "state:wip" --label "state:review"
    glab issue note "$BRANCH" -R "$HUB" --message "Branch merged in \`$(basename $PWD)\`. Work complete, ready for review."
  else
    gh issue edit "$BRANCH" -R "$HUB" --remove-label "state:wip" --add-label "state:review"
    gh issue comment "$BRANCH" -R "$HUB" --body "Branch merged in \`$(basename $PWD)\`. Work complete, ready for review."
  fi
  # Remove from active_claims
  yq -i "del(.active_claims[] | select(. == $BRANCH))" "$KWS_LINK"
fi
```

#### `prepare-commit-msg` — Context Injection (optional)

```bash
#!/bin/bash
# .git/hooks/prepare-commit-msg (installed by /kws-sat init)
# Purpose: Auto-append KWS issue reference if on an issue branch

BRANCH=$(git branch --show-current)
if [[ "$BRANCH" =~ ^issue/([0-9]+)- ]]; then
  ID="${BASH_REMATCH[1]}"
  # Only add if not already referenced
  if ! grep -q "KWS #$ID" "$1"; then
    echo "" >> "$1"
    echo "(KWS #$ID)" >> "$1"
  fi
fi
```

**Key design choice**: Git hooks are the "never forget" layer. They don't make judgment calls about knowledge value — they mechanically ensure that task progress is tracked and state transitions happen. They run in background (`&`) to avoid slowing down git operations.

---

## Mechanism Responsibility Matrix

| Concern | AGENTS.md | Agent Hooks | Git Hooks |
|---------|-----------|-------------|-----------|
| Decide what knowledge is worth capturing | **Primary** | Trigger | — |
| Negotiate with user before pushing | **Primary** | Prompt | — |
| Detect architectural decisions | **Primary** | — | — |
| Offer to create new issues | **Primary** | Remind | — |
| Show active claims at session start | Context | **Primary** | — |
| Prompt wrap-up before session end | — | **Primary** | — |
| Track commit progress on issues | — | — | **Primary** |
| Transition issue state on merge | — | — | **Primary** |
| Auto-append issue refs to commits | — | — | **Primary** |
| Report batch progress (every N commits) | — | — | **Primary** |

**Summary**:
- **AGENTS.md** = *What* to capture and *how* to negotiate (judgment, intent)
- **Agent Hooks** = *When* to think about KWS (lifecycle triggers)
- **Git Hooks** = *Track* progress and *persist* state (mechanical reliability)

---

## .kws-link.yaml (Satellite Config)

```yaml
# Created by: /kws-sat init
hub:
  platform: "gitlab"           # gitlab | github
  project_path: "user/kws-hub" # Full path to KWS repo (same as kws.yaml#instance.project_path)
  default_branch: "main"

identity:
  workspace_name: "frontend-app"  # Human-readable name for this workspace
  workspace_path: "/home/user/projects/frontend-app"

preferences:
  default_domain: "engineering" # Pre-fill domain for new issues
  progress_interval: 5          # Comment every N commits on issue branch (git hook)
  auto_issue_ref: true          # prepare-commit-msg appends (KWS #ID) on issue branches

active_claims: []               # Issue IDs currently being worked in this workspace
```

### Authentication

Mirrors KWS hub exactly — no tokens stored in config. Auth is delegated to the platform CLI:

- **GitLab**: `glab auth status` must pass (user runs `glab auth login` once per machine)
- **GitHub**: `gh auth status` must pass (user runs `gh auth login` once per machine)

The `-R <project_path>` flag on all remote commands routes operations to the hub repo using the CLI's existing credential store. If auth is expired or missing, commands fail with a clear "not authenticated" error — the skill never prompts for or stores tokens.

---

## Commands

Commands split into two categories:

### Init-Time (installer)

| Command | Action |
|---------|--------|
| `/kws-sat init` | Install all mechanisms — config, AGENTS.md, hooks, git hooks |
| `/kws-sat uninstall` | Remove all installed artifacts, disconnect from hub |
| `/kws-sat update` | Re-run hook installation (after skill version update) |

### On-Demand (explicit operations)

| Command | Action |
|---------|--------|
| `/kws-sat board` | Show current task board from hub |
| `/kws-sat claim <ID>` | Claim a ready issue, create local branch |
| `/kws-sat done <ID>` | Mark issue complete (→ review) |
| `/kws-sat blocked <ID> <reason>` | Mark issue blocked |
| `/kws-sat release <ID>` | Unclaim issue (→ ready) |
| `/kws-sat new <title>` | Create new issue on hub (inbox) |
| `/kws-sat log <ID> <note>` | Add progress note to issue |
| `/kws-sat contribute <path>` | Push a wiki page/decision to hub |
| `/kws-sat status` | Show what this workspace is working on |
| `/kws-sat brief` | Fetch and display the latest morning brief |

On-demand commands exist for when the user/agent needs explicit control, but the default flow is that the three mechanisms handle everything passively.

---

## /kws-sat init — Full Installation Flow

1. **Detect platform CLI**: Check which is available — `glab auth status` or `gh auth status`
   - If neither authenticated → fail with: "Run `glab auth login` or `gh auth login` first"
   - If both present → ask user which platform hosts their KWS hub
2. Ask user for hub project path (or detect from git remotes)
3. Verify hub project exists and has KWS labels: `glab label list -R <path> | grep "state:inbox"`
   - If no KWS labels found → warn: "Hub doesn't appear to have KWS initialized. Run `/kws init` in the hub first."
4. Ask for workspace name (default: current directory name)
5. Ask for default domain (list available from hub labels: `glab label list -R <path> | grep "domain:"`)
6. **Write `.kws-link.yaml`** (config)
7. **Append to `.gitignore`**: `.kws-link.yaml` (personal config, not shared)
8. **Augment AGENTS.md**: Append KWS Satellite section (create file if missing)
9. **Install agent hooks**:
   - Detect which AI tools are configured in workspace (`.claude/`, `.opencode/`, `.cursor/`)
   - Install appropriate hook files for each detected tool
   - If none detected → install AGENTS.md-only (universal fallback)
10. **Install git hooks**:
    - Write `post-commit`, `post-merge`, `prepare-commit-msg` to `.git/hooks/`
    - If hooks already exist → append (don't overwrite) with guard comments
    - Make executable: `chmod +x .git/hooks/*`
11. **Verify installation**: Run a dry-run of `glab issue list -R <hub>` to confirm connectivity
12. Display summary of what was installed

### Post-Init Output

```
KWS Satellite initialized.

Hub: user/kws-hub (GitLab)
Workspace: frontend-app
Domain: engineering

Installed:
  ✓ .kws-link.yaml (config)
  ✓ AGENTS.md (KWS Satellite section appended)
  ✓ .opencode/hooks/kws-satellite.yaml (session lifecycle)
  ✓ .git/hooks/post-commit (progress tracking)
  ✓ .git/hooks/post-merge (completion detection)
  ✓ .git/hooks/prepare-commit-msg (issue ref injection)

This workspace is now tracked by KWS. All future AI sessions
will have KWS context, and git operations will report progress
to hub issues automatically.

On-demand commands: /kws-sat board, claim, done, new, contribute
```

---

## Non-Goals (v1)

- **No wiki read/browse** — use the hub directly for that
- **No source-pull** — only the hub manages ingestion
- **No synthesis** — requires full wiki access
- **No domain/source management** — admin stays in hub
- **No local queue mode** — satellite always requires platform CLI connectivity
- **No multi-hub** — one satellite links to exactly one hub
- **No auto-push without confirmation** — agents always ask before contributing knowledge

## Future Considerations (v2+)

- **Multi-hub**: `.kws-link.yaml` supports array of hubs
- **Offline queue**: Buffer issue operations locally, sync when connected
- **Hub-side awareness**: KWS hub's morning brief auto-discovers satellites from issue comments
- **Satellite health check**: Hub can ping satellites for status (via issue metadata)
- **Cross-satellite coordination**: Multiple satellites working on related issues get context about each other

## Skill File Structure

```
kws-satellite/
├── SKILL.md              ← The installable skill (init + on-demand commands)
├── README.md             ← Usage docs
├── AGENTS.md             ← Contributor guide (for skill development)
├── CHANGELOG.md
├── VERSION               ← 0.1.0
├── hooks/                ← Hook templates (copied during init)
│   ├── git/
│   │   ├── post-commit
│   │   ├── post-merge
│   │   └── prepare-commit-msg
│   └── agents/
│       ├── opencode.yaml
│       ├── claude.md
│       └── cursor.json
└── reference/
    └── protocol.md       ← How satellite interacts with hub coordination protocol
```

## Relationship to KWS Skill

| Concern | KWS (Hub) | kws-satellite |
|---------|-----------|---------------|
| Primary role | System of record | Installer + bridge |
| Init result | Full KWS system | Persistent hooks in workspace |
| Needed after init? | Yes (ongoing operations) | No (artifacts persist) |
| Manage domains/sources | Yes | No |
| Issue lifecycle | Full state machine | Consume + contribute |
| Wiki management | Full | Contribute only (with user consent) |
| Knowledge detection | Via source-pull | Via AGENTS.md judgment |
| Progress tracking | Manual/scheduled | Automatic (git hooks) |
| Platform support | gitlab/github/local | gitlab/github only |

## Open Questions

1. **Hook coexistence**: If workspace already has git hooks (husky, lint-staged), how do we play nice? (Recommendation: append with clearly marked sections, or use `.git/hooks/` directory approach if git 2.36+ core.hooksPath supports it)
2. **Sparse clone caching**: For `/contribute`, maintain persistent sparse clone or fresh each time? (Trade-off: disk vs latency)
3. **AGENTS.md ownership**: If workspace already has AGENTS.md, how much do we append? (Recommendation: minimal section with link to full protocol, keep it under 40 lines)
4. **Hook updates**: When the satellite skill updates (new hook logic), how does `kws-sat update` handle existing customizations? (Recommendation: versioned guard comments, replace only between markers)
5. **Multiple AI tools**: If workspace has both `.claude/` and `.opencode/`, install hooks for all? (Recommendation: yes, detect and install for all found)

## Implementation Phases

### Phase 1: Core Installation (MVP)
- `/kws-sat init` — full installation flow
- `/kws-sat uninstall` — clean removal
- Git hooks: post-commit progress tracking
- AGENTS.md augmentation (universal)
- `/kws-sat board` and `/kws-sat claim`/`done` (on-demand fallback)

### Phase 2: Agent Hook Integration
- OpenCode hooks (session start/end)
- Claude Code hooks (CLAUDE.md + hooks.json)
- Cursor rules integration
- `/kws-sat contribute` (sparse clone flow)

### Phase 3: Polish & Automation
- `prepare-commit-msg` auto-reference
- `post-merge` completion detection
- `/kws-sat update` (hook versioning)
- Hub brief integration (satellite activity appears in morning brief)

## Success Criteria

- After `/kws-sat init`, a workspace is permanently tracked by KWS with zero ongoing skill dependency
- AI agent sessions automatically show active claims and prompt for knowledge contribution
- Git commits on issue branches automatically report progress to hub without AI involvement
- Branch merges automatically transition issue state
- Knowledge captured in satellites reaches hub wiki within one user confirmation
- Uninstall cleanly removes all artifacts with no residue
