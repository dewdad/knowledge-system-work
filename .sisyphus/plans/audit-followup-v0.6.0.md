# KSW v0.6.0 Plan — Audit Follow-Up + Context-Aware Skill Loading

> Successor to v0.5.0. Integrates the 8 audit recommendations with a structural rewrite of `SKILL.md` so consuming agents load only the context they need for the use-case at hand.

**Owner:** maintainer
**Tracking issue:** _to be created on hub_
**Target version:** 0.6.0 (minor bump — adds new fragments, breaks single-file install assumption → must be called out in CHANGELOG)
**Touches:** `SKILL.md`, `reference/`, `README.md`, `CHANGELOG.md`, `VERSION`, `AGENTS.md`

---

## STATUS (2026-05-19)

Phases A + B + C executed in one session and verified (`bash scripts/lint-skill.sh` clean, all cross-refs resolve, SKILL.md = 104 lines).

| Item | Phase | Status |
|---|---|---|
| A1 — SKILL.md frontmatter | A | ✅ shipped |
| A2 — Version stamp in `ksw.yaml` / `.ksw-link.yaml` | A | ✅ shipped |
| A3 — VERSION bump + CHANGELOG entry | A | ✅ shipped |
| B1 — Install model decision (chose B1.a directory install) | B | ✅ shipped |
| B2 — README rewrite + `INSTALL.md` | B | ✅ shipped |
| B3 — Init-smoke-test directory-install check | B | ✅ shipped |
| C1 — Target structure (7 fragments + reference/) | C | ✅ shipped |
| C2 — SKILL.md router contract (104 lines, ≤200 target) | C | ✅ shipped |
| C3 — Fragment extraction rules (self-contained, "Loaded when" headers) | C | ✅ shipped |
| C4 — `scripts/lint-skill.sh` drift lint | C | ✅ shipped (CI wiring deferred) |
| C5 — Content migration per the table | C | ✅ shipped |
| C6 — Token-cost validation | C | ⚠️ approximated by line count, not measured |
| D1 — Branch convention unification (`ksw/` everywhere) | D | ⏸ deferred — current dual convention documented in `COORDINATION.md` |
| D2 — Default-branch detection in hooks | D | ⏸ deferred (config field added to `.ksw-link.yaml` schema, hooks unchanged) |
| D3 — Complete label table | D | ✅ shipped via `COORDINATION.md` (canonical list including `type:bug`, `needs:clarification`, `domain:<n>`, `satellite:<n>`) |
| D4 — State-machine single source of truth | D | ⏸ deferred — note added in `COORDINATION.md` header; PROTOCOL.md rewrite not done |
| D5 — `secrets/` schema file | D | ⏸ deferred — schema shape inlined in `HUB-COMMANDS.md` `/add-source` Step 4 |
| E1 — `/reap` stale-WIP command | E | ⏸ deferred |
| E2 — Satellite-on-local-hub guard | E | ✅ shipped at `/init` time in `INIT.md` Step 1 |
| E3 — `max_parallel_agents` enforce-or-drop | E | ⏸ deferred (field preserved in schema, no behavioural change) |
| E4 — Cross-host pull lock | E/F | ⏸ deferred (limitation documented in `WORKFLOWS.md`) |
| E5 — Satellite registry reconciliation | E | ⏸ deferred |
| E6 — `/sat uninstall` | E | ⏸ deferred (manual procedure documented in `INSTALL.md`) |
| F1 — Hub `prepare-commit-msg` hook | F | ⏸ deferred |
| F2 — Orphans → `wiki-to-issue` wiring | F | ⏸ deferred |
| F3 — `/sat contribute` conflict spec | F | ✅ shipped (added to `SATELLITE-COMMANDS.md` while migrating that section) |

**Files added:** `INIT.md`, `HUB-COMMANDS.md`, `SATELLITE-COMMANDS.md`, `PLATFORM-OPS.md`, `COORDINATION.md`, `WORKFLOWS.md`, `INSTALL.md`, `scripts/lint-skill.sh`.
**Files modified:** `SKILL.md`, `README.md`, `AGENTS.md`, `CHANGELOG.md`, `VERSION`, `reference/workflows/init-smoke-test/SKILL.md`.

**Carry-over for the next session:** D1, D2, D4, D5, E1, E3, E5, E6, F1, F2 (and any C4 CI wiring + C6 measured token validation). Sections §1–§11 below preserve the original specs for those items.

