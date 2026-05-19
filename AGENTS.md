# AGENTS.md

> For AI agents contributing to this skill repo.

## What This Repo Is

**KSW** is an installable AI agent skill. The product is a directory containing `SKILL.md` plus sibling fragments and `reference/`. Any AI coding agent can load the skill to bootstrap and operate a knowledge management system.

This repo is NOT an application. It is a multi-file skill definition with supporting reference material.

## Repo Structure

```
SKILL.md              ← Router. Frontmatter + workspace detection + command index. Keep ≤200 lines.
INIT.md               ← /init flow (hub + satellite) and config schemas (ksw.yaml, .ksw-link.yaml)
HUB-COMMANDS.md       ← /add-domain, /add-source
SATELLITE-COMMANDS.md ← All /sat * commands
PLATFORM-OPS.md       ← Platform CLI tables (gitlab/github/local) + the post-mutation re-read rule
COORDINATION.md       ← State machine, claim/release, stale-WIP recovery, branch convention, label catalogue
WORKFLOWS.md          ← Workflow router/index → reference/workflows/*
INSTALL.md            ← Install methods (skillshare/manual). Directory install required.
README.md             ← Human-facing overview
AGENTS.md             ← You are here (contributor guide)
CHANGELOG.md          ← Release history
VERSION               ← Semver version
LICENSE               ← MIT
scripts/              ← Repo dev tooling (lint-skill.sh)
reference/            ← Read at runtime by /init when installing hooks/workflows. Ships with the skill.
  coordination/       ← Normative state and label YAMLs + protocol guide
  hooks/              ← Hook templates installed during /init
    hub/git/          ← Hub git hooks (post-commit, post-merge, pre-push, post-checkout)
    hub/agents/       ← Hub agent hooks (opencode.yaml, claude.md)
    satellite/git/    ← Satellite git hooks (post-commit, post-merge, prepare-commit-msg)
    satellite/agents/ ← Satellite agent hooks (opencode.yaml, claude.md)
  schemas/            ← YAML schema definitions for validation
  templates/          ← Issue/MR templates, CI pipeline fragments
  workflows/          ← Detailed per-workflow documentation (source-pull, triage, etc.)
```

## Critical Context

- The skill is **multi-file**. Consumers must install the directory. Single-file installs (`cp SKILL.md ...`) fail at `/init`. See [INSTALL.md](INSTALL.md).
- The skill supports 3 platforms: GitLab (`glab`), GitHub (`gh`), and local (filesystem-only, hub mode only).
- The skill supports 2 init modes: **hub** (full system) and **satellite** (bridge to hub).
- The skill supports 2 coordination modes: solo (no locking) and team (full coordination protocol).
- **Architecture**: SKILL.md is a router. It tells the agent which fragment to load based on workspace role (`ksw.yaml` vs `.ksw-link.yaml` vs neither) and command. Fragments are self-contained for their use case.
- **Generated workflow docs**: detailed workflow instructions are generated as `.ksw/workflows/*.md` during `/init`. The router-level summaries live in `WORKFLOWS.md`; the canonical detail lives in `reference/workflows/*/SKILL.md`.
- **Hook templates**: `reference/hooks/` contains the actual bash/yaml scripts installed during init. The relevant fragment (INIT.md, COORDINATION.md, etc.) references these by path — the agent reads the template content from `reference/` when installing.
- **Single source of truth for state and labels**: [`reference/coordination/states.yaml`](reference/coordination/states.yaml) and [`reference/coordination/labels.yaml`](reference/coordination/labels.yaml) are normative. `COORDINATION.md` is a rendered view; if the two disagree, the YAMLs win — fix `COORDINATION.md` and run `scripts/lint-skill.sh`.

## Working Here

### Editing SKILL.md

This is the primary deliverable's entry point. Changes here affect every consumer.

- Keep SKILL.md ≤200 lines.
- SKILL.md must not duplicate imperative content from fragments. Drift between SKILL.md and fragments is the failure mode the split is designed to eliminate.
- Allowed in SKILL.md: frontmatter, the routing tables (workspace + command), `/status` (small enough to inline), and short top-level notes.
- Adding a new command? Add a row to the command index **and** add the heading to exactly one fragment. The lint script will catch you if you skip step two.

### Editing fragments (INIT.md, HUB-COMMANDS.md, SATELLITE-COMMANDS.md, PLATFORM-OPS.md, COORDINATION.md, WORKFLOWS.md)

- Each fragment opens with a `> Loaded when:` header so an agent that sees the file out of context still knows when it applies.
- Each fragment is self-contained for its use case. Cross-references between fragments are explicit (`[PLATFORM-OPS.md](PLATFORM-OPS.md)`). No implicit "see SKILL.md §X".
- `PLATFORM-OPS.md` is the **only** place that lists `glab` / `gh` / local-queue command forms. Other fragments link there; they do not inline platform commands.
- Workflow detail (algorithms, step-by-step recipes) belongs in `reference/workflows/<name>/SKILL.md`. `WORKFLOWS.md` is a router.
- Schemas (`ksw.yaml`, `.ksw-link.yaml`) live in `INIT.md` because that's where they're generated and consumed.

### Editing reference/

Reference material serves two purposes:
1. **Templates installed at runtime** — `reference/hooks/`, `reference/templates/`, `reference/workflows/`. These ship with the skill and are read during `/init`.
2. **Normative specs** — `reference/coordination/states.yaml` and `reference/coordination/labels.yaml` define the state machine and label catalogue. Update these first; rendered views (`COORDINATION.md`) follow.

After any edit under `reference/coordination/`, re-run `scripts/lint-skill.sh` to verify `COORDINATION.md` is still in sync.

### Lint script (`scripts/lint-skill.sh`)

Run from repo root:

```bash
bash scripts/lint-skill.sh
```

Verifies:
- Every state in `reference/coordination/states.yaml` is named in `COORDINATION.md`.
- Every label in `reference/coordination/labels.yaml` is named in `COORDINATION.md`.
- Every command in SKILL.md's routing table maps to exactly one fragment.
- Every fragment is reachable from SKILL.md.

Required tools: `bash`, `grep`, `awk`, `sed`. `yq` is used opportunistically; the script falls back to grep-only parsing when it is absent. Exits `0` on clean, `1` on drift, `2` on missing tools/files.

### Versioning

- Version in `VERSION` file (semver).
- The same version is mirrored in `SKILL.md` frontmatter (`version:`) and in the `ksw.skill_version` field of generated `ksw.yaml` / `.ksw-link.yaml`. Bump all three together.
- Patch: workflow clarifications, typo fixes.
- Minor: new workflows, new commands, schema additions, additive frontmatter fields, fragment splits.
- Major: breaking changes to `/init` output structure, `ksw.yaml` format, or fragment public API.
- Any breaking schema change MUST also bump `ksw.config_version` in the generated configs.

## Conventions

- Commit messages: imperative mood (`Add source-pull retry logic`, not `Added...`).
- Hook/script bodies live in `reference/hooks/`, never inline in any fragment.
- All command examples must be copy-pasteable (no pseudocode in commands; use `<placeholders>` for substitution).
- Workflow detail (steps, algorithms) lives in `reference/workflows/<name>/SKILL.md` and the generated `.ksw/workflows/*.md`. Fragment-level summaries are router entries only.
- Branch convention: hub uses `ksw/<ID>-<slug>`, satellite uses `issue/<ID>-<slug>`. The hooks key off these regexes; do not introduce a third prefix.
- Do not break the directory-install model. Adding a runtime dependency on a new sibling file is fine; adding a runtime dependency on a file outside the skill repo (network call, external git clone) is not.
