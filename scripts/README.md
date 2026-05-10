# Scripts

Automation scripts for LifeOS instance management.

## Setup (Run Once)

| Script | Purpose |
|--------|---------|
| `setup/bootstrap.sh` | Initialize new LifeOS instance (folders, labels, board) |
| `setup/bootstrap.ps1` | Windows PowerShell variant |
| `setup/install-glab.sh` | Install glab CLI |
| `setup/configure-gitlab.sh` | Set up labels, protected branches, board |

## Maintenance (Run Periodically)

| Script | Purpose | Typical Schedule |
|--------|---------|-----------------|
| `maintenance/source-pull.sh` | Pull new items from domain sources | Daily |
| `maintenance/stale-lock-recovery.sh` | Reclaim abandoned work | Before each work session |
| `maintenance/wiki-lint.sh` | Validate wiki structure and links | Daily |
| `maintenance/upgrade-system.sh` | Pull latest .system/ from remote | Weekly/on-demand |

## CI (Used by GitLab CI/CD)

| Script | Purpose |
|--------|---------|
| `ci/lint-wiki.sh` | CI job: validate wiki on push |
| `ci/validate-sources.sh` | CI job: check source configs |
| `ci/publish-wiki.sh` | CI job: build public wiki |

## Usage

All scripts assume they're run from the LifeOS instance root directory:

```bash
# From instance root
.system/scripts/setup/bootstrap.sh
.system/scripts/maintenance/source-pull.sh --domain health
```

## Cross-Platform

- `.sh` scripts work on Linux, macOS, WSL, and Git Bash on Windows
- `.ps1` scripts are PowerShell 7+ (Windows native)
- Scripts detect their environment and adapt where possible
