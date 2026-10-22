#!/usr/bin/env bash
# =============================================================================
# verify_template.sh — ONE command that proves the template repository works.
#
# This is the TEMPLATE repository's own verification entry point (repo root).
# It is deliberately named differently from the generated apps'
# `scripts/fverify.sh` (app-local analyze+test gate) and never invokes itself,
# directly or through the apps it generates: it delegates to
# `tools/test_template.py`, which generates apps in throwaway directories
# outside this checkout.
#
# Levels:
#   ./scripts/verify_template.sh            # fast level (fake tools; seconds)
#   ./scripts/verify_template.sh --full     # + real-Flutter smoke suite
#                                           # (several minutes; unique temp
#                                           # dirs; logs retained on failure)
#
# Optional flags:
#   --artifacts <dir>   where --full records the smoke report (Flutter/Dart
#                       versions, template git revision, resolved generated
#                       pubspec.lock). Default: a retained directory under
#                       ${TMPDIR:-/tmp} (its path is printed).
#
# Prerequisites (checked up front — see docs/compatibility.md):
#   - bash, uv on PATH; dart+flutter on PATH for --full
#   - Shell contract: every shipped script must run under macOS's stock
#     Bash 3.2 (checked below by parsing each script with the system Bash;
#     the fast test suite additionally executes representative helpers
#     under it).
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

FULL=false
ARTIFACTS_DIR=""
while [ $# -gt 0 ]; do
  case $1 in
    --full) FULL=true; shift ;;
    --artifacts)
      if [ $# -lt 2 ]; then
        echo "--artifacts requires a directory path."
        exit 1
      fi
      ARTIFACTS_DIR="$2"; shift 2 ;;
    *)
      echo "Unknown argument: $1  (supported: --full, --artifacts <dir>)"
      exit 1
      ;;
  esac
done

GREEN='\033[0;32m'; RED='\033[0;31m'; CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'
step() { echo -e "\n${CYAN}[template-verify]${RESET} $*"; }
ok()   { echo -e "${GREEN}[ ok ]${RESET} $*"; }
fail() { echo -e "${RED}[fail]${RESET} $*"; }

# -- 1. Prerequisites ----------------------------------------------------------
step "Checking prerequisites (bash, uv$( [ "$FULL" = true ] && printf ', flutter, dart' ))..."
for tool in bash uv; do
  command -v "$tool" >/dev/null 2>&1 || { fail "'$tool' not found on PATH."; exit 1; }
done
if [ "$FULL" = true ]; then
  for tool in flutter dart; do
    command -v "$tool" >/dev/null 2>&1 || { fail "'$tool' not found on PATH (required for --full)."; exit 1; }
  done
fi
ok "prerequisites present"

# -- 2. Shell contract: every shipped script parses under the system bash -----
step "Shell contract: syntax-checking shipped scripts with the system bash..."
SYSTEM_BASH=/bin/bash
[ -x "$SYSTEM_BASH" ] || SYSTEM_BASH=bash
SYSTEM_BASH_VERSION="$($SYSTEM_BASH -c 'echo "${BASH_VERSINFO[0]}.${BASH_VERSINFO[1]}"')"
for script in "$REPO_ROOT"/scripts/*.sh "$REPO_ROOT"/remove_counter.sh; do
  [ -e "$script" ] || continue
  if ! "$SYSTEM_BASH" -n "$script"; then
    fail "$script does not parse under bash $SYSTEM_BASH_VERSION."
    fail "The shipped helpers must stay compatible with macOS's stock Bash 3.2 — see docs/compatibility.md."
    exit 1
  fi
done
ok "all scripts parse under $SYSTEM_BASH ($SYSTEM_BASH_VERSION)"

# -- 3. Run the harness ---------------------------------------------------------
if [ "$FULL" = true ]; then
  if [ -z "$ARTIFACTS_DIR" ]; then
    ARTIFACTS_DIR="$(mktemp -d "${TMPDIR:-/tmp}/flutterforge-smoke-artifacts.XXXXXX")"
  else
    mkdir -p "$ARTIFACTS_DIR"
  fi
  step "Running FULL smoke suite (real Flutter; several minutes)..."
  step "Artifacts (log, versions, git revision, resolved pubspec.lock) -> $ARTIFACTS_DIR"
  # The complete suite output is retained in the artifacts dir, on success and
  # failure alike (full-smoke.log) — not only in the terminal/CI console.
  LOG_FILE="$ARTIFACTS_DIR/full-smoke.log"
  # FORGE_VERIFY_WRAPPER=1 lets the harness know it is running inside this
  # wrapper (its wrapper test skips itself to avoid re-entering the wrapper).
  set +e
  (
    cd "$REPO_ROOT" &&
    FORGE_VERIFY_WRAPPER=1 FORGE_ARTIFACTS_DIR="$ARTIFACTS_DIR" \
      uv run --no-project tools/test_template.py
  ) 2>&1 | tee "$LOG_FILE"
  STATUS=${PIPESTATUS[0]}
  set -e
  if [ "$STATUS" -ne 0 ]; then
    fail "full smoke suite failed (exit $STATUS) — retained log: $LOG_FILE"
    exit "$STATUS"
  fi
  ok "full suite passed (log retained: $LOG_FILE)"
  echo ""
  echo -e "${BOLD}-- template-verify --------------------------------------------------${RESET}"
  echo -e "  ${GREEN}fast + full smoke suites ✓${RESET}"
  echo -e "  Artifacts: $ARTIFACTS_DIR"
  echo ""
else
  step "Running fast suite (fake tools; real Flutter NOT invoked)..."
  # FORGE_VERIFY_WRAPPER=1 lets the harness know it is running inside this
  # wrapper (its wrapper test skips itself to avoid re-entering the wrapper).
  ( cd "$REPO_ROOT" && FORGE_SKIP_SLOW=1 FORGE_VERIFY_WRAPPER=1 uv run --no-project tools/test_template.py )
  ok "fast suite passed"
  echo ""
  echo -e "${BOLD}-- template-verify --------------------------------------------------${RESET}"
  echo -e "  ${GREEN}fast suite ✓  (run with --full for the real-Flutter smoke suite)${RESET}"
  echo ""
fi
