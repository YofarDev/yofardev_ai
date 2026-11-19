# shellcheck shell=bash
# =============================================================================
# fqueue.sh — machine-wide queue for heavy Flutter runs (sourced, not run).
#
# Several projects (and several agents) running `flutter test`/`flutter
# analyze` at once each start a pool of test processes and an analyzer; the
# machine thrashes and every run gets slower. ftest.sh, fverify.sh and the
# optional `flutter` PATH shim source this file and hold a machine-wide slot
# while they run. The lock lives in the user's cache directory, NOT in the
# project, so it is shared by every project on the machine.
#
# Two lanes, so a one-file check never waits behind another project's full
# suite:
#   heavy  full suites, fverify, flutter analyze   (FORGE_QUEUE_SLOTS, default 1)
#   light  test runs scoped to explicit paths      (FORGE_QUEUE_LIGHT_SLOTS, default 1)
#
#   fqueue_acquire "<label>" [heavy|light]  # blocks until a slot is free
#   fqueue_nice <command...>                # runs it niced, as the slot's child
#
# Environment:
#   FORGE_QUEUE=0              disable queueing (CI runners do not need it)
#   FORGE_QUEUE_SLOTS=N        concurrent heavy runs (default 1)
#   FORGE_QUEUE_LIGHT_SLOTS=N  concurrent light runs (default 1)
#   FORGE_QUEUE_DIR=<dir>      lock directory
#                              (default ${XDG_CACHE_HOME:-~/.cache}/flutterforge/test-queue)
#   FORGE_NICE=N               niceness for queued commands (default 10; 0 = off)
#
# A slot records its holder pid and the pid of the command it runs. It is
# reclaimed only when BOTH are gone, so a hard-killed script whose `flutter
# test` is still running keeps its slot until that run ends. A process that
# already holds a slot (FQUEUE_HELD=1 in its environment) does not queue
# again, so nesting never deadlocks. Bash 3.2 compatible (macOS stock bash).
# =============================================================================

FQUEUE_SLOT_DIR=""

# Stops the slot's running command (if any) and frees the slot.
fqueue_release() {
  if [ -n "$FQUEUE_SLOT_DIR" ]; then
    local child
    child="$(sed -n '1p' "$FQUEUE_SLOT_DIR/child" 2>/dev/null || true)"
    if [ -n "$child" ] && kill -0 "$child" 2>/dev/null; then
      kill -TERM "$child" 2>/dev/null || true
    fi
    rm -rf "$FQUEUE_SLOT_DIR"
    FQUEUE_SLOT_DIR=""
  fi
}

_fqueue_first_line() {
  if [ -f "$1" ]; then
    sed -n '1p' "$1" 2>/dev/null || true
  fi
}

_fqueue_alive() {
  [ -n "$1" ] && kill -0 "$1" 2>/dev/null
}

# Removes a slot whose holder and command are both gone (status 0 when it
# did). A slot with no owner file yet is either being created right now or
# was abandoned between mkdir and the write; only the latter (older than a
# minute) goes.
_fqueue_reclaim_if_stale() {
  local slot="$1" pid child
  pid="$(_fqueue_first_line "$slot/owner")"
  if [ -z "$pid" ]; then
    if [ -n "$(find "$slot" -maxdepth 0 -mmin +1 2>/dev/null || true)" ]; then
      rm -rf "$slot"
      return 0
    fi
    return 1
  fi
  child="$(_fqueue_first_line "$slot/child")"
  if _fqueue_alive "$pid" || _fqueue_alive "$child"; then
    return 1
  fi
  # Re-check right before removing: never remove a slot re-taken meanwhile.
  if [ "$(_fqueue_first_line "$slot/owner")" = "$pid" ]; then
    rm -rf "$slot"
    return 0
  fi
  return 1
}

fqueue_acquire() {
  local label="${1:-flutter}" lane="${2:-heavy}"
  if [ "${FORGE_QUEUE:-1}" = "0" ] || [ "${FQUEUE_HELD:-0}" = "1" ]; then
    return 0
  fi
  local dir="${FORGE_QUEUE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/flutterforge/test-queue}"
  local slots
  if [ "$lane" = "light" ]; then
    slots="${FORGE_QUEUE_LIGHT_SLOTS:-1}"
  else
    lane="heavy"
    slots="${FORGE_QUEUE_SLOTS:-1}"
  fi
  case "$slots" in ''|*[!0-9]*|0) slots=1 ;; esac
  if ! mkdir -p "$dir" 2>/dev/null; then
    echo "[queue] cannot create $dir — running without the queue." >&2
    return 0
  fi

  local waited=0 announced=false reclaimed i slot holder
  while :; do
    reclaimed=false
    i=0
    while [ "$i" -lt "$slots" ]; do
      slot="$dir/$lane-slot-$i"
      if mkdir "$slot" 2>/dev/null; then
        printf '%s\n%s\n%s\n' "$$" "$PWD" "$label" > "$slot/owner"
        FQUEUE_SLOT_DIR="$slot"
        export FQUEUE_HELD=1
        trap 'fqueue_release' EXIT
        trap 'fqueue_release; exit 130' INT
        trap 'fqueue_release; exit 143' TERM
        if [ "$announced" = true ]; then
          echo "[queue] slot acquired after ${waited}s."
        fi
        return 0
      fi
      if _fqueue_reclaim_if_stale "$slot"; then
        reclaimed=true
      fi
      i=$((i + 1))
    done
    if [ "$reclaimed" = true ]; then
      continue # a dead holder's slot was freed: retry at once
    fi
    if [ "$announced" = false ]; then
      holder="$( (sed -n '2p;3p' "$dir/$lane-slot-0/owner" 2>/dev/null || true) | tr '\n' ' ')"
      echo "[queue] another $lane Flutter run is in progress${holder:+ ($holder)}; waiting for a free slot..."
      announced=true
    elif [ $((waited % 60)) -eq 0 ]; then
      echo "[queue] still waiting (${waited}s)..."
    fi
    sleep 2
    waited=$((waited + 2))
  done
}

# Runs "$@" at reduced CPU priority. Inside a held slot the command runs as a
# recorded child (so the slot outlives a killed holder while it still runs)
# and is stopped when the holder is interrupted.
fqueue_nice() {
  local level="${FORGE_NICE:-10}"
  local -a runner=()
  if [ "$level" != "0" ] && command -v nice >/dev/null 2>&1; then
    runner=(nice -n "$level")
  fi
  if [ -z "$FQUEUE_SLOT_DIR" ]; then
    "${runner[@]+"${runner[@]}"}" "$@"
    return $?
  fi
  "${runner[@]+"${runner[@]}"}" "$@" < /dev/null &
  local child=$! status=0
  printf '%s\n' "$child" > "$FQUEUE_SLOT_DIR/child"
  wait "$child" || status=$?
  rm -f "$FQUEUE_SLOT_DIR/child"
  return "$status"
}
