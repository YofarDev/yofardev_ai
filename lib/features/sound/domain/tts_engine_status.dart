import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/models/failure.dart';

part 'tts_engine_status.freezed.dart';

/// Lifecycle of the on-device Kokoro voice: the one-time model download, its
/// extraction, the engine load, then ready (or failed, with a typed cause).
@freezed
sealed class TtsEngineStatus with _$TtsEngineStatus {
  const factory TtsEngineStatus.notInstalled() = TtsEngineNotInstalled;

  /// [progress] in 0..1, or null while the size is unknown.
  const factory TtsEngineStatus.downloading(double? progress) =
      TtsEngineDownloading;
  const factory TtsEngineStatus.extracting() = TtsEngineExtracting;
  const factory TtsEngineStatus.loading() = TtsEngineLoading;
  const factory TtsEngineStatus.ready() = TtsEngineReady;
  const factory TtsEngineStatus.failed(Failure failure) = TtsEngineFailed;
}
