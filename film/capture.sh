#!/bin/bash
# Records one harness run of the real macOS app with a 60 fps screen capture
# of the second display, plus sparse in-app grabs (for sync) and the
# timeline / Kokoro WAVs.
#   film/capture.sh <WOW> <W> <H> [more --dart-define=... args]
# W x H = window CONTENT size (logical px); the title bar (28) is added.
set -u
cd "$(dirname "$0")/.."
WOW=$1; W=$2; H=$3; shift 3
OUT="$PWD/film/work/cap"
mkdir -p "$OUT"
TAG="${TAG:-$WOW}"
X=$((1920 + (1920 - W) / 2)); Y=25
REC="$OUT/${TAG}.mov"
rm -f "$REC"
ffmpeg -loglevel error -y -f avfoundation -capture_cursor 0 -framerate 60 \
  -pixel_format nv12 -i "2:none" -c:v h264_videotoolbox -b:v 80M -realtime 1 \
  "$REC" < /dev/null > "$OUT/${TAG}.ffmpeg.log" 2>&1 &
FF=$!
# wait for frames to flow (a busy screen device never opens)
for i in $(seq 1 40); do
  [ -f "$REC" ] && [ "$(stat -f %z "$REC")" -gt 200000 ] && break
  sleep 0.5
done
if ! [ -f "$REC" ] || [ "$(stat -f %z "$REC")" -le 200000 ]; then
  echo "REC FAILED: no frames from the screen capture"; kill -9 $FF 2>/dev/null; exit 1
fi
perl -MTime::HiRes -e 'printf "%d\n", Time::HiRes::time()*1000' > "$OUT/${TAG}.recstart"
flutter test integration_test/wow_capture_test.dart -d macos \
  --dart-define=WOW=$WOW --dart-define=TIER=ultra --dart-define=VOICE=kokoro \
  --dart-define=PXR=0.25 --dart-define=GRAB_MS=250 --dart-define=FRONT=true --dart-define=FILM_OUTFIT=true \
  "--dart-define=WIN_POS={$X,$Y}" "--dart-define=WIN_SIZE={$W,$((H + 28))}" \
  "--dart-define=KOKORO_SRC=$HOME/Library/Application Support/fr.yofardev.yofardevAi/tts" \
  "--dart-define=SHOW_OUT=$OUT/$TAG" "$@" 2>&1 | tee "$OUT/${TAG}.test.log" | \
  grep -E "LIVENESS|WOW_DIR|All tests passed|Some tests failed|EXCEPTION|Error:" | head -8
kill -INT $FF
for i in $(seq 1 20); do kill -0 $FF 2>/dev/null || break; sleep 0.5; done
kill -9 $FF 2>/dev/null; wait $FF 2>/dev/null
echo "REC $REC $(du -h "$REC" | cut -f1)"
