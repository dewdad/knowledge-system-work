# Design Note: Three-Mechanism Approach for KSW Hub

> Apply the same install-once architecture (AGENTS.md + agent hooks + git hooks) to the main KSW `/init` command.

## Context

The satellite skill uses persistent installed artifacts so workspaces are "tracked forever" after init. The same principle applies to the hub itself — currently `/ksw init` generates AGENTS.md but relies entirely on the agent re-reading it each session. No lifecycle hooks, no mechanical git automation.

## Proposed Addition to `/ksw init`

After Step 7 (commit), add:

- **Step 8**: Install agent hooks (tool-specific lifecycle triggers)
- **Step 9**: Install git hooks (mechanical automation)

## Mechanism Design (Hub-Specific)

### AGENTS.md (already exists — enhance)

Current AGENTS.md tells agents about KSW structure and commands. Enhance with:

- Active system state awareness (not just structure)
- Proactive maintenance prompts (stale items, overdue pulls)
- Knowledge capture heuristics for work done within the hub itself

### Agent Hooks

```yaml
on_session_start:
  - Show inbox count and any stale WIP items
  - Show overdue source pulls
  - Show brief if not generated today
  - "3 items in inbox — triage now?"

on_session_end:
  - If wiki pages were created/edited → offer to run graph-build
  - If issues were worked → verify state transitions are clean
  - If decisions were made → prompt issue-to-wiki
  - "Source pull overdue by 2 days — run before closing?"
```

### Git Hooks

| Hook | Trigger | Action |
|------|---------|--------|
| `post-commit` | Any commit on `issue/<ID>-*` branch | Auto-comment progress on issue (local, no `-R` needed) |
| `post-merge` | Branch merged to main | Close related issue, trigger issue-to-wiki if `type:decision` |
| `pre-push` | Before pushing to remote | Run wiki lint, warn on broken wikilinks |
| `post-checkout` | Switch to issue branch | Display issue context (title, description, priority) |
| `commit-msg` | Commit message written | Validate format matches KSW conventions |

### Differences from Satellite

| Concern | Satellite Git Hooks | Hub Git Hooks |
|---------|---------------------|---------------|
| Issue operations | Remote (`-R <hub>`) | Local (same repo) |
| Wiki awareness | None | Full — can lint, check orphans |
| State transitions | claim/done/blocked | Full lifecycle including triage triggers |
| Source pull | N/A | Detect staleness, prompt |
| Complexity | Lightweight (3 hooks) | Richer (5 hooks) |

## Impact on SKILL.md

This would add ~30-40 lines to the `/init` section:
- Hook installation steps (detect AI tools, write hook files)
- Git hook installation (with coexistence logic for husky/lint-staged)
- A new `hooks/` directory in the KSW project structure (templates)

## Open Questions

1. Should hub git hooks be committed to the repo (shared with team) or local-only (`.git/hooks/`)? Team mode likely wants shared hooks via husky or similar.
2. Agent hooks vary by tool — should KSW maintain templates for all major tools, or just AGENTS.md (universal) + one reference implementation?
3. How do hub hooks interact with `coordination.mode: solo` vs `team`? Solo mode might skip the pre-push lint gate.

## Priority

Low urgency — the hub works without this. But implementing it alongside satellite ensures a consistent mental model: "init = install persistent awareness, not just create files."
