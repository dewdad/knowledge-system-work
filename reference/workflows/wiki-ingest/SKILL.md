# Skill: Wiki Ingest

> Process raw material (files, exports, transcripts) into structured wiki pages.

## When to Use

- New file dropped in `raw/` or `wiki/_raw/`
- Explicit request to "add this to the wiki"
- After a research session produces notes

## Ingest Pipeline

### 1. Identify Source Material

```bash
# Check raw staging areas
ls raw/
ls wiki/_raw/
```

Supported formats: `.md`, `.txt`, `.pdf`, `.json`, `.html`, `.csv`

### 2. Extract Knowledge

For each source file:
1. **Read content** — Parse the format
2. **Identify knowledge units** — Each discrete fact, concept, or decision
3. **Classify** — What type of knowledge is this?

| Knowledge Type | Target Location | Example |
|---|---|---|
| Concept / Pattern | `wiki/concepts/` | "Event-driven architecture" |
| Person / Tool / Org | `wiki/entities/` | "Dr. Andrew Huberman" |
| Decision made | `wiki/decisions/` | "Chose PostgreSQL over MySQL" |
| Project-specific | `wiki/projects/<project>/` | "Alpha API design" |
| Cross-domain insight | `wiki/synthesis/` | "Sleep affects productivity" |

### 3. Resolve Against Existing Wiki

Before creating a new page:
```bash
# Check if page already exists
grep -r "<concept>" wiki/ --include="*.md" -l
```

- **Exists**: Merge new information into existing page and append source references
- **Alias match**: If any page frontmatter `aliases` contains the concept, merge there
- **Doesn't exist**: Create new page with a stable `id`
- **Contradicts existing**: Note contradiction, create issue for resolution

### 4. Write Wiki Page

Follow Obsidian markdown format:

```markdown
---
id: "<category>-<slug>-<short-hash>"
title: "<Page Title>"
aliases: ["<alternate name>"]
category: concept | entity | decision | project | synthesis
domain: <domain_name>
tags: [tag1, tag2]
sources:
  - source_id: "<source_item_id_or_raw_filename>"
    path: "<raw/filename.ext>"
    claim_scope: "page|section|inline"
confidence: high | medium | low
created: "YYYY-MM-DD"
updated: "YYYY-MM-DD"
---

# <Page Title>

<Content here>

## Related
- [[link-to-related-page]]
- [[another-related-page]]

## Sources
- `<source_id>` — <what this source supports>
```

### 5. Cross-Link

After creating/updating pages:
1. Scan for unlinked mentions of existing wiki pages
2. Add `[[wikilinks]]` where appropriate
3. Preserve existing aliases and do not rename files without adding redirects/aliases
4. Update the source page's "Related" section

### 6. Update Manifest

```bash
# Update wiki/_meta/.manifest.json with new page tracking
```

### 7. Clean Up

```bash
# Move processed raw file to indicate completion
# (Don't delete — raw/ is immutable source material)
# Add frontmatter note: processed: true, wiki_pages: [...]
```

## Quality Rules

- **One concept per page** — Don't create mega-pages
- **Wikilinks over plain text** — Always link to existing pages
- **Stable identity** — Page `id` never changes, even if title or filename changes
- **Aliases** — Add common names/synonyms to `aliases` before creating a near-duplicate page
- **Source attribution** — Every substantive claim traces to `sources` in frontmatter or an inline/section source note
- **Confidence** — Use `confidence: low` when importing weak, inferred, or agent-synthesized claims
- **No duplication** — If it exists, merge rather than create new
- **Markdown only** — No HTML, no embedded media (link externally)
