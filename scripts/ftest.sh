#!/usr/bin/env bash
# =============================================================================
# ftest.sh — `flutter test` through the machine-wide queue, made cheap.
#
# Use it instead of a bare `flutter test` (agents especially).
#
#   ./scripts/ftest.sh test/features/profile/   # while iterating: only the
#                                               # affected tests ("light" lane)
#   ./scripts/ftest.sh                          # full suite ("heavy" lane)
#   ./scripts/ftest.sh --slowest[=N] [paths]    # + the N slowest files/tests
#   ./scripts/ftest.sh --reporter expanded test/core/
#
# What it does:
#   - waits for a slot in the queue shared by every project on this machine
#     (scripts/fqueue.sh): runs scoped to explicit paths use a separate light
#     lane, so a one-file check never waits behind another project's full
#     suite; tests run at lower CPU priority;
#   - FULL runs compile per shard, not per file: test files are imported into
#     FORGE_TEST_SHARDS generated entrypoints (default = concurrency, 4;
#     .dart_tool/flutterforge/shard_<n>_test.dart, each file in a group named
#     after its path, files balanced by size) that run in parallel — per-file
#     loading was ~80% of a small app's full run, while large suites keep
#     their test bodies running in parallel. Files that need their own isolate
#     run separately: golden tests (paths are relative to the test file),
#     files with library-level @TestOn/@Tags/@Timeout/@Skip/@OnPlatform, files
#     with a `// ftest:isolate` line (state a shared isolate breaks, e.g. a
#     full app boot that needs fresh plugins), and everything when a nested
#     flutter_test_config.dart exists.
#     FORGE_TEST_AGGREGATE=0 restores one isolate per file;
#   - FULL runs skip test/architecture_test.dart when lib/, pubspec.lock and
#     the checker are unchanged since its last green run (stamp in
#     .dart_tool/flutterforge/). It always runs on CI (CI=true) or with
#     FORGE_ARCH_ALWAYS=1;
#   - prints each compile error once (a broken file used to repeat it for
#     every test file importing it), without flutter_tools stack frames and
#     with project-relative paths;
#   - passing tests print nothing (`--reporter failures-only`) unless a
#     reporter is given.
#
# --slowest[=N] measures before optimizing (one isolate per file, so file
# load times are visible): it records the run with the JSON file reporter and
# prints the N slowest test files (load + run) and tests. Needs `uv`.
#
# Environment: FORGE_QUEUE=0 (no queue), FORGE_QUEUE_SLOTS /
# FORGE_QUEUE_LIGHT_SLOTS (default 1 each), FORGE_NICE (default 10),
# FORGE_TEST_CONCURRENCY (flutter test -j; default 4 full, 2 scoped),
# FORGE_TEST_AGGREGATE=0, FORGE_ARCH_ALWAYS=1.
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=fqueue.sh
. "$SCRIPT_DIR/fqueue.sh"

PROJECT_ROOT=""
dir="$PWD"
while [ "$dir" != "/" ]; do
  if [ -f "$dir/pubspec.yaml" ]; then
    PROJECT_ROOT="$dir"
    break
  fi
  dir="$(dirname "$dir")"
done
if [ -z "$PROJECT_ROOT" ]; then
  echo "Could not find pubspec.yaml." >&2
  exit 1
fi

# -- Arguments (Bash 3.2 + `set -u`: rebuild "$@", no arrays) -----------------
HAS_REPORTER=false
HAS_CONCURRENCY=false
HAS_PATHS=false
SLOWEST=""
remaining=$#
while [ "$remaining" -gt 0 ]; do
  arg="$1"; shift
  case "$arg" in
    --slowest) SLOWEST=10 ;;
    --slowest=*) SLOWEST="${arg#--slowest=}" ;;
    -r|--reporter|--reporter=*) HAS_REPORTER=true; set -- "$@" "$arg" ;;
    -j|--concurrency|--concurrency=*|-j[0-9]*) HAS_CONCURRENCY=true; set -- "$@" "$arg" ;;
    -*) set -- "$@" "$arg" ;;
    *)
      # An existing path (relative to the current directory) scopes the run.
      if [ -e "$arg" ]; then
        HAS_PATHS=true
      fi
      set -- "$@" "$arg"
      ;;
  esac
  remaining=$((remaining - 1))
