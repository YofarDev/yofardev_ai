import '../../../core/l10n/failure_localization.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/models/failure.dart';
import '../domain/tts_engine_status.dart';

/// One line for [status] ("Downloading… 42%", "Ready, on this device", the
/// localized failure…).
String ttsVoiceStatusLabel(AppLocalizations l10n, TtsEngineStatus status) =>
    switch (status) {
      TtsEngineNotInstalled() => l10n.ttsVoiceNotInstalled,
      TtsEngineDownloading(:final double? progress) =>
        progress == null
            ? l10n.ttsVoiceDownloadingStarted
            : l10n.ttsVoiceDownloading((progress * 100).floor()),
      TtsEngineExtracting() => l10n.ttsVoiceExtracting,
      TtsEngineLoading() => l10n.ttsVoiceLoading,
      TtsEngineReady() => l10n.ttsVoiceReady,
      TtsEngineFailed(:final Failure failure) =>
        '${l10n.ttsVoiceFailed} · ${localizeFailure(l10n, failure)}',
    };
