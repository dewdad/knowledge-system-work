---
name: ksw
version: 0.6.0
description: AI-native knowledge management — domains, source ingestion, wiki, issue coordination, hub/satellite. Use when the user says "init ksw", "set up knowledge system", runs any /sat command, or references wiki/domains/sources/triage/brief.
when_to_use:
  - User says "init ksw" / "set up knowledge system" / "bootstrap knowledge management"
  - User runs any /sat command
  - User references domains, sources, wiki pages, triage, morning brief, synthesis
  - User wants to connect a project workspace to a KSW hub
entry_points:
  - /init        # Bootstrap (hub or satellite)
  - /sat *       # Satellite ops (requires .ksw-link.yaml)
  - /pull, /triage, /ingest, /synthesize, /brief, /review, /status, /graph-build, /add-domain, /add-source  # Hub ops
---

# Knowledge Work System (KSW)

> AI-native knowledge management. Domain-driven source ingestion, structured wiki, issue coordination, and synthesis — orchestrated by agents. Hub (full system) + Satellite (project workspace bridge) architecture.

## How To Use This Skill (router contract)

This file is **only** a router. It tells you which fragment to load for the current task. Do **not** load INIT.md, HUB-COMMANDS.md, SATELLITE-COMMANDS.md, WORKFLOWS.md, or COORDINATION.md until you have determined which one applies. Loading every fragment up front defeats the purpose of the split.

### Step 1 — Detect workspace role

| Signal | Role | Load |
|--------|------|------|
| `.ksw-link.yaml` present in workspace | **Satellite** workspace | [SATELLITE-COMMANDS.md](SATELLITE-COMMANDS.md) (+ [PLATFORM-OPS.md](PLATFORM-OPS.md), [COORDINATION.md](COORDINATION.md) on demand) |
| `ksw.yaml` present in workspace        | **Hub** workspace       | [HUB-COMMANDS.md](HUB-COMMANDS.md) and/or [WORKFLOWS.md](WORKFLOWS.md), pulling [PLATFORM-OPS.md](PLATFORM-OPS.md) and [COORDINATION.md](COORDINATION.md) as needed |
| Neither file present                   | **Uninitialized**       | [INIT.md](INIT.md) (only) |

If both files are present, the workspace is misconfigured — ask the user to pick a role and remove the other file. If `ksw.yaml` exists but lists `instance.mode: satellite`, the file is wrong; treat the workspace as satellite based on `.ksw-link.yaml` and surface the inconsistency.

### Step 2 — Pick the fragment from the command

| Command | Mode | Load |
|---------|------|------|
| `/init` | uninitialized | [INIT.md](INIT.md) |
| `/add-domain <name>` | hub | [HUB-COMMANDS.md](HUB-COMMANDS.md) |
| `/add-source <domain> <type> <id>` | hub | [HUB-COMMANDS.md](HUB-COMMANDS.md) |
| `/pull [domain]` | hub | [WORKFLOWS.md](WORKFLOWS.md) → `reference/workflows/source-pull/SKILL.md` |
| `/triage` | hub | [WORKFLOWS.md](WORKFLOWS.md) → `reference/workflows/issue-triage/SKILL.md` |
| `/ingest <path>` | hub | [WORKFLOWS.md](WORKFLOWS.md) → `reference/workflows/wiki-ingest/SKILL.md` |
| `/synthesize` | hub | [WORKFLOWS.md](WORKFLOWS.md) → `reference/workflows/wiki-synthesize/SKILL.md` |
| `/review <domain>` | hub | [WORKFLOWS.md](WORKFLOWS.md) → `reference/workflows/domain-review/SKILL.md` |
| `/brief` | hub | [WORKFLOWS.md](WORKFLOWS.md) → `reference/workflows/morning-brief/SKILL.md` |
| `/graph-build` | hub | [WORKFLOWS.md](WORKFLOWS.md) (zero-LLM, deterministic) |
| `/status` | hub | this file (inline below) |
| `/sat board` | satellite | [SATELLITE-COMMANDS.md](SATELLITE-COMMANDS.md) |
| `/sat claim <ID>` | satellite | [SATELLITE-COMMANDS.md](SATELLITE-COMMANDS.md) + [COORDINATION.md](COORDINATION.md) (note: satellite branches are `issue/<ID>-…`) |
| `/sat done <ID>` | satellite | [SATELLITE-COMMANDS.md](SATELLITE-COMMANDS.md) |
| `/sat blocked <ID> <reason>` | satellite | [SATELLITE-COMMANDS.md](SATELLITE-COMMANDS.md) |
| `/sat release <ID>` | satellite | [SATELLITE-COMMANDS.md](SATELLITE-COMMANDS.md) + [COORDINATION.md](COORDINATION.md) |
| `/sat new <title>` | satellite | [SATELLITE-COMMANDS.md](SATELLITE-COMMANDS.md) |
| `/sat log <ID> <note>` | satellite | [SATELLITE-COMMANDS.md](SATELLITE-COMMANDS.md) |
| `/sat contribute <path>` | satellite | [SATELLITE-COMMANDS.md](SATELLITE-COMMANDS.md) |
| `/sat status` | satellite | [SATELLITE-COMMANDS.md](SATELLITE-COMMANDS.md) |
| `/sat brief` | satellite | [SATELLITE-COMMANDS.md](SATELLITE-COMMANDS.md) |

