#!/usr/bin/env bash
# Rebuild every .riv in assets/rive/ from the generators in rive/tools/.
#   ./scripts/frive.sh            # all: avatar, every scene, the UI kit and the scene posters
#   ./scripts/frive.sh campfire   # avatar + UI kit + the named scenes (and their posters) only
# The UI kit (rive/ui_kit -> assets/rive/ui/ui_kit.riv) is always rebuilt: it takes under a second.
# Posters (assets/rive/posters/<sceneId>.webp) come from rive/tools/gen_posters.py (needs Pillow,
# pulled in through `uv run --with pillow`).
# Requires: rive CLI (>= 1.8.0) and uv on PATH. Deterministic: generators use fixed seeds and ids.
# Fails on any build warning, a size over budget (avatar 600 KB, scene 400 KB, UI kit 150 KB,
# poster 40 KB), or any name that differs from rive/CONTRACT.md (rive/tools/check_contract.py).
# Then runs the objective gates (rive/tools/rive_gates.py: parallax, plane travel, pointer proofs,
# rain and front-layer gates per built scene, then the tablet and newspaper prop gates); any FAIL
# fails the script. FRIVE_GATES=0 ./scripts/frive.sh skips them (sequential renders, minutes).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TOOLS="$ROOT/rive/tools"
OUT="$ROOT/assets/rive"
AVATAR_MAX=$((600 * 1024))
SCENE_MAX=$((400 * 1024))
UI_KIT_MAX=$((150 * 1024))

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
uv run "$TOOLS/gen_ui_kit.py" >/dev/null

echo "▸ building"
build "$ROOT/rive/avatar" "$OUT/avatar.riv" "$AVATAR_MAX"
for s in "${SCENES[@]}"; do
  build "$ROOT/rive/scenes/$s" "$OUT/scenes/$s.riv" "$SCENE_MAX"
done
build "$ROOT/rive/ui_kit" "$OUT/ui/ui_kit.riv" "$UI_KIT_MAX"
echo "▸ scene posters"
uv run --with pillow "$TOOLS/gen_posters.py" "${SCENES[@]}"
echo "▸ contract self-check"
uv run "$TOOLS/check_contract.py"
if [ "${FRIVE_GATES:-1}" != "0" ]; then
  echo "▸ gates (FRIVE_GATES=0 skips)"
  uv run --with pillow --with numpy "$TOOLS/rive_gates.py" "${SCENES[@]}"
fi
echo "✓ done"
