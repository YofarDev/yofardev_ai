#!/usr/bin/env bash
# =============================================================================
# fdead.sh
#
# ADVISORY ONLY — this script never deletes anything.
#
# Reports potentially unreferenced Dart files — files whose basename appears
# in no import/export/part statement, which often means they were orphaned by
# a refactor. The scan is purely textual (basenames in import/export/part
# lines), so a finding is a HINT for manual review, never proof that a file
# is safe to delete:
#
#   - Conditional directives (`if (dart.library.io) ...`) can reference files
#     in branches this scan treats loosely.
#   - Custom entry points (tools/, bin/, scripts/) are not scanned as
#     referencing sources.
#   - Filename collisions: a file is considered referenced if its BASENAME
#     appears anywhere in any import — two files named the same thing mask
#     each other.
#
# Exclusions (never reported):
#   - main.dart (app entry point)
#   - *_test.dart files (test entry points)
#   - *.g.dart / *.freezed.dart / *.gen.dart (generated files)
#   - Any file exported via a barrel file (index.dart or any *_exports.dart)
#
# Usage:
#   ./fdead.sh            # scan lib/ only
#   ./fdead.sh --test     # scan lib/ and test/
#
# The former --clean-dead / --clean-empty flags are rejected: deletion is
# disabled because findings require manual review.
# =============================================================================

set -euo pipefail

# -- Flags --------------------------------------------------------------------
INCLUDE_TEST=false

for arg in "$@"; do
  case $arg in
    --test) INCLUDE_TEST=true ;;
    --clean-dead|--clean-empty)
      echo "Error: deletion is disabled ('$arg' is no longer supported)."
      echo ""
      echo "This script is advisory only: its findings are textual basename"
      echo "matches and cannot prove that deleting a file is safe. Conditional"
      echo "directives, custom entry points, and filename collisions can all"
      echo "affect the results, so findings require manual review — nothing"
      echo "is ever deleted by this script."
      exit 1
      ;;
    *) echo "Unknown argument: $arg  (supported: --test)"; exit 1 ;;
  esac
done

# -- Colours ------------------------------------------------------------------
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; DIM='\033[2m'; RESET='\033[0m'

log()  { echo -e "${CYAN}[info]${RESET}  $*"; }
ok()   { echo -e "${GREEN}[ ok ]${RESET}  $*"; }
warn() { echo -e "${YELLOW}[warn]${RESET}  $*"; }
dead() { echo -e "  ${RED}✗${RESET}  $*"; }

# -- Find project root --------------------------------------------------------
PROJECT_ROOT=""
dir="$PWD"
while [[ "$dir" != "/" ]]; do
  [[ -f "$dir/pubspec.yaml" ]] && PROJECT_ROOT="$dir" && break
  dir="$(dirname "$dir")"
done
[[ -z "$PROJECT_ROOT" ]] && echo "Could not find pubspec.yaml." && exit 1

cd "$PROJECT_ROOT"
LIB_DIR="$PROJECT_ROOT/lib"
TEST_DIR="$PROJECT_ROOT/test"

[[ ! -d "$LIB_DIR" ]] && echo "No lib/ directory found." && exit 1

log "Project root: $PROJECT_ROOT"
[[ "$INCLUDE_TEST" == true ]] && log "Scanning lib/ and test/" \
                               || log "Scanning lib/ only  (use --test to include test/)"

# -- Step 1: collect all dart files to check ----------------------------------
SCAN_DIRS=("$LIB_DIR")
[[ "$INCLUDE_TEST" == true ]] && [[ -d "$TEST_DIR" ]] && SCAN_DIRS+=("$TEST_DIR")

# Portable collection loop (no `mapfile`): the shipped helpers must run under
# macOS's stock Bash 3.2 as well as modern Bash — see docs/compatibility.md.
ALL_DART_FILES=()
while IFS= read -r f; do
  ALL_DART_FILES+=("$f")
done < <(find "${SCAN_DIRS[@]}" -type f -name "*.dart" | sort)

# -- Step 2: collect all import/export statements across the whole project ----
SEARCH_DIRS=("$LIB_DIR")
[[ -d "$TEST_DIR" ]] && SEARCH_DIRS+=("$TEST_DIR")

ALL_REFERENCES=$(
  grep -rh \
    -e "^import ['\"]" \
    -e "^export ['\"]" \
    -e "^part ['\"]" \
    "${SEARCH_DIRS[@]}" \
    --include="*.dart" 2>/dev/null || true
)

