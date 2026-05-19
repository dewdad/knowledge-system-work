# Skill: Init Smoke Test

> Verify a freshly initialized KSW hub or satellite before relying on automation.

## When to Use

- Immediately after `/init`
- After changing hook templates or generated workflow docs
- Before enabling unattended source pulls, briefs, or stale-lock recovery

## Common: Directory-install check (run first, both modes)

Before any other check, verify the skill itself was installed as a directory (not a single-file `cp SKILL.md`). The `/init` flow needs sibling fragments and `reference/` templates.

1. Resolve the skill root — the directory containing `SKILL.md` that the agent loaded.
2. Confirm at least one expected sibling and one expected `reference/` template are readable:
   ```bash
   test -f "<skill_root>/INIT.md"
   test -f "<skill_root>/reference/hooks/hub/git/post-commit"          # hub mode
   test -f "<skill_root>/reference/hooks/satellite/git/post-commit"    # satellite mode
   ```
3. On any failure, stop the smoke test with this exact message so the user can fix the install:
   ```
   Skill installed without `reference/` siblings — re-install as a directory.
   See INSTALL.md.
   ```

## Hub Checks

1. Confirm required tools:
   ```bash
   git --version
   yq --version
   jq --version
   ```
2. Validate core files exist:
   ```bash
   test -f ksw.yaml
   test -d .ksw/workflows
   test -d wiki
   test -d domains
   ```
3. Confirm `ksw.yaml` has a `ksw.skill_version` field and that it matches the installed skill (warn on mismatch, do not fail).
4. Check platform command based on `ksw.yaml#instance.platform`:
   ```bash
   glab auth status   # GitLab
   gh auth status     # GitHub
   ```
5. Create, read, and close one test issue or local queue item.
6. Run `/graph-build` on the current wiki and confirm `wiki/_graph/graph.json` is written.
7. Verify installed hooks are executable and do not fail when dependencies are missing.

## Satellite Checks

1. Confirm `.ksw-link.yaml` exists, parses with `yq`, and has both `ksw.skill_version` and `hub.default_branch` populated.
2. List routed work from the hub using the configured platform CLI.
3. Create a test issue with the satellite label, claim it, then release it.
4. Confirm `active_claims` changes only after remote claim verification succeeds.
5. Make a dry-run commit on a `ksw/<ID>-test` branch and verify the commit message gets `(KSW #ID)` from `prepare-commit-msg`.

## Failure Rule

If any smoke check fails, do not enable unattended hooks or scheduled automation. Fix the generated config or platform permissions first.
