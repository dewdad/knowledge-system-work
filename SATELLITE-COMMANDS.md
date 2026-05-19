# KSW Satellite Commands

> Loaded when: this workspace contains `.ksw-link.yaml` (i.e. operates as a KSW satellite) and the user invokes any `/sat *` command. All commands operate against the remote hub recorded in `.ksw-link.yaml#hub.project_path`. Local mode hubs are not supported as satellite targets.

Every command below assumes:
- `.ksw-link.yaml` is present and parses with `yq`.
- The platform CLI (`glab` or `gh`) is authenticated.
- The hub repo has KSW labels (verify once at `/init` time).

Platform-specific shell forms come from [PLATFORM-OPS.md](PLATFORM-OPS.md). State transition semantics come from [COORDINATION.md](COORDINATION.md).

Throughout this file, substitute:
- `<hub>` → `.ksw-link.yaml#hub.project_path`
- `<name>` → `.ksw-link.yaml#identity.workspace_name`
- `<domain>` → `.ksw-link.yaml#preferences.default_domain`

---

## /sat board

Show the task board filtered to this satellite's label.

```bash
# GitLab
glab issue list -R <hub> --label "satellite:<name>" --per-page 20
# GitHub
gh issue list -R <hub> --label "satellite:<name>" --limit 20
```

Group output by state: `ready` → `wip` → `blocked`. Highlight items assigned to the current user (`@me`).

## /sat claim `<ID>`

Claim a `state:ready` issue, transition it to `state:wip`, and create a local working branch.

1. **Verify** the issue exists and is `state:ready`:
   ```bash
   glab issue view <ID> -R <hub> --output json | jq '.labels'
   gh   issue view <ID> -R <hub> --json labels
   ```
2. **Assign + transition** (per [PLATFORM-OPS.md](PLATFORM-OPS.md)):
   ```bash
   # GitLab
   glab issue update <ID> -R <hub> --assignee "@me" --unlabel "state:ready" --label "state:wip"
   # GitHub
   gh issue edit <ID> -R <hub> --add-assignee "@me" --remove-label "state:ready" --add-label "state:wip"
   ```
