# Skills Library

Skills are markdown-based instructions that agents load and follow for specific tasks.

## Available Skills

| Skill | Purpose | Trigger |
|-------|---------|---------|
| [source-pull](source-pull/SKILL.md) | Pull items from domain sources | Scheduled or manual |
| [issue-triage](issue-triage/SKILL.md) | Auto-label and prioritize `state:inbox` issues | New issue created |
| [wiki-ingest](wiki-ingest/SKILL.md) | Process raw material into wiki pages | File dropped in `raw/` |
| [wiki-synthesize](wiki-synthesize/SKILL.md) | Find cross-domain patterns | Weekly or on-demand |
| [domain-review](domain-review/SKILL.md) | Health check on a domain | Weekly |
| [issue-to-wiki](issue-to-wiki/SKILL.md) | Closed issue → decision record | Issue closed |
| [wiki-to-issue](wiki-to-issue/SKILL.md) | Wiki gap → actionable issue | On wiki analysis |
| [morning-brief](morning-brief/SKILL.md) | Generate daily summary | Daily scheduled |
| **[ksw](/SKILL.md)** | **Installable agent skill — /init bootstraps full KSW** | **`/ksw init` or install via skillshare** |

## Skill Format

Each skill follows this structure:

```
skills/<name>/
└── SKILL.md      ← Complete instructions for the agent
```

## How to Use

1. Identify which skill matches your current task
2. Read the SKILL.md in full before executing
3. Follow the steps exactly (they handle edge cases)
4. Skills reference scripts in `.system/scripts/` — run those as instructed

## Creating New Skills

Place new skills in this directory following the same format. Skills in `.system/` are generic (work for any KSW instance). Instance-specific skills go in the parent project's custom location.
