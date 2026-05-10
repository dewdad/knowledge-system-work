# AGENTS.md

> Compact reference for AI agents working in this repo. Read `AGENT_BOOTSTRAP.md` for the full operational protocol.

## What This Repo Is

**Knowledge Work System (KWS)** — a reusable orchestration substrate consumed as a **git submodule at `.system/`** inside LifeOS instance repos. It is NOT a standalone application.

This repo provides: coordination protocol, agent skills, automation scripts, YAML schemas, and GitLab templates. It never contains instance-specific content (wiki pages, domain configs, raw materials).

## Repo Structure

```
coordination/   ← Agent locking protocol (GitLab issues + glab CLI)
skills/         ← Markdown-based agent instructions (one SKILL.md per skill)
scripts/        ← Bash/PowerShell automation (setup + maintenance)
schemas/        ← YAML schemas for lifeos.yaml, sources, domains
templates/      ← GitLab CI fragments, issue/MR templates, instance scaffolding
.dev/           ← Internal architecture docs (not consumed by instances)
```

## Critical Context

- **GitLab-first**: The coordination protocol uses `glab` CLI against GitLab, not GitHub. This GitHub repo is the source-of-truth for the submodule code only.
- **Never push to `main` directly** in LifeOS instances — always branch + MR. This repo itself has no such constraint for development.
- **Submodule path**: Consumers mount this at `.system/` — scripts assume they run from the parent instance root as `.system/scripts/...`
- **No runtime dependencies**: Everything is shell scripts, YAML, and markdown. No package manager, no build step.
- **Version tracked in `VERSION` file** (semver). Update it + `CHANGELOG.md` on every release.

## Working Here

### Adding/Editing Skills

Each skill lives at `skills/<name>/SKILL.md`. Skills must be generic (work for any LifeOS instance). Instance-specific logic belongs in the parent repo.

### Adding Scripts

Scripts go in `scripts/setup/` or `scripts/maintenance/`. All `.sh` scripts must work on Linux, macOS, WSL, and Git Bash. Include a `.ps1` variant for Windows-native use when relevant.

### Schemas

YAML schemas in `schemas/` are validated by bootstrap/upgrade scripts. Changes here are breaking for existing instances — bump the minor version.

### Templates

- `templates/ci/` — GitLab CI pipeline fragments (included via `include:` in instance `.gitlab-ci.yml`)
- `templates/gitlab/` — Issue and MR templates
- `templates/instance/` — Scaffolding for new LifeOS instances (`lifeos.yaml.template`, domain stubs)

## Conventions

- Commit messages: imperative mood, reference issue if applicable
- Branch names in consumer repos: `issue/<ID>-<slug>` (max 30 char slug)
- Label taxonomy defined in `coordination/labels.yaml` — states are mutually exclusive
- Issue state machine defined in `coordination/states.yaml` — agents must follow valid transitions
- WIP locks expire after 30 minutes (configurable per-instance in `lifeos.yaml`)

## What NOT to Put Here

- Domain-specific knowledge or wiki content
- Instance configuration (`lifeos.yaml` belongs in the parent)
- Actual GitLab labels/milestones (created per-instance by bootstrap script)
- Secrets or credentials of any kind