---

## 0. Goals (and non-goals)

### Goals

1. Fix the install hole that makes `reference/hooks/` invisible to /init in non-skillshare installs.
2. Add skill-loader frontmatter so Claude Code / opencode index KSW correctly.
3. Decompose SKILL.md so an agent invoked for a single satellite command does **not** load the full hub init flow.
4. Reconcile the half-dozen documented inconsistencies (branch names, label table, state-machine drift, default branch, etc.).
5. Ship a stale-WIP reaper that actually runs.
6. Tighten the `secrets/`, satellite-on-local-hub, and `max_parallel_agents` edges.

### Non-goals

- No new commands beyond what audit gaps require.
- No new workflows.
- No schema changes that would invalidate v0.5.0 `ksw.yaml` files (additive only — version field, satellites[]).
- No platform additions (still gitlab/github/local).

### Success criteria (verifiable)

- [ ] Fresh install via `cp -r` and via skillshare both produce a working `/init` end-to-end on hub + satellite + local.
- [ ] Token cost of a `/sat board` invocation drops measurably (target: <30% of current full-SKILL.md load).
- [ ] `/init` smoke test passes on all three platforms.
- [ ] `lint-skill` (new script — see §3.4) reports zero drift between SKILL.md, `reference/coordination/states.yaml`, `reference/coordination/labels.yaml`.
- [ ] `ksw.yaml` produced by /init contains a `version` key, and consuming agents emit a warning on version mismatch.

---

## 1. Phase A — Foundations (cheap, unblocks everything)

### A1. Add SKILL.md frontmatter

**File:** `SKILL.md` (top of file)

**Change:** prepend YAML frontmatter:

```yaml
---
name: ksw
version: 0.6.0
description: AI-native knowledge management — domains, source ingestion, wiki, issue coordination, hub/satellite. Use when user says "init ksw", "set up knowledge system", "/sat ...", or references wiki/domains/sources/triage/brief.
when_to_use:
  - User says "init ksw" / "set up knowledge system" / "bootstrap knowledge management"
  - User runs any /sat command
  - User references domains, sources, wiki pages, triage, morning brief, synthesis
  - User wants to connect a project workspace to a KSW hub
entry_points:
  - /init        # Bootstrap (hub or satellite)
  - /sat *       # Satellite ops (requires .ksw-link.yaml)
  - /pull, /triage, /ingest, /synthesize, /brief, /review, /status, /graph-build  # Hub ops
---
```

**Why frontmatter (not just an h1):** Claude Code Skills and opencode skill loaders index `name` and `description` from frontmatter. Without it, the skill displays empty metadata.

**Verification:** `head -20 SKILL.md` shows the block; opencode `/skills` command (or equivalent) lists ksw with the new description.

### A2. Add version stamp to generated configs

**Files affected:**
- `SKILL.md` — `/init` Step 4 (hub) and `.ksw-link.yaml` template (satellite)

**Changes:**
- `ksw.yaml` template gains:
  ```yaml
  ksw:
    skill_version: "0.6.0"   # SKILL.md version that generated this
    config_version: 1        # Bump on breaking schema changes
  ```
- `.ksw-link.yaml` template gains the same `ksw:` block.
- Add a "Compatibility" section to SKILL.md `/init` documenting that future versions will check `config_version` and offer migration.

**Verification:** Run `/init` on a clean dir; `yq -r '.ksw.skill_version' ksw.yaml` returns `0.6.0`.

### A3. Bump VERSION + CHANGELOG entry

Pre-write the CHANGELOG entry for 0.6.0 covering all changes in this plan. Bump VERSION to `0.6.0` only at end of plan.

---

## 2. Phase B — Installation correctness

### B1. Decide install model

**Decision required (Question to maintainer):**
The current SKILL.md tells /init to read `reference/hooks/...`. That works for `git clone` installs but fails for `cp SKILL.md .../skills/ksw/SKILL.md`. Three options:

