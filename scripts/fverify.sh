#!/usr/bin/env bash
# =============================================================================
# fverify.sh — one-command quality gate to run before finishing a change.
#
# Runs, in order:
#   1. dart format --output=none --set-exit-if-changed <source dirs>  (CHECK only —
#      without --fix this script never rewrites files)
#   2. flutter analyze
#   3. flutter test via scripts/ftest.sh (one aggregated entrypoint; the
#      architecture gate runs whenever lib/ changed since its last green run)
#
# --fix (opt-in, mutating): first runs `dart fix --apply` (refused when the
# preview spans more than FVERIFY_FIX_MAX_FILES files) and `dart format` on the
# source dirs,
# then the same gate — preparation and verification in one command. CI and
# the default invocation stay non-mutating.
#
# A formatting failure does not stop the run: analysis and tests still
# execute so every problem is reported in one pass. An analysis failure
# stops before tests (they would only repeat the same compile errors).
#
# Tests use `--reporter failures-only` (passing tests print nothing) unless a
# reporter is passed explicitly, e.g. `fverify.sh --reporter expanded`.
#
# Codegen prerequisites: `flutter pub get`, `flutter gen-l10n` and
# `dart run build_runner build --delete-conflicting-outputs` must already have
# been run, or analysis will fail on missing generated parts.
#
# Exits non-zero if any step fails. Arguments other than --fix are forwarded
# to `flutter test` (e.g. `fverify.sh --coverage`).
#
# Machine-wide queue: the gate waits for a free slot shared by every
# FlutterForge app on this machine (scripts/fqueue.sh), so parallel agents in
# several projects take turns instead of freezing the machine, and analysis
# and tests run at lower CPU priority. FORGE_QUEUE=0 disables it (CI);
# FORGE_QUEUE_SLOTS, FORGE_NICE and FORGE_TEST_CONCURRENCY tune it.
#
# Usage:
#   ./scripts/fverify.sh          # check only
#   ./scripts/fverify.sh --fix    # dart fix + dart format, then check
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=fqueue.sh
. "$SCRIPT_DIR/fqueue.sh"

# -- Colours ------------------------------------------------------------------
GREEN='\033[0;32m'; RED='\033[0;31m'; CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'
# Colours only on an interactive terminal: agents, pipes and CI get plain text
# (ANSI escapes are pure noise in a captured log). NO_COLOR is honoured too.
if [ ! -t 1 ] || [ -n "${NO_COLOR:-}" ]; then
  GREEN=''; RED=''; CYAN=''; BOLD=''; RESET=''
fi

step()  { echo -e "\n${CYAN}[verify]${RESET} $*"; }
ok()    { echo -e "${GREEN}[ ok  ]${RESET} $*"; }
fail()  { echo -e "${RED}[fail ]${RESET} $*"; }

# -- Arguments ----------------------------------------------------------------
# Bash 3.2 + `set -u`: rebuild the positional parameters instead of using an
# array (an empty array expansion is an unbound-variable error there).
FIX=false
HAS_REPORTER=false
remaining=$#
while [ "$remaining" -gt 0 ]; do
  arg="$1"; shift
  case "$arg" in
    --fix) FIX=true ;;
    -r|--reporter|--reporter=*) HAS_REPORTER=true; set -- "$@" "$arg" ;;
    *) set -- "$@" "$arg" ;;
  esac
  remaining=$((remaining - 1))
done
[ "$HAS_REPORTER" = true ] || set -- --reporter failures-only "$@"

# -- Find project root --------------------------------------------------------
PROJECT_ROOT=""
dir="$PWD"
while [[ "$dir" != "/" ]]; do
  [[ -f "$dir/pubspec.yaml" ]] && PROJECT_ROOT="$dir" && break
  dir="$(dirname "$dir")"
done
[[ -z "$PROJECT_ROOT" ]] && fail "Could not find pubspec.yaml." && exit 1
cd "$PROJECT_ROOT"

fqueue_acquire "fverify"
START_TS=$SECONDS

