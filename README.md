# Knowledge Work System (KSW)

Installable AI agent skill for bootstrapping a complete knowledge management, project coordination, and task orchestration system. Supports a **hub** (central system of record) and **satellite** (project workspace bridge) architecture.

## What It Does

One `/init` command gives you either:

### Hub Mode (central KSW repository)
- **Structured knowledge base** — Obsidian-compatible wiki with concepts, entities, decisions, synthesis
- **Source ingestion pipeline** — RSS, YouTube, APIs, Git repos → issues → wiki pages
- **Agent coordination** — State machine for parallel work (solo or team mode)
- **Domain-driven organization** — Life/work domains with goals, sources, reviews
- **Daily operations** — Morning briefs, domain reviews, cross-domain synthesis
- **Persistent hooks** — Agent lifecycle hooks + git hooks for automated tracking

### Satellite Mode (project workspace bridge)
- **Install-once bridge** — Connects any project workspace to your KSW hub permanently
- **Automatic progress tracking** — Git hooks report to hub issues without AI involvement
- **Agent awareness** — Every AI session starts with KSW context (active claims, routed work)
- **Knowledge flow** — Decisions and learnings flow back to hub wiki with user consent
- **Dual-label routing** — `satellite:<name>` for workspace routing + `domain:<name>` for context

## Install

KSW is a **multi-file skill**. Install it as a directory — single-file installs (`cp SKILL.md …`) will fail at `/init` because the init flow reads sibling fragments and `reference/` templates. See [INSTALL.md](INSTALL.md) for full details.

### Skillshare (recommended)
```bash
skillshare install ksw --source github:dewdad/knowledge-system-work
```

### OpenCode (manual)
```bash
git clone https://github.com/dewdad/knowledge-system-work.git ~/.config/opencode/skills/ksw
```

### Claude Code (manual — directory, not flat file)
```bash
git clone https://github.com/dewdad/knowledge-system-work.git ~/.claude/skills/ksw
```

### Cursor / other tools
Clone (or copy) the whole repo into `<tool_skills_dir>/ksw/` so `SKILL.md`, sibling fragments, and `reference/` ship together.

> ⚠️ `cp SKILL.md ~/.claude/skills/ksw.md` will not work. The skill needs its sibling files. Always install as a directory.

## Usage

Once installed, tell your AI agent:

```
/init
```

The agent will ask: **Hub or Satellite?**

### Hub Setup
```
/init                          # Choose "Hub", authenticate, select/create repo
/add-domain health
/add-source health rss huberman-lab
/pull
/triage
/brief
```

### Satellite Setup
```
/init                          # Choose "Satellite", authenticate, select hub repo
/sat board                     # See tasks routed to this workspace
/sat claim 12                  # Claim an issue, create local branch
# ... work ...
/sat done 12                   # Mark complete
```

After satellite init, the workspace is permanently tracked — no skill reload needed. Agent hooks and git hooks carry behavior forward automatically.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  KSW Hub (GitLab/GitHub repo)                               │
│  ├── ksw.yaml, domains/, wiki/, .ksw/workflows/             │
│  └── Issue Board ← receives progress, knowledge, new issues │
└──────────────────────────┬──────────────────────────────────┘
                           │ glab/gh CLI (remote commands)
         ┌─────────────────┼─────────────────────────┐
    ┌────▼───┐       ┌────▼───┐               ┌─────▼────┐
    │ Proj A │       │ Proj B │               │ Proj C   │
    │ (sat)  │       │ (sat)  │               │ (sat)    │
    │        │       │        │               │          │
    │ .ksw-link.yaml + AGENTS.md + hooks      │          │
    └────────┘       └────────┘               └──────────┘
