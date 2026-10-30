import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/design/design.dart';
import '../../../core/design/rive/ui_kit.dart';
import '../../../core/models/avatar_scene.dart';
import '../../../core/models/talking_phase.dart';
import '../../../core/services/motion/parallax_source.dart';
import '../../../core/services/world/world_state_service.dart';
import '../../../core/services/presence/composer_activity_service.dart';
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
/// [speech] and [composerActivity] go to the composer; [onStartDemo] to the
/// More menu. [parallax] feeds the scene's depth planes, and hears the
/// pointer's position over the stage (hover, on desktop and web).
class HomeContentStack extends StatefulWidget {
  const HomeContentStack({
    super.key,
    required this.speech,
    this.composerActivity,
    this.parallax,
    this.world,
    this.facePerformer,
    this.camera,
    required this.onStartDemo,
  });

  final SpeechInputService speech;
  final ComposerActivityService? composerActivity;
  final ParallaxSource? parallax;

  /// The world the scene shows: its rain and time of day (null: dry, night).
  final WorldStateService? world;

  /// Drives the avatar's face and speech (null: static mood faces).
  final FacePerformer? facePerformer;

  /// Frames the Rive stage, chrome excluded (null: always the whole stage).
  final CameraDirector? camera;
  final VoidCallback onStartDemo;

  /// The glow's width, relative to the composer pill (the art fills about
  /// 85% of its box).
  static const double glowWidthFactor = 1.3;

  /// The glow's largest box (wide windows), at most 1.5× the artboard.
  static const Size glowMaxSize = Size(720, 240);

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

  /// Reports the hover position as -1..1 (0 at the centre, +y up). No
  /// rebuild: it only feeds the parallax source.
  void _onHover(PointerEvent event) {
    final RenderObject? box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize || box.size.isEmpty) {
      return;
    }
    final Size size = box.size;
    widget.parallax?.pointer(
      Offset(
        event.localPosition.dx / size.width * 2 - 1,
        1 - event.localPosition.dy / size.height * 2,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // No MediaQuery read here: the keyboard and the safe area only move the
    // chrome (the slots below), never the Rive views.
    final Widget stack = Stack(
      fit: StackFit.expand,
      children: <Widget>[
        _CameraStage(
          camera: widget.camera,
          child: _RiveStage(
            facePerformer: widget.facePerformer,
            parallax: widget.parallax,
            world: widget.world,
          ),
        ),
        const StageScrim.top(),
        _TopBarSlot(
          onStartDemo: widget.onStartDemo,
          onTouch: widget.composerActivity?.touch,
        ),
        _BottomChrome(
          composerMode: _composerMode,
          onComposerMode: _onComposerMode,
          speech: widget.speech,
          composerActivity: widget.composerActivity,
        ),
      ],
    );
    final ParallaxSource? parallax = widget.parallax;
    if (parallax == null) {
      return stack;
    }
    return MouseRegion(
      opaque: false,
      onHover: _onHover,
      onExit: (PointerEvent _) => parallax.pointer(Offset.zero),
      child: stack,
    );
  }
}

/// Puts [child] (the Rive stage, never the chrome) behind the [camera]'s
/// [StageCamera], and feeds the director what only the widget tree knows:
/// the user's reduce-motion setting and the talking phase. Without a
/// [camera] it is [child] itself.
class _CameraStage extends StatefulWidget {
  const _CameraStage({required this.camera, required this.child});

  final CameraDirector? camera;
  final Widget child;

  @override
  State<_CameraStage> createState() => _CameraStageState();
}

class _CameraStageState extends State<_CameraStage> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    widget.camera?.setReduceMotion(MediaQuery.disableAnimationsOf(context));
  }

  @override
  void didUpdateWidget(_CameraStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.camera != oldWidget.camera) {
      widget.camera?.setReduceMotion(MediaQuery.disableAnimationsOf(context));
    }
  }

  @override
  Widget build(BuildContext context) {
    final CameraDirector? camera = widget.camera;
    if (camera == null) {
      return widget.child;
    }
    return MultiBlocListener(
      listeners: <BlocListener<dynamic, dynamic>>[
        BlocListener<TalkingCubit, TalkingState>(
          listenWhen: (TalkingState previous, TalkingState current) =>
              previous.phase != current.phase,
          listener: (BuildContext context, TalkingState state) =>
              camera.setPhase(state.phase),
        ),
        // A journey holds the camera wide (M7 ruling 3.2).
        BlocListener<AvatarCubit, AvatarState>(
          listenWhen: (AvatarState previous, AvatarState current) =>
              (previous.journey == null) != (current.journey == null),
          listener: (BuildContext context, AvatarState state) =>
              camera.setJourney(state.journey != null),
        ),
      ],
      child: StageCamera(shot: camera.shot, child: widget.child),
    );
  }
}