# -- Step 3: collect all files exported via barrel files ----------------------
# Portable collection loop (no `mapfile`) — see the Bash contract above.
BARREL_EXPORTS=()
while IFS= read -r export_path; do
  BARREL_EXPORTS+=("$export_path")
done < <(
  grep -rh "^export ['\"]" "${SCAN_DIRS[@]}" --include="*.dart" 2>/dev/null \
    | grep -oE "['\"][^'\"]+\.dart['\"]" \
    | tr -d "'\"" \
    || true
)

is_barrel_exported() {
  local basename="$1"
  for export in "${BARREL_EXPORTS[@]:-}"; do
    [[ "$(basename "$export")" == "$basename" ]] && return 0
  done
  return 1
}

# -- Step 4: for each candidate file, check if it's referenced anywhere -------
UNREFERENCED_FILES=()
SKIPPED=0

for filepath in ${ALL_DART_FILES[@]+"${ALL_DART_FILES[@]}"}; do
  filename=$(basename "$filepath")
  rel="${filepath#$PROJECT_ROOT/}"

  # -- Exclusions -------------------------------------------------------------
  if [[ "$filename" == "main.dart" ]] || \
     [[ "$filename" == *_test.dart ]] || \
     [[ "$filename" == *.g.dart ]] || \
     [[ "$filename" == *.freezed.dart ]] || \
     [[ "$filename" == *.gen.dart ]] || \
     is_barrel_exported "$filename"; then

    SKIPPED=$((SKIPPED + 1))
    continue
  fi

  # -- Check if filename appears in any import/export/part --------------------
  if echo "$ALL_REFERENCES" | grep -qF "$filename"; then
    continue
  fi

  UNREFERENCED_FILES+=("$rel")
done

# -- Step 5: report (advisory only — nothing is ever deleted) ------------------
echo ""
TOTAL=${#ALL_DART_FILES[@]}
UNREFERENCED_COUNT=${#UNREFERENCED_FILES[@]}
CHECKED=$(( TOTAL - SKIPPED ))

echo -e "${BOLD}-- Potentially Unreferenced Files ------------------------------------${RESET}"

if [[ $UNREFERENCED_COUNT -eq 0 ]]; then
  ok "No potentially unreferenced files found. All $CHECKED checked files are referenced."
else
  echo -e "  ${RED}${BOLD}$UNREFERENCED_COUNT potentially unreferenced file(s) found:${RESET}"
  echo ""

  current_dir=""
  for f in "${UNREFERENCED_FILES[@]}"; do
    dir=$(dirname "$f")
    if [[ "$dir" != "$current_dir" ]]; then
      echo -e "  ${DIM}$dir/${RESET}"
      current_dir="$dir"
    fi
    dead "$(basename "$f")"
  done

  echo ""
  warn "This scan is textual and advisory: conditional directives, custom entry"
  warn "points, and filename collisions can affect findings. Nothing was deleted;"
  warn "review each file manually before removing anything yourself."
fi

# -- Step 6: find empty directories in lib/ (report only) ----------------------
EMPTY_DIRS=()
while IFS= read -r -d '' d; do
  # Exclude .gitkeep from making a directory "not empty"
  if [[ -z "$(find "$d" -mindepth 1 -type f ! -name ".gitkeep" -print -quit)" ]]; then
    EMPTY_DIRS+=("${d#$PROJECT_ROOT/}")
  fi
done < <(find "$LIB_DIR" -mindepth 1 -type d -print0 | sort -rz)

EMPTY_COUNT=${#EMPTY_DIRS[@]}

# -- Step 7: report empty directories (advisory only — nothing is removed) -----
echo ""
echo -e "${BOLD}-- Empty Directories in lib/ ----------------------------------------${RESET}"

if [[ $EMPTY_COUNT -eq 0 ]]; then
  ok "No empty directories found in lib/."
else
  echo -e "  ${YELLOW}${BOLD}$EMPTY_COUNT empty director$([ $EMPTY_COUNT -eq 1 ] && echo y || echo ies) found:${RESET}"
  echo ""
  for d in "${EMPTY_DIRS[@]}"; do
    echo -e "  ${YELLOW}⊘${RESET}  ${DIM}$d/${RESET}"
  done

  echo ""
  echo -e "${DIM}  Advisory only: nothing was removed. Remove empty directories (and"
  echo -e "  their .gitkeep files) manually if they are truly unused.${RESET}"
fi

echo ""
echo -e "${DIM}  Scanned $CHECKED files  •  Skipped $SKIPPED (main/tests/generated/barrel-exported)  •  $EMPTY_COUNT empty dir(s)${RESET}"
echo ""
