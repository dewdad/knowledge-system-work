# KSW Platform Operations

> Loaded when: any KSW command needs to mutate or query an issue board (or local queue) — by hub commands, satellite commands, and generated workflows. This is the single source of truth for platform-specific shell invocations.

KSW abstracts three platforms behind a uniform action vocabulary. Pick the column that matches `ksw.yaml#instance.platform` (hub) or `.ksw-link.yaml#hub.platform` (satellite).

| Platform | CLI | Hub support | Satellite support |
|----------|-----|-------------|-------------------|
| `gitlab` | `glab` | Primary | Primary |
| `github` | `gh`   | Documented; verify generated hooks before unattended use | Documented; verify generated hooks before unattended use |
| `local`  | none — filesystem queue | Hub only | Not supported (satellites require a remote-accessible hub) |

Authentication is delegated entirely to the platform CLI (`glab auth login` / `gh auth login`). KSW never stores tokens in config files. Source pull credentials live in `secrets/<source_id>.yaml` (gitignored).

---

## Hub Operations

Run from the hub workspace itself (no `-R` flag).

| Action | GitLab (`glab`) | GitHub (`gh`) | Local |
|--------|-----------------|---------------|-------|
| List inbox | `glab issue list --label "state:inbox"` | `gh issue list --label "state:inbox"` | `ls .ksw/queue/inbox/` |
| List ready | `glab issue list --label "state:ready"` | `gh issue list --label "state:ready"` | `ls .ksw/queue/ready/` |
| Create issue | `glab issue create --title "..." --label "..."` | `gh issue create --title "..." --label "..."` | Create `.ksw/queue/inbox/<id>.md` |
| Claim (assign+wip) | `glab issue update <ID> --assignee "@me" --unlabel "state:ready" --label "state:wip"` | `gh issue edit <ID> --add-assignee "@me" --remove-label "state:ready" --add-label "state:wip"` | `mv .ksw/queue/ready/<file> .ksw/queue/wip/` |
| Complete (→review) | `glab issue update <ID> --unlabel "state:wip" --label "state:review"` | `gh issue edit <ID> --remove-label "state:wip" --add-label "state:review"` | `mv .ksw/queue/wip/<file> .ksw/queue/done/` |
| Close | `glab issue close <ID>` | `gh issue close <ID>` | `mv to done/ + add closed_at` |
| Add comment | `glab issue note <ID> --message "..."` | `gh issue comment <ID> --body "..."` | Append to `## Notes` section |
| Apply labels | `glab issue update <ID> --label "x" --unlabel "y"` | `gh issue edit <ID> --add-label "x" --remove-label "y"` | Edit frontmatter |
| List by satellite | `glab issue list --label "satellite:<name>"` | `gh issue list --label "satellite:<name>"` | N/A |
| Route to satellite | `glab issue update <ID> --label "satellite:<name>"` | `gh issue edit <ID> --add-label "satellite:<name>"` | N/A |

### Local mode queue items

Each queue item is a markdown file with frontmatter:

```yaml
---
id: "<YYYYMMDD-HHMMSS-slug>"
title: "<title>"
domain: "<domain>"
type: "<type>"
priority: "<P0-P3>"
state: "<inbox|ready|wip|blocked|done>"
created: "<ISO8601>"
---
```

Transitions are file moves between `.ksw/queue/<state>/` directories. Apply labels by editing frontmatter.

### Label creation (hub init)

| GitLab | GitHub | Local |
|--------|--------|-------|
| `glab label create "<label>" --color "<color>" --description "<desc>"` | `gh label create "<label>" --color "<color without #>" --description "<desc>"` | Subdirectories under `.ksw/queue/` |

The full label catalogue lives in [`reference/coordination/labels.yaml`](reference/coordination/labels.yaml). Hub `/init` creates every label in that file.

---

## Satellite Operations (remote — uses `-R <hub>`)

Run from the satellite workspace against the configured hub. Local mode is not supported — `gitlab` or `github` only.

| Action | GitLab (`glab`) | GitHub (`gh`) |
|--------|-----------------|---------------|
| List routed work | `glab issue list -R <hub> --label "satellite:<name>,state:ready"` | `gh issue list -R <hub> --label "satellite:<name>,state:ready"` |
| List my WIP | `glab issue list -R <hub> --label "satellite:<name>,state:wip" --assignee "@me"` | `gh issue list -R <hub> --label "satellite:<name>,state:wip" --assignee "@me"` |
| Claim (remote) | `glab issue update <ID> -R <hub> --assignee "@me" --unlabel "state:ready" --label "state:wip"` | `gh issue edit <ID> -R <hub> --add-assignee "@me" --remove-label "state:ready" --add-label "state:wip"` |
| Complete (remote) | `glab issue update <ID> -R <hub> --unlabel "state:wip" --label "state:review"` | `gh issue edit <ID> -R <hub> --remove-label "state:wip" --add-label "state:review"` |
| Create (remote) | `glab issue create -R <hub> --title "..." --label "state:inbox,satellite:<name>,domain:<d>"` | `gh issue create -R <hub> --title "..." --label "state:inbox,satellite:<name>,domain:<d>"` |
| Comment (remote) | `glab issue note <ID> -R <hub> --message "..."` | `gh issue comment <ID> -R <hub> --body "..."` |

---

## Verification rule

After any state-mutating call, **re-read the issue** to confirm the labels and assignee actually changed. Platform issue state is remote system state — cannot be assumed from a successful exit code. If the round-trip read does not show the expected state, treat the operation as failed and surface that to the user.
