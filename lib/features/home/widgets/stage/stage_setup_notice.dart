import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/components/components.dart';
import '../../../../core/design/design.dart';
import '../../../../core/l10n/generated/app_localizations.dart';
import '../../../../core/router/route_constants.dart';
import '../../../../core/services/llm/llm_service_interface.dart';

/// "Connect an AI" notice above the composer while no LLM configuration
/// exists: what is missing, and a button straight to the new-config form.
/// It slides in once the stored configurations are known to be empty, goes
/// away by itself once one is saved, and for the session once dismissed.
/// Its key icon breathes gently (still under reduce motion).
class StageSetupNotice extends StatefulWidget {
  const StageSetupNotice({super.key, this.llm});

  /// Null: no notice (tests, harnesses).
  final LlmServiceInterface? llm;

  @override
  State<StageSetupNotice> createState() => _StageSetupNoticeState();
}

class _StageSetupNoticeState extends State<StageSetupNotice> {
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(StageSetupNotice oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.llm != oldWidget.llm) {
      _load();
    }
  }

  /// The configurations load lazily (first chat or Settings): read them now
  /// so the notice knows whether to show.
  void _load() {
    final LlmServiceInterface? llm = widget.llm;
    if (llm != null && llm.configured.value == null) {
      unawaited(llm.init());
    }
  }

  @override
  Widget build(BuildContext context) {
    final LlmServiceInterface? llm = widget.llm;
    if (llm == null) return const SizedBox.shrink();
    final bool reduceMotion = MediaQuery.disableAnimationsOf(context);
    final Duration duration = reduceMotion ? AppMotion.fast : AppMotion.slow;
    return ValueListenableBuilder<bool?>(
      valueListenable: llm.configured,
      builder: (BuildContext context, bool? configured, Widget? _) {
        final bool shown = !_dismissed && configured == false;
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
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: Offset(0, reduceMotion ? 0 : 0.25),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                ),
              ),
          child: shown
              ? _Notice(
                  key: const ValueKey<String>('llm-setup-notice'),
                  breathe: !reduceMotion,
                  onSetUp: () =>
                      unawaited(context.push(RouteConstants.newLlmConfig)),
                  onDismiss: () => setState(() => _dismissed = true),
                )
              : const SizedBox(
                  key: ValueKey<String>('no-llm-setup-notice'),
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
    required this.breathe,
    required this.onSetUp,
    required this.onDismiss,
  });

  final bool breathe;
  final VoidCallback onSetUp;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final TextTheme text = context.text;
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
                  _BreathingKey(animate: breathe),
                  const SizedBox(width: AppSpace.sm),
                  Expanded(
                    child: Text(
                      l10n.llmSetupTitle,
                      maxLines: 2,
                      style: text.bodyMedium?.copyWith(
                        color: context.colors.onSurface,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: onDismiss,
                    tooltip: l10n.llmSetupDismiss,
                    icon: const Icon(Icons.close, size: 18),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(right: AppSpace.sm),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        l10n.llmSetupBody,
                        maxLines: 3,
                        style: text.bodySmall?.copyWith(
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpace.sm),
                    FilledButton(
                      onPressed: onSetUp,
                      child: Text(l10n.llmSetupAction),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The key icon in the scene's accent, with a slow glow pulse behind it.
class _BreathingKey extends StatefulWidget {
  const _BreathingKey({required this.animate});

  final bool animate;

  @override
  State<_BreathingKey> createState() => _BreathingKeyState();
}

class _BreathingKeyState extends State<_BreathingKey>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(_BreathingKey oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate != oldWidget.animate) _sync();
  }

  void _sync() {
    if (widget.animate) {
      unawaited(_pulse.repeat(reverse: true));
    } else {
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ScenePalette scene = context.tokens.scene;
    return SizedBox.square(
      dimension: 28,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (BuildContext context, Widget? child) {
          final double t = Curves.easeInOut.transform(_pulse.value);
          return DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scene.accent.withValues(alpha: 0.12 + 0.10 * t),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: scene.glow.withValues(alpha: 0.35 * t),
                  blurRadius: 4 + 8 * t,
                ),
              ],
            ),
            child: child,
          );
        },
        child: Icon(Icons.key_rounded, size: 16, color: scene.accent),
      ),
    );
  }
}
