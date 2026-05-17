## KSW Satellite Session Hooks

### On Start
- Read .ksw-link.yaml → identify hub and satellite label
- GitLab active claims: `glab issue list -R <hub> --label "satellite:<name>,state:wip" --assignee "@me"`
- GitHub active claims: `gh issue list -R <hub> --label "satellite:<name>,state:wip" --assignee "@me"`
- GitLab routed work: `glab issue list -R <hub> --label "satellite:<name>,state:ready"`
- GitHub routed work: `gh issue list -R <hub> --label "satellite:<name>,state:ready"`
- Mention to user if any exist

### On Wrap-Up (user says "done", "wrap up", or session ends)
- Summarize session against active KSW claims
- Ask: "Should I log this progress to KSW issue #<ID>?"
- Ask: "Any knowledge worth contributing to the hub wiki?"
