#!/usr/bin/env bash
# =============================================================================
# fmap.sh — compact project map for orienting at the start of a session.
#
# One line per feature: routes, optional layers (service/dto), module/barrel
# presence, whether the module is wired into DI and the router, and which
# other features it imports (through their barrels). Read-only, text-based:
# it reads `// fgen:`-style wiring and import lines, not the analyzer, so
# treat it as orientation, not proof (architecture_test.dart is the gate).
#
# Usage: ./scripts/fmap.sh
# =============================================================================
set -euo pipefail

PROJECT_ROOT=""
dir="$PWD"
while [[ "$dir" != "/" ]]; do
  [[ -f "$dir/pubspec.yaml" ]] && PROJECT_ROOT="$dir" && break
  dir="$(dirname "$dir")"
done
[[ -z "$PROJECT_ROOT" ]] && echo "Could not find pubspec.yaml." && exit 1
cd "$PROJECT_ROOT"

PACKAGE="$(grep -E '^name:' pubspec.yaml | head -n 1 | sed -E 's/^name:[[:space:]]*//')"
LOCATOR="lib/core/di/service_locator.dart"
ROUTER="lib/core/router/app_router.dart"
CONSTANTS="lib/core/router/route_constants.dart"
count() { find "$1" -name '*.dart' ! -name '*.g.dart' ! -name '*.freezed.dart' ! -path '*/generated/*' 2>/dev/null | wc -l | tr -d ' '; }

echo "$PACKAGE — lib: $(count lib) files, test: $(count test) files (excl. generated)"
echo "core: $(ls -d lib/core/*/ 2>/dev/null | xargs -n1 basename 2>/dev/null | tr '\n' ' ')"

if [[ ! -d lib/features ]]; then
  echo "features: none"
  exit 0
fi

echo "features:"
for feature_dir in lib/features/*/; do
  f="$(basename "$feature_dir")"
  module="lib/features/$f/${f}_module.dart"
  flags=()
  [[ -f "lib/features/$f/$f.dart" ]] && flags+=("barrel")
  [[ -d "lib/features/$f/domain/services" ]] && flags+=("service")
  [[ -d "lib/features/$f/data/models" ]] && flags+=("dto")

  routes="-"
  wiring="no module"
  if [[ -f "$module" ]]; then
    register="$(grep -oE 'void register[A-Za-z0-9_]+Feature' "$module" | head -n 1 | sed 's/^void //')" || true
    routes_fn="$(grep -oE '^List<RouteBase> [A-Za-z0-9_]+Routes' "$module" | head -n 1 | sed 's/^List<RouteBase> //')" || true
    di="no"; nav="no"
    [[ -n "$register" ]] && grep -q "${register}(" "$LOCATOR" 2>/dev/null && di="yes"
    [[ -n "$routes_fn" ]] && grep -q "\.\.\.${routes_fn}(" "$ROUTER" 2>/dev/null && nav="yes"
    wiring="DI:$di router:$nav"
    paths=()
    while IFS= read -r constant; do
      [[ -z "$constant" ]] && continue
      path="$(grep -E "static const String ${constant} *=" "$CONSTANTS" 2>/dev/null | sed -E "s/.*= *'([^']*)'.*/\1/")" || true
      paths+=("${path:-$constant}")
    done < <(grep -oE 'Routes\.[A-Za-z0-9_]+' "$module" | sed 's/Routes\.//' | sort -u)
    [[ ${#paths[@]} -gt 0 ]] && routes="$(IFS=,; echo "${paths[*]}")"
  fi

  deps="$(grep -rhoE "features/[a-z0-9_]+/[a-z0-9_]+\.dart|\.\./\.\./[a-z0-9_]+/[a-z0-9_]+\.dart" "lib/features/$f" --include='*.dart' 2>/dev/null \
    | sed -E 's#.*/([a-z0-9_]+)/([a-z0-9_]+)\.dart#\1 \2#' | awk -v self="$f" '$1 == $2 && $1 != self { print $1 }' | sort -u | tr '\n' ',' | sed 's/,$//')" || true

  printf '  %-18s routes: %-16s %-18s %s%s\n' "$f" "$routes" "$wiring" \
    "$(IFS=' '; echo "${flags[*]:-}")" "${deps:+  uses: $deps}"
done
