import 'package:flutter/material.dart';

import '../../../../core/design/components/components.dart';
import '../../../../core/design/design.dart';
import '../../../../core/l10n/generated/app_localizations.dart';
import '../../../sound/sound.dart';

/// First-run notice for the Kokoro voice, above the tool chip: while its
/// model downloads and installs (with the size and where it comes from),
/// or when the install failed (Retry). Hidden once ready, while the engine
/// only loads (later launches), and for the session once dismissed.
class StageVoiceNotice extends StatefulWidget {
  const StageVoiceNotice({super.key, this.engine});

  /// Null: no notice (tests, harnesses).
  final TtsEngineStatusService? engine;

  @override
  State<StageVoiceNotice> createState() => _StageVoiceNoticeState();
}

class _StageVoiceNoticeState extends State<StageVoiceNotice> {
  bool _dismissed = false;

  static bool _shows(TtsEngineStatus status) => switch (status) {
    TtsEngineDownloading() || TtsEngineExtracting() => true,
    TtsEngineFailed() => true,
    _ => false,
  };

  @override
  Widget build(BuildContext context) {
    final TtsEngineStatusService? engine = widget.engine;
    if (engine == null) return const SizedBox.shrink();
    final Duration duration = MediaQuery.disableAnimationsOf(context)
        ? AppMotion.fast
        : AppMotion.base;
    return StreamBuilder<TtsEngineStatus>(
      stream: engine.status,
      initialData: engine.current,
      builder: (BuildContext context, AsyncSnapshot<TtsEngineStatus> snap) {
        final TtsEngineStatus status = snap.data ?? engine.current;
        final bool shown = !_dismissed && _shows(status);
        return AnimatedSwitcher(
          duration: duration,
          switchInCurve: AppMotion.standard,
          switchOutCurve: AppMotion.standard,
          transitionBuilder: (Widget child, Animation<double> animation) =>
              FadeTransition(
                opacity: animation,
                child: SizeTransition(
                  sizeFactor: animation,
                  alignment: Alignment.bottomCenter,
                  child: child,
                ),
              ),
          child: shown
              ? _Notice(
                  key: const ValueKey<String>('voice-notice'),
                  status: status,
                  onRetry: engine.install,
                  onDismiss: () => setState(() => _dismissed = true),
                )
              : const SizedBox(
                  key: ValueKey<String>('no-voice-notice'),
                  width: double.infinity,
                ),
        );
      },
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({
    super.key,
    required this.status,
    required this.onRetry,
    required this.onDismiss,
  });

  final TtsEngineStatus status;
  final VoidCallback onRetry;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final TextTheme text = context.text;
    final bool failed = status is TtsEngineFailed;
    final double? progress = switch (status) {
      TtsEngineDownloading(:final double? progress) => progress,
      _ => null,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.sm),
      child: Semantics(
        liveRegion: true,
        child: GlassPanel(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.md,
            AppSpace.sm,
            AppSpace.xs,
            AppSpace.sm,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(
                    failed
                        ? Icons.error_outline
                        : Icons.record_voice_over_outlined,
                    size: 18,
                    color: failed
                        ? context.colors.error
                        : context.tokens.scene.accent,
                  ),
                  const SizedBox(width: AppSpace.sm),
                  Expanded(
                    child: Text(
                      '${l10n.ttsVoiceBannerTitle} · '
                      '${ttsVoiceStatusLabel(l10n, status)}',
                      maxLines: 2,
                      style: text.bodyMedium?.copyWith(
                        color: context.colors.onSurface,
                      ),
                    ),
                  ),
                  if (failed)
                    TextButton(
                      onPressed: onRetry,
                      child: Text(l10n.ttsVoiceRetry),
                    ),
                  IconButton(
                    onPressed: onDismiss,
                    tooltip: l10n.ttsVoiceDismiss,
                    icon: const Icon(Icons.close, size: 18),
                  ),
                ],
              ),
              if (!failed) ...<Widget>[
                const SizedBox(height: AppSpace.xs),
                LinearProgressIndicator(
                  value: status is TtsEngineExtracting ? null : progress,
                ),
              ],
              const SizedBox(height: AppSpace.xs),
              Padding(
                padding: const EdgeInsets.only(right: AppSpace.sm),
                child: Text(
                  '${l10n.ttsVoiceSource} ${l10n.ttsVoiceFallbackNote}',
                  maxLines: 3,
                  style: text.bodySmall?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
