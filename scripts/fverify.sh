#!/usr/bin/env bash
# =============================================================================
# fverify.sh — one-command quality gate to run before finishing a change.
#
# Runs, in order:
#   1. dart format --output=none --set-exit-if-changed .   (CHECK only —
#      without --fix this script never rewrites files)
#   2. flutter analyze
#   3. flutter test   (includes the architecture boundary + DI smoke tests)
#
# --fix (opt-in, mutating): first runs `dart fix --apply` and `dart format .`,
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
# Usage:
#   ./scripts/fverify.sh          # check only
#   ./scripts/fverify.sh --fix    # dart fix + dart format, then check
# =============================================================================

set -euo pipefail

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

START_TS=$SECONDS

# -- 0. Optional preparation (--fix only; the only mutating path) ----------------
if [ "$FIX" = true ]; then
  step "dart fix --apply"
  if ! dart fix --apply; then
    fail "dart fix --apply failed."
    exit 1
  fi
  step "dart format ."
  if ! dart format .; then
    fail "dart format failed (syntax error?) — see above."
    exit 1
  fi
fi

# -- 1. Format check (non-mutating) ---------------------------------------------
FORMAT_OK=true
step "dart format check"
if dart format --output=none --set-exit-if-changed .; then
  ok "formatting compliant"
else
  FORMAT_OK=false
  fail "dart format would change the files listed above."
  fail "Run 'dart format .' (or './scripts/fverify.sh --fix'). Continuing with analysis and tests."
fi

# -- 2. Static analysis ---------------------------------------------------------
step "flutter analyze"
if flutter analyze --no-pub; then
  ok "analyze clean"
else
  fail "flutter analyze reported issues — fix them before finishing."
  exit 1
fi

# -- 3. Tests -------------------------------------------------------------------
step "flutter test $*"
if flutter test "$@"; then
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
