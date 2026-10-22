#!/usr/bin/env bash
# =============================================================================
# sync_skills.sh — single source of truth for skill files.
#
# The canonical copy of every skill lives in <template>/.agents/skills/.
# This script pushes it to the locations that expect a copy:
#
#   .codex/skills/     (OPTIONAL target — Codex. Skipped, with a notice,
#                       when the directory does not exist: .agents/skills/
#                       is the single source of truth and .codex/skills/
#                       is present only if you choose to keep a copy.
#                       Preserves Codex-only extras such as
#                       RED_TEST_SCENARIOS.md and agents/openai.yaml)
#   ~/.agents/skills/  (with --user)
#   ~/.claude/skills/  (with --user)
#
# Only top-level *.md files are copied (SKILL.md and companions such as
# examples.md). Nothing is ever deleted from the targets, so per-target
# extras survive.
#
# Usage:
#   ./scripts/sync_skills.sh            # sync project-local targets
#   ./scripts/sync_skills.sh --user     # also sync user-level targets
#   ./scripts/sync_skills.sh --check    # report drift only (exit 1 on drift)
# =============================================================================

set -euo pipefail

# -- Flags --------------------------------------------------------------------
USER_SCOPE=false
CHECK_ONLY=false
for arg in "$@"; do
  case $arg in
    --user)   USER_SCOPE=true ;;
    --check)  CHECK_ONLY=true ;;
    *) echo "Unknown argument: $arg  (supported: --user, --check)"; exit 1 ;;
  esac
done

# -- Resolve template root (parent of this script's folder) --------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CANONICAL="$TEMPLATE_ROOT/.agents/skills"

[[ ! -d "$CANONICAL" ]] && echo "Canonical skills dir not found: $CANONICAL" && exit 1

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; DIM='\033[2m'; BOLD='\033[1m'; RESET='\033[0m'
ok()   { echo -e "  ${GREEN}✓${RESET} $*"; }
skip() { echo -e "  ${DIM}·${RESET} $*"; }
diff_(){ echo -e "  ${YELLOW}≠${RESET} $*"; }

SKILLS=()
while IFS= read -r d; do
  SKILLS+=("$(basename "$d")")
done < <(find "$CANONICAL" -mindepth 1 -maxdepth 1 -type d | sort)

declare -a TARGETS=("$TEMPLATE_ROOT/.codex/skills")  # optional; skipped when absent
if [[ "$USER_SCOPE" == true ]]; then
  TARGETS+=("$HOME/.agents/skills" "$HOME/.claude/skills")
fi

DRIFT=0
SYNCED=0

for target in "${TARGETS[@]}"; do
  echo -e "\n${CYAN}== ${target/#$HOME/~} ${RESET}"
  if [[ ! -d "$target" ]]; then
    skip "target dir does not exist — skipped"
    continue
  fi
  for skill in "${SKILLS[@]}"; do
    src_dir="$CANONICAL/$skill"
    dst_dir="$target/$skill"
    if [[ ! -d "$dst_dir" ]]; then
      skip "$skill (not present in target — skipped)"
      continue
    fi
    for md in "$src_dir"/*.md; do
      [[ -e "$md" ]] || continue
      name="$(basename "$md")"
      dst="$dst_dir/$name"
      if [[ ! -f "$dst" ]] || ! cmp -s "$md" "$dst"; then
        if [[ "$CHECK_ONLY" == true ]]; then
          diff_ "$skill/$name differs"
          DRIFT=$((DRIFT + 1))
        else
          cp "$md" "$dst"
          ok "$skill/$name synced"
          SYNCED=$((SYNCED + 1))
        fi
      fi
    done
  done
done

# Track which targets were present so the summary is honest about scope:
# absent targets (e.g. a deliberately deleted .codex/skills/) are optional
# and are skipped, not synchronized.
declare -a PRESENT_TARGETS=()
for target in "${TARGETS[@]}"; do
  if [[ -d "$target" ]]; then
    PRESENT_TARGETS+=("${target/#$HOME/~}")
  fi
done

echo ""
if [[ "$CHECK_ONLY" == true ]]; then
  if [[ "$DRIFT" -gt 0 ]]; then
    echo -e "${YELLOW}${BOLD}Drift detected: $DRIFT file(s) differ from .agents/skills${RESET}"
    exit 1
  fi
  if [[ "${#PRESENT_TARGETS[@]}" -eq 0 ]]; then
    echo -e "${GREEN}No sync targets present — nothing to check (targets are optional).${RESET}"
  else
    echo -e "${GREEN}All skill copies match .agents/skills (targets checked: ${PRESENT_TARGETS[*]})${RESET}"
  fi
else
  echo -e "${GREEN}Synced $SYNCED file(s) from .agents/skills (targets present: ${PRESENT_TARGETS[*]:-none})${RESET}"
  echo -e "${DIM}Missing target directories are skipped — they are optional (canonical source:"
  echo -e "     .agents/skills). Tip: run with --check in CI to catch drift, and --user to update"
  echo -e "     the user-level copies (~/.agents/skills, ~/.claude/skills).${RESET}"
fi
echo ""
