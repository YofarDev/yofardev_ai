import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/design.dart';
import '../../../../core/design/rive/ui_kit.dart';
import '../../../../core/l10n/generated/app_localizations.dart';
import '../../../talking/talking.dart';
import 'stage_line.dart';

/// The live caption: the sentence the avatar is speaking, as large display
/// type above the composer.
///
/// Shown when captions are on and the composer is not listening or
/// thinking ([composerMode]): the caption is the character's last line,
/// not something to read while it hears or prepares a new one. Each new
/// sentence ([CaptionState.seq]) fades in; a tap turns captions off.
class StageCaption extends StatelessWidget {
  const StageCaption({super.key, required this.composerMode});

  final ValueListenable<ComposerOrbState> composerMode;

  static const Key lineKey = ValueKey<String>('stage-caption-line');

  /// Whether the caption steps aside while the composer is in [mode].
  static bool hiddenDuring(ComposerOrbState mode) =>
      mode == ComposerOrbState.listening || mode == ComposerOrbState.thinking;

  @override
  Widget build(BuildContext context) {
    final Duration duration = MediaQuery.disableAnimationsOf(context)
        ? AppMotion.fast
        : AppMotion.slow;
    return ValueListenableBuilder<ComposerOrbState>(
      valueListenable: composerMode,
      builder: (BuildContext context, ComposerOrbState mode, Widget? _) =>
          BlocBuilder<CaptionCubit, CaptionState>(
            builder: (BuildContext context, CaptionState state) {
              final String? text = state.enabled && !hiddenDuring(mode)
                  ? state.text
                  : null;
              return AnimatedSize(
                duration: duration,
                curve: AppMotion.standard,
                alignment: Alignment.bottomCenter,
                child: AnimatedSwitcher(
                  duration: duration,
                  switchInCurve: AppMotion.standard,
                  switchOutCurve: AppMotion.standard,
                  layoutBuilder: (Widget? current, List<Widget> previous) =>
                      Stack(
                        alignment: AlignmentDirectional.bottomStart,
                        children: <Widget>[...previous, ?current],
                      ),
                  transitionBuilder:
                      (Widget child, Animation<double> animation) =>
                          FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0, 0.12),
                                end: Offset.zero,
                              ).animate(animation),
                              child: child,
                            ),
                          ),
                  child: text == null || text.isEmpty
                      ? const SizedBox(
                          key: ValueKey<String>('no-caption'),
                          width: double.infinity,
                        )
                      : _CaptionLine(key: ValueKey<int>(state.seq), text: text),
                ),
              );
            },
          ),
    );
  }
}

class _CaptionLine extends StatelessWidget {
  const _CaptionLine({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      liveRegion: true,
      onTapHint: AppLocalizations.of(context).stageHideCaptions,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => context.read<CaptionCubit>().toggle(),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.sm,
              0,
              AppSpace.xxl,
              AppSpace.lg,
            ),
            child: Align(
              alignment: AlignmentDirectional.bottomStart,
              heightFactor: 1,
              child: StageLine(
                key: StageCaption.lineKey,
                text: text,
                style: context.text.headlineSmall?.copyWith(height: 1.22),
                align: TextAlign.start,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
