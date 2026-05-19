# KSW Hub Commands

> Loaded when: this workspace contains `ksw.yaml` (i.e. operates as a KSW hub) and the user invokes `/add-domain` or `/add-source`. Workflow-driven hub commands (`/pull`, `/triage`, `/ingest`, `/synthesize`, `/review`, `/brief`, `/graph-build`) are routed through [WORKFLOWS.md](WORKFLOWS.md). System-state commands (`/status`) and bootstrap (`/init`) are router-resident in [SKILL.md](SKILL.md) and [INIT.md](INIT.md) respectively.

Every command below assumes the agent has already verified workspace mode (see SKILL.md routing block). Platform commands come from [PLATFORM-OPS.md](PLATFORM-OPS.md).

---

## /add-domain `<name>`

Add a new knowledge domain to the hub.

1. **Validate name** — lowercase, alphanumeric + hyphens, no spaces. Reject otherwise.
2. **Create directory structure**:
   ```
   domains/<name>/
   ├── domain.yaml
   ├── sources.yaml
   └── .state/
       └── pulls.json    ← {}
   ```
3. **Write `domains/<name>/domain.yaml`**:
   ```yaml
   name: <name>
   description: "<ask user or infer>"
   color: "<assign from palette>"
   goals: []
   review_schedule: weekly
   wiki_path: "wiki/projects/<name>"
   related_domains: []
   ```
   The full schema (and field semantics) lives at [`reference/schemas/domain.schema.yaml`](reference/schemas/domain.schema.yaml).
4. **Write `domains/<name>/sources.yaml`**:
   ```yaml
   domain: <name>
   sources: []
   ```
   Schema: [`reference/schemas/sources.schema.yaml`](reference/schemas/sources.schema.yaml).
5. **Create wiki landing page** — `wiki/projects/<name>/` (empty directory; `/ingest` will populate).
6. **Update `ksw.yaml`** — append `<name>` to the `domains:` list.
7. **Create platform label** `domain:<name>` with the assigned color (see [PLATFORM-OPS.md](PLATFORM-OPS.md)).
8. **Regenerate AGENTS.md domains section** so the agent's session-start context reflects the new domain.
9. **Commit**:
   ```bash
   git add domains/<name>/ wiki/projects/<name>/ ksw.yaml AGENTS.md
   git commit -m "feat: add domain <name>"
   ```

After adding a domain, the next typical action is `/add-source <name> <type> <id>`.

---

## /add-source `<domain> <type> <id>`

Add a source feed to an existing domain.

1. **Parse args** — `type ∈ {rss, youtube, api, git, email, chat, calendar, manual}`.
2. **Validate domain exists** — `test -d domains/<domain>/`. If not, suggest `/add-domain <domain>` first.
3. **Prompt for type-specific fields**:

   | Type | Required fields |
   |------|-----------------|
   | `rss` | `url` |
   | `youtube` | `channel_id` or `playlist_id` |
   | `api` | `endpoint`, optional `auth_ref` |
   | `git` | `repo` (`owner/repo`), `events` (any of `commits|releases|issues|tags`) |
   | `email` / `chat` / `calendar` | service-specific connection params (and `auth_ref`) |
   | `manual` | nothing extra |

4. **Auth handling** — if the source requires credentials, ask: *"Where should I store the credential? `[secrets/<id>.yaml]`"* and write a stub. Accept any of: `{ token }` (bearer/API key), `{ username, password }` (basic), or `{ client_id, client_secret, scope? }` (OAuth2 client credentials). The `secrets/` directory is gitignored by `/init` — never commit credentials.
5. **Append to `domains/<domain>/sources.yaml`**:
   ```yaml
   - id: <id>
     type: <type>
     pull_schedule: daily
     auto_triage: true
     <type_specific_fields>
   ```
6. **Initialize pull state** in `domains/<domain>/.state/pulls.json`:
   ```json
   { "<id>": { "last_pull": null, "items_pulled": 0, "failures": 0 } }
   ```
   Schema: [`reference/schemas/pull-state.schema.yaml`](reference/schemas/pull-state.schema.yaml).
7. **Commit**:
   ```bash
   git add domains/<domain>/sources.yaml domains/<domain>/.state/pulls.json
   # Plus secrets stub path IF you wrote one — but secrets/ is gitignored so this is normally nothing.
   git commit -m "feat(<domain>): add source <id>"
   ```

After adding a source, run `/pull <domain>` (or just `/pull`) to fetch the first batch.

---

## Cross-references

- Generated workflow docs that operate on domains and sources: see [WORKFLOWS.md](WORKFLOWS.md), particularly **Source Pull**, **Issue Triage**, and **Domain Review**.
- All issue/queue mutations route through [PLATFORM-OPS.md](PLATFORM-OPS.md).
- Coordination state for issues created by triage: [COORDINATION.md](COORDINATION.md).
