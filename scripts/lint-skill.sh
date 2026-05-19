#!/usr/bin/env bash
# scripts/lint-skill.sh — KSW skill drift lint
#
# Verifies:
#   1. Every state in reference/coordination/states.yaml is named in COORDINATION.md.
#   2. Every label in reference/coordination/labels.yaml is named in COORDINATION.md.
#   3. Every command listed in SKILL.md's Step 2 routing table has a corresponding
#      `## /command` heading in exactly one fragment.
#   4. Every fragment in the split (INIT, HUB-COMMANDS, SATELLITE-COMMANDS,
#      PLATFORM-OPS, COORDINATION, WORKFLOWS) is reachable from SKILL.md.
#
# Exit codes:
#   0 — clean
#   1 — drift detected (details printed to stderr)
#   2 — environment problem (missing tools)
#
# Run from repo root. Requires bash 4+, grep, awk, sed. yq is used opportunistically;
# if absent we fall back to grep-only parsing of the YAML files.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

errors=0
warn() { printf 'lint-skill: %s\n' "$*" >&2; errors=$((errors + 1)); }
info() { printf 'lint-skill: %s\n' "$*"; }

# ---------------------------------------------------------------------------
# Pre-flight
# ---------------------------------------------------------------------------

for tool in grep awk sed; do
  command -v "$tool" >/dev/null || { echo "lint-skill: required tool missing: $tool" >&2; exit 2; }
done

HAS_YQ=0
command -v yq >/dev/null && HAS_YQ=1

for f in SKILL.md INIT.md HUB-COMMANDS.md SATELLITE-COMMANDS.md \
         PLATFORM-OPS.md COORDINATION.md WORKFLOWS.md \
         reference/coordination/states.yaml \
         reference/coordination/labels.yaml; do
  [[ -f "$f" ]] || { echo "lint-skill: missing required file: $f" >&2; exit 2; }
done

# ---------------------------------------------------------------------------
# 1. States in COORDINATION.md
# ---------------------------------------------------------------------------

states_file="reference/coordination/states.yaml"

if (( HAS_YQ )); then
  mapfile -t state_keys < <(yq -r '.states | keys | .[]' "$states_file")
else
  # Top-level state keys: lines like `  inbox:` / `  ready:` etc. that appear
  # under `states:` and are 2-space-indented.
  mapfile -t state_keys < <(awk '
    /^states:/ { in_states=1; next }
    in_states && /^[A-Za-z_]/ { in_states=0 }
    in_states && /^  [a-z_]+:/ { sub(/:.*/, ""); sub(/^  /, ""); print }
  ' "$states_file")
fi

[[ ${#state_keys[@]} -gt 0 ]] || warn "could not parse states from $states_file"

for s in "${state_keys[@]}"; do
  # Each state key has a `state:<key>` label, except `done` (label: null).
  if [[ "$s" == "done" ]]; then
    continue
  fi
  if ! grep -q "state:$s" COORDINATION.md; then
    warn "state '$s' (label state:$s) defined in $states_file but missing from COORDINATION.md"
  fi
done

# ---------------------------------------------------------------------------
# 2. Labels in COORDINATION.md
# ---------------------------------------------------------------------------

labels_file="reference/coordination/labels.yaml"

if (( HAS_YQ )); then
  mapfile -t label_names < <(yq -r '
    [.states[]?.name, .priority[]?.name, .type[]?.name] | .[]
  ' "$labels_file")
else
  mapfile -t label_names < <(awk '
    /^[a-zA-Z_]+:[[:space:]]*$/ { section=$0; next }
    /^[[:space:]]*-[[:space:]]*name:[[:space:]]*"/ {
      # Extract value between quotes.
      match($0, /"[^"]+"/)
      if (RSTART) {
        v = substr($0, RSTART + 1, RLENGTH - 2)
        print v
      }
    }
  ' "$labels_file")
fi

[[ ${#label_names[@]} -gt 0 ]] || warn "could not parse labels from $labels_file"

for l in "${label_names[@]}"; do
  if ! grep -qF "$l" COORDINATION.md; then
    warn "label '$l' defined in $labels_file but missing from COORDINATION.md"
  fi
done

# ---------------------------------------------------------------------------
# 3. SKILL.md command index → exactly one fragment owns each command heading
# ---------------------------------------------------------------------------

# Extract commands listed in SKILL.md backticks. Take backtick content that
# starts with `/`, then keep tokens until we hit a placeholder (<...> or [...])
# so multi-word commands like `/sat board` are preserved as a single unit.
mapfile -t commands < <(
  grep -oE '`/[^`]+`' SKILL.md \
    | sed 's/^`//; s/`$//' \
    | awk '{
        out=""
        for (i=1; i<=NF; i++) {
          if ($i ~ /^[<[]/) break
          out = (out == "" ? $i : out " " $i)
        }
        if (out != "") print out
      }' \
    | sort -u
)

# Fragments that may own command headings.
fragments=(INIT.md HUB-COMMANDS.md SATELLITE-COMMANDS.md WORKFLOWS.md)

for cmd in "${commands[@]}"; do
  # `/sat` alone is the namespace prefix — skip if no second token.
  [[ "$cmd" == "/sat" ]] && continue
  # `/ksw` never appears as a real command; it's a placeholder in the notes.
  [[ "$cmd" == "/ksw" ]] && continue
  # Anything with a literal ellipsis (e.g. "/sat …", "/ksw …") is prose, not a command.
  case "$cmd" in *…*) continue ;; esac

  # Escape regex metacharacters in the command for use in patterns.
  esc_cmd=$(printf '%s' "$cmd" | sed 's/[][\\/.*^$]/\\&/g')

  hits=()
  for frag in "${fragments[@]}"; do
    # Match `## /cmd` (possibly followed by args/EOL) at the start of a line.
    if grep -Eq "^## ${esc_cmd}( |\$|\\\\<)" "$frag"; then
      hits+=("$frag")
    fi
  done

  case "${#hits[@]}" in
    0)
      # `/status` lives in SKILL.md itself by design.
      if [[ "$cmd" == "/status" ]] && grep -Eq "^## /status" SKILL.md; then
        continue
      fi
      # `/init` is documented as the whole INIT.md file rather than a `## /init` heading.
      if [[ "$cmd" == "/init" ]] && grep -Eq "^# KSW Init Flow" INIT.md; then
        continue
      fi
      # Workflow commands (`/pull`, `/triage`, `/ingest`, `/synthesize`, `/review`,
      # `/brief`, `/graph-build`) appear in WORKFLOWS.md under
      # `## <Title> (\`/cmd …\`)` headings.
      if grep -qE "^## .*\`${esc_cmd}( |\`)" WORKFLOWS.md; then
        continue
      fi
      warn "command '$cmd' listed in SKILL.md but no fragment defines it"
      ;;
    1) : ;;
    *)
      warn "command '$cmd' defined in multiple fragments: ${hits[*]}"
      ;;
  esac
done

# ---------------------------------------------------------------------------
# 4. Every fragment reachable from SKILL.md
# ---------------------------------------------------------------------------

for frag in "${fragments[@]}" PLATFORM-OPS.md COORDINATION.md INSTALL.md; do
  if ! grep -qF "$frag" SKILL.md; then
    warn "fragment '$frag' is not referenced from SKILL.md"
  fi
done

# ---------------------------------------------------------------------------
# Exit
# ---------------------------------------------------------------------------

if (( errors > 0 )); then
  printf 'lint-skill: %d issue(s) detected.\n' "$errors" >&2
  exit 1
fi

info "OK — no drift detected."
exit 0