/// The Rive scene with the avatar on it. Const and free of MediaQuery, so
/// keyboard, inset and theme changes never rebuild it.
class _RiveStage extends StatelessWidget {
  const _RiveStage({this.facePerformer, this.parallax, this.world});

  final FacePerformer? facePerformer;
  final ParallaxSource? parallax;

  /// The weather and the time of day (null: dry, night).
  final WorldStateService? world;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AvatarCubit, AvatarState>(
      builder: (BuildContext context, AvatarState avatarState) {
        return RiveSceneView(
          scene: avatarState.scene,
          sceneEvent: avatarState.sceneEvent,
          parallax: parallax,
          rain: world?.rain,
          daylight: world?.daylight,
          dusk: world?.dusk,
          onPropTapped: (String propId) {
            context.read<AvatarCubit>().onPropTapped(avatarState.scene, propId);
          },
          // M7 journeys: the destination decodes during the walk-off, and
          // the cut waits for it on screen.
          preload: avatarState.preloadScene,
          onSceneShown: (AvatarScene scene) {
            context.read<AvatarCubit>().onSceneShown(scene);
          },
          // The avatar, between the scene and its front weather (v9).
          // Narrow scope: only the avatar view depends on the whole
          // TalkingState (mouth + phase); a mouth change must not rebuild
          // the scene view, the glow or the chrome.
          middle: JourneyLayer(
            journey: avatarState.journey,
            daylight: world?.daylight,
            avatar: BlocBuilder<TalkingCubit, TalkingState>(
              // with a face performer the mouth comes from it, not from
              // mouthState: only the phase matters here
              buildWhen: (TalkingState previous, TalkingState current) =>
                  facePerformer == null || previous.phase != current.phase,
              builder: (BuildContext context, TalkingState talkingState) {
                return RiveAvatarView(
                  avatarState: avatarState,
                  talkingState: talkingState,
                  facePerformer: facePerformer,
                  daylight: world?.daylight,
                  onAvatarTapped: (String zone) {
                    context.read<AvatarCubit>().onAvatarTapped(zone);
                  },
                  onPresenceDone: (String presence) {
                    context.read<AvatarCubit>().onPresenceDone(presence);
                  },
                  onGestureDone: () {
                    context.read<AvatarCubit>().onGestureDone();
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }
}

/// The History / More chips, below the top safe area.
class _TopBarSlot extends StatelessWidget {
  const _TopBarSlot({required this.onStartDemo, this.onTouch});

  final VoidCallback onStartDemo;
  final VoidCallback? onTouch;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.paddingOf(context).top + AppSpace.sm,
      left: AppSpace.lg,
      right: AppSpace.sm,
      child: StageTopBar(onStartDemo: onStartDemo, onTouch: onTouch),
    );
  }
}

/// Everything that rides on the keyboard: the bottom scrim, the glow and
/// the column (tool chip, caption, composer), lifted by
/// `max(keyboard, bottom safe area) + md`.
class _BottomChrome extends StatelessWidget {
  const _BottomChrome({
    required this.composerMode,
    required this.onComposerMode,
    required this.speech,
    this.composerActivity,
  });

  final ValueNotifier<ComposerOrbState> composerMode;
  final ValueChanged<ComposerOrbState> onComposerMode;
  final SpeechInputService speech;
  final ComposerActivityService? composerActivity;

  @override
  Widget build(BuildContext context) {
    final double keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final double bottom =
        math.max(keyboard, MediaQuery.paddingOf(context).bottom) + AppSpace.md;
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        // Lifted with the keyboard, so it stays behind the caption.
        Positioned.fill(bottom: keyboard, child: const StageScrim.bottom()),
        _GlowLayer(bottom: bottom),
        Positioned(
          left: AppSpace.lg,
          right: AppSpace.lg,
          bottom: bottom,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const StageToolChip(),
              StageCaption(composerMode: composerMode),
              _Composer(
                speech: speech,
                activity: composerActivity,
                onModeChanged: onComposerMode,
              ),
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
        // Capped on wide windows: the glow is a halo, not a backdrop.
        final double width = math.min(
          pillWidth * HomeContentStack.glowWidthFactor,
          HomeContentStack.glowMaxSize.width,
        );
        final double height = math.min(
          width / _aspect,
          HomeContentStack.glowMaxSize.height,
        );
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
  const _Composer({
    required this.speech,
    required this.onModeChanged,
    this.activity,
  });

  final SpeechInputService speech;
  final ComposerActivityService? activity;
  final ValueChanged<ComposerOrbState> onModeChanged;

  @override
  Widget build(BuildContext context) {
    final bool initializing = context.select<ChatCubit, bool>(
      (ChatCubit cubit) => cubit.state.initializing,
    );
    if (initializing) {
      return const SizedBox(height: StageComposer.height);
    }
    return StageComposer(
      speech: speech,
      activity: activity,
      onModeChanged: onModeChanged,
    );
  }
}
