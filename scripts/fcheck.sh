#!/bin/bash
# =============================================================================
# fcheck.sh — check for potentially unused pubspec dependencies.
#
# Compares declared dependencies against `import 'package:...'` usage in lib/.
# Heuristic only: a package with zero imports in lib/ is flagged for review,
# NOT proven removable — codegen companions and SDK packages may be required
# even when nothing imports them directly.
#
# Companion pairs (annotation package + its generator) are never advised for
# removal when the generator is present:
#   freezed_annotation -> freezed, json_annotation -> json_serializable
#
# Usage:
#   ./fcheck.sh                  # check all dependencies
#   ./fcheck.sh <package_name>   # show where a specific package is imported
# =============================================================================

# Codegen annotation packages: keep them while their generator is declared.
# value -> packages that justify keeping it
COMPANIONS="freezed_annotation:freezed json_annotation:json_serializable"

# Check if pubspec.yaml exists in current directory
if [ ! -f "pubspec.yaml" ]; then
    echo "❌ Error: pubspec.yaml not found in current directory"
    echo "Please run this script from a Flutter project root directory"
    exit 1
fi

# Check if lib/ directory exists
if [ ! -d "lib" ]; then
    echo "❌ Error: lib/ directory not found"
    echo "Please run this script from a Flutter project root directory"
    exit 1
fi

companion_is_required() {
    # $1 = annotation package name
    for pair in $COMPANIONS; do
        ANNOTATION="${pair%%:*}"
        GENERATOR="${pair##*:}"
        if [ "$1" = "$ANNOTATION" ] && grep -qE "^  $GENERATOR:" pubspec.yaml; then
            return 0
        fi
    done
    return 1
}

# If argument provided, check specific package
if [ ! -z "$1" ]; then
    PACKAGE_NAME="$1"
    echo "🔍 Checking if '$PACKAGE_NAME' is used in lib/..."
    echo ""

    if grep -r "import 'package:$PACKAGE_NAME" lib/ > /dev/null 2>&1; then
        echo "✅ Package '$PACKAGE_NAME' IS used"
        echo ""
        echo "Found in:"
        grep -rn "import 'package:$PACKAGE_NAME" lib/ | sed 's/:/ - line /'
    else
        echo "❌ Package '$PACKAGE_NAME' is NOT directly imported in lib/"
        echo ""
        if companion_is_required "$PACKAGE_NAME"; then
            echo "⚠️  But it is a codegen companion — its generator uses it. KEEP it."
        else
            echo "Review indirect usage, exports, code generation, assets and platform channels before changing this dependency."
            echo "This scan does not establish that the package is removable."
        fi
    fi
    exit 0
fi

# If no argument, check all dependencies
echo "=== Checking for unused dependencies ==="
echo ""

# Get ONLY regular dependencies from pubspec.yaml using awk.
# This strictly extracts the `dependencies:` block and inherently ignores `dev_dependencies`
DECLARED=$(awk '
    /^dependencies:/ { in_deps=1; next }
    /^[a-zA-Z_-]+:/ { in_deps=0 }
    in_deps && /^  [a-zA-Z0-9_-]+:/ { print $1 }
' pubspec.yaml | tr -d ':' | grep -vE "^(flutter|cupertino_icons)$")

# Get actually imported packages from lib/
IMPORTED=$(grep -rh "import 'package:" lib/ 2>/dev/null | grep -o "package:[^/]*" | sed 's/package://g' | sort -u)

UNUSED_COUNT=0
USED_COUNT=0
KEPT_COUNT=0

echo "📦 Dependencies not directly imported in lib/:"
echo ""
for dep in $DECLARED; do
    if ! echo "$IMPORTED" | grep -q "^$dep$"; then
        if companion_is_required "$dep"; then
            echo "  🔒 $dep — codegen companion (generator declared), KEEP"
            ((KEPT_COUNT++))
        else
            echo "  ❌ $dep"
            ((UNUSED_COUNT++))
        fi
    else
        ((USED_COUNT++))
    fi
done

if [ $UNUSED_COUNT -eq 0 ] && [ $KEPT_COUNT -eq 0 ]; then
    echo "  (none - all dependencies are being used!)"
fi

echo ""
echo "📊 Summary:"
echo "  Used: $USED_COUNT"
echo "  Unused (review): $UNUSED_COUNT"
[ $KEPT_COUNT -gt 0 ] && echo "  Codegen companions kept: $KEPT_COUNT"
echo ""
echo "💡 Tip: Run with a package name to see where it's used:"
echo "   $(basename "$0") package_name"
