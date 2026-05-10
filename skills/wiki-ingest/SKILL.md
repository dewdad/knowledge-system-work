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

- **Exists**: Merge new information into existing page
- **Doesn't exist**: Create new page
- **Contradicts existing**: Note contradiction, create issue for resolution

### 4. Write Wiki Page

Follow Obsidian markdown format:

```markdown
---
title: "<Page Title>"
category: concept | entity | decision | project | synthesis
domain: <domain_name>
tags: [tag1, tag2]
source: "<raw/filename.ext>"
created: "YYYY-MM-DD"
updated: "YYYY-MM-DD"
---

# <Page Title>

<Content here>

## Related
- [[link-to-related-page]]
- [[another-related-page]]
```

### 5. Cross-Link

After creating/updating pages:
1. Scan for unlinked mentions of existing wiki pages
2. Add `[[wikilinks]]` where appropriate
3. Update the source page's "Related" section

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
- **Source attribution** — Every claim traces to `source:` in frontmatter
- **No duplication** — If it exists, merge rather than create new
- **Markdown only** — No HTML, no embedded media (link externally)
