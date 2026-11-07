#!/usr/bin/env bash
# =============================================================================
# fcoverage.sh — line-coverage measurement + floor for the pure-logic layers.
#
# Runs the full test suite with --coverage, scopes coverage/lcov.info to
# lib/core/ and lib/features/*/domain/ (the layers the review flagged as
# must-stay-covered), prints a per-area table, and exits non-zero when the
# scoped total is below the floor.
#
# Floor: default 75 (%). Override for one run:
#   FCOVERAGE_MIN=80 ./scripts/fcoverage.sh     # env var
#   ./scripts/fcoverage.sh 80                   # first argument
#   ./scripts/fcoverage.sh 0                    # measure only, never fail
#
# Reuse an existing lcov (no second suite run), e.g. after CI produced one:
#   FCOVERAGE_LCOV=path/to/lcov.info ./scripts/fcoverage.sh 0
#
# Not part of fverify.sh on purpose: it runs the whole suite again.
# =============================================================================

set -euo pipefail

# -- Find project root --------------------------------------------------------
PROJECT_ROOT=""
dir="$PWD"
while [[ "$dir" != "/" ]]; do
  [[ -f "$dir/pubspec.yaml" ]] && PROJECT_ROOT="$dir" && break
  dir="$(dirname "$dir")"
done
[[ -z "$PROJECT_ROOT" ]] && echo "fcoverage: no pubspec.yaml found" >&2 && exit 1
cd "$PROJECT_ROOT"

MIN="${FCOVERAGE_MIN:-${1:-75}}"
LCOV="${FCOVERAGE_LCOV:-coverage/lcov.info}"

if [[ -z "${FCOVERAGE_LCOV:-}" ]]; then
  echo "[fcoverage] running flutter test --coverage (the full suite)…"
  flutter test --coverage
fi

if [[ ! -f "$LCOV" ]]; then
  echo "[fcoverage] $LCOV not found — did the test run produce it?" >&2
  exit 1
fi

# -- Scoped summary -----------------------------------------------------------
# lcov sections: SF:<path> … DA:<line>,<hits> … end_of_record.
# Scope: lib/core/** (area "core") and lib/features/<name>/domain/** (area
# "domain:<name>"). Everything else is ignored. awk (portable, no gawk-only
# asorti) aggregates "area lines hit" rows; sort + bash render and check.
rows="$(awk '
  function area_for(path,   rest) {
    if (path ~ /^lib\/core\//) return "core";
    if (path ~ /^lib\/features\/[^\/]+\/domain\//) {
      rest = substr(path, 14);
      return "domain:" substr(rest, 1, index(rest, "/") - 1);
    }
    return "";
  }
  /^SF:/ {
    area = area_for(substr($0, 4));
    in_scope = (area != "");
    if (in_scope && !(area in lf)) { lf[area] = 0; lh[area] = 0; }
    next;
  }
  in_scope && /^DA:/ {
    split(substr($0, 4), parts, ",");
    lf[area]++;
    if (parts[2] + 0 > 0) lh[area]++;
    next;
  }
  /^end_of_record$/ { in_scope = 0; next; }
  END { for (a in lf) print a, lf[a], lh[a]; }
' "$LCOV" | sort)"

if [[ -z "$rows" ]]; then
  echo "[fcoverage] no in-scope records found in $LCOV — is the lcov scoped to lib/?" >&2
  exit 1
fi

total_lf=0
total_lh=0
printf "  %-28s %8s %8s %7s\n" "area" "lines" "hit" "pct"
while read -r a f h; do
  pct="$(awk -v h="$h" -v f="$f" 'BEGIN { printf "%.1f", (f > 0) ? 100 * h / f : 0 }')"
  printf "  %-28s %8d %8d %6s%%\n" "$a" "$f" "$h" "$pct"
  total_lf=$((total_lf + f))
  total_lh=$((total_lh + h))
done <<< "$rows"

total_pct="$(awk -v h="$total_lh" -v f="$total_lf" 'BEGIN { printf "%.1f", (f > 0) ? 100 * h / f : 0 }')"
printf "  %-28s %8d %8d %6s%%\n" "TOTAL (scoped)" "$total_lf" "$total_lh" "$total_pct"

if awk -v t="$total_lh" -v f="$total_lf" -v m="$MIN" 'BEGIN { exit !((f > 0 ? 100 * t / f : 0) < m + 0) }'; then
  echo "[fcoverage] FAIL: ${total_pct}% < floor ${MIN}%" >&2
  exit 1
fi
echo "[fcoverage] ok: ${total_pct}% >= floor ${MIN}%"
