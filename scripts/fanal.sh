#!/usr/bin/env bash
# ============================================================
# fanal.sh
# Compact pre-analysis of a Flutter project for LLM-assisted audit.
#
# Usage:
#   ./fanal.sh [path/to/flutter/project]
#   ./fanal.sh                     # defaults to current dir
#
# Output:
#   <project>/flutter_analysis.md (overwritten each run — no litter)
# ============================================================

set -euo pipefail

PROJECT_DIR="${1:-.}"
PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"
LIB_DIR="$PROJECT_DIR/lib"
FEATURES_DIR="$LIB_DIR/features"
OUT_FILE="$PROJECT_DIR/flutter_analysis.md"

h2() {
  echo ""
  echo "## $*"
}

info() {
  echo "$*"
}

relpath() {
  echo "${1#$PROJECT_DIR/}"
}

is_ignored_file() {
  case "$1" in
    *.g.dart|*.freezed.dart|*.gen.dart|*.gr.dart|*.mocks.dart)
      return 0
      ;;
    */l10n/generated/*|*/generated/l10n/*|*/flutter_gen/*|*/firebase_options.dart)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

list_dart_files() {
  find "$LIB_DIR" -type f -name "*.dart" ! -name ".gitkeep" 2>/dev/null | sort
}

dart_files() {
  while IFS= read -r f; do
    if ! is_ignored_file "$f"; then
      echo "$f"
    fi
  done < <(list_dart_files)
}

feature_dirs() {
  if [[ -d "$FEATURES_DIR" ]]; then
    find "$FEATURES_DIR" -mindepth 1 -maxdepth 1 -type d | sort
  fi
}

lines_in_file() {
  wc -l < "$1" | tr -d ' '
}

count_dart_files_in_dir() {
  local dir="$1"
  local count=0

  while IFS= read -r f; do
    if ! is_ignored_file "$f"; then
      count=$((count + 1))
    fi
  done < <(find "$dir" -type f -name "*.dart" ! -name ".gitkeep" 2>/dev/null | sort)

  echo "$count"
}

count_pattern_matches() {
  local pattern="$1"
  local count=0
  local matches

  while IFS= read -r f; do
    matches=$(grep -cE "$pattern" "$f" 2>/dev/null || true)
    count=$((count + matches))
  done < <(dart_files)

  echo "$count"
}

scan_files() {
  local label="$1"
  local pattern="$2"
  local exclude="${3:-__none__}"
  local found=0

  while IFS= read -r f; do
    if [[ "$exclude" != "__none__" ]] && echo "$f" | grep -Eq "$exclude"; then
      continue
    fi

    if grep -qE "$pattern" "$f" 2>/dev/null; then
      if [[ "$found" -eq 0 ]]; then
        info ""
        info "**$label**"
        found=1
      fi
      info "- \`$(relpath "$f")\`"
    fi
  done < <(dart_files)
}

scan_lines() {
  local label="$1"
  local pattern="$2"
  local cap="${3:-3}"
  local exclude="${4:-__none__}"
  local found=0
  local matches
  local rel

  while IFS= read -r f; do
    if [[ "$exclude" != "__none__" ]] && echo "$f" | grep -Eq "$exclude"; then
      continue
    fi

    matches=$(grep -nE "$pattern" "$f" 2>/dev/null | head -"$cap" || true)
    if [[ -n "$matches" ]]; then
      if [[ "$found" -eq 0 ]]; then
        info ""
        info "**$label**"
        found=1
      fi
      rel="$(relpath "$f")"
      while IFS= read -r line; do
        info "- \`$rel:$line\`"
      done <<< "$matches"
    fi
  done < <(dart_files)
}

