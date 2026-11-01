import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/rive/ui_kit.dart';
import '../../../../core/l10n/generated/app_localizations.dart';
import '../../../../core/models/avatar_scene.dart';
import '../../../avatar/avatar.dart';
import 'scene_picker_sheet.dart';

/// The stage as one screen-reader node (M11 ruling 17).
///
/// Label: "<assistant> in the <scene> scene" (the app's name: the persona
/// has no name of its own); value: the phase ("listening", "thinking",
/// "speaking" or "idle", from the composer's mode). Not a live region: the
/// caption already is one.
///
/// Its custom actions are the scene's props, one per contract `propId` in
/// contract order ([onProp] runs what a tap on it runs), then its drag
/// handle, if any ([onDrag] runs the drag's action). The Rive layers in
/// [child] are excluded from semantics, so no stray node comes from them.
///
/// Needs an [AvatarCubit] above it (the scene on screen).
class StageSemantics extends StatelessWidget {
  const StageSemantics({
    super.key,
    required this.composerMode,
    required this.onProp,
    this.onDrag,
    required this.child,
  });

  /// The composer's mode, for the phase.
  final ValueListenable<ComposerOrbState> composerMode;

  /// A prop's action: the `propId` tapped.
  final ValueChanged<String> onProp;

  /// The drag handle's action (null: no drag action).
  final VoidCallback? onDrag;

  /// The Rive stage (scene and avatar).
  final Widget child;

  /// The localized phase [mode] reads as.
  static String phaseLabel(AppLocalizations l10n, ComposerOrbState mode) =>
      switch (mode) {
        ComposerOrbState.listening => l10n.stagePhaseListening,
        ComposerOrbState.thinking => l10n.stagePhaseThinking,
        ComposerOrbState.speaking => l10n.stagePhaseSpeaking,
        ComposerOrbState.idle ||
        ComposerOrbState.typing ||
        ComposerOrbState.error => l10n.stagePhaseIdle,
      };

  /// The node's label for [scene].
  static String label(AppLocalizations l10n, AvatarScene scene) =>
      l10n.stageSemanticsLabel(l10n.appName, sceneName(l10n, scene));

  /// The action labels of [scene], in the order the node lists them: its
  /// props (contract order), then its drag handle.
  static List<String> actionLabels(
    AppLocalizations l10n,
    AvatarScene scene,
  ) => <String>[
    for (final String propId in _props(scene)) ?stagePropAction(l10n, propId),
    if (SceneDrags.of(scene) case final SceneDragHandle handle)
      ?stageDragAction(l10n, handle.id),
  ];

  static List<String> _props(AvatarScene scene) =>
      AvatarRiveContract.sceneProps[scene.name] ?? const <String>[];

  @override
  Widget build(BuildContext context) {
    final Widget stage = ExcludeSemantics(child: child);
    return BlocSelector<AvatarCubit, AvatarState, AvatarScene>(
      selector: (AvatarState state) => state.scene,
      builder: (BuildContext context, AvatarScene scene) {
        return ValueListenableBuilder<ComposerOrbState>(
          valueListenable: composerMode,
          child: stage,
          builder:
              (BuildContext context, ComposerOrbState mode, Widget? child) {
                final AppLocalizations l10n = AppLocalizations.of(context);
                return Semantics(
                  container: true,
                  liveRegion: false,
                  label: label(l10n, scene),
                  value: phaseLabel(l10n, mode),
                  customSemanticsActions: _actions(l10n, scene),
                  child: child,
                );
              },
        );
      },
    );
  }

  Map<CustomSemanticsAction, VoidCallback> _actions(
    AppLocalizations l10n,
    AvatarScene scene,
  ) {
    final Map<CustomSemanticsAction, VoidCallback> actions =
        <CustomSemanticsAction, VoidCallback>{};
    for (final String propId in _props(scene)) {
      final String? label = stagePropAction(l10n, propId);
      if (label != null) {
        actions[CustomSemanticsAction(label: label)] = () => onProp(propId);
      }
    }
    final SceneDragHandle? handle = SceneDrags.of(scene);
    final VoidCallback? drag = onDrag;
    if (handle != null && drag != null) {
      final String? label = stageDragAction(l10n, handle.id);
      if (label != null) {
        actions[CustomSemanticsAction(label: label)] = drag;
      }
    }
    return actions;
  }
}

/// The localized action for the contract `propId` [propId] (null: unknown).
/// One phrase per prop id, whatever the scene (the train's lamp and the
/// living room's are both "Tap the lamp").
String? stagePropAction(AppLocalizations l10n, String propId) =>
    switch (propId) {
      'lamp' => l10n.stagePropLamp,
      'tv' => l10n.stagePropTv,
      'cat' => l10n.stagePropCat,
      'plant' => l10n.stagePropPlant,
      'fire' => l10n.stagePropFire,
      'tent' => l10n.stagePropTent,
      'owl' => l10n.stagePropOwl,
      'sky' => l10n.stagePropSky,
      'crab' => l10n.stagePropCrab,
      'umbrella' => l10n.stagePropUmbrella,
      'seagull' => l10n.stagePropSeagull,
      'planet' => l10n.stagePropPlanet,
      'ufo' => l10n.stagePropUfo,
      'rubberDuck' => l10n.stagePropRubberDuck,
      'cup' => l10n.stagePropCup,
      'espresso' => l10n.stagePropEspresso,
      'window' => l10n.stagePropWindow,
      'fish' => l10n.stagePropFish,
      'telescope' => l10n.stagePropTelescope,
      'antenna' => l10n.stagePropAntenna,
      'pigeon' => l10n.stagePropPigeon,
      'moon' => l10n.stagePropMoon,
      'stove' => l10n.stagePropStove,
      'dog' => l10n.stagePropDog,
      'bell' => l10n.stagePropBell,
      'lantern' => l10n.stagePropLantern,
      'pinwheel' => l10n.stagePropPinwheel,
      'squirrel' => l10n.stagePropSquirrel,
      'woodpile' => l10n.stagePropWoodpile,
      'suitcase' => l10n.stagePropSuitcase,
      'ladybug' => l10n.stagePropLadybug,
      'book' => l10n.stagePropBook,
      'globe' => l10n.stagePropGlobe,
      'clock' => l10n.stagePropClock,
      'mouse' => l10n.stagePropMouse,
      _ => null,
    };

/// The localized action for the contract `dragId` [dragId] (null: unknown).
String? stageDragAction(AppLocalizations l10n, String dragId) =>
    switch (dragId) {
      'cord' => l10n.stageDragCord,
      'poke' => l10n.stageDragPoke,
      'sand' => l10n.stageDragSand,
      'spin' => l10n.stageDragSpin,
      'wipe' => l10n.stageDragWipe,
      'aim' => l10n.stageDragAim,
      'rope' => l10n.stageDragRope,
      'pinwheel' => l10n.stageDragPinwheel,
      'chain' => l10n.stageDragChain,
      'ladder' => l10n.stageDragLadder,
      _ => null,
    };
