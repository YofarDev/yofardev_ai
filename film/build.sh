#!/bin/bash
# Builds the film from the captures in work/cap (film/capture_all.sh):
#   film/build.sh            # everything
#   film/build.sh render     # only the score/mix/render/mux steps
set -euo pipefail
cd "$(dirname "$0")"
PY="uv run --with numpy --with pillow --with soundfile --with scipy --with pedalboard --with pyloudnorm python -I"
if [ "${1:-}" != "render" ]; then
  for mov in work/cap/*.mov; do
    tag=$(basename "$mov" .mov)
    [ -d "work/cap/$tag" ] || continue
    [ "$tag" = test_land ] && continue
    if [ ! -f "work/clips/$tag.json" ] || [ "$mov" -nt "work/clips/$tag.json" ]; then
      echo "== sync $tag"; $PY tools/sync.py "$tag" | tail -3
      $PY tools/runaudio.py "$tag" | tail -2
    fi
  done
  python3 tools/events.py
fi
(cd video && npx -y tsx scripts/sections.ts > ../music/sections.json && npx -y tsx scripts/edl.ts > ../work/edl.json)
(cd music && uv run --with pretty_midi --with numpy python compose.py | tail -1 \
  && uv run --with pedalboard --with soundfile --with numpy --with pyloudnorm python mix.py | head -1)
$PY tools/mixfilm.py
mkdir -p out
(cd video && npx remotion render Film ../work/film_video.mp4 --codec=h264 --crf=14 --muted \
  --concurrency=6 --log=error)
ffmpeg -loglevel error -y -i work/film_video.mp4 -i work/soundtrack.wav -map 0:v -map 1:a \
  -c:v copy -c:a aac -b:a 320k -movflags +faststart -shortest out/yofardev-ai-film.mp4
echo "== out/yofardev-ai-film.mp4"; ffprobe -v error -show_entries format=duration,size -of default=nw=1 out/yofardev-ai-film.mp4
