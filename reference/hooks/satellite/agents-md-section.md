## KSW Satellite — Automatic Knowledge Bridge

This workspace is connected to KSW hub: `<project_path>` (<platform>)
Config: `.ksw-link.yaml` | Label: `satellite:<workspace_name>`

### Your Responsibilities as an Agent in This Workspace

1. **Session Awareness**: At session start, check active claims:
   GitLab: `glab issue list -R <hub> --label "satellite:<name>,state:wip" --assignee "@me"`
   GitHub: `gh issue list -R <hub> --label "satellite:<name>,state:wip" --assignee "@me"`
   Also check for newly assigned work:
   GitLab: `glab issue list -R <hub> --label "satellite:<name>,state:ready"`
   GitHub: `gh issue list -R <hub> --label "satellite:<name>,state:ready"`

2. **Decision Detection**: When you help the user make an architectural,
   design, or strategic decision — offer to record it as a KSW decision
   record via `/sat contribute`.

3. **Knowledge Extraction**: When the session produces reusable knowledge
   (patterns, gotchas, how-tos), assess whether it belongs in the KSW wiki.
   Ask: "This looks like knowledge worth capturing in KSW under [domain]. Want me to contribute it?"

4. **Issue Creation**: When you discover bugs, technical debt, or future
   work, offer to create a KSW issue:
   GitLab: `glab issue create -R <hub> --title "..." --label "state:inbox,satellite:<name>,domain:<domain>"`
   GitHub: `gh issue create -R <hub> --title "..." --label "state:inbox,satellite:<name>,domain:<domain>"`

5. **Context Linking**: When working on code related to a KSW issue,
   reference in commit messages: "Fix auth flow (KSW #12)"

### What NOT to Do
- Don't push trivial session artifacts (debugging notes, scratch work)
- Don't create duplicate issues — check existing board first
- Don't auto-push without user confirmation (ask first, always)
- Don't log progress on every minor step — summarize at milestones