- **B1.a (recommended).** Require directory install. Treat KSW as a multi-file skill. Update README. Make `cp SKILL.md` an explicit anti-pattern.
- **B1.b.** Inline all hook bodies into SKILL.md as code-fences. Bloats SKILL but works for any install model. (We are about to split SKILL.md anyway, so we'd inline into a sibling fragment, not the main file.)
- **B1.c.** Have /init shell out to `git clone` the skill repo to a temp dir on first run. Adds dependency on git + network at install time.

**Default choice:** B1.a (directory install) + reference fragments inlined into the matching split file (so the fragment that uses the hook also carries it). This combines best of A and B.

### B2. Implement the chosen install model

**Under B1.a:**
- Update README install snippets:
  ```bash
  # Skillshare (preferred)
  skillshare install ksw --source github:dewdad/knowledge-system-work

  # Manual
  git clone https://github.com/dewdad/knowledge-system-work.git ~/.config/opencode/skills/ksw
  # or for Claude Code (note: directory, not flat .md):
  git clone https://github.com/dewdad/knowledge-system-work.git ~/.claude/skills/ksw
  ```
- Add `INSTALL.md` at repo root documenting both methods + the directory layout consumers must preserve.
- Remove the misleading `cp SKILL.md ~/.claude/skills/ksw.md` line.

### B3. Smoke test the install

Add `reference/workflows/init-smoke-test/SKILL.md` step: after /init completes, verify it can `cat` at least one expected hook template path. Fails with a clear "skill installed without reference/ — re-install as directory" message.

---

## 3. Phase C — Context-aware skill decomposition

This is the largest change. Goal: an agent loading `ksw` for `/sat board` should not pay for the 456 lines of /init flow.

### C1. Target structure

```
ksw/
├── SKILL.md              ← Router (~120 lines). Frontmatter + decision tree + command index + state detection.
├── INSTALL.md            ← Existing (from B2). Human-facing.
├── INIT.md               ← Hub + satellite /init flow (lines 49-505 of current SKILL.md).
├── HUB-COMMANDS.md       ← /add-domain, /add-source, /triage, /pull, /ingest, /synthesize, /review, /brief, /graph-build, /status.
├── SATELLITE-COMMANDS.md ← All /sat * commands with full detail.
├── PLATFORM-OPS.md       ← The platform abstraction tables (gitlab/github/local). Loaded transitively by every command file.
├── COORDINATION.md       ← State machine, claim/release, stale-WIP recovery. Single source of truth.
├── WORKFLOWS.md          ← One-line map: command → reference/workflows/<name>/SKILL.md. Workflow detail stays in those files.
└── reference/            ← Unchanged structurally (hooks, schemas, workflows, templates, coordination).
```

### C2. SKILL.md router contract

The new SKILL.md must contain, in this order:

1. Frontmatter (from A1).
2. **Workspace detection block** (≤25 lines):
   ```
   Detect role:
   - `.ksw-link.yaml` present → SATELLITE workspace. Read SATELLITE-COMMANDS.md.
   - `ksw.yaml` present       → HUB workspace.       Read HUB-COMMANDS.md.
   - Neither                  → UNINITIALIZED.       Read INIT.md.
   ```
3. **Command index** — table mapping every command (hub + satellite) to the file the agent must read for execution.
4. **Cross-cutting references** — pointer to `COORDINATION.md` (for any claim/release work) and `PLATFORM-OPS.md` (for any platform call).
5. **Stop here** — explicit instruction: "Do not load INIT.md / HUB-COMMANDS.md / SATELLITE-COMMANDS.md until you know which one applies."

**Non-content rule:** SKILL.md must not duplicate any imperative content from the fragments. Drift is the failure mode we are eliminating.

### C3. Fragment extraction rules

- Each fragment is self-contained for its use case (no implicit "see SKILL.md §X").
- Each fragment opens with a one-paragraph "Loaded when:" header so an agent that sees the file out-of-context still knows when it applies.
- `PLATFORM-OPS.md` is referenced **by file path** from every other fragment — agents do not inline platform commands.
- Workflow detail summaries (current SKILL.md §"Workflow Summaries", lines 598-666) move to `WORKFLOWS.md`. The 8 detailed workflow files in `reference/workflows/` remain authoritative; `WORKFLOWS.md` is a router/index.

### C4. Drift lint

**New file:** `scripts/lint-skill.sh` (or `.ps1`).

Verifies:
- Every state in `reference/coordination/states.yaml` appears in `COORDINATION.md`.
- Every label in `reference/coordination/labels.yaml` appears in `INIT.md` Step 7.
- Every command in SKILL.md command index has a corresponding section in exactly one fragment.
- Every fragment is reachable from SKILL.md.

Wired into CI (extends `reference/templates/ci/maintenance-pipeline.yml`).

### C5. Migration of existing content

| Current SKILL.md lines | Destination | Notes |
|---|---|---|
| 1-46 | `SKILL.md` (router) | Keep When-to-Use + command tables; collapse tables into one. |
| 49-136 | `INIT.md` § Common preamble | Step 0, Step 1 (mode + auth + repo) |
| 138-340 | `INIT.md` § Hub flow | Steps 2-11 of hub init |
| 343-505 | `INIT.md` § Satellite flow | Steps 2-9 of satellite init |
| 509-563 | `HUB-COMMANDS.md` | /add-domain, /add-source |
| 566-595 | `PLATFORM-OPS.md` | Both tables (hub + satellite ops) |
| 598-666 | `WORKFLOWS.md` | Workflow summaries — keep terse, link to reference/workflows/* |
| 669-697 | `COORDINATION.md` | State machine, team/solo, stale lock |
| 700-708 | `SKILL.md` (router) | /status is small enough to inline |
| 712-end | `SATELLITE-COMMANDS.md` | All /sat * commands |

### C6. Token-cost validation

After split, measure approximate tokens loaded for representative tasks:

| Scenario | Files loaded | Pre-split | Post-split target |
|---|---|---|---|
| `/init` on empty dir | SKILL + INIT + PLATFORM-OPS + COORDINATION | ~3500 tokens | ~3500 tokens (parity — full setup needs full context) |
| `/sat board` on satellite | SKILL + SATELLITE-COMMANDS + PLATFORM-OPS | ~3500 | ~1200 |
| `/triage` on hub | SKILL + HUB-COMMANDS + PLATFORM-OPS + workflows/issue-triage | ~3500 | ~1500 |
| `/status` (router-resident) | SKILL only | ~3500 | ~600 |

These are estimates. Validate by counting lines × ~5 tokens/line in actual fragments.

---

## 4. Phase D — Convention reconciliation

### D1. Branch naming — pick one

**Decision required:** hub uses `ksw/<ID>-<slug>`, satellite uses `issue/<ID>-<slug>`. Pick `ksw/<ID>-<slug>` everywhere (more grep-distinctive, matches the brand).

**Touches:**
- `SKILL.md` router command table (new) — branch convention note.
- `INIT.md` and `SATELLITE-COMMANDS.md`.
- All hook scripts under `reference/hooks/satellite/git/` and `reference/hooks/hub/git/` — regex changes from `^issue/([0-9]+)-` to `^ksw/([0-9]+)-`.
- `COORDINATION.md`.

### D2. Default-branch detection in hooks

**File:** `reference/hooks/satellite/git/post-commit` (and any other hook hard-coding `main`).

**Change:** read default from `.ksw-link.yaml` or `ksw.yaml`:
```bash
DEFAULT_BRANCH=$(yq -r '.coordination.default_branch // "main"' ksw.yaml 2>/dev/null \
  || yq -r '.hub.default_branch // "main"' .ksw-link.yaml 2>/dev/null \
  || echo "main")
COMMIT_COUNT=$(git rev-list --count "${DEFAULT_BRANCH}..${BRANCH}" 2>/dev/null || echo 0)
```

Add `default_branch` field to `.ksw-link.yaml` schema (populated from hub during /init satellite flow).

### D3. Complete the label table in INIT.md

Current Step 7 omits: `type:source-item`, `type:bug`, `needs:clarification`, `domain:<n>` (templated), `satellite:<n>` (templated). Add all of them, sourced authoritatively from `reference/coordination/labels.yaml`. The lint script (C4) enforces parity.

### D4. State-machine single source of truth

Pick **`reference/coordination/states.yaml`** as authoritative. `COORDINATION.md` and `reference/coordination/PROTOCOL.md` become rendered views — the YAML is normative. Add a header note to PROTOCOL.md: "States and transitions are defined in `states.yaml`. This document is the operational guide."

Also: rewrite PROTOCOL.md to be platform-agnostic (currently GitLab-only). Use the platform abstraction from `PLATFORM-OPS.md`.

### D5. `secrets/` schema

**New file:** `reference/schemas/secrets.schema.yaml`:

```yaml
# Schema: secrets/<source_id>.yaml
# Read by source-pull workflow when source.auth_ref points here.
type: object
oneOf:
  - { required: [token] }                              # Bearer / API key
  - { required: [username, password] }                 # Basic auth
  - { required: [client_id, client_secret] }           # OAuth2 client credentials
properties:
  token:
    type: string
    description: "Bearer token or API key"
  username: { type: string }
  password: { type: string }
  client_id: { type: string }
  client_secret: { type: string }
  scope:
    type: string
    description: "OAuth2 scope, optional"
  expires_at:
    type: string
    format: date-time
    description: "Optional expiry hint for the agent"
```

`/add-source` interactive flow gains: "This source needs auth. Where should I store the credential? [secrets/<source_id>.yaml]" and writes a stub.

`.gitignore` already excludes `secrets/`. Document this loudly in `INIT.md`.

---

## 5. Phase E — Operational completion

### E1. Stale-WIP reaper

**New command:** `/reap` (hub-only).

**Behavior:**
- Read `coordination.stale_wip_timeout_minutes` from `ksw.yaml` (raise default from 30 → **240** minutes).
- For each `state:wip` issue: compute `now - updated_at`. If > timeout: unassign, swap `state:wip` → `state:ready`, post comment "Auto-released after N minutes idle. Branch preserved."
- Optional `--dry-run` flag.

**Hook integration:** call `/reap --dry-run` from `on_session_start` in `reference/hooks/hub/agents/opencode.yaml` (and the Claude.md equivalent) so every hub session reports stale WIP.

**Verification:** Manually transition an issue to wip, set timeout to 1 minute, wait 90 seconds, run `/reap`, confirm transition.

### E2. Satellite-on-local-hub guard

**File:** `INIT.md` § Step 0.

After mode selection, if user picks **Satellite** and the hub repo selected in Step 1 has `instance.platform: local` (detectable by trying to clone it as a remote — local hubs have no remote), abort with:

> Satellite mode requires a remote-accessible hub (GitLab or GitHub). The selected hub is local-only.
> Either: (a) re-init the hub with a remote platform, or (b) use the hub directly without a satellite.

### E3. `max_parallel_agents` enforcement OR removal

**Decision required:** enforce or drop?

- **Enforce.** Before `/sat claim` or hub claim path: count current `state:wip` issues assigned to all known agents (across satellites). If ≥ `max_parallel_agents`, refuse claim with "System at parallelism limit (N)."
- **Drop.** Remove field from ksw.yaml; document in CHANGELOG.

**Default:** drop. Cross-agent counting is fragile and the feature is unused.

### E4. Pull-lock platform agnosticism (deferred to v0.7.0)

Cross-host pull-lock via hub label is the right design but requires a new `pulling:<domain>` label and TTL semantics. Defer; document the local-FS lock's limitation in `WORKFLOWS.md`.

### E5. Satellite registry reconciliation

**New step in `/status` (hub-only):** for each entry in `ksw.yaml#satellites[]`, check `last_seen_at` (new field, written by satellite post-commit hook → hub via a heartbeat issue comment OR via `last_commented_issue_at`). If `last_seen > 30 days`, flag in status output.

`last_seen_at` is an additive schema change — backward compatible.

### E6. Satellite uninstall

**New command:** `/sat uninstall` (satellite-only).

**Behavior:**
1. Confirm with user (destructive of local config).
2. Remove `.ksw-link.yaml`.
3. Strip KSW sections from `AGENTS.md`, `CLAUDE.md`.
4. Remove `.opencode/hooks/ksw-satellite.yaml`.
5. Remove KSW-bracketed sections from `.git/hooks/*` (post-commit, post-merge, prepare-commit-msg). Use the `[KSW-SAT-HOOK-START]` / `[KSW-SAT-HOOK-END]` markers we already write.
6. Notify hub: `glab issue create -R <hub> --title "Satellite <name> uninstalled" --label "type:maintenance,satellite:<name>"`.
7. Print: "Local config removed. To deregister this satellite from the hub, edit ksw.yaml#satellites[] manually."

---

## 6. Phase F — Loose ends from audit

### F1. `prepare-commit-msg` for hub

Add hook at `reference/hooks/hub/git/prepare-commit-msg` mirroring the satellite version (auto-inject `(KSW #ID)` on `ksw/<ID>-*` branches).

### F2. Orphans → wiki-to-issue wiring

Update `reference/workflows/wiki-to-issue/SKILL.md` to read `wiki/_graph/orphans.md` as one of its inputs. No new command needed.

### F3. `/sat contribute` conflict spec

In `SATELLITE-COMMANDS.md`, document the three resolution paths when contributing a wiki page that already exists on hub:
- **No conflict**: write directly.
- **Same content**: skip with note.
- **Diverged**: open a hub issue `type:decision` with both versions, mark the satellite contribution `state:blocked` until resolved.

---

## 7. Execution order + dependencies

```
A1 (frontmatter) ──┐
A2 (version stamp) ┤
A3 (CHANGELOG/VER) ┘
                   │
B1 (decide model) ──→ B2 (implement) ──→ B3 (smoke test)
                                │
C1 (target structure) ──────────┤
C2 (router contract) ───────────┤
C3 (extraction rules) ──────────┤
C5 (migration) ──→ C6 (token validation) ──→ C4 (lint script)
                                │
D1-D5 (conventions) ────────────┤   ← runs against the new fragments
                                │
E1 (reaper) ────────────────────┤
E2 (sat-on-local guard) ────────┤
E3 (max_parallel_agents) ───────┤
E5 (registry reconciliation) ───┤
E6 (sat uninstall) ─────────────┤
                                │
F1, F2, F3 ─────────────────────┘
```

**Critical path:** A → C → D → E. B is parallel to A. F is parallel to E.

**Don't start C5 until B1 is decided** — the install model determines whether fragments need to be discoverable as siblings or inlined.

---

## 8. Open decisions (before execution)

1. **B1**: install model — directory copy vs inline vs git-clone? **Default: directory copy.**
2. **D1**: branch convention — `ksw/<ID>-...` or `issue/<ID>-...`? **Default: `ksw/<ID>-...`.**
3. **E3**: enforce or drop `max_parallel_agents`? **Default: drop.**
4. **E1 default timeout**: 240 minutes? Or make it `null` (disabled by default, opt-in)? **Default: 240 minutes.**
5. **C1 fragment file extensions** — keep `.md` for everything (preferred for skill loaders) or use `.skill.md` to mark them as auto-loadable? **Default: plain `.md`.**

---

## 9. Out of scope (explicit non-goals for 0.6.0)

- Cross-host pull lock (deferred to 0.7.0, see E4).
- New platforms (no Bitbucket / Gitea / Forgejo support).
- Migration tool from 0.5.0 → 0.6.0 ksw.yaml (additive changes only — no migration needed).
- Wiki rendering / UI.
- Source pull beyond the 8 documented types.

---

## 10. Acceptance checklist

Run before tagging 0.6.0:

- [ ] `head -20 SKILL.md` shows valid YAML frontmatter with name + description + version.
- [ ] `wc -l SKILL.md` reports ≤ 200.
- [ ] All fragments listed in §C1 exist and open with a "Loaded when:" header.
- [ ] `scripts/lint-skill.sh` exits 0.
- [ ] Fresh `/init` on hub (gitlab + github + local), then satellite (gitlab + github), then `/init` smoke test passes.
- [ ] `/sat board` against an active hub returns the board without loading INIT.md or HUB-COMMANDS.md (verify via tracing or token-count).
- [ ] All hooks under `reference/hooks/**` reference `ksw/<ID>-*` (not `issue/<ID>-*`).
- [ ] `ksw.yaml` written by /init contains `ksw.skill_version: "0.6.0"`.
- [ ] `/reap --dry-run` runs cleanly on a hub with at least one stale wip.
- [ ] `/sat uninstall` removes all installed artifacts and reports any it could not remove.
- [ ] CHANGELOG entry for 0.6.0 lists all changes in §1-§6.
- [ ] VERSION reads `0.6.0`.

---

## 11. Risk register

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Skill loaders treat directory install differently across opencode/Claude/Cursor | Medium | High | Test all three before release; document explicit per-tool install steps in INSTALL.md. |
| Drift lint produces false positives blocking PRs | Low | Medium | Lint runs as warning first release, gating second release. |
| Splitting SKILL.md confuses agents that expect everything in one file | Medium | High | Router enforces "stop here, load the matching fragment". Smoke-test with a real agent before release. |
| Branch rename breaks existing hub repos with active `issue/<ID>-*` branches | Medium | Low | Document in CHANGELOG; hooks accept BOTH conventions during 0.6.x grace period. |
| Stale-WIP reaper releases work an agent is genuinely doing | Low | High | Default timeout 240m; hub agent hook posts a "still alive" comment on session_start. |