done
case "$SLOWEST" in
  '') ;;
  *[!0-9]*|0) echo "--slowest takes a positive number (e.g. --slowest=20)." >&2; exit 2 ;;
esac
LANE=heavy
if [ "$HAS_PATHS" = true ]; then
  LANE=light
fi
[ "$HAS_REPORTER" = true ] || set -- --reporter failures-only "$@"
if [ "$HAS_CONCURRENCY" = false ]; then
  if [ -n "${FORGE_TEST_CONCURRENCY:-}" ]; then
    set -- "--concurrency=$FORGE_TEST_CONCURRENCY" "$@"
  elif [ "$LANE" = light ]; then
    set -- --concurrency=2 "$@"
  else
    # Measured: -j8 was no faster than -j5 (compiles are serialized) and -j4
    # cut peak memory by a third.
    set -- --concurrency=4 "$@"
  fi
fi

# -- Output filter: each compile error once, no tool frames, short paths -------
filter_output() {
  awk -v root="$PROJECT_ROOT/" -v phys="$(cd "$PROJECT_ROOT" && pwd -P)/" '
    function strip(line, prefix,    i) {
      while ((i = index(line, prefix)) > 0) {
        line = substr(line, 1, i - 1) substr(line, i + length(prefix))
      }
      return line
    }
    function shorten(line) {
      line = strip(line, "file://")
      line = strip(line, phys)
      return strip(line, root)
    }
    /package:flutter_tools\// || /dart:async\// || /dart:async-patch\// || /dart:isolate-patch\// { next }
    # A repeated compile error: drop its notes and source excerpt up to the
    # caret marker (bounded, so an unusual block can never hide real output).
    skipping > 0 && !/ Error: / {
      skipping--
      if ($0 ~ /^[ \t]*\^+[ \t]*$/) skipping = 0
      next
    }
    { skipping = 0 }
    / Error: / {
      # Same error raw and inside a "Failed to load" block: one key.
      key = shorten($0)
      sub(/^[ \t]+/, "", key)
      sub(/^Compilation failed for testPath=[^:]*: /, "", key)
      if (key in seen) { repeats++; skipping = 8; next }
      seen[key] = 1
    }
    { print shorten($0); fflush() }
    END {
      if (repeats > 0) printf("(%d repeated compile error(s) omitted)\n", repeats)
    }
  '
}

# Runs flutter test through the queue and the filter; returns its status.
run_flutter_test() {
  local status=0
  set +e
  fqueue_nice flutter test "$@" 2>&1 | filter_output
  status=${PIPESTATUS[0]}
  set -e
  return "$status"
}

fqueue_acquire "ftest" "$LANE"

# -- --slowest: one isolate per file, timings summarized ------------------------
if [ -n "$SLOWEST" ]; then
  TIMINGS="$(mktemp "${TMPDIR:-/tmp}/ftest-timings.XXXXXX")"
  trap 'rm -f "$TIMINGS"; fqueue_release' EXIT
  STATUS=0
  run_flutter_test --file-reporter "json:$TIMINGS" "$@" || STATUS=$?
  echo ""
  echo "-- slowest (top $SLOWEST) ------------------------------------------------"
  uv run --no-project python - "$TIMINGS" "$SLOWEST" <<'PYEOF' || echo "(timing summary unavailable: needs uv)"
import json, os, sys

path, limit = sys.argv[1], int(sys.argv[2])
suites, tests, starts, done = {}, {}, {}, {}
with open(path, encoding="utf-8") as handle:
    for line in handle:
        try:
            event = json.loads(line)
        except ValueError:
            continue
        kind = event.get("type")
        if kind == "suite":
            raw = event["suite"].get("path") or "?"
            suites[event["suite"]["id"]] = os.path.relpath(raw) if os.path.isabs(raw) else raw
        elif kind == "testStart":
            test = event["test"]
            tests[test["id"]] = (test.get("suiteID"), test.get("name", ""))
            starts[test["id"]] = event["time"]
        elif kind == "testDone" and event["testID"] in starts:
            done[event["testID"]] = event["time"]

