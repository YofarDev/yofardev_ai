#!/bin/bash
# Every film beat, one after another (~35 min). Display 2 must be free.
cd "$(dirname "$0")/.."
for run in film_wardrobe wow3 film_goodnight wow1 tour; do
  echo "=== $run"; film/capture.sh $run 576 1024
done
for s in livingRoom campfire beach deepSpace cafe rooftop mountainHut forestCabin trainCompartment library; do
  echo "=== scene $s"; TAG=scene_$s film/capture.sh scene 576 1024 --dart-define=SCENE=$s
done
echo "=== all captures done"
  echo '=== wow3 retake'; film/capture.sh wow3 576 1024
