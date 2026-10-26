# Frame-timing capture

Prints build/raster percentiles from a running **profile-mode** Flutter app.

```bash
flutter run -d <device> --profile          # note the "Dart VM Service ... http://127.0.0.1:PORT/TOKEN/" line
cd scripts/perf && dart pub get
dart run bin/frames.dart ws://127.0.0.1:PORT/TOKEN/ws 10 home-idle
```

Arguments: VM service websocket URI, seconds to record, label. The first 2 s are
discarded (the stream replays buffered frames on connect). Frames over 16.7 ms count as
jank, so on a 75/120 Hz display read the percentiles, not the jank count.
