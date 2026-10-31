// ignore-l10n: debug — the UI lab is debug-only; its strings are hardcoded.
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../../../../core/design/design.dart';
import '../../../../core/models/avatar_config.dart';
import '../../../../core/models/avatar_scene.dart';
import '../../../../core/models/performance/avatar_prop.dart';
import '../../../../core/models/performance/shot.dart';
import '../../../../core/services/world/world_state_service.dart';
import '../../../../core/utils/logger.dart';
import '../../../avatar/avatar.dart';
import '../../../talking/talking.dart';
import 'lab_config.dart';
import 'lab_stage_layouts.dart';

/// Builds the stage under the lab's Home chrome: the scene and the character
/// for [scene], animated per [talkingState], wearing [face] (the lab's
/// hand-set face) when it is non-null.
typedef LabStageBuilder =
    Widget Function(
      BuildContext context,
      AvatarScene scene,
      TalkingState talkingState,
      FaceFrame? face,
    );

/// What the lab's config adds to the stage beyond the [LabStageBuilder]
/// arguments (contract v7): the held prop and the hand-set parallax. The real
/// stage reads it from the tree, so a stage builder written for the four
/// arguments keeps working.
class LabStageExtras extends InheritedWidget {
  const LabStageExtras({
    super.key,
    required this.prop,
    required this.parallax,
    this.rain,
    this.fog,
    this.npc,
    this.npc2,
    this.moonPhase,
    this.festive,
    this.localDay,
    this.topTint = AvatarTint.none,
    this.hatTint = AvatarTint.none,
    required super.child,
  });

  final AvatarProp prop;
  final Offset? parallax;

  /// The world's rain (contract v8), written to the scene; null: dry.
  final ValueListenable<double>? rain;

  /// The world's fog (contract v11), written to the scene; null: clear.
  final ValueListenable<double>? fog;

  /// A hand-set NPC pose (contract v11); null: the NPC rests.
  final NpcIntent? npc;

  /// A hand-set second-slot pose (contract v12, the gulls); null: the live
  /// gull tree is not running in the lab, so they stay away.
  final NpcIntent? npc2;

  /// The world's moon phase and December dressing (contract v12), written to
  /// the scene; null: the moon as drawn, no dressing.
  final ValueListenable<double>? moonPhase;
  final ValueListenable<double>? festive;

  /// The world's local day, for the avatar's December outfit.
  final ValueListenable<DateTime>? localDay;

  /// The stage avatar's wardrobe tints (contract v13).
  final AvatarTint topTint;
  final AvatarTint hatTint;

  /// The extras above [context], or none (no prop, no parallax).
  static LabStageExtras? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LabStageExtras>();

  @override
  bool updateShouldNotify(LabStageExtras oldWidget) =>
      prop != oldWidget.prop ||
      parallax != oldWidget.parallax ||
      rain != oldWidget.rain ||
      fog != oldWidget.fog ||
      npc != oldWidget.npc ||
      npc2 != oldWidget.npc2 ||
      moonPhase != oldWidget.moonPhase ||
      festive != oldWidget.festive ||
      localDay != oldWidget.localDay ||
      topTint != oldWidget.topTint ||
      hatTint != oldWidget.hatTint;
}

/// The default [LabStageBuilder]: the real Rive scene and avatar.
Widget buildLabRiveStage(
  BuildContext context,
  AvatarScene scene,
  TalkingState talkingState,
  FaceFrame? face,
) => LabRiveStage(scene: scene, talkingState: talkingState, face: face);

/// A mock Home screen for the UI lab's Stage tab: the stage (real Rive scene
/// and avatar by default) under the chrome of `config.layout`, on a phone
/// sized canvas scaled to fit.
///
/// The stage sits at a fixed place in the tree, so look, layout and composer
/// changes only update it; the avatar's phase follows the composer (thinking
/// → generating, speaking → speaking, with a moving mouth).
class LabStagePreview extends StatefulWidget {
  const LabStagePreview({
    super.key,
    required this.config,
    this.stageBuilder = buildLabRiveStage,
    this.world,
  });

  final LabConfig config;

  /// The app's world state; its rain is shown on the scene (null: dry).
  final WorldStateService? world;

  /// Injected so widget tests, which cannot decode Rive files, can pass a
  /// placeholder.
  final LabStageBuilder stageBuilder;