per_file, per_test = {}, []
for test_id, end in done.items():
    suite_id, name = tests[test_id]
    elapsed = end - starts[test_id]
    file = suites.get(suite_id, "?")
    first, last = per_file.get(file, (starts[test_id], end))
    per_file[file] = (min(first, starts[test_id]), max(last, end))
    if not name.startswith("loading "):
        per_test.append((elapsed, file, name))

print("files (load + run):")
for file, (first, last) in sorted(per_file.items(), key=lambda kv: kv[1][0] - kv[1][1])[:limit]:
    print(f"  {(last - first) / 1000:7.2f}s  {file}")
print("tests:")
for elapsed, file, name in sorted(per_test, reverse=True)[:limit]:
    print(f"  {elapsed / 1000:7.2f}s  {file}: {name}")
PYEOF
  exit "$STATUS"
fi

# -- Scoped runs, or aggregation disabled: plain flutter test ------------------
if [ "$LANE" = light ] || [ "${FORGE_TEST_AGGREGATE:-1}" = "0" ] || [ ! -d "$PROJECT_ROOT/test" ]; then
  STATUS=0
  run_flutter_test "$@" || STATUS=$?
  exit "$STATUS"
fi

# -- Full run: one aggregated entrypoint + files that need their own isolate ---
cd "$PROJECT_ROOT"
STATE_DIR=".dart_tool/flutterforge"
mkdir -p "$STATE_DIR"
ARCH_TEST="test/architecture_test.dart"
ARCH_STAMP="$STATE_DIR/architecture.stamp"

ALL_FILES="$(find test -name '*_test.dart' -type f | LC_ALL=C sort)"
if [ -z "$ALL_FILES" ]; then
  # No test files: let flutter test report that in its own words.
  STATUS=0
  run_flutter_test "$@" || STATUS=$?
  exit "$STATUS"
fi
NESTED_CONFIG="$(find test -mindepth 2 -name 'flutter_test_config.dart' | head -n 1)"

# Golden comparisons resolve paths relative to the test file, so golden tests
# keep their own isolate — also when they go through a shared helper
# (test/**/golden_harness.dart calling matchesGoldenFile).
GOLDEN_HELPERS="$(grep -rl 'matchesGoldenFile' test --include='*.dart' 2>/dev/null \
  | grep -v '_test\.dart$' | sed 's|.*/||' | LC_ALL=C sort -u || true)"
uses_golden_helper() {
  local helper
  for helper in $GOLDEN_HELPERS; do
    if grep -Eq "^import ['\"][^'\"]*/?$helper['\"]" "$1"; then
      return 0
    fi
  done
  return 1
}

AGGREGATED=""
STANDALONE=""
for file in $ALL_FILES; do
  [ "$file" = "$ARCH_TEST" ] && continue
  if [ -n "$NESTED_CONFIG" ] \
    || grep -q 'matchesGoldenFile' "$file" \
    || uses_golden_helper "$file" \
    || grep -q '^// ftest:isolate' "$file" \
    || grep -Eq '^@(TestOn|Tags|Timeout|Skip|OnPlatform)' "$file" \
    || ! grep -Eq '(^|[^A-Za-z0-9_])main *\( *\)' "$file"; then
    STANDALONE="$STANDALONE $file"
  else
    AGGREGATED="$AGGREGATED $file"
  fi
done

arch_fingerprint() {
  {
    find lib -type f -name '*.dart' | LC_ALL=C sort | while IFS= read -r source; do
      cksum "$source"
    done
    for extra in pubspec.lock "$ARCH_TEST" test/support/architecture_checker.dart; do
      if [ -f "$extra" ]; then
        cksum "$extra"
      fi
    done
  } | cksum
}