```

## Platform Support

| Platform | CLI | Hub | Satellite |
|----------|-----|-----|-----------|
| **GitLab** | `glab` | Primary supported target | Primary supported bridge |
| **GitHub** | `gh` | Supported command surface, verify before automation | Supported command surface, verify before automation |
| **Local** | none | Filesystem queue only, manual operation | Not supported |

Current reference workflows and hook templates are GitLab-first. GitHub and local variants are documented in `SKILL.md`, but production use should start with GitLab until the generated workflows and hooks have been smoke-tested in your environment.

## Modes

### Init Modes
- **Hub** — Central KSW repository with full system (issue board, wiki, domains, synthesis)
- **Satellite** — Lightweight bridge connecting a project workspace to an existing hub

### Coordination Modes (hub only)
- **Solo** — No locking, direct commits OK, filesystem queue
- **Team** — Full coordination protocol, branch + MR/PR required, stale lock recovery

## Repository Structure

```
SKILL.md              ← Router (frontmatter + workspace detection + command index)
INIT.md               ← /init flow (hub + satellite) and config schemas
HUB-COMMANDS.md       ← /add-domain, /add-source
SATELLITE-COMMANDS.md ← All /sat * commands
PLATFORM-OPS.md       ← Platform CLI tables (gitlab/github/local)
COORDINATION.md       ← State machine, claim/release, stale-WIP recovery
WORKFLOWS.md          ← Workflow router/index → reference/workflows/*
INSTALL.md            ← Install methods + directory-form requirement
reference/            ← Templates and detailed workflows (read at runtime by /init)
  coordination/       ← Normative state and label YAMLs + protocol guide
  hooks/              ← Hook templates installed during /init
    hub/git/          ← Hub git hooks (post-commit, post-merge, pre-push, post-checkout)
    hub/agents/       ← Hub agent hooks (opencode.yaml, claude.md)
    satellite/git/    ← Satellite git hooks (post-commit, post-merge, prepare-commit-msg)
    satellite/agents/ ← Satellite agent hooks (opencode.yaml, claude.md)
  schemas/            ← YAML schema definitions
  templates/          ← Issue/MR templates, CI fragments
  workflows/          ← Detailed per-workflow documentation
scripts/              ← Repo dev tooling (lint-skill.sh, etc.)
```

## Commands Reference

### Hub Commands

| Command | Action |
|---------|--------|
| `/init` | Bootstrap KSW — choose hub or satellite mode |
| `/add-domain <name>` | Add a knowledge domain |
| `/add-source <domain> <type> <id>` | Add source feed to domain |
| `/pull [domain]` | Pull from sources |
| `/triage` | Auto-label inbox items |
| `/ingest <path>` | Process raw material into wiki |
| `/synthesize` | Cross-domain pattern detection |
| `/review <domain>` | Domain health check |
| `/brief` | Generate status summary |
| `/graph-build` | Rebuild wikilink graph index |
| `/status` | System state overview |

### Satellite Commands

| Command | Action |
|---------|--------|
| `/sat board` | Show task board filtered to this satellite |
| `/sat claim <ID>` | Claim issue, create local branch |
| `/sat done <ID>` | Mark issue complete (→ review) |
| `/sat blocked <ID> <reason>` | Mark issue blocked |
| `/sat release <ID>` | Unclaim issue (→ ready) |
| `/sat new <title>` | Create new issue on hub |
| `/sat log <ID> <note>` | Add progress note to issue |
| `/sat contribute <path>` | Push wiki page/decision to hub |
| `/sat status` | Show workspace state |
| `/sat brief` | Fetch latest morning brief |

## Orchestration

- **Hub**: Designed for autonomous orchestration via agentic harnesses (e.g., [hermes-agent](https://github.com/nousresearch/hermes-agent), CI pipelines, scheduled agent loops)
- **Satellite**: Designed for interactive development with AI coding tools (e.g., [opencode](https://github.com/nicholasgriffintn/opencode), [openwork](https://github.com/different-ai/openwork))

## Requirements

- **Git** — initialized repository
- **One of**: `glab` (GitLab), `gh` (GitHub), or neither (local hub mode only)
- **Bash** or **PowerShell 7+** for shell commands
- An AI agent that supports markdown skills
- **Required for hooks**: `yq`
- **Required for several validation/maintenance snippets**: `jq`
- **Optional**: `markitdown` (enhanced ingest), `yt-dlp` (YouTube sources)

## License

MIT
