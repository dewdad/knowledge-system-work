# Knowledge Work System (KSW)

Installable AI agent skill for bootstrapping a complete knowledge management, project coordination, and task orchestration system in any git repository.

## What It Does

One `/init` command gives you:

- **Structured knowledge base** — Obsidian-compatible wiki with concepts, entities, decisions, synthesis
- **Source ingestion pipeline** — RSS, YouTube, APIs, Git repos → issues → wiki pages
- **Agent coordination** — State machine for parallel work (solo or team mode)
- **Domain-driven organization** — Life/work domains with goals, sources, reviews
- **Daily operations** — Morning briefs, domain reviews, cross-domain synthesis

## Install

### Skillshare
```bash
skillshare install ksw --source github:dewdad/knowledge-system-work
```

### OpenCode
```bash
# Copy or symlink SKILL.md into your skills directory
cp SKILL.md ~/.config/opencode/skills/ksw/SKILL.md
```

### Claude Code
```bash
# Add to .claude/skills/ in your project or global config
cp SKILL.md ~/.claude/skills/ksw.md
```

### Manual
Copy `SKILL.md` from this repo into your AI client's skill directory.

## Usage

Once installed, tell your AI agent:

```
/ksw init
```

This bootstraps the full system in your current project. Then:

```
/ksw add-domain health
/ksw add-source health rss huberman-lab
/ksw pull
/ksw triage
/ksw brief
```

## Platform Support

| Platform | CLI | Features |
|----------|-----|----------|
| **GitLab** | `glab` | Full issue coordination, labels, MR workflow |
| **GitHub** | `gh` | Full issue coordination, labels, PR workflow |
| **Local** | none | Filesystem queue, no external service needed |

## Modes

- **Solo** — No locking, direct commits OK, filesystem queue
- **Team** — Full coordination protocol, branch + MR/PR required, stale lock recovery

## Repository Structure

```
SKILL.md              ← The installable skill (this is the product)
reference/            ← Supporting documentation
  coordination/       ← Protocol specs (state machine, labels, recovery)
  schemas/            ← YAML schema definitions
  templates/          ← Issue/MR templates, CI fragments
  workflows/          ← Detailed per-workflow documentation
  architecture/       ← System design docs
```

## Commands Reference

| Command | Action |
|---------|--------|
| `/ksw init` | Bootstrap full system in project root |
| `/ksw add-domain <name>` | Add a knowledge domain |
| `/ksw add-source <domain> <type> <id>` | Add source feed to domain |
| `/ksw pull [domain]` | Pull from sources |
| `/ksw triage` | Auto-label inbox items |
| `/ksw ingest <path>` | Process raw material into wiki |
| `/ksw synthesize` | Cross-domain pattern detection |
| `/ksw review <domain>` | Domain health check |
| `/ksw brief` | Generate status summary |
| `/ksw status` | System state overview |

## Requirements

- **Git** — initialized repository
- **One of**: `glab` (GitLab), `gh` (GitHub), or neither (local mode)
- **Bash** or **PowerShell 7+** for shell commands
- An AI agent that supports markdown skills

## License

MIT
