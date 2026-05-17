# Skill: Init Smoke Test

> Verify a freshly initialized KSW hub or satellite before relying on automation.

## When to Use

- Immediately after `/init`
- After changing hook templates or generated workflow docs
- Before enabling unattended source pulls, briefs, or stale-lock recovery

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
3. Check platform command based on `ksw.yaml#instance.platform`:
   ```bash
   glab auth status   # GitLab
   gh auth status     # GitHub
   ```
4. Create, read, and close one test issue or local queue item.
5. Run `/graph-build` on the current wiki and confirm `wiki/_graph/graph.json` is written.
6. Verify installed hooks are executable and do not fail when dependencies are missing.

## Satellite Checks

1. Confirm `.ksw-link.yaml` exists and parses with `yq`.
2. List routed work from the hub using the configured platform CLI.
3. Create a test issue with the satellite label, claim it, then release it.
4. Confirm `active_claims` changes only after remote claim verification succeeds.
5. Make a dry-run commit on an `issue/<ID>-test` branch and verify the commit message gets `(KSW #ID)`.

## Failure Rule

If any smoke check fails, do not enable unattended hooks or scheduled automation. Fix the generated config or platform permissions first.