RUN_ARCH=false
FINGERPRINT=""
if [ -f "$ARCH_TEST" ]; then
  FINGERPRINT="$(arch_fingerprint)"
  if [ "${CI:-}" = "true" ] || [ "${FORGE_ARCH_ALWAYS:-0}" = "1" ] \
    || [ "$(cat "$ARCH_STAMP" 2>/dev/null || true)" != "$FINGERPRINT" ]; then
    RUN_ARCH=true
  else
    echo "[ftest] architecture gate: lib/ unchanged since its last green run — skipped (FORGE_ARCH_ALWAYS=1 forces it)."
  fi
fi

# Writes one aggregated entrypoint: $1 = output path, remaining = test files.
write_shard() {
  local entry="$1" index=0 file
  shift
  {
    echo "// GENERATED by scripts/ftest.sh for full runs — do not edit or commit."
    echo "// These test files run in one isolate (compiled once)."
    echo "// ignore_for_file: type=lint"
    echo "import 'package:flutter_test/flutter_test.dart';"
    if [ -f test/flutter_test_config.dart ]; then
      echo "import '../../test/flutter_test_config.dart' as forge_config;"
    fi
    for file in "$@"; do
      echo "import '../../$file' as t$index;"
      index=$((index + 1))
    done
    echo ""
    if [ -f test/flutter_test_config.dart ]; then
      echo "Future<void> main() => forge_config.testExecutable(_all);"
      echo ""
      echo "void _all() {"
    else
      echo "void main() {"
    fi
    index=0
    for file in "$@"; do
      echo "  group('$file', () {"
      echo "    _load(t$index.main);"
      echo "  });"
      index=$((index + 1))
    done
    echo "}"
    echo ""
    echo "// A file whose main() throws fails alone (as in its own isolate), not the run."
    echo "void _load(Function main) {"
    echo "  try {"
    echo "    main();"
    echo "  } catch (error, stackTrace) {"
    echo "    test('loading', () => Error.throwWithStackTrace(error, stackTrace));"
    echo "  }"
    echo "}"
  } > "$entry"
}

# Shards: one compile each, run in parallel (test bodies keep their
# parallelism; compiles drop from one per file to one per shard). Files are
# balanced by size, largest first, onto the lightest shard.
SHARDS="${FORGE_TEST_SHARDS:-${FORGE_TEST_CONCURRENCY:-4}}"
case "$SHARDS" in ''|*[!0-9]*|0) SHARDS=4 ;; esac
TARGETS=""
if [ -n "$AGGREGATED" ]; then
  ASSIGNMENT="$(for file in $AGGREGATED; do printf '%s %s\n' "$(wc -c < "$file" | tr -d ' ')" "$file"; done \
    | LC_ALL=C sort -k1,1nr -k2,2 \
    | awk -v n="$SHARDS" '{
        best = 0
        for (i = 1; i < n; i++) if (load[i] < load[best]) best = i
        load[best] += $1
        print best, $2
      }')"
  shard=0
  while [ "$shard" -lt "$SHARDS" ]; do
    SHARD_FILES="$(printf '%s\n' "$ASSIGNMENT" | awk -v s="$shard" '$1 == s { print $2 }' | LC_ALL=C sort)"
    if [ -n "$SHARD_FILES" ]; then
      # shellcheck disable=SC2086 # plain test paths
      write_shard "$STATE_DIR/shard_${shard}_test.dart" $SHARD_FILES
      TARGETS="$TARGETS $STATE_DIR/shard_${shard}_test.dart"
    fi
    shard=$((shard + 1))
  done
fi
TARGETS="$TARGETS $STANDALONE"
if [ "$RUN_ARCH" = true ]; then
  TARGETS="$TARGETS $ARCH_TEST"
fi

if [ -z "${TARGETS// /}" ]; then
  echo "[ftest] nothing to run."
  exit 0
fi

STATUS=0
# shellcheck disable=SC2086 # TARGETS holds plain test paths (no spaces)
run_flutter_test "$@" $TARGETS || STATUS=$?
if [ "$STATUS" -eq 0 ] && [ "$RUN_ARCH" = true ]; then
  printf '%s\n' "$FINGERPRINT" > "$ARCH_STAMP"
fi
exit "$STATUS"
