# Knowledge Work System (KWS)

Reusable orchestration substrate for AI agent-driven knowledge, project, and task management. Consumed as a git submodule (`.system/`) inside LifeOS instance repositories.

## What It Does

- **Agent Coordination** — Work-locking via GitLab issues so multiple agents never collide
- **Skills Library** — Markdown-based instructions agents load for specific tasks (triage, synthesis, source-pull, etc.)
- **Automation Scripts** — Setup, maintenance, and CI scripts for instance lifecycle
- **Schemas** — YAML validation for instance config, sources, and domains
- **Templates** — GitLab CI fragments, issue/MR templates, instance scaffolding

## Quick Start (for LifeOS instances)

```bash
# Add KWS as a submodule in your LifeOS instance
git submodule add https://github.com/dewdad/knowledge-system-work.git .system

# Bootstrap the instance (creates labels, board, folder structure)
.system/scripts/setup/bootstrap.sh

# Agents start here:
cat .system/AGENT_BOOTSTRAP.md
```

## Repository Structure

```
coordination/       Agent locking protocol (GitLab issues + glab CLI)
skills/             Markdown agent instructions (one SKILL.md per skill)
scripts/            Bash/PowerShell automation
  setup/            One-time instance initialization
  maintenance/      Periodic tasks (source-pull, lint, upgrade)
schemas/            YAML schemas for validation
templates/
  ci/               GitLab CI pipeline fragments
  gitlab/           Issue and MR templates
  instance/         Scaffolding for new instances
.dev/               Internal architecture documentation
```

## Requirements

- **Git** with submodule support
- **glab** CLI (GitLab CLI) — authenticated against the target GitLab instance
- **Bash** (Linux, macOS, WSL, Git Bash) or **PowerShell 7+** (Windows)
- A GitLab project as the LifeOS instance host

## How Agents Work

1. Agent reads `AGENT_BOOTSTRAP.md`
2. Checks for available work: `glab issue list --label "state:ready" --assignee ""`
3. Claims an issue (assign + `state:wip` label)
4. Works on branch `issue/<ID>-<slug>`
5. Creates MR, transitions to `state:review`

See `coordination/PROTOCOL.md` for the full protocol and `coordination/states.yaml` for the state machine.

## Versioning

Version tracked in `VERSION` file (semver). Breaking schema changes bump the minor version. See `CHANGELOG.md` for release history.

## License

MIT
