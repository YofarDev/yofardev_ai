import 'kokoro_engine.dart';
import 'sherpa_kokoro_engine_stub.dart'
    if (dart.library.ffi) 'sherpa_kokoro_engine.dart';

/// sherpa-onnx where `dart:ffi` exists, an engine that never loads on web.
KokoroEngine createKokoroEngine() => createPlatformKokoroEngine();
