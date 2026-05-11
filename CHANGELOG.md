# Changelog

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
