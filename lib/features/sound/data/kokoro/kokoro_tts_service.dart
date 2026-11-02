import 'dart:async';

import '../../../../core/errors/exception_mapper.dart';
import '../../../../core/models/failure.dart';
import '../../../../core/utils/logger.dart';
import '../../domain/services/tts_engine_status_service.dart';
import '../../domain/tts_engine_status.dart';
import 'kokoro_engine.dart';
import 'kokoro_model_paths.dart';
import 'kokoro_model_store.dart';
import 'voice_blender.dart';

/// Installs the Kokoro model and loads the engine, publishing each step.
class KokoroTtsService implements TtsEngineStatusService {
  KokoroTtsService({
    required KokoroModelStore store,
    required KokoroEngine engine,
    required VoiceBlender voiceBlender,
  }) : _store = store,
       _engine = engine,
       _voiceBlender = voiceBlender;

  final KokoroModelStore _store;
  final KokoroEngine _engine;
  final VoiceBlender _voiceBlender;
  final StreamController<TtsEngineStatus> _controller =
      StreamController<TtsEngineStatus>.broadcast();

  TtsEngineStatus _current = const TtsEngineStatus.notInstalled();
  Future<void>? _inFlight;

  @override
  TtsEngineStatus get current => _current;

  @override
  Stream<TtsEngineStatus> get status => _controller.stream;

  @override
  Future<void> install() {
    if (_current is TtsEngineReady) return Future<void>.value();
    return _inFlight ??= _install().whenComplete(() => _inFlight = null);
  }

  Future<void> _install() async {
    final KokoroModelPaths paths;
    try {
      paths = await _store.install(onStatus: _emit);
    } on ModelDownloadException catch (e) {
      AppLogger.error(
        'Kokoro download failed',
        tag: 'KokoroTtsService',
        error: e,
      );
      _emit(TtsEngineStatus.failed(NetworkFailure(e.message, e)));
      return;
    } on ModelLayoutException catch (e) {
      AppLogger.error(
        'Kokoro model incomplete',
        tag: 'KokoroTtsService',
        error: e,
      );
      _emit(TtsEngineStatus.failed(StorageFailure(e.message, e)));
      return;
    } catch (e, st) {
      _emit(
        TtsEngineStatus.failed(
          mapExceptionToFailure(e, stackTrace: st, tag: 'KokoroTtsService'),
        ),
      );
      return;
    }
    try {
      _emit(const TtsEngineStatus.loading());
      await _voiceBlender.apply(paths);
      await _engine.load(paths);
      AppLogger.info('Kokoro voice ready', tag: 'KokoroTtsService');
      _emit(const TtsEngineStatus.ready());
    } catch (e, st) {
      AppLogger.error(
        'Kokoro voice failed to load',
        tag: 'KokoroTtsService',
        error: e,
        stackTrace: st,
      );
      _emit(TtsEngineStatus.failed(TtsFailure('voice load failed', e)));
    }
  }

  void _emit(TtsEngineStatus status) {
    _current = status;
    if (!_controller.isClosed) _controller.add(status);
  }

  Future<void> dispose() => _controller.close();
}
