# Integration Plan: Ideas from Ar9av/obsidian-wiki

> Selectively adopt the best patterns from [`Ar9av/obsidian-wiki`](https://github.com/Ar9av/obsidian-wiki) into KSW.
> This is NOT a dependency — it's cherry-picking ideas from a peer system.

## Context

`obsidian-wiki` is a skill-based wiki maintenance framework (Karpathy's "LLM Wiki" pattern). KSW already covers its core domain (wiki ingest, synthesis, graph) plus much more (source management, issue coordination, triage, scheduling). However, obsidian-wiki has several battle-tested patterns KSW lacks:

1. **Page-level provenance tracking** (`.manifest.json`)
2. **Agent history mining** (Claude/Codex/ChatGPT session → wiki)
3. **Cross-project wiki sync** (`wiki-update` from any project)
4. **Multi-format graph export** (JSON, GraphML, Neo4j Cypher, HTML)
5. **Dedicated cross-linker pass** (discover + insert missing wikilinks post-hoc)

---

## Feature 1: Page-Level Provenance Tracking

### What obsidian-wiki does

Maintains `.manifest.json` at vault root with per-source entries:

```json
{
  "sources": {
    "/path/to/source/file.md": {
      "ingested_at": "2025-12-01T10:30:00Z",
      "pages_created": ["concepts/transformers", "entities/openai"],
      "pages_updated": ["concepts/attention-mechanisms"],
      "content_hash": "sha256:abc123...",
      "last_commit_synced": "a1b2c3d"
    }
  },
  "pages": {
    "concepts/transformers": {
      "created_at": "2025-12-01T10:30:00Z",
      "updated_at": "2025-12-15T08:00:00Z",
      "sources": ["/path/to/source/file.md", "claude-session:ses_abc"],
      "source_type": "document"
    }
  }
}
```

This enables: delta ingestion (only process new/modified sources), staleness detection (source changed but wiki page hasn't), and provenance queries ("which source produced this page?").

### How KSW should adapt this

KSW already tracks pull state in `.ksw/state/pulls.json` (per-source). The gap is **page-level provenance** — knowing which source item → which wiki page(s).

**Proposed implementation:**

- Add `.ksw/state/provenance.json` tracking:
  - `source_item_id → wiki_page[]` mapping (forward reference)
  - `wiki_page → source_item_id[]` mapping (backward reference)
  - `content_hash` per source for delta detection
  - `ingested_at` timestamp per entry
- Update `wiki-ingest.md` workflow to write provenance entries after page creation/update
- Update `domain-review.md` to check for stale pages (source updated, page hasn't)

### Files to read from obsidian-wiki

| File | Why |
|------|-----|
| [`.skills/wiki-update/SKILL.md`](https://raw.githubusercontent.com/Ar9av/obsidian-wiki/main/.skills/wiki-update/SKILL.md) | Manifest read/write patterns, delta computation via `last_commit_synced` |
| [`.skills/wiki-ingest/SKILL.md`](https://raw.githubusercontent.com/Ar9av/obsidian-wiki/main/.skills/wiki-ingest/SKILL.md) | How manifest entries are written during ingest |
| [`.skills/wiki-status/SKILL.md`](https://raw.githubusercontent.com/Ar9av/obsidian-wiki/main/.skills/wiki-status/SKILL.md) | How manifest is queried for status/staleness reporting |
| [DeepWiki: Manifest, Index, and Log Files](https://deepwiki.com/Ar9av/obsidian-wiki/4.2-manifest-index-and-log-files) | Full schema documentation |

### Effort: Medium

Changes: `reference/schemas/` (new schema), `wiki-ingest.md` workflow, `domain-review.md` workflow, SKILL.md `/ingest` summary.

---

## Feature 2: Agent History Mining

### What obsidian-wiki does

Dedicated skills (`claude-history-ingest`, `codex-history-ingest`, `hermes-history-ingest`) that:

1. Scan agent session directories:
   - Claude: `~/.claude/projects/*/` (JSONL conversations + memory files)
   - Claude Desktop: `~/Library/Application Support/Claude/local-agent-mode/` or `%APPDATA%/Claude/`
   - Codex: `~/.codex/` (sessions, rollouts, history index)
2. Check manifest for already-ingested sessions (delta mode)
3. Extract knowledge units: architecture decisions, patterns, debugging breakthroughs, project-specific insights
4. Write wiki pages with proper `source_type: "claude-session"` provenance
5. Update manifest with `content_hash` and `ingested_at`

**Key insight**: It doesn't dump conversations verbatim. It _distills_ — asking "what would you want to know if you came back in 3 months?"

### How KSW should adapt this

Add `agent-history` as a new **source type** in `sources.yaml`:

```yaml
domains:
  - name: meta
    sources:
      - type: agent-history
        id: claude
        path: "~/.claude"
        # auto-detects platform (Windows: %APPDATA%/Claude, macOS: ~/Library/...)
      - type: agent-history
        id: codex
        path: "~/.codex"
```

The `source-pull.md` workflow would gain a new handler for `type: agent-history` that:
- Scans session directories for new/modified JSONL files
- Creates inbox items per session (or batch per project)
- The existing `wiki-ingest.md` then processes these into wiki pages

### Files to read from obsidian-wiki

| File | Why |
|------|-----|
| [`.skills/claude-history-ingest/SKILL.md`](https://raw.githubusercontent.com/Ar9av/obsidian-wiki/main/.skills/claude-history-ingest/SKILL.md) | Full Claude data layout, JSONL parsing, extraction algorithm, memory file handling |
| [`.skills/codex-history-ingest/SKILL.md`](https://raw.githubusercontent.com/Ar9av/obsidian-wiki/main/.skills/codex-history-ingest/SKILL.md) | Codex session format, rollout logs, history index |
| [`.skills/wiki-history-ingest/SKILL.md`](https://raw.githubusercontent.com/Ar9av/obsidian-wiki/main/.skills/wiki-history-ingest/SKILL.md) | Router skill that dispatches to the right ingest handler |
| [`.skills/data-ingest/SKILL.md`](https://raw.githubusercontent.com/Ar9av/obsidian-wiki/main/.skills/data-ingest/SKILL.md) | Generic ingest for ChatGPT exports, Slack logs, transcripts |
| [DeepWiki: Agent History Ingest Skills](https://deepwiki.com/Ar9av/obsidian-wiki/3.2.1-agent-history-ingest-skills) | Architecture overview of all history ingest skills |

### Effort: High

Changes: New source type in schemas, new handler in `source-pull.md`, new JSONL parsing logic, platform detection (Win/Mac/Linux paths), memory file extraction rules.

---

## Feature 3: Cross-Project Wiki Sync

### What obsidian-wiki does

The `wiki-update` skill works from ANY project directory (not just the wiki repo):

1. Resolves vault path from `~/.obsidian-wiki/config` (global config)
2. Scans current project: README, source structure, git log, docs, claude memory
3. Computes delta via `git log <last_commit_synced>..HEAD`
4. Distills: architecture decisions, patterns, key abstractions, trade-offs, lessons learned
5. Writes pages to the vault with proper provenance
6. Updates manifest with `last_commit_synced`

**Key insight**: It answers "what would you forget in 3 months?" — not "what files exist?"

### How KSW should adapt this

KSW is currently project-scoped (one KSW instance per repo). Adding a global sync command would let users push knowledge from any project into their KSW wiki.

**Proposed command: `/sync`**

```
/sync [--project <path>]   # Sync current (or specified) project into this KSW wiki
```

Implementation:
- KSW already has the wiki layer. The new piece is the "external project scanner"
- Would create a new workflow: `.ksw/workflows/project-sync.md`
- Adds a `synced_projects` section to `ksw.yaml`:

```yaml
synced_projects:
  - path: ~/code/my-api
    last_commit: "a1b2c3d"
    last_sync: "2025-12-15T08:00:00Z"
  - path: ~/code/frontend
    last_commit: "d4e5f6g"
    last_sync: "2025-12-14T10:00:00Z"
```

### Files to read from obsidian-wiki

| File | Why |
|------|-----|
| [`.skills/wiki-update/SKILL.md`](https://raw.githubusercontent.com/Ar9av/obsidian-wiki/main/.skills/wiki-update/SKILL.md) | Complete workflow: project scanning, delta computation, distillation criteria, page creation |
| [`.skills/llm-wiki/SKILL.md`](https://raw.githubusercontent.com/Ar9av/obsidian-wiki/main/.skills/llm-wiki/SKILL.md) | Core pattern architecture — the "compile once, query many" philosophy, config resolution protocol |
| [`setup.sh`](https://raw.githubusercontent.com/Ar9av/obsidian-wiki/main/setup.sh) | Global config write pattern (`~/.obsidian-wiki/config`) |
| [DeepWiki: Query and Update Skills](https://deepwiki.com/Ar9av/obsidian-wiki/3.3-query-and-update-skills) | How wiki-update and wiki-query work together |

### Effort: Medium-High

Changes: New command in SKILL.md, new workflow file, `ksw.yaml` schema extension, new state tracking in `.ksw/state/`.

---

## Feature 4: Multi-Format Graph Export

### What obsidian-wiki does

The `wiki-export` skill outputs 4 formats from the wikilink graph:

1. **`graph.json`** — Nodes with `id`, `label`, `category`, `tags`, `summary` + edges with `source`, `target`, `relation`, `confidence`
2. **`graph.graphml`** — Standard GraphML XML for Gephi/yEd
3. **`cypher.txt`** — Neo4j Cypher `CREATE` statements for direct import
4. **`graph.html`** — Self-contained interactive force-directed visualization (D3.js or vis.js)

Also supports a **visibility filter** (exclude `visibility/internal` or `visibility/pii` tagged pages from public exports).

### How KSW should adapt this

KSW's `/graph-build` currently outputs only `wiki/_graph/graph.json` (adjacency list + stats). Extend with export formats.

**Proposed enhancement to `/graph-build`:**

```
/graph-build [--export json,graphml,cypher,html] [--filter public]
```

- Default behavior unchanged (just rebuilds graph.json + orphans.md)
- `--export` adds additional output files to `wiki/_graph/`
- `--filter public` excludes pages tagged `visibility:internal`

### Files to read from obsidian-wiki

| File | Why |
|------|-----|
| [`.skills/wiki-export/SKILL.md`](https://raw.githubusercontent.com/Ar9av/obsidian-wiki/main/.skills/wiki-export/SKILL.md) | Full format specs: GraphML XML structure, Cypher generation pattern, HTML template with D3 |
| [DeepWiki: Knowledge Graph and Taxonomy](https://deepwiki.com/Ar9av/obsidian-wiki/4.3-knowledge-graph-and-taxonomy) | How the graph model works, node/edge schema |
| [DeepWiki: Vault Lifecycle Skills](https://deepwiki.com/Ar9av/obsidian-wiki/3.1-vault-lifecycle-skills:-setup-rebuild-and-export) | Export in context of vault lifecycle |

### Effort: Low-Medium

Changes: Extend `graph-build.md` workflow with format generators. No new commands — just new `--export` option on existing command.

---

## Feature 5: Dedicated Cross-Linker Pass

### What obsidian-wiki does

A separate `cross-linker` skill that:

1. **Builds page registry**: glob all pages, extract filename/title/aliases/tags/summary as "vocabulary"
2. **Scans for unlinked mentions**: for each page, search body text for page names/titles/aliases that aren't already wrapped in `[[...]]`
3. **Applies confidence scoring**:
   - Exact filename/title match → high confidence, auto-link
   - Alias match → medium confidence, auto-link
   - Partial/fuzzy match → low confidence, skip or flag
4. **Inserts links**: replaces first unlinked occurrence with `[[target|display text]]`
5. **Reports**: summary of links added per page

**Key design choice**: Only links the FIRST occurrence per page (not every mention). Skips code blocks, frontmatter, and existing links.

### How KSW should adapt this

KSW currently bakes cross-linking into the `wiki-ingest.md` workflow (link at write time). But pages drift — new pages get created that old pages should link to. A post-hoc pass catches this.

**Proposed: Add to `/review` or new `/cross-link` command**

Option A: Extend `/review <domain>` to include a cross-link check (report only)
Option B: New `/cross-link` command that actually inserts links (write operation)

Recommendation: **Option B** — separate command because it's a write operation that should be explicitly requested.

### Files to read from obsidian-wiki

| File | Why |
|------|-----|
| [`.skills/cross-linker/SKILL.md`](https://raw.githubusercontent.com/Ar9av/obsidian-wiki/main/.skills/cross-linker/SKILL.md) | Full algorithm: registry building, unlinked mention detection, confidence scoring, insertion rules |
| [`.skills/wiki-lint/SKILL.md`](https://raw.githubusercontent.com/Ar9av/obsidian-wiki/main/.skills/wiki-lint/SKILL.md) | Read-only lint (reports orphans, broken links) — compare to cross-linker's write approach |
| [`.skills/tag-taxonomy/SKILL.md`](https://raw.githubusercontent.com/Ar9av/obsidian-wiki/main/.skills/tag-taxonomy/SKILL.md) | Related pattern: enforcing consistency across pages post-hoc |
| [DeepWiki: Maintenance Skills](https://deepwiki.com/Ar9av/obsidian-wiki/3.4-maintenance-skills:-lint-status-cross-linker-and-tag-taxonomy) | How cross-linker fits into the maintenance skill family |

### Effort: Medium

Changes: New command in SKILL.md, new workflow file, algorithm definition (vocabulary building, scanning, confidence thresholds, insertion rules).

---

## Implementation Priority

| # | Feature | Effort | Value | Priority |
|---|---------|--------|-------|----------|
| 6 | Semantic search integration | Medium-High | **Critical** (improves every workflow) | **P0** |
| 1 | Page-level provenance | Medium | High (enables staleness, delta, audit) | **P1** |
| 5 | Cross-linker pass | Medium | High (wiki quality degrades without it) | **P1** |
| 4 | Multi-format graph export | Low-Medium | Medium (visualization, external tools) | **P2** |
| 2 | Agent history mining | High | High (free knowledge capture) | **P2** |
| 3 | Cross-project sync | Medium-High | Medium (personal productivity) | **P3** |

### Rationale

- **P0**: Semantic search is foundational — it improves wiki-ingest (better merge detection), wiki-synthesize (find non-obvious patterns), cross-linker (suggest semantic links), and triage (smarter routing). Every other feature benefits from it. Design as opt-in enhancement with grep fallback.
- **P1 items** directly improve wiki quality and are prerequisites for other features (provenance needed by history mining; cross-linker needed after any bulk ingest)
- **P2 items** add significant capability but are more complex or less frequently used
- **P3 items** are nice-to-have and require architectural decisions about KSW's scope (project-scoped vs. global)

### Dependency Graph

```
Semantic Search (P0)
    ↓ enhances
├── Cross-linker (P1) — uses semantic matching for link discovery
├── Wiki-ingest (existing) — uses semantic resolve for merge-vs-create
└── Wiki-synthesize (existing) — uses semantic similarity for pattern detection

Provenance (P1)
    ↓ enables
├── Agent History Mining (P2) — needs provenance to track session → page mapping
└── Domain Review (existing) — uses provenance for staleness detection

Cross-project Sync (P3)
    ↓ requires
└── Provenance (P1) — needs to track external project → page mapping
```

---

## Additional Reference Files (General Architecture)

| File | Why |
|------|-----|
| [`.skills/llm-wiki/SKILL.md`](https://raw.githubusercontent.com/Ar9av/obsidian-wiki/main/.skills/llm-wiki/SKILL.md) | Core architecture reference — 3-layer model, page templates, retrieval primitives, config resolution |
| [`AGENTS.md`](https://raw.githubusercontent.com/Ar9av/obsidian-wiki/main/AGENTS.md) | System overview, conventions, how skills compose |
| [`SETUP.md`](https://raw.githubusercontent.com/Ar9av/obsidian-wiki/main/SETUP.md) | Full setup documentation, vault structure, skill reference table |
| [`.env.example`](https://raw.githubusercontent.com/Ar9av/obsidian-wiki/main/.env.example) | Configuration variables, QMD semantic search integration |
| [DeepWiki: Core Concepts](https://deepwiki.com/Ar9av/obsidian-wiki/1.2-core-concepts-and-architecture) | "Compile once, query many" philosophy, 3-layer architecture |
| [DeepWiki: Page Schema](https://deepwiki.com/Ar9av/obsidian-wiki/4.1-page-schema-and-frontmatter) | Frontmatter field definitions, confidence levels, visibility tags |

---

## Feature 6: Semantic Search Integration

### Why this matters

KSW currently uses `grep -r` for ALL knowledge retrieval:

| Workflow | Current Search | What's missed |
|----------|---------------|---------------|
| **wiki-ingest** "resolve against existing wiki" | `grep -r "<concept>" wiki/ -l` | Synonyms, paraphrases, conceptual overlap |
| **wiki-synthesize** "detect patterns" | `grep -roh '\[\[...\]\]'` + wikilink counting | Semantic similarity between unlinked pages |
| **issue-triage** "determine domain" | "keyword match to ksw.yaml domains" | Concepts that don't use domain keywords |
| **cross-linker** (proposed) | Page name/title exact match | Conceptual references without exact naming |
| **morning-brief** context | Scans recent git changes | Can't surface "related to what you're working on" |

Grep finds **exact strings**. A knowledge base needs to find **related meaning**.

### What obsidian-wiki does (QMD integration)

obsidian-wiki uses [QMD](https://github.com/tobi/qmd) (24K stars) as an optional MCP server:

- `QMD_WIKI_COLLECTION` → indexes compiled wiki pages
- `QMD_PAPERS_COLLECTION` → indexes raw source documents
- `wiki-query` runs `lex+vec` pass before falling back to grep
- `wiki-ingest` queries indexed sources before writing, surfacing related work, detecting contradictions, deciding merge vs. create
- **Graceful fallback**: Without QMD, both skills fall back to Grep/Glob and remain fully functional

### Integration preference: CLI-first, not MCP-first

KSW is a **skill** — a markdown file that instructs AI agents. Its workflows are expressed as shell commands the agent executes. This means:

- **CLI tools are the primary interface.** Workflow instructions say `qmd search "..." --json` — the agent runs it directly. No server process to manage, no transport protocol, no connection lifecycle.
- **MCP servers are secondary.** They're useful when the agent's host supports MCP natively, but KSW workflows shouldn't *require* MCP. An agent that can only run shell commands must still work.
- **Skills over servers.** If a search tool ships as both a CLI and an MCP server, KSW workflows reference the CLI. Users who want MCP can configure it in their agent's MCP config independently — KSW doesn't need to know.

**Why CLI is better for KSW:**

1. **Universality** — Every AI agent can run shell commands. Not every agent supports MCP.
2. **Debuggability** — User can run the same commands manually to verify behavior.
3. **No daemon management** — CLI tools run on-demand. MCP servers need to be started, kept alive, monitored.
4. **Workflow portability** — Bash/shell commands work across all platforms KSW supports (GitLab CI, GitHub Actions, local agents).
5. **Simpler `/init`** — Detecting `which qmd` is trivial. Verifying an MCP server is running and responsive adds complexity.

**When MCP is acceptable:**

- The user has already configured the MCP server in their agent (KSW doesn't care — it's orthogonal)
- A tool's CLI is insufficient (e.g., lacks `--json` output) and MCP provides richer structured responses
- Background indexing/watching that benefits from a persistent process (Phase 2 optimization, not Phase 1)

### Landscape of Local Semantic Search Tools (2025-2026)

Evaluated for **CLI quality** (JSON output, scriptable, no daemon required):

| Tool | Language | Embedding Model | Search Modes | CLI Quality | MCP Also? | Platform | Install | Stars |
|------|----------|----------------|--------------|-------------|-----------|----------|---------|-------|
| **[QMD](https://github.com/tobi/qmd)** | TypeScript | embeddinggemma-300M (GGUF, local) | BM25 + vector + LLM reranking | ⭐ Excellent (`--json`, `--files`, `--all`) | Yes | All | `npm i -g @tobilu/qmd` | 24K |
| **[mdvdb](https://mdvdb.dev/)** | Rust | Ollama or OpenAI | BM25/Tantivy + vector + RRF | ⭐ Excellent (single binary, `--mode`, `--filter`) | No (CLI + REST) | All | Single binary | ~new |
| **[sqmd](https://github.com/itkoren/sqmd)** | TypeScript | nomic-embed-text-v1.5 (ONNX, local) | BM25/Tantivy + vector + RRF | Good (CLI + REST + MCP) | Yes | All | npm/binary | ~new |
| **[kbx](https://github.com/tenfourty/kbx)** | Python | Qwen3-Embedding-0.6B | FTS5 + vector + RRF | Good (`--json`, `--fast`) | Yes (optional extra) | All (MLX on Mac) | `pip install kbx[search]` | ~new |
| **[mdkb](https://github.com/sstraus/mdkb)** | TypeScript | AllMiniLM-L6-V2 (ONNX) | BM25 + semantic + code | Fair (CLI exists, MCP-focused) | Yes (primary) | All | npm | ~new |
| **[mcpmydocs](https://github.com/mattdennewitz/mcpmydocs)** | Go | all-MiniLM-L6-v2 (ONNX) | Vector + cross-encoder reranking | Poor (MCP-primary, CLI minimal) | Yes (primary) | macOS/Linux | Binary + models | ~new |
| **[pdf-brain](https://github.com/joelhooks/pdf-brain)** | TypeScript | mxbai-embed-large (Ollama) | Vector + FTS5 hybrid | Fair (CLI exists, MCP-focused) | Yes (primary) | All (needs Ollama) | npm | ~new |

**Top picks for KSW (CLI-first criterion):**

1. **QMD** — Best CLI ergonomics (`search`, `vsearch`, `query` with `--json`), largest community, handles collections well, no daemon needed for search (only embed step pre-computes).
2. **mdvdb** — Single Rust binary, zero dependencies to install, excellent CLI with rich filtering (`--boost-links`, `--decay`, `--filter KEY=VALUE`), markdown-native (understands frontmatter + wikilinks natively). No MCP at all — pure CLI.
3. **kbx** — Python ecosystem, `--fast` mode for instant FTS-only, proper `--json` output. Good if user already has Python.

### Recommended approach: CLI-based, tool-agnostic search layer

KSW should NOT couple to any specific tool. Instead, define a **CLI search interface** that any tool can satisfy — invoked as shell commands, not as MCP tool calls:

```yaml
# ksw.yaml addition
search:
  provider: auto    # auto | qmd | sqmd | mdvdb | kbx | disabled
  index_path: .ksw/cache/search-index/
  collections:
    wiki: wiki/
    raw: raw/
  fallback: grep    # Always works without search provider
```

**Provider detection (`auto` mode) — CLI binary presence only:**
1. `which qmd` succeeds → use QMD (best overall: 24K stars, rich CLI, local GGUF models)
2. `which mdvdb` succeeds → use mdvdb (single binary, markdown-native, link-aware)
3. `which sqmd` succeeds → use sqmd (TypeScript, Tantivy, incremental)
4. `which kbx` succeeds → use kbx (Python, Qwen3, FTS5+vector)
5. None found → fallback to grep (current behavior, always works)

Note: Detection is a simple `which`/`command -v` check. No MCP server health checks, no port probing, no daemon verification.

### Integration points in KSW workflows

| Workflow | Grep (current) | Semantic (enhanced) |
|----------|---------------|---------------------|
| **wiki-ingest** Step 3 "Resolve against existing wiki" | `grep -r "<concept>" wiki/ -l` | `<search> query "<concept>" --collection wiki --top-k 5` → finds related pages even with different naming |
| **wiki-synthesize** Step 2 "Cross-domain pattern detection" | Count wikilinks + find orphans | `<search> query "<page_summary>" --collection wiki` per page → find semantically similar pages that aren't linked |
| **cross-linker** Step 2 "Scan for missing links" | Exact filename/title/alias match | `<search> query "<paragraph>" --collection wiki --top-k 3` → suggest links based on meaning |
| **issue-triage** "Determine domain" | Keyword match against domain names | `<search> query "<issue_title>" --collection wiki` → route to domain with most matching pages |
| **graph-build** (new capability) | Structural links only | Add "semantic edges" — pages that are semantically similar but not linked (weight: inferred) |

### Implementation design

**Phase 1: CLI search abstraction layer**

Workflows reference search via direct CLI commands. The agent reads `ksw.yaml` to determine which tool to invoke:

```bash
# All invocations are direct CLI commands — no MCP, no servers, no SDKs.
# The agent picks the right command based on ksw.yaml search.provider:

# QMD (preferred — best CLI ergonomics)
qmd search "$query" -c wiki -n 5 --json

# mdvdb (single binary, markdown-native)
mdvdb search "$query" --limit 5 --mode hybrid --boost-links

# sqmd
sqmd search "$query" --top-k 5 --mode hybrid

# kbx
kbx search "$query" --limit 5 --json

# Fallback (always available, no install needed)
grep -r "$query" wiki/ --include="*.md" -l | head -n 5
```

The workflow docs (`.ksw/workflows/*.md`) will contain a "Search Primitive" section:

```markdown
## Search Primitive

Check `ksw.yaml` → `search.provider`. Execute the corresponding CLI command:

| Provider | Command |
|----------|---------|
| `qmd` | `qmd search "<query>" -c <collection> -n <top_k> --json` |
| `mdvdb` | `mdvdb search "<query>" --limit <top_k> --mode hybrid` |
| `sqmd` | `sqmd search "<query>" --top-k <top_k> --mode hybrid` |
| `kbx` | `kbx search "<query>" --limit <top_k> --json` |
| `disabled` / not found | `grep -r "<query>" <collection>/ --include="*.md" -l \| head -n <top_k>` |

All commands return file paths with relevance scores. Parse JSON output when available.
```

**Phase 2: Index management (CLI-driven)**

Index commands are also CLI — run by the agent on-demand or by cron:

```bash
# Index/embed commands (run after content changes)
qmd collection add wiki/ --name wiki && qmd embed
mdvdb ingest
sqmd index
kbx index run
```

Add to `ksw.yaml` scheduling:
```yaml
scheduling:
  search_reindex: "0 5 * * *"    # After source-pull, before morning-brief
```

Reindex triggers (agent runs the embed/index command):
- After `/ingest` completes (new wiki pages added)
- After `/pull` adds new raw items
- Scheduled nightly (catch manual edits)

No persistent daemon needed. The agent calls `<tool> embed` or `<tool> index` as a shell command, then calls `<tool> search` later. State lives on disk (index files), not in memory.

**Phase 3: Enhanced workflows**

Update wiki-ingest, wiki-synthesize, cross-linker to use the Search Primitive when provider is available, grep when not. Each workflow has a single decision point: "Is `search.provider` set in ksw.yaml? If yes, use semantic. If no, use grep."

### Files to read from obsidian-wiki

| File | Why |
|------|-----|
| [`.skills/wiki-ingest/SKILL.md`](https://raw.githubusercontent.com/Ar9av/obsidian-wiki/main/.skills/wiki-ingest/SKILL.md) | How QMD is queried during ingest (contradiction detection, merge-vs-create decision) |
| [`.skills/wiki-query/SKILL.md`](https://raw.githubusercontent.com/Ar9av/obsidian-wiki/main/.skills/wiki-query/SKILL.md) | How the lex+vec search pass works, fallback pattern |
| [`.skills/llm-wiki/SKILL.md`](https://raw.githubusercontent.com/Ar9av/obsidian-wiki/main/.skills/llm-wiki/SKILL.md) | "Retrieval Primitives" table — how obsidian-wiki abstracts search |
| [`.env.example`](https://raw.githubusercontent.com/Ar9av/obsidian-wiki/main/.env.example) | QMD configuration variables pattern |
| [QMD README](https://github.com/tobi/qmd/blob/main/README.md) | Full CLI reference, MCP tools, collection model, embedding flow |
| [sqmd README](https://github.com/itkoren/sqmd) | TypeScript alternative — incremental indexing, ONNX embeddings, filesystem watcher |
| [mdvdb docs](https://mdvdb.dev/) | Rust single-binary — markdown-native, link-aware graph search, decay scoring |

### Effort: Medium-High

Changes: New search abstraction in generated workflows, `ksw.yaml` schema extension, provider detection logic, updates to wiki-ingest/wiki-synthesize/cross-linker workflows, index management scheduling.

### Key design principles

1. **CLI-first, not MCP-first.** Workflows invoke search as shell commands (`qmd search ...`). MCP is the user's concern, not KSW's. If a user wants to configure their agent to use QMD via MCP, that's orthogonal — KSW's workflow instructions remain CLI commands.
2. **Skills over servers.** Semantic search is a tool the agent calls, like `grep` or `markitdown`. Not a background service it connects to. KSW's `tools:` section in ksw.yaml follows this pattern: `markitdown: auto`, `search: auto`.
3. **Never a hard dependency.** Grep fallback always works. Semantic search is enhancement, not requirement. `/init` reports "search: qmd (detected)" or "search: disabled (install qmd for semantic search)".
4. **Tool-agnostic.** User brings their own search tool. KSW detects CLI presence and adapts. No vendor lock-in.
5. **Incremental by default.** Only re-index changed files (all recommended tools support this via content hashing).
6. **Collections map to KSW directories.** `wiki/` = compiled knowledge, `raw/` = source material. Maps directly to search tool collection/directory concepts.
7. **Same output contract for all providers.** Query in → ranked file paths with scores out. Agent parses JSON when available, falls back to newline-separated paths.

---

## Non-Goals (explicitly NOT adopting)

- **MCP-first search integration** — KSW will NOT require running an MCP server for semantic search. Workflows use CLI commands. Users who want MCP can configure it in their agent independently — KSW doesn't reference MCP tools in its workflow instructions.
- **Skill distribution via symlinks** — KSW uses single-file SKILL.md distribution. Not adopting the multi-file `.skills/*/SKILL.md` + `setup.sh` symlink model.
- **`wiki-query` as a standalone command** — KSW integrates semantic search INTO existing workflows rather than exposing a separate "ask your wiki" command. The knowledge surfaces where needed (ingest, synthesize, brief) rather than requiring explicit querying.
- **`wiki-capture` (save current conversation)** — Overlaps with history mining but is too ephemeral for KSW's structured approach.
- **Coupling to a single search provider** — KSW will NOT require QMD, sqmd, or any specific tool. Provider-agnostic CLI abstraction with grep fallback.
- **Background search daemons** — No requirement for persistent processes. Search tools are invoked on-demand like any other CLI tool. File watchers and background indexing are user-configured optimizations, not KSW requirements.
