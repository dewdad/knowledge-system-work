# Skill: Wiki Synthesize

> Analyze wiki content across domains to find patterns, contradictions, and opportunities.

## When to Use

- Weekly scheduled synthesis run
- After significant wiki growth (10+ new pages)
- On-demand "find patterns" request
- After multiple domain reviews complete

## Steps

### 1. Inventory Current Wiki State

```bash
# Count pages per section
find wiki/concepts -name "*.md" | wc -l
find wiki/entities -name "*.md" | wc -l
find wiki/decisions -name "*.md" | wc -l
find wiki/projects -name "*.md" | wc -l
find wiki/synthesis -name "*.md" | wc -l

# Recently modified pages (last 7 days)
git log --since="7 days ago" --name-only --format="" -- wiki/ | sort -u
```

### 2. Cross-Domain Pattern Detection

Look for:
- **Concepts appearing in 3+ domains** → Candidate for synthesis page
- **Entities referenced by multiple projects** → May need global page upgrade
- **Tags used inconsistently** → Taxonomy needs cleanup
- **Contradictions** → Pages that claim opposite things
- **Orphans** → Pages with zero incoming wikilinks

```bash
# Find most-linked pages (high-value nodes)
grep -roh '\[\[[^]]*\]\]' wiki/ | sort | uniq -c | sort -rn | head -20

# Find orphaned pages
for file in $(find wiki/ -name "*.md" -not -path "wiki/_*"); do
  BASENAME=$(basename "$file" .md)
  LINKS=$(grep -r "\[\[${BASENAME}" wiki/ --include="*.md" -l | grep -v "$file" | wc -l)
  if [ "$LINKS" -eq 0 ]; then
    echo "ORPHAN: $file"
  fi
done
```

### 3. Generate Synthesis

For each detected pattern, create or update a synthesis page:

```markdown
---
title: "<Pattern Name>"
category: synthesis
tags: [cross-domain, <relevant_tags>]
domains: [<domain1>, <domain2>]
created: "YYYY-MM-DD"
updated: "YYYY-MM-DD"
---

# <Pattern Name>

## Observation

<What pattern was detected across domains?>

## Evidence

- [[<page1>]] (domain:X) — <how it manifests>
- [[<page2>]] (domain:Y) — <how it manifests>

## Implications

<What does this mean? What should we do about it?>

## Open Questions

- <Unanswered question that could become an issue>
```

### 4. Update Insights

Write findings to `wiki/_meta/_insights.md`:

```markdown
# Wiki Insights — YYYY-MM-DD

## Patterns Found
- <pattern1>: linked from <pages>
- <pattern2>: ...

## Contradictions
- <page A> says X, but <page B> says Y

## Gaps
- Domain <X> has no coverage of <topic>

## Recommendations
- Create synthesis page for <pattern>
- Investigate contradiction in <topic>
- Add coverage for <gap>
```

### 5. Create Follow-Up Issues

For actionable findings, use `wiki-to-issue` skill to create GitLab issues.

## Output

- Updated/new pages in `wiki/synthesis/`
- Updated `wiki/_meta/_insights.md`
- (Optional) New GitLab issues for actionable findings
