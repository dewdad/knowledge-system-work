## KSW Hub Session Hooks

### On Start
- Read `ksw.yaml#instance.platform`.
- GitLab inbox depth: `glab issue list --label "state:inbox" | wc -l`
- GitHub inbox depth: `gh issue list --label "state:inbox" --limit 100 | wc -l`
- Check stale WIP: items with state:wip updated >30min ago
- Check if today's brief exists in wiki/_meta/briefs/
- Report: "KSW: N inbox, M stale WIP. Brief: [generated/missing]"

### On Wrap-Up
- If wiki edited → offer /graph-build
- If issues transitioned → verify labels are consistent
- If source pulls overdue (check pulls.json vs schedule) → remind
