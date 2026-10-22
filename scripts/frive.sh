#!/usr/bin/env bash
# Rebuild every .riv in assets/rive/ from the generators in rive/tools/.
#   ./scripts/frive.sh            # all
#   ./scripts/frive.sh campfire   # avatar + the named scenes only
# Requires: rive CLI (>= 1.7.0) and uv on PATH. Deterministic: generators use fixed seeds and ids.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TOOLS="$ROOT/rive/tools"
OUT="$ROOT/assets/rive"
AVATAR_MAX=$((600 * 1024))
SCENE_MAX=$((400 * 1024))

SCENES=("$@")
if [ ${#SCENES[@]} -eq 0 ]; then
  SCENES=()
  for d in "$ROOT"/rive/scenes/*/; do SCENES+=("$(basename "$d")"); done
fi

build() { # <project dir> <dest .riv> <max bytes>
  local dir="$1" dest="$2" max="$3" name
  name="$(basename "$dir")"
  mkdir -p "$dir/build"; rive "$dir" --once >/dev/null 2>"$dir/build/frive.log" || { cat "$dir/build/frive.log"; echo "✗ build failed: $name"; exit 1; }
  if grep -qE "[1-9][0-9]* (errors|warnings)" "$dir/build/frive.log"; then
    cat "$dir/build/frive.log"; echo "✗ $name built with errors/warnings"; exit 1
  fi
  mkdir -p "$(dirname "$dest")"
  cp "$dir/build/$name.riv" "$dest"
  local size
  size=$(wc -c <"$dest" | tr -d ' ')
  if [ "$size" -gt "$max" ]; then echo "✗ $dest is $size bytes (budget $max)"; exit 1; fi
  echo "✓ $(basename "$dest")  ${size} B"
}

echo "▸ generating RML"
uv run "$TOOLS/gen_avatar.py" >/dev/null
uv run "$TOOLS/gen_scenes.py" "${SCENES[@]}" >/dev/null

echo "▸ building"
build "$ROOT/rive/avatar" "$OUT/avatar.riv" "$AVATAR_MAX"
for s in "${SCENES[@]}"; do
  build "$ROOT/rive/scenes/$s" "$OUT/scenes/$s.riv" "$SCENE_MAX"
done
echo "✓ done"
