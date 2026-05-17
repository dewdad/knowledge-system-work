# Changelog

## [0.5.0] - 2026-05-11

### Added
- **Hub/Satellite architecture** — `/init` now asks "Hub or Satellite?" to determine workspace role
- **Authentication & repo selection** — Step 1 authenticates via `glab auth`/`gh auth` and lets user select or create a KSW repo
- **Satellite init flow** — Install-once bridge: `.ksw-link.yaml`, AGENTS.md augmentation, agent hooks, git hooks, hub registration
- **Satellite commands** — `/sat board`, `/sat claim`, `/sat done`, `/sat blocked`, `/sat release`, `/sat new`, `/sat log`, `/sat contribute`, `/sat status`, `/sat brief`
- **Hub agent hooks** — OpenCode `.opencode/hooks/ksw-hub.yaml` and Claude Code `CLAUDE.md` appendage for session lifecycle (inbox count, stale WIP, brief status, wrap-up prompts)
- **Hub git hooks** — `post-commit` (batch progress), `post-merge` (state transition), `pre-push` (wikilink lint), `post-checkout` (issue context display)
- **Satellite agent hooks** — OpenCode/Claude hooks for session awareness (active claims, routed work, wrap-up)
- **Satellite git hooks** — `post-commit` (progress to hub), `post-merge` (completion detection), `prepare-commit-msg` (auto issue ref)
- **Dual-label routing** — `satellite:<name>` for workspace routing + `domain:<name>` for semantic context
- **`reference/hooks/`** directory — Hook templates extracted from SKILL.md for maintainability
- **Hub registration** — Satellite init registers itself in hub's `ksw.yaml#satellites[]` via sparse checkout
- `ksw.yaml#instance.mode` field (hub|satellite)
- `ksw.yaml#satellites[]` array for tracking registered satellite workspaces
- `.ksw-link.yaml` schema (satellite bridge config)
- `hub-hooks.md` workflow doc generated during hub init
- `satellite:<name>` label in platform setup

### Changed
- `/init` restructured: Step 0 (mode selection) → Step 1 (auth + repo) → mode-specific flow
- Hub init steps renumbered (2-11) to accommodate new preamble
- Platform Command Reference split into Hub Operations and Satellite Operations tables
- AGENTS.md updated with `reference/hooks/` directory, hub/satellite mode documentation
- Line limit for SKILL.md raised from 500 to 1000 (proportional to doubled scope)

## [0.3.0] - 2026-05-10

### Added
- **Wikilink graph index** (`wiki/_graph/graph.json`) — deterministic adjacency list parsed from `[[wikilinks]]`
- `/graph-build` command — zero-cost, no-LLM graph rebuild from wiki content
- `graph.json` schema definition (nodes, edges, stats, orphans, most-connected)
- `wiki/_graph/orphans.md` auto-generated orphan report
- **markitdown integration** — optional `pip install markitdown[all]` for ingesting Office, PDF, images, audio
- Step 0 in wiki-ingest: auto-convert non-markdown files via markitdown before processing
- `ksw.yaml#wiki.graph` toggle for auto-rebuild after ingest/synthesize
- `ksw.yaml#tools.markitdown` config (auto/disabled/path)

### Changed
- Wiki-synthesize now uses `graph.json` when available (graceful degradation to grep)
- Wiki-ingest supports all markitdown formats (.docx, .pptx, .xlsx, .pdf, .html, images, audio)
- AGENTS.md template updated with `_graph/` directory and graph-build workflow
- Notes section clarifies: core = zero-dependency, optional tools enhance capabilities

## [0.2.0] - 2026-05-10

### Changed
- **BREAKING**: Refactored from git submodule to installable agent skill
- Removed `.system/` mount pattern and AGENT_BOOTSTRAP.md entry point
- Removed `scripts/` directory (replaced by /init command in SKILL.md)
- Moved `coordination/`, `schemas/`, `templates/`, `skills/` under `reference/`
- Renamed `skills/` to `reference/workflows/` (reference only, not deployed)

### Added
- `SKILL.md` at repo root — the installable skill product
- Multi-platform support: GitLab, GitHub, and local (filesystem-only)
- Solo mode (no locking, direct commits) alongside team mode
- `/init` command that bootstraps complete system in any git repo
- `/add-domain`, `/add-source`, `/triage`, `/pull`, `/ingest`, `/synthesize`, `/review`, `/brief`, `/status` commands
- Platform command abstraction table (glab/gh/local equivalents)
- Local queue mode (`.ksw/queue/` with markdown task files)
- Inline schemas for ksw.yaml, domain.yaml, sources.yaml
- AGENTS.md template generation during /init

### Removed
- `AGENT_BOOTSTRAP.md` (replaced by SKILL.md itself)
- `scripts/setup/bootstrap.sh` and `bootstrap.ps1` (replaced by /init)
- `scripts/maintenance/` (instructions now inline in workflows)
- Direct dependency on GitLab (now platform-agnostic)
- Submodule consumption pattern

## [0.1.0] - 2026-05-10

### Added
- Initial system architecture document
- Agent coordination protocol (work-locking via GitLab)
- AGENT_BOOTSTRAP.md entry point
- Folder structure: coordination/, skills/, scripts/, schemas/, templates/
- Source/feed system schema and pull protocol
- Bootstrap scripts for KSW instances (bash + PowerShell)
- CI pipeline fragments (wiki, source, maintenance)
- GitLab issue/MR templates
- Domain and source configuration schemas
