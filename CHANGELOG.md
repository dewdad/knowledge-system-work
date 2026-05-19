# Changelog

## [0.6.1] - 2026-05-19

Carry-over from the v0.6.0 audit follow-up plan. All items below were tracked as deferred in `.sisyphus/plans/audit-followup-v0.6.0.md` and are now shipped.

### Added
- **`/reap` (hub-only)** — stale-WIP reaper. Reads `coordination.stale_wip_timeout_minutes`, lists `state:wip` items, computes idle time as `max(updated_at, last_comment_at, branch_last_commit_at)`, and unassigns + transitions stale items to `state:ready`. Branches are preserved. Supports `--dry-run`. Hub agent hooks now invoke `/reap --dry-run` on session start so every hub session sees stale WIP without mutating state. ([HUB-COMMANDS.md § /reap](HUB-COMMANDS.md#reap))
- **`/sat uninstall` (satellite-only)** — tears down the satellite bridge: removes `.ksw-link.yaml`, strips `## KSW …` sections from `AGENTS.md` / `CLAUDE.md`, removes `.opencode/hooks/ksw-satellite.yaml`, and strips `[KSW-SAT-HOOK-START]…[KSW-SAT-HOOK-END]` blocks from `.git/hooks/{post-commit,post-merge,prepare-commit-msg}`. Posts a `type:maintenance` notification on the hub. Prints a manual-deregister hint for `ksw.yaml#satellites[]`. ([SATELLITE-COMMANDS.md § /sat uninstall](SATELLITE-COMMANDS.md#sat-uninstall))
- **Hub `prepare-commit-msg` git hook** — auto-injects `(KSW #<ID>)` on `ksw/<ID>-*` branches in hub workspaces, mirroring the satellite hook. Gated on `coordination.auto_issue_ref` (default `true`).
- **`reference/schemas/secrets.schema.yaml`** — JSON-schema definition for `secrets/<source_id>.yaml` files. Covers bearer/API-key, basic-auth, and OAuth2 client-credential shapes plus an optional `expires_at`. Linked from `/add-source` Step 4.
- **Satellite registry reconciliation in `/status`** — every entry in `ksw.yaml#satellites[]` gains an additive `last_seen_at` field, refreshed from the most recent satellite-posted comment on the hub. `/status` flags any satellite older than 30 days as `(stale)` (informational only).
- **Drift-lint in CI** — `reference/templates/ci/maintenance-pipeline.yml` now includes a `skill-drift-lint` job that runs `bash scripts/lint-skill.sh` on every change to fragments or coordination YAMLs.

### Changed
- **Branch convention unified to `ksw/<ID>-<slug>`** — both hub and satellite branches now use the same prefix. Hub git hooks (`post-commit`, `post-checkout`, `post-merge`) and satellite git hooks (`post-commit`, `post-merge`, `prepare-commit-msg`) all accept `ksw/<ID>-...` (preferred) **and** legacy `issue/<ID>-...` during the 0.6.x grace period. Existing branches keep working; new branches should always use `ksw/`. Removal of legacy `issue/` is targeted for the next minor release. (`SATELLITE-COMMANDS.md`, `COORDINATION.md`, hooks)
- **Default-branch detection in hooks** — hub `post-commit` reads `coordination.default_branch` from `ksw.yaml`; satellite `post-commit` reads `hub.default_branch` from `.ksw-link.yaml`. Both fall back to `main`. Hardcoded `main..` rev-list ranges are gone.
- **`reference/coordination/PROTOCOL.md` rewritten platform-agnostic** — operational guide now references the `PLATFORM-OPS.md` action vocabulary instead of inlining `glab` commands. Header explicitly names `states.yaml` and `labels.yaml` as the normative sources of truth. `recovery.md` rewritten to match.
- **`reference/coordination/states.yaml`** — `wip.timeout.minutes` raised from `30` → `240` (matching the new ksw.yaml default). Branch entry-action notes the unified convention plus the legacy grace period.
- **`coordination.stale_wip_timeout_minutes` default raised 30 → 240** in the generated `ksw.yaml`. The aggressive 30-minute default fired on legitimate work; 240 minutes (4 hours) better matches realistic agent session lengths and is documented as the trigger for `/reap`.
- **`/reap` wired into hub agent hooks** — `reference/hooks/hub/agents/opencode.yaml` and `claude.md` now call `/reap --dry-run` on session start.
- **`reference/workflows/wiki-to-issue/SKILL.md`** — explicitly lists `wiki/_graph/orphans.md` as an input. Orphans with domain/concept context become `type:research` issues.

### Removed
- **`coordination.max_parallel_agents`** — dropped from the generated `ksw.yaml` template. Cross-agent counting was fragile and the field had no enforcement path. Existing `ksw.yaml` files keep the field harmlessly; nothing reads it.

### Notes
- Backward compatible. Existing 0.6.0 hub repos and satellite installs continue to work. The `default_branch` field added to `.ksw-link.yaml` is read with a `// "main"` fallback. The `last_seen_at` field on satellites is additive. `auto_issue_ref` (hub) defaults to `true` if absent.
- No `config_version` bump.

## [0.6.0] - 2026-05-19

Audit follow-up — installation correctness, skill loader metadata, and a structural split of `SKILL.md` so consuming agents only load the fragment relevant to the current command.

### Added
- **Skill frontmatter** — `SKILL.md` now starts with a YAML block (`name`, `version`, `description`, `when_to_use`, `entry_points`) so Claude Code / opencode skill loaders index KSW correctly.
- **Multi-file skill split** — SKILL.md is now a router (~95 lines). Detailed content moved into siblings:
  - `INIT.md` — full hub + satellite init flow and config schemas.
  - `HUB-COMMANDS.md` — `/add-domain`, `/add-source`.
  - `SATELLITE-COMMANDS.md` — every `/sat *` command.
  - `PLATFORM-OPS.md` — gitlab/github/local CLI tables and the post-mutation re-read rule.
  - `COORDINATION.md` — state machine, claim/release rules, stale-WIP recovery, branch conventions, canonical label table.
  - `WORKFLOWS.md` — workflow router/index pointing to `reference/workflows/*`.
- **`INSTALL.md`** — install methods for skillshare, OpenCode, Claude Code, Cursor; explicit anti-pattern: single-file `cp SKILL.md` install.
- **Version stamp in generated configs** — `ksw.yaml` and `.ksw-link.yaml` now include a `ksw:` block with `skill_version` and `config_version` (default `1`). `/status` warns on skill version mismatch; `config_version` is reserved for future breaking schema changes.
- **Directory-install smoke check** — `reference/workflows/init-smoke-test/SKILL.md` gains a "Common: Directory-install check" step. `/init` aborts with a clear "re-install as a directory" message if `reference/` siblings are missing.
- **`scripts/lint-skill.sh`** — drift lint that validates: every state in `reference/coordination/states.yaml` is named in `COORDINATION.md`; every label in `reference/coordination/labels.yaml` is named in `COORDINATION.md`; every command in SKILL.md's routing table maps to exactly one fragment; every fragment is reachable from SKILL.md. Exits non-zero on any drift.

### Changed
- **README install section** — removed the `cp SKILL.md ~/.claude/skills/ksw.md` line; documented directory installs for OpenCode, Claude Code, and other tools.
- **README repository structure** — updated to reflect the split fragments and the new `scripts/` directory.
- **Init smoke test** — also verifies `ksw.skill_version` matches the loaded skill (warning, not error) and uses the `ksw/<ID>-test` branch on the hub-side smoke and `issue/<ID>-test` on the satellite-side smoke (matching the unchanged hooks).
- **`COORDINATION.md` (new)** explicitly documents the current dual branch convention (`ksw/<ID>-...` for hub, `issue/<ID>-...` for satellite). Unification is planned for a future minor.

### Fixed
- **Install hole** — single-file `cp SKILL.md ksw.md` installs no longer silently fail at `/init`. The smoke test surfaces the problem with an actionable message.
- **Empty skill metadata** — Claude Code / opencode skill loaders previously displayed empty fields for KSW because no frontmatter was present.

### Notes
- Backward compatible. Existing 0.5.0 hub repos and satellite installs continue to work — no `config_version` bump. Re-running `/init` will refresh generated workflow docs and add the `ksw.skill_version` field to existing `ksw.yaml` / `.ksw-link.yaml`.
- The single-file install (`cp SKILL.md ...`) is now an explicit anti-pattern. Reinstall as a directory.
- The following audit items are documented in `.sisyphus/plans/audit-followup-v0.6.0.md` but deferred to a later release: cross-host pull lock (E4), stale-WIP reaper (`/reap`), `/sat uninstall`, satellite registry reconciliation, branch convention unification, hub `prepare-commit-msg` hook, `secrets/` schema file, drift-lint CI integration.

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
