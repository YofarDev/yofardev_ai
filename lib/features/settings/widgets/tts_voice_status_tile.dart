import 'package:flutter/material.dart';

import '../../../core/design/design.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../sound/sound.dart';

/// The Kokoro voice's install state in Settings: where the model comes
/// from, the download progress, and Download / Retry when it is not there.
class TtsVoiceStatusTile extends StatelessWidget {
  const TtsVoiceStatusTile({
    super.key,
    required this.status,
    required this.onInstall,
  });

  final TtsEngineStatus status;
  final VoidCallback onInstall;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final String? action = switch (status) {
      TtsEngineNotInstalled() => l10n.ttsVoiceDownload,
      TtsEngineFailed() => l10n.ttsVoiceRetry,
      _ => null,
    };
    final bool installing = switch (status) {
      TtsEngineDownloading() || TtsEngineExtracting() => true,
      TtsEngineLoading() => true,
      _ => false,
    };
    final double? progress = switch (status) {
      TtsEngineDownloading(:final double? progress) => progress,
      _ => null,
    };
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            context.tokens.glassSurface.withValues(alpha: 0.12),
            context.tokens.glassSurface.withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: context.tokens.glassBorder.withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: <Color>[
                      context.colors.tertiary.withValues(alpha: 0.2),
                      context.colors.tertiary.withValues(alpha: 0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.record_voice_over_outlined,
                  color: context.colors.tertiary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      l10n.ttsVoiceTitle,
                      style: text.titleMedium?.copyWith(
                        color: context.colors.onSurface,
                      ),
                    ),
                    Text(
                      ttsVoiceStatusLabel(l10n, status),
                      style: text.bodySmall?.copyWith(
                        color: status is TtsEngineFailed
                            ? context.colors.error
                            : context.colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (action != null)
                TextButton(onPressed: onInstall, child: Text(action)),
            ],
          ),
          if (installing) ...<Widget>[
            const SizedBox(height: 12),
            LinearProgressIndicator(value: progress),
          ],
          if (status is! TtsEngineReady) ...<Widget>[
            const SizedBox(height: 12),
            Text(
              l10n.ttsVoiceSource,
              style: text.bodySmall?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
            Text(
              l10n.ttsVoiceFallbackNote,
              style: text.bodySmall?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
