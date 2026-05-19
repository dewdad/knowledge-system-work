# Installing KSW

KSW is a **multi-file skill**. It must be installed as a directory, not a single file. The skill's bootstrap (`/init`) reads templates from sibling files (`INIT.md`, hook templates under `reference/`) — copying only `SKILL.md` will fail at first run.

## Layout the installer must preserve

```
ksw/
├── SKILL.md
├── INIT.md
├── HUB-COMMANDS.md
├── SATELLITE-COMMANDS.md
├── PLATFORM-OPS.md
├── COORDINATION.md
├── WORKFLOWS.md
├── INSTALL.md
└── reference/
    ├── coordination/
    ├── hooks/
    ├── schemas/
    ├── templates/
    └── workflows/
```

`README.md`, `CHANGELOG.md`, `VERSION`, `LICENSE`, `AGENTS.md`, and `scripts/` are repo-level files — they are not consumed at runtime, so they don't need to ship with the skill, but copying them does no harm.

## Skillshare (recommended)

```bash
skillshare install ksw --source github:dewdad/knowledge-system-work
```

Skillshare handles the directory copy/symlink across every configured AI tool target. This is the supported install path.

## Manual — OpenCode

```bash
git clone https://github.com/dewdad/knowledge-system-work.git ~/.config/opencode/skills/ksw
```

Result: `~/.config/opencode/skills/ksw/SKILL.md` plus all sibling fragments and `reference/`.

## Manual — Claude Code

Claude Code skills can be a single file **or** a directory. KSW requires the **directory** form.

```bash
git clone https://github.com/dewdad/knowledge-system-work.git ~/.claude/skills/ksw
```

Result: `~/.claude/skills/ksw/SKILL.md` plus the rest of the tree.

> ⚠️ Anti-pattern (will not work): `cp SKILL.md ~/.claude/skills/ksw.md`
> The skill loads, but `/init` will fail to read `INIT.md`, `reference/hooks/...`, etc.

## Manual — Cursor / other tools

Most tools that load markdown skills accept a directory under their skills root. Use the same pattern: clone (or copy) the whole repo into `<tool_skills_dir>/ksw/`.

## Verifying an install

After installing, in a fresh directory run `/init` and pick **Hub** (or **Satellite** if you already have a hub). The init flow ends with a smoke test that reads at least one expected hook template path. If it fails:

```
Skill installed without `reference/` siblings — re-install as a directory.
```

…you've installed the single-file form. Re-install as above.

## Updating

Skillshare:

```bash
skillshare update ksw
```

Manual:

```bash
cd <skills_dir>/ksw
git pull
```

After upgrading, `/status` (in any hub workspace) will warn if the workspace's `ksw.skill_version` is older than the new `SKILL.md`. Run `/init` again to refresh generated workflow docs and hooks if you want the new templates; existing config (domains, sources, claims) is preserved.

## Uninstalling

Skillshare: `skillshare uninstall ksw`.

Manual: delete the directory (`rm -rf <skills_dir>/ksw`). This does not touch any workspace where you ran `/init`; those workspaces continue to work via their generated `.ksw/workflows/` and installed hooks.

To remove KSW from a satellite workspace, see `/sat uninstall` (planned in 0.7.0). Until then: delete `.ksw-link.yaml`, strip the KSW-bracketed sections from `AGENTS.md` and `.git/hooks/*`, and notify the hub.