  /// Logical size of the phone the mock is laid out on.
  static const Size canvas = Size(390, 844);

  /// Simulated system bars of that phone.
  static const EdgeInsets systemInsets = EdgeInsets.only(top: 36, bottom: 16);

  @override
  State<LabStagePreview> createState() => _LabStagePreviewState();
}

class _LabStagePreviewState extends State<LabStagePreview>
    with SingleTickerProviderStateMixin {
  static const Duration _mouthCycle = Duration(milliseconds: 1600);

  /// A loose syllable rhythm, read around [_mouthCycle].
  static const List<MouthState> _mouthPattern = <MouthState>[
    MouthState.semi,
    MouthState.open,
    MouthState.slightly,
    MouthState.wide,
    MouthState.semi,
    MouthState.closed,
    MouthState.open,
    MouthState.slightly,
    MouthState.semi,
    MouthState.open,
    MouthState.closed,
    MouthState.slightly,
  ];

  late final AnimationController _mouth = AnimationController(
    vsync: this,
    duration: _mouthCycle,
  )..addListener(_onMouthTick);

  /// The syllable on screen; the stage rebuilds only when it changes, not on
  /// every animation frame.
  final ValueNotifier<MouthState> _syllable = ValueNotifier<MouthState>(
    MouthState.semi,
  );
  bool _reduceMotion = false;

  /// The camera's command: the lab cuts to `config.shot` by hand.
  late final ValueNotifier<CameraShot> _camera = ValueNotifier<CameraShot>(
    CameraShot(shot: widget.config.shot, move: CameraMove.cut),
  );

  bool get _speaking => widget.config.composer == LabComposerState.speaking;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    _syncMouth();
  }

  @override
  void didUpdateWidget(LabStagePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncMouth();
    if (widget.config.shot != _camera.value.shot) {
      _camera.value = CameraShot(
        shot: widget.config.shot,
        move: CameraMove.cut,
        serial: _camera.value.serial + 1,
      );
    }
  }

  @override
  void dispose() {
    _mouth.dispose();
    _syllable.dispose();
    _camera.dispose();
    super.dispose();
  }

  void _onMouthTick() {
    final int i =
        (_mouth.value * _mouthPattern.length).floor() % _mouthPattern.length;
    _syllable.value = _mouthPattern[i];
  }

  void _syncMouth() {
    if (_speaking && !_reduceMotion) {
      if (!_mouth.isAnimating) {
        _mouth.repeat();
      }
    } else {
      _mouth.stop();
      // A still, half-open mouth when motion is reduced.
      _syllable.value = MouthState.semi;
    }
  }

  TalkingState _talkingState(MouthState syllable) {
    return switch (widget.config.composer) {
      LabComposerState.thinking => const TalkingState.generating(),
      LabComposerState.speaking => TalkingState.speaking(syllable),
      _ => const TalkingState.idle(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final LabConfig config = widget.config;
    final AppTokens tokens = context.tokens;
    final BorderRadius screen = BorderRadius.circular(tokens.radius(28));
    return Padding(
      padding: const EdgeInsets.all(AppSpace.md),
      child: Center(
        child: FittedBox(
          child: SizedBox.fromSize(
            size: LabStagePreview.canvas,
            child: MediaQuery(
              data: MediaQuery.of(context).copyWith(
                size: LabStagePreview.canvas,
                padding: LabStagePreview.systemInsets,
                viewPadding: LabStagePreview.systemInsets,
                viewInsets: EdgeInsets.zero,
              ),
              child: DecoratedBox(
                position: DecorationPosition.foreground,
                decoration: BoxDecoration(
                  borderRadius: screen,
                  border: Border.all(
                    color: context.colors.onSurface.withValues(alpha: 0.12),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: screen,
                  child: ColoredBox(
                    color: tokens.background,
                    child: Stack(
                      fit: StackFit.expand,
                      children: <Widget>[
                        LabStageExtras(
                          prop: config.prop,
                          parallax: config.parallax,
                          rain: widget.world?.rain,
                          fog: widget.world?.fog,
                          npc: config.npc,
                          npc2: config.npc2,
                          moonPhase: widget.world?.moonPhase,
                          festive: widget.world?.festive,
                          localDay: widget.world?.localDay,
                          topTint: config.topTint,
                          hatTint: config.hatTint,
                          child: StageCamera(
                            shot: _camera,
                            child: ValueListenableBuilder<MouthState>(
                              valueListenable: _syllable,
                              builder:
                                  (
                                    BuildContext context,
                                    MouthState syllable,
                                    Widget? _,
                                  ) => widget.stageBuilder(
                                    context,
                                    config.scene,
                                    _talkingState(syllable),
                                    config.face,
                                  ),
                            ),
                          ),
                        ),
                        LabStageLayout(
                          layout: config.layout,
                          composer: config.composer,
                          scene: config.scene,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The real stage: one Rive scene, keyed by scene (a scene switch disposes
/// the old file and loads the new one, nothing else does), with one avatar on
/// top that lives as long as the stage (a [GlobalKey] carries it into each
/// new scene layer, under the scene's front weather).
class LabRiveStage extends StatefulWidget {
  const LabRiveStage({
    super.key,
    required this.scene,
    required this.talkingState,
    this.face,
  });

  final AvatarScene scene;
  final TalkingState talkingState;

  /// The lab's hand-set face, written instead of the live one; null shows
  /// the live face.
  final FaceFrame? face;

  @override
  State<LabRiveStage> createState() => _LabRiveStageState();
}

class _LabRiveStageState extends State<LabRiveStage> {
  static const AvatarState _avatar = AvatarState(
    avatar: Avatar(),
    avatarConfig: AvatarConfig(),
  );

  final GlobalKey _avatarKey = GlobalKey(debugLabel: 'lab-avatar');

  @override
  Widget build(BuildContext context) {
    final LabStageExtras? extras = LabStageExtras.maybeOf(context);
    return _LabSceneLayer(
      key: ValueKey<AvatarScene>(widget.scene),
      scene: widget.scene,
      parallax: extras?.parallax,
      rain: extras?.rain,
      fog: extras?.fog,
      npc: extras?.npc,
      npc2: extras?.npc2,
      moonPhase: extras?.moonPhase,
      festive: extras?.festive,
      middle: RiveAvatarView(
        key: _avatarKey,
        // The scene's light rig follows the lab's scene, and the prop the
        // lab's prop.
        avatarState: _avatar.copyWith(
          scene: widget.scene,
          prop: extras?.prop ?? AvatarProp.none,
          avatar: Avatar(
            topTint: extras?.topTint ?? AvatarTint.none,
            hatTint: extras?.hatTint ?? AvatarTint.none,
          ),
        ),
        talkingState: widget.talkingState,
        faceOverride: widget.face,
        localDay: extras?.localDay,
      ),
    );
  }
}

/// One scene's Rive view; logs its lifetime so rapid switching can be checked
/// for duplicate loads.
class _LabSceneLayer extends StatefulWidget {
  const _LabSceneLayer({
    super.key,
    required this.scene,
    this.parallax,
    this.rain,
    this.fog,
    this.npc,
    this.npc2,
    this.moonPhase,
    this.festive,
    this.middle,
  });

  final AvatarScene scene;
  final Offset? parallax;
  final ValueListenable<double>? rain;
  final ValueListenable<double>? fog;
  final NpcIntent? npc;
  final NpcIntent? npc2;
  final ValueListenable<double>? moonPhase;
  final ValueListenable<double>? festive;
  final Widget? middle;

  @override
  State<_LabSceneLayer> createState() => _LabSceneLayerState();
}

class _LabSceneLayerState extends State<_LabSceneLayer> {
  static const String _tag = 'UiLabStage';
  static const ({SceneEvent sceneEvent, int seq}) _noEvent = (
    sceneEvent: SceneEvent.lightsOff,
    seq: 0,
  );

  @override
  void initState() {
    super.initState();
    AppLogger.info('scene mounted: ${widget.scene.name}', tag: _tag);
  }

  @override
  void dispose() {
    AppLogger.info('scene disposed: ${widget.scene.name}', tag: _tag);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RiveSceneView(
      scene: widget.scene,
      sceneEvent: _noEvent,
      parallaxOverride: widget.parallax,
      rain: widget.rain,
      fog: widget.fog,
      npcOverride: widget.npc,
      npc2Override: widget.npc2,
      moonPhase: widget.moonPhase,
      festive: widget.festive,
      middle: widget.middle,
    );
  }
}
