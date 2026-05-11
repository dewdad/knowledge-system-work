# AGENTS.md

> For AI agents contributing to this skill repo.

## What This Repo Is

**KSW** is an installable AI agent skill. The product is `SKILL.md` — a single markdown file that any AI coding agent can load to bootstrap and operate a knowledge management system.

This repo is NOT an application. It's a skill definition with supporting reference material.

## Repo Structure

```
SKILL.md              ← THE PRODUCT. Installable skill file.
README.md             ← Human-facing install/usage docs
AGENTS.md             ← You are here (contributor guide)
CHANGELOG.md          ← Release history
VERSION               ← Semver version
LICENSE               ← MIT
reference/            ← Supporting documentation (not consumed at runtime)
  coordination/       ← Protocol specs (state machine, labels, recovery)
  schemas/            ← YAML schema definitions for validation
  templates/          ← Issue/MR templates, CI pipeline fragments
  workflows/          ← Detailed per-workflow documentation (source-pull, triage, etc.)
  architecture/       ← System design documents
```

## Critical Context

- `SKILL.md` is the ONLY file consumers install. Everything else is development reference.
- The skill supports 3 platforms: GitLab (`glab`), GitHub (`gh`), and local (filesystem-only).
- The skill supports 2 modes: solo (no locking) and team (full coordination protocol).
- Reference material in `reference/` informs the SKILL.md content but is NOT deployed with it.
- All schemas, protocols, and workflow details must be summarized inline in SKILL.md — consumers don't have access to `reference/`.

## Working Here

### Editing SKILL.md

This is the primary deliverable. Changes here affect all consumers.

- Keep it self-contained — no external file references that consumers won't have
- Follow the existing section structure: Commands table → /init → /add-domain → workflows → schemas
- Platform commands must always show all 3 variants (gitlab/github/local)
- Test by loading the skill in an AI agent and running `/ksw init`

### Editing reference/

Reference material serves two purposes:
1. **Design source** — detailed specs that get summarized into SKILL.md
2. **Deep documentation** — for contributors who need to understand the full design

Changes here don't affect consumers unless you also update SKILL.md.

### Versioning

- Version in `VERSION` file (semver)
- Patch: workflow clarifications, typo fixes
- Minor: new workflows, new commands, schema additions
- Major: breaking changes to /init output structure or ksw.yaml format

## Conventions

- Commit messages: imperative mood (`Add source-pull retry logic`, not `Added...`)
- The SKILL.md should remain under 800 lines (currently ~620) — be concise
- All command examples must be copy-pasteable (no pseudocode in commands)
- Schemas inline in SKILL.md use simplified format (not full JSON Schema)