# Formatting covers the Dart source roots only. A bare `dart format .` also
# walks gitignored trees such as build/ (Swift Package Manager checkouts,
# vendored plugin code) and fails or rewrites code the app does not own.
FORMAT_DIRS=""
for candidate in lib test bin tool integration_test test_driver; do
  [ -d "$candidate" ] && FORMAT_DIRS="$FORMAT_DIRS $candidate"
done
FORMAT_DIRS="${FORMAT_DIRS# }"
[ -n "$FORMAT_DIRS" ] || FORMAT_DIRS="lib"

# -- 0. Optional preparation (--fix only; the only mutating path) ----------------
# `dart fix` is previewed first: lint autofixes touch a few files, but after an
# SDK upgrade it can also carry a sweeping migration (e.g. hundreds of files
# moved to a new package plus new pubspec dependencies). Above
# FVERIFY_FIX_MAX_FILES files (default 25) nothing is applied; run
# `dart fix --apply` yourself once you have decided on that migration.
if [ "$FIX" = true ]; then
  MAX_FIX_FILES="${FVERIFY_FIX_MAX_FILES:-25}"
  step "dart fix (preview)"
  if ! FIX_PREVIEW="$(fqueue_nice dart fix --dry-run 2>&1)"; then
    echo "$FIX_PREVIEW"
    fail "dart fix --dry-run failed."
    exit 1
  fi
  FIX_FILES="$(printf '%s\n' "$FIX_PREVIEW" | sed -nE 's/.*proposed fix(es)? in ([0-9]+) files?.*/\2/p' | head -n 1)"
  if [ -z "$FIX_FILES" ] || [ "$FIX_FILES" -eq 0 ]; then
    ok "nothing to fix"
  elif [ "$FIX_FILES" -gt "$MAX_FIX_FILES" ]; then
    printf '%s\n' "$FIX_PREVIEW" | head -n 20
    fail "dart fix proposes changes in $FIX_FILES files (limit $MAX_FIX_FILES) — likely an SDK migration."
    fail "Not applied. Review it, then run 'dart fix --apply' deliberately (or raise FVERIFY_FIX_MAX_FILES)."
    exit 1
  else
    step "dart fix --apply ($FIX_FILES file(s))"
    if ! fqueue_nice dart fix --apply; then
      fail "dart fix --apply failed."
      exit 1
    fi
  fi
  step "dart format $FORMAT_DIRS"
  # shellcheck disable=SC2086 # word-split on purpose: plain directory names
  if ! dart format $FORMAT_DIRS; then
    fail "dart format failed (syntax error?) — see above."
    exit 1
  fi
fi

# -- 1. Format check (non-mutating) ---------------------------------------------
FORMAT_OK=true
step "dart format check"
# shellcheck disable=SC2086
if dart format --output=none --set-exit-if-changed $FORMAT_DIRS; then
  ok "formatting compliant"
else
  FORMAT_OK=false
  fail "dart format would change the files listed above."
  fail "Run 'dart format $FORMAT_DIRS' (or './scripts/fverify.sh --fix'). Continuing with analysis and tests."
fi

# -- 2. Static analysis ---------------------------------------------------------
step "flutter analyze"
if fqueue_nice flutter analyze --no-pub; then
  ok "analyze clean"
else
  fail "flutter analyze reported issues — fix them before finishing."
  exit 1
fi

# -- 3. Tests -------------------------------------------------------------------
# Tests run through ftest.sh (same queue slot — this script already holds it):
# a full run compiles test files into a few parallel shards, skips an unchanged
# architecture gate, and prints each compile error once.
step "flutter test $* (via scripts/ftest.sh)"
if bash "$SCRIPT_DIR/ftest.sh" "$@"; then
  ok "all tests passed"
else
  fail "flutter test failed — fix failing tests before finishing."
  exit 1
fi

ELAPSED=$((SECONDS - START_TS))
if [ "$FORMAT_OK" = false ]; then
  echo ""
  fail "analyze ✓   test ✓   but formatting is NOT compliant (${ELAPSED}s) — see the format step above."
  exit 1
fi
echo ""
echo -e "${BOLD}-- verify -----------------------------------------------------------${RESET}"
echo -e "  ${GREEN}format ✓   analyze ✓   test ✓   (${ELAPSED}s)${RESET}"
echo -e "  ${GREEN}Ready to finish.${RESET}"
echo ""