3. **Re-read** the issue. If assignment or label did not stick, release immediately and stop (see [COORDINATION.md](COORDINATION.md#team-mode-rules)).
4. **Create local branch** using the satellite branch convention:
   ```bash
   git checkout -b issue/<ID>-<slug>
   ```
   `<slug>` is derived from the issue title: lowercase, alphanumeric + hyphens, ≤40 chars. The satellite git hooks (`post-commit`, `post-merge`, `prepare-commit-msg`) recognize this prefix; do not use a different one or progress reporting will silently stop.
5. **Update `.ksw-link.yaml`**:
   ```bash
   yq -i '.active_claims += [<ID>]' .ksw-link.yaml
   ```

## /sat done `<ID>`

Mark a claimed issue complete (transition to `state:review` for hub follow-up).

1. **Transition**:
   ```bash
   # GitLab
   glab issue update <ID> -R <hub> --unlabel "state:wip" --label "state:review"
   glab issue note <ID> -R <hub> --message "Work complete in \`<name>\`. Ready for review."
   # GitHub
   gh issue edit <ID> -R <hub> --remove-label "state:wip" --add-label "state:review"
   gh issue comment <ID> -R <hub> --body "Work complete in \`<name>\`. Ready for review."
   ```
2. **Remove from `active_claims`**:
   ```bash
   yq -i 'del(.active_claims[] | select(. == <ID>))' .ksw-link.yaml
   ```

The satellite `post-merge` git hook performs the same transition automatically when an `issue/<ID>-*` branch is merged into the hub's `default_branch`. `/sat done` is the manual path for non-MR workflows.

## /sat blocked `<ID> <reason>`

Mark a claimed issue blocked.

```bash
# GitLab
glab issue update <ID> -R <hub> --unlabel "state:wip" --label "state:blocked"
glab issue note <ID> -R <hub> --message "Blocked: <reason> (from \`<name>\`)"
# GitHub
gh issue edit <ID> -R <hub> --remove-label "state:wip" --add-label "state:blocked"
gh issue comment <ID> -R <hub> --body "Blocked: <reason> (from \`<name>\`)"
```

The issue stays assigned. The user is responsible for unblocking, which manually transitions back to `state:ready`.

## /sat release `<ID>`

Unclaim an issue without completing — return it to the ready pool.

```bash
# GitLab
glab issue update <ID> -R <hub> --unassign "@me" --unlabel "state:wip" --label "state:ready"
# GitHub
gh issue edit <ID> -R <hub> --remove-assignee "@me" --remove-label "state:wip" --add-label "state:ready"
```

Then remove from `active_claims`:

```bash
yq -i 'del(.active_claims[] | select(. == <ID>))' .ksw-link.yaml
```

The branch is preserved on the satellite (and on the remote if pushed). A successor agent can resume.

## /sat new `<title>`

Create a new issue on the hub with satellite + domain context.

```bash
# GitLab
glab issue create -R <hub> \
  --title "<title>" \
  --label "state:inbox,satellite:<name>,domain:<domain>"
# GitHub
gh issue create -R <hub> \
  --title "<title>" \
  --label "state:inbox,satellite:<name>,domain:<domain>"
```

Optionally add a body with workspace context (file references, error traces, command output). The hub's `/triage` workflow will classify priority and type.

## /sat log `<ID> <note>`

Add a progress note to an issue without changing its state.

```bash
# GitLab
glab issue note <ID> -R <hub> --message "[<name>] <note>"
# GitHub
gh issue comment <ID> -R <hub> --body "[<name>] <note>"
```

The satellite `post-commit` git hook adds batched progress notes automatically every `preferences.progress_interval` commits on `issue/<ID>-*` branches. `/sat log` is for explicit, off-branch updates.

## /sat contribute `<path>`

Push a wiki page or decision record to the hub. Uses sparse checkout to avoid cloning the full hub.

1. **Sparse-clone hub wiki**:
   ```bash
   TMPDIR=$(mktemp -d "${TMPDIR:-/tmp}/ksw-contribute.XXXXXX")
   trap 'rm -rf "$TMPDIR"' EXIT
   git clone --no-checkout --depth 1 <hub_url> "$TMPDIR"
   cd "$TMPDIR"
   git sparse-checkout set wiki/
   git checkout
   ```
2. **Conflict resolution** before copying:
   - **No conflict** (path does not exist on hub): write directly.
   - **Same content** (`diff -q` returns identical): skip with note `Already on hub at <path>; skipping.`.
   - **Diverged** (path exists with different content): do **not** overwrite. Open a hub issue:
     ```bash
     glab issue create -R <hub> --title "Wiki conflict: <path>" \
       --label "state:inbox,type:decision,satellite:<name>" \
       --description "Both versions attached…"
     ```
     Mark the local contribution `state:blocked` until resolved.
3. **Copy** local file to appropriate wiki location and add frontmatter if missing (`contributed_from: <name>`, `date`, `domain`).
4. **Commit and push**:
   ```bash
   git add wiki/
   git commit -m "feat(wiki): contribute <filename> from <name>"
   git push
   ```
5. Cleanup is automatic via the `trap` above.

## /sat status

Show current workspace state — claims, recent progress, hub link.

```
Satellite: <name>
Hub: <hub> (<platform>)
Label: satellite:<name>
Domain: <domain>

Active claims:
  #12 — Implement auth flow [state:wip]
  #15 — Fix database migration [state:wip]

Recent progress (last 5 commits with KSW refs):
  abc1234 Fix token refresh (KSW #12)
  def5678 Add migration script (KSW #15)
```

Source the active claims from `.ksw-link.yaml#active_claims`. Source recent KSW-tagged commits via `git log --grep '(KSW #' -n 5 --pretty=format:'%h %s'`.

## /sat brief

Fetch and display the latest morning brief from the hub.

```bash
# GitLab — list and fetch latest brief
LATEST=$(glab api "projects/<hub_encoded>/repository/tree?path=wiki/_meta/briefs&per_page=1&sort=desc" \
         | jq -r '.[0].name')
glab api "projects/<hub_encoded>/repository/files/wiki%2F_meta%2Fbriefs%2F${LATEST}/raw" | cat

# GitHub
LATEST=$(gh api "repos/<hub>/contents/wiki/_meta/briefs" --jq '.[-1].name')
gh api "repos/<hub>/contents/wiki/_meta/briefs/${LATEST}" --jq '.content' | base64 -d
```

If no brief exists yet, surface the message `No brief yet on hub. Run /brief on the hub first.` rather than failing silently.

---

## Cross-references

- Bootstrap and persistent install (`.ksw-link.yaml`, AGENTS.md augmentation, hooks): [INIT.md](INIT.md) — Satellite Init Flow.
- Coordination semantics (claim/release, branch convention, stale recovery): [COORDINATION.md](COORDINATION.md).
- Platform CLI invocations: [PLATFORM-OPS.md](PLATFORM-OPS.md).
