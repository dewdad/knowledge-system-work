# Skill: Issue to Wiki

> When an issue is closed, extract the decision rationale and log it as a wiki page.

## When to Use

- Issue with `type:decision` is closed
- Issue resolution contains valuable knowledge worth preserving
- Closing a significant task that established a pattern or convention

## Steps

### 1. Read the Closed Issue

```bash
glab issue view <ID> --comments
```

Extract:
- Title (becomes wiki page title)
- Description (context)
- Comments (especially the resolution/decision rationale)
- Labels (determine wiki placement: domain, type)

### 2. Determine Wiki Placement

| Issue Type | Wiki Location | Page Category |
|---|---|---|
| `type:decision` | `wiki/decisions/` | decision |
| `type:research` | `wiki/concepts/` or `wiki/projects/<domain>/` | concept |
| `type:task` (significant) | `wiki/projects/<domain>/` | project |

### 3. Create Wiki Page

```markdown
---
title: "<Decision/Finding Title>"
category: decision
domain: <domain_from_label>
tags: [<relevant_tags>]
source: "gitlab-issue#<ID>"
created: "<close_date>"
---

# <Title>

## Context

<From issue description — why was this needed?>

## Decision

<What was decided/concluded?>

## Rationale

<From comments — WHY this choice?>

## Consequences

<What follows from this decision?>

## Related

- [[<linked_concepts>]]
- [GitLab Issue #<ID>](link)
```

### 4. Cross-Link

- Find existing wiki pages that reference this topic
- Add `[[wikilinks]]` bidirectionally
- Update `wiki/index.md` if this is a significant decision

### 5. Commit

```bash
git add wiki/
git commit -m "docs: log decision from issue #<ID>"
```

## When NOT to Use

- Trivial issues (typo fixes, routine maintenance)
- Issues closed as "won't do" or duplicate
- Issues where the resolution is self-evident from the code
