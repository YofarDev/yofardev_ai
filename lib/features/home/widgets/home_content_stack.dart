import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/design/design.dart';
import '../../../core/design/rive/ui_kit.dart';
import '../../../core/models/talking_phase.dart';
import '../../../core/services/speech/speech_input_service.dart';
import '../../avatar/avatar.dart';
import '../../chat/chat.dart';
import '../../talking/talking.dart';
import 'stage/stage_caption.dart';
import 'stage/stage_composer.dart';
import 'stage/stage_scrim.dart';
import 'stage/stage_tool_chip.dart';
import 'stage/stage_top_bar.dart';

/// Home's "Stage": the Rive scene with the avatar on it, and the chrome
/// drawn over them:
///
/// - top and bottom scrims, so the chrome stays legible on bright scenes;
/// - the History / More chips on top ([StageTopBar]);
/// - the [StatusGlow] behind the composer, shaped by the talking phase;
/// - at the bottom, above the keyboard or the system bar: the running-tool
///   chip, the live caption and the [StageComposer].
///
/// [speech] goes to the composer; [onStartDemo] to the More menu.
class HomeContentStack extends StatefulWidget {
  const HomeContentStack({
    super.key,
    required this.speech,
    required this.onStartDemo,
  });

  final SpeechInputService speech;
  final VoidCallback onStartDemo;

  /// The glow's width, relative to the composer pill (the art fills about
  /// 85% of its box).
  static const double glowWidthFactor = 1.3;

  @override
  State<HomeContentStack> createState() => _HomeContentStackState();
}

class _HomeContentStackState extends State<HomeContentStack> {
  /// The composer's mode, for the caption (which hides while it listens or
  /// thinks) without rebuilding the rest of the stage.
  final ValueNotifier<ComposerOrbState> _composerMode =
      ValueNotifier<ComposerOrbState>(ComposerOrbState.idle);

  @override
  void dispose() {
    _composerMode.dispose();
    super.dispose();
  }

  void _onComposerMode(ComposerOrbState mode) => _composerMode.value = mode;

  @override
  Widget build(BuildContext context) {
    final EdgeInsets padding = MediaQuery.paddingOf(context);
    final double keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final double bottom = math.max(keyboard, padding.bottom) + AppSpace.md;
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        BlocBuilder<AvatarCubit, AvatarState>(
          builder: (BuildContext context, AvatarState avatarState) {
            return Stack(
              fit: StackFit.expand,
              children: <Widget>[
                RiveSceneView(
                  scene: avatarState.scene,
                  sceneEvent: avatarState.sceneEvent,
                  onPropTapped: (String propId) {
                    context.read<AvatarCubit>().onPropTapped(
                      avatarState.scene,
                      propId,
                    );
                  },
                ),
                // Narrow scope: only the avatar view depends on the whole
                // TalkingState (mouth + phase); a mouth change must not
                // rebuild the scene view, the glow or the chrome.
                BlocBuilder<TalkingCubit, TalkingState>(
                  builder: (BuildContext context, TalkingState talkingState) {
                    return RiveAvatarView(
                      avatarState: avatarState,
                      talkingState: talkingState,
                      onAvatarTapped: (String zone) {
                        context.read<AvatarCubit>().onAvatarTapped(zone);
                      },
                      onPresenceDone: (String presence) {
                        context.read<AvatarCubit>().onPresenceDone(presence);
                      },
                    );
                  },
                ),
              ],
            );
          },
        ),
        const StageScrim.top(),
        // Lifted with the keyboard, so it stays behind the caption.
        Positioned.fill(bottom: keyboard, child: const StageScrim.bottom()),
        _GlowLayer(bottom: bottom),
        Positioned(
          top: padding.top + AppSpace.sm,
          left: AppSpace.lg,
          right: AppSpace.sm,
          child: StageTopBar(onStartDemo: widget.onStartDemo),
        ),
        Positioned(
          left: AppSpace.lg,
          right: AppSpace.lg,
          bottom: bottom,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const StageToolChip(),
              StageCaption(composerMode: _composerMode),
              _Composer(speech: widget.speech, onModeChanged: _onComposerMode),
            ],
          ),
        ),
      ],
    );
  }
}

/// The [StatusGlow], centred on the composer pill and
/// [HomeContentStack.glowWidthFactor] times as wide.
class _GlowLayer extends StatelessWidget {
  const _GlowLayer({required this.bottom});

  /// Distance from the stage's bottom edge to the composer pill's.
  final double bottom;

  /// The artboard's aspect (480×200).
  static const double _aspect = 2.4;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double pillWidth = math.max(
          0,
          constraints.maxWidth - AppSpace.lg * 2,
        );
        final double width = pillWidth * HomeContentStack.glowWidthFactor;
        final double height = width / _aspect;
        return Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            Positioned(
              left: (constraints.maxWidth - width) / 2,
              width: width,
              bottom: bottom + StageComposer.height / 2 - height / 2,
              height: height,
              child: BlocSelector<TalkingCubit, TalkingState, TalkingPhase>(
                selector: (TalkingState state) => state.phase,
                builder: (BuildContext context, TalkingPhase phase) =>
                    StatusGlow(phase: phase),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The composer once the chat is loaded; until then, its height in empty
/// space, so the caption above doesn't jump.
class _Composer extends StatelessWidget {
  const _Composer({required this.speech, required this.onModeChanged});

  final SpeechInputService speech;
  final ValueChanged<ComposerOrbState> onModeChanged;

  @override
  Widget build(BuildContext context) {
    final bool initializing = context.select<ChatCubit, bool>(
      (ChatCubit cubit) => cubit.state.initializing,
    );
    if (initializing) {
      return const SizedBox(height: StageComposer.height);
    }
    return StageComposer(speech: speech, onModeChanged: onModeChanged);
  }
}