### Step 3 — Cross-cutting fragments

These two files are loaded **only when the active command actually needs them** — never speculatively:

- [PLATFORM-OPS.md](PLATFORM-OPS.md) — every `glab` / `gh` / local-queue invocation. Loaded by every command that mutates issue/queue state.
- [COORDINATION.md](COORDINATION.md) — state transitions, claim/release rules, stale-WIP recovery. Loaded by every command that touches `state:*` labels or branches.

### Step 4 — STOP HERE until role + command are known

Do not load any fragment beyond this file based on a guess. If the user's request is ambiguous (e.g. they said "ksw" without a verb), ask which command they want, or read [INIT.md](INIT.md) only if the workspace is uninitialized.

---

## /status — System State Overview (router-resident)

Small enough to live here. Run from a hub workspace.

Report:

- **Domains** — count from `domains/` (one row per directory).
- **Queue** — count per state (`inbox` / `ready` / `wip` / `blocked`). Source from platform issues with `state:*` labels (`gitlab`/`github`) or `.ksw/queue/<state>/` (`local`).
- **Wiki pages** — count `.md` files in `wiki/` excluding `_graph/` and `_meta/`.
- **Last brief** — most recent file in `wiki/_meta/briefs/`.
- **Last pull** — most recent `last_pull` value across all `domains/*/.state/pulls.json`.
- **Graph** — node/edge count from `wiki/_graph/graph.json` if it exists; otherwise `not built (run /graph-build)`.
- **Skill version** — `ksw.skill_version` from `ksw.yaml`. If it does not match the version in this file's frontmatter, surface a one-line warning suggesting `/init` is re-run to refresh templates.
- **Stale WIP** — count of `state:wip` issues idle for more than `coordination.stale_wip_timeout_minutes`. Display the count only; recovery is a separate flow (see [COORDINATION.md](COORDINATION.md#stale-lock-recovery)).

Output is a single short summary block; no edits, no commits.

---

## Notes for the agent

- **Never** invent commands not in the table above. If the user mentions an unfamiliar `/ksw …` or `/sat …` command, ask before doing anything.
- **Authentication** is delegated entirely to the platform CLI (`glab auth login` / `gh auth login`). KSW never stores tokens in config files. Source pull credentials live in `secrets/<source_id>.yaml` (gitignored).
- **All durable state is in git.** Platform issue state is remote system state and must be re-read after every mutation (see [PLATFORM-OPS.md § Verification rule](PLATFORM-OPS.md#verification-rule)).
- **Scheduling** fields are advisory unless the user installs CI schedules, cron, or an agent harness. KSW does not run a daemon.
- **Graph** is an optimization, never a hard dependency. If `wiki/_graph/graph.json` is missing, fall back to grep across `wiki/`.
- **Hub vs satellite mental model**: hub is the system of record (orchestrated by autonomous agents — e.g. `hermes-agent`, CI loops); satellites are project workspaces (developed with interactive AI tools — `opencode`, `openwork`) that bridge back via CLI commands and git hooks.
- **Satellite install-once** — after `/init` satellite, the workspace is permanently tracked. AGENTS.md + agent hooks + git hooks carry behavior forward; no skill reload needed for routine `/sat …` invocations.
- **Dual-label routing** — issues use `satellite:<name>` for workspace routing **and** `domain:<name>` for semantic context. Hub assigns work by applying the satellite label.
- **Required tools at runtime**: `git`, `yq`. Many workflow snippets also need `jq`.
- **Optional tools**: `markitdown` (Office/PDF/image/audio → markdown during ingest), `yt-dlp` (YouTube sources).
- **Install**: this skill ships as a directory containing `SKILL.md` + sibling fragments + `reference/`. Single-file installs (`cp SKILL.md …`) will fail at `/init`. See [INSTALL.md](INSTALL.md).