{
  info "# Flutter Pre-Analysis - $(date +%Y-%m-%d)"
  info "_Project: \`$PROJECT_DIR\`_"
  info ""
  info "_This report is heuristic only. Use it to guide the audit, not to replace file reads._"

  h2 "Lib overview"
  if [[ -d "$LIB_DIR" ]]; then
    info '```text'
    info 'lib/'
    while IFS= read -r entry; do
      rel="${entry#$LIB_DIR/}"
      if [[ -d "$entry" ]]; then
        count=$(count_dart_files_in_dir "$entry")
        printf '+-- %s/ (%d dart files)\n' "$rel" "$count"
      else
        printf '+-- %s (%d lines)\n' "$rel" "$(lines_in_file "$entry")"
      fi
    done < <(find "$LIB_DIR" -mindepth 1 -maxdepth 1 \( -type d -o -type f \) | sort)
    info '```'
  else
    info "❌ No \`lib/\` directory found"
  fi

  h2 "Feature map"
  if [[ -d "$FEATURES_DIR" ]]; then
    while IFS= read -r feat; do
      name=$(basename "$feat")
      layers=()
      [[ -d "$feat/data" ]] && layers+=("data")
      [[ -d "$feat/domain" ]] && layers+=("domain")
      [[ -d "$feat/presentation" ]] && layers+=("presentation")
      file_count=$(count_dart_files_in_dir "$feat")
      cubit_count=$(find "$feat" -type f \( -name "*_cubit.dart" -o -name "*_bloc.dart" \) 2>/dev/null | wc -l | tr -d ' ')
      info "- **$name**: ${layers[*]:-no standard layers} | $file_count dart files | $cubit_count cubits/blocs"
    done < <(feature_dirs)
  else
    info "⚠️ No \`lib/features/\` directory found"
  fi

  h2 "Core layout"
  CORE_DIR="$LIB_DIR/core"
  if [[ -d "$CORE_DIR" ]]; then
    CORE_SUBDIRS=$(find "$CORE_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | xargs -I{} basename {} | sort | tr '\n' ' ' | sed 's/ $//')
    if [[ -n "$CORE_SUBDIRS" ]]; then
      info "Present directories: $CORE_SUBDIRS"
    else
      info "⚠️ \`lib/core/\` exists but has no subdirectories"
    fi

    for sub in di router; do
      if [[ -d "$CORE_DIR/$sub" ]]; then
        info "✅ core/$sub"
      else
        info "⚠️ core/$sub missing"
      fi
    done
  else
    info "⚠️ No \`lib/core/\` directory found"
  fi

  h2 "Large files to inspect"
  info "_Heuristic only. Long files are cohesion review candidates, not automatic violations._"
  info "_Thresholds: general >300 | screen/widget/cubit/bloc >350 | service/repo/api >400_"
  FOUND=0
  while IFS= read -r f; do
    rel="$(relpath "$f")"
    base=$(basename "$f")
    lc=$(lines_in_file "$f")
    limit=300

    if echo "$base" | grep -qiE '(service|repository|repo|api)'; then
      limit=400
    elif echo "$base" | grep -qiE '(_cubit|_bloc|screen|dialog|sheet|widget)\.dart$'; then
      limit=350
    fi

    if [[ "$lc" -gt "$limit" ]]; then
      info "- \`$rel\` - $lc lines (threshold $limit)"
      FOUND=1
    fi
  done < <(dart_files)
  [[ "$FOUND" -eq 0 ]] && info "✅ None"

  h2 "Cross-feature imports"
  if [[ -d "$FEATURES_DIR" ]]; then
    INTERNAL_FOUND=0
    DOMAIN_FOUND=0

    while IFS= read -r f; do
      current=$(echo "$f" | sed "s|$FEATURES_DIR/||" | cut -d'/' -f1)
      while IFS= read -r line; do
        imported=$(echo "$line" | grep -oE "features/[^'\"]+" || true)
        if [[ -z "$imported" ]]; then
          continue
        fi

        target=$(echo "$imported" | cut -d'/' -f2)
        layer=$(echo "$imported" | cut -d'/' -f3)

        if [[ -z "$target" || "$target" == "$current" ]]; then
          continue
        fi

        if [[ "$layer" == "data" || "$layer" == "presentation" ]]; then
          if [[ "$INTERNAL_FOUND" -eq 0 ]]; then
            info ""
            info "**Imports into another feature's internal layers**"
            INTERNAL_FOUND=1
          fi
          info "- \`$(relpath "$f")\`: **$current** -> **$target/$layer**"
          info "  \`$line\`"
        else
          if [[ "$DOMAIN_FOUND" -eq 0 ]]; then
            info ""
            info "**Cross-feature domain/shared imports to review**"
            DOMAIN_FOUND=1
          fi
          info "- \`$(relpath "$f")\`: **$current** -> **$target/$layer**"
          info "  \`$line\`"
        fi
      done < <(grep -n '^import' "$f" 2>/dev/null || true)
    done < <(dart_files | grep -F "$FEATURES_DIR" || true)

    [[ "$INTERNAL_FOUND" -eq 0 ]] && info "✅ No imports into another feature's data/presentation layers"
    [[ "$DOMAIN_FOUND" -eq 0 ]] && info "✅ No cross-feature domain/shared imports to review"
  else
    info "⚠️ No features directory - skipped"
  fi

  h2 "Heuristic signals"
  info "_These are grep-based leads. Inspect surrounding code before turning them into audit findings._"

  scan_files "Direct color usage to inspect" "Colors\\.|Color\\(0x" "_colors\\.dart|_theme\\.dart"
  scan_files "print / debugPrint to inspect" "print\\(|debugPrint\\(" "logger\\.dart"
  scan_lines "GoRouter navigation calls to inspect" "context\\.go\\(|context\\.push\\(|GoRouter\\.of\\(context\\)\\.(go|push)" 5
  scan_lines "Widget helper methods to inspect" "Widget _build" 3
  scan_lines "Nested BlocListener patterns to inspect" "child:.*BlocListener\\b" 5
  scan_lines "BlocConsumer usage to inspect" "BlocConsumer<" 5

  h2 "DI wiring integrity"
  SL_FILE=$(dart_files | grep -E '/(service_locator|injection)\.dart$' | head -1 || true)
  if [[ -n "$SL_FILE" ]]; then
    rel="$(relpath "$SL_FILE")"
    REG_COUNT=$(grep -Ec 'register(LazySingleton|Singleton|Factory|FactoryParam)' "$SL_FILE" 2>/dev/null || echo 0)
    info "✅ \`$rel\` - $REG_COUNT registration(s)"

    FOUND=0
    while IFS= read -r f; do
      matches=$(grep -nE 'create:.*=>.*[A-Za-z0-9_]+(Cubit|Bloc)\(' "$f" 2>/dev/null | grep -v 'getIt<' || true)
      if [[ -n "$matches" ]]; then
        if [[ "$FOUND" -eq 0 ]]; then
          info ""
          info "**Potential manual cubit/bloc construction outside DI-backed composition roots**"
          FOUND=1
        fi
        info "- \`$(relpath "$f")\`"
        while IFS= read -r line; do
          info "  \`$line\`"
        done <<< "$matches"
      fi
    done < <(dart_files | grep -vE '/(service_locator|injection)\.dart$|_test\.dart$' || true)

    [[ "$FOUND" -eq 0 ]] && info "✅ No obvious manual cubit/bloc construction detected"
  else
    info "⚠️ No service_locator.dart / injection.dart found"
  fi

  h2 "Cubit coupling analysis"
  if [[ -d "$FEATURES_DIR" ]]; then
    info "**Cubit/bloc count per feature** (raw counts only — judge boundaries by cohesion, not by number):"
    while IFS= read -r feat; do
      name=$(basename "$feat")
      count=$(find "$feat" -type f \( -name '*_cubit.dart' -o -name '*_bloc.dart' \) 2>/dev/null | wc -l | tr -d ' ')
      info "- $name: $count"
    done < <(feature_dirs)
  fi

  info ""
  info "**Stored cubit/bloc dependencies** (should usually be 0):"
  FOUND=0
  while IFS= read -r f; do
    matches=$(grep -nE 'final .*Cubit\b|final .*Bloc\b' "$f" 2>/dev/null || true)
    if [[ -n "$matches" ]]; then
      info "- ⚠️ \`$(relpath "$f")\`"
      while IFS= read -r line; do
        info "  \`$line\`"
      done <<< "$matches"
      FOUND=1
    fi
  done < <(dart_files | grep -E '(_cubit|_bloc)\.dart$' || true)
  [[ "$FOUND" -eq 0 ]] && info "✅ None detected"

  h2 "Routing"
  ROUTER_FILE=$(dart_files | grep -E '/(app_router|router)\.dart$' | head -1 || true)
  if [[ -n "$ROUTER_FILE" ]]; then
    rel="$(relpath "$ROUTER_FILE")"
    ROUTE_COUNT=$(grep -c 'path:' "$ROUTER_FILE" 2>/dev/null || echo 0)
    info "✅ \`$rel\` - $ROUTE_COUNT route(s)"

    VALUE_COUNT=$(count_pattern_matches 'BlocProvider\.value')
    PUSH_COUNT=$(count_pattern_matches 'Navigator\.push')
    DIALOG_COUNT=$(count_pattern_matches 'showDialog|showModalBottomSheet')
    info "Provider boundary signals: BlocProvider.value=$VALUE_COUNT | Navigator.push=$PUSH_COUNT | dialogs/sheets=$DIALOG_COUNT"
  else
    info "⚠️ No router file found"
  fi

  h2 "Test coverage"
  TEST_DIR="$PROJECT_DIR/test"
  if [[ -d "$TEST_DIR" ]]; then
    TOTAL=$(find "$TEST_DIR" -name '*_test.dart' | wc -l | tr -d ' ')
    BLOC=$(find "$TEST_DIR" \( -name '*cubit*_test.dart' -o -name '*bloc*_test.dart' \) | wc -l | tr -d ' ')
    WIDGET=$(find "$TEST_DIR" \( -name '*widget*_test.dart' -o -name '*screen*_test.dart' \) | wc -l | tr -d ' ')
    REPO=$(find "$TEST_DIR" \( -name '*repo*_test.dart' -o -name '*repository*_test.dart' \) | wc -l | tr -d ' ')
    info "Total: $TOTAL | Cubit/BLoC: $BLOC | Widget/Screen: $WIDGET | Repo: $REPO"

    if [[ -d "$FEATURES_DIR" ]]; then
      info ""
      while IFS= read -r feat; do
        FEAT_NAME=$(basename "$feat")
        COUNT=$(find "$TEST_DIR" \( -path "*features/$FEAT_NAME/*" -o -name "*${FEAT_NAME}*_test.dart" \) 2>/dev/null | wc -l | tr -d ' ')
        if [[ "$COUNT" -eq 0 ]]; then
          info "- ⚠️ $FEAT_NAME (no obvious feature tests)"
        else
          info "- ✅ $FEAT_NAME ($COUNT file(s))"
        fi
      done < <(feature_dirs)
    fi
  else
    info "⚠️ No \`test/\` directory found"
  fi

} > "$OUT_FILE"

echo "✅ Pre-analysis written to: $OUT_FILE"
