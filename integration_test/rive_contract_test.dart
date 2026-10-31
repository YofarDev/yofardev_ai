import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:rive/rive.dart';
import 'package:yofardev_ai/core/models/avatar_config.dart';
import 'package:yofardev_ai/core/models/avatar_scene.dart';
import 'package:yofardev_ai/core/services/audio/foley_service.dart'
    show DragHaptic;
import 'package:yofardev_ai/features/avatar/domain/models/scene_drag.dart';
import 'package:yofardev_ai/features/avatar/domain/services/prop_drag_physics.dart';
import 'package:yofardev_ai/features/avatar/presentation/bloc/avatar_state.dart';
import 'package:yofardev_ai/features/avatar/presentation/rive/avatar_rive_contract.dart';
import 'package:yofardev_ai/features/avatar/presentation/rive/prop_drag_controller.dart';
import 'package:yofardev_ai/features/avatar/presentation/widgets/rive/avatar_zone_hit_gate.dart';
import 'package:yofardev_ai/features/avatar/presentation/widgets/rive/mouth_anchor_reader.dart';
import 'package:yofardev_ai/features/avatar/presentation/widgets/rive/rive_avatar_view.dart';
import 'package:yofardev_ai/features/avatar/presentation/widgets/rive/rive_scene_view.dart';
import 'package:yofardev_ai/features/talking/presentation/bloc/talking_state.dart';

/// Keeps the `.riv` files in line with `rive/CONTRACT.md`: every name in
/// [AvatarRiveContract] must exist in the shipped assets.
///
/// Runs on macOS (`flutter test integration_test/rive_contract_test.dart
/// -d macos`). Rive listener event names can't be enumerated through the
/// runtime API, so the data-binding surface is asserted directly
/// (artboards, state machines, view model property names, every enum value
/// read back after setting it) and the scenes' `propId`s are found by
/// tapping a grid over each real scene.
///
/// v12 (M9): the drag handles run on the real runtime: one real drag per
/// handle through a real `RiveSceneView` and `PropDragController`, the
/// numbers read back from the file's view model; the avatar's translucent
/// hit test over the scene; the café wipe's holes in the mist in a rendered frame.
/// These run with the window's frames fully live, in real time.
void main() {
  final IntegrationTestWidgetsFlutterBinding binding =
      IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  group('avatar.riv matches the contract', () {
    late File file;
    late Artboard artboard;
    late RiveWidgetController controller;
    late ViewModelInstance vmi;

    setUpAll(() async {
      final File? loaded = await File.asset(
        AvatarRiveContract.avatarAssetPath,
        riveFactory: Factory.rive,
      );
      expect(loaded, isNotNull, reason: 'avatar.riv must load');
      file = loaded!;
      artboard = file.artboard(AvatarRiveContract.avatarArtboard)!;
      controller = RiveWidgetController(
        file,
        artboardSelector: ArtboardSelector.byName(
          AvatarRiveContract.avatarArtboard,
        ),
        stateMachineSelector: StateMachineSelector.byName(
          AvatarRiveContract.avatarStateMachine,
        ),
      );
      vmi = controller.dataBind(DataBind.auto());
    });

    tearDownAll(() {
      vmi.dispose();
      controller.dispose();
      file.dispose();
    });

    test('artboard and state machine exist', () {
      expect(file.artboard(AvatarRiveContract.avatarArtboard), isNotNull);
      expect(
        artboard.stateMachine(AvatarRiveContract.avatarStateMachine),
        isNotNull,
      );
    });

    test('every contract property exists in AvatarVM', () {
      final Set<String> names = vmi.properties
          .map((ViewModelProperty p) => p.name)
          .toSet();
      const List<String> expected = <String>[
        AvatarRiveContract.propMood,
        AvatarRiveContract.propMouth,
        AvatarRiveContract.propPhase,
        AvatarRiveContract.propGestureId,
        AvatarRiveContract.propGestureTrigger,
        AvatarRiveContract.propHat,
        AvatarRiveContract.propTop,
        AvatarRiveContract.propGlasses,
        AvatarRiveContract.propCostume,
        AvatarRiveContract.propPresence,
        AvatarRiveContract.propYaw,
        AvatarRiveContract.propPitch,
        AvatarRiveContract.propHairLagYaw,
        AvatarRiveContract.propHairLagPitch,
        AvatarRiveContract.propEyeLeadYaw,
        AvatarRiveContract.propEyeLeadPitch,
        ...AvatarRiveContract.actionUnitProps,
        ...AvatarRiveContract.actionUnitSideProps,
        AvatarRiveContract.propLipTuck,
        AvatarRiveContract.propTongueUp,
        AvatarRiveContract.propRoll,
        AvatarRiveContract.propBreath,
        AvatarRiveContract.propAutoBlink,
        AvatarRiveContract.propBlinkTrigger,
        ...AvatarRiveContract.lightNumberProps,
        ...AvatarRiveContract.lightColorProps,
        AvatarRiveContract.propProp,
        AvatarRiveContract.propLean,
        AvatarRiveContract.propJacket,
        AvatarRiveContract.propTabletWeather,
        AvatarRiveContract.propTabletTemp,
      ];
      for (final String name in expected) {
        expect(names, contains(name), reason: 'AvatarVM.$name missing');
      }
    });

    test('every enum value is accepted and read back, in order', () {
      final Map<String, List<String>> enumProperties = <String, List<String>>{
        AvatarRiveContract.propMood: AvatarRiveContract.moodValues,
        AvatarRiveContract.propPhase: AvatarRiveContract.phaseValues,
        AvatarRiveContract.propGestureId: AvatarRiveContract.gestureIdValues,
        AvatarRiveContract.propHat: AvatarRiveContract.hatValues,
        AvatarRiveContract.propTop: AvatarRiveContract.topValues,
        AvatarRiveContract.propGlasses: AvatarRiveContract.glassesValues,
        AvatarRiveContract.propCostume: AvatarRiveContract.costumeValues,
        AvatarRiveContract.propPresence: AvatarRiveContract.presenceValues,
        AvatarRiveContract.propProp: AvatarRiveContract.propValues,
        AvatarRiveContract.propTabletWeather:
            AvatarRiveContract.tabletWeatherValues,
      };
      enumProperties.forEach((String property, List<String> values) {
        final ViewModelInstanceEnum? enumProperty = vmi.enumerator(property);
        expect(
          enumProperty,
          isNotNull,
          reason: '$property is not a VM enum property',
        );
        // The VM instance is shared by later tests: restore the default.
        final String original = enumProperty!.value;
        for (final String value in values) {
          enumProperty.value = value;
          expect(
            enumProperty.value,
            value,
            reason: '$property rejected value "$value"',
          );
        }
        enumProperty.value = original;
      });
    });

    test('mouth accepts the full 0-4 range', () {
      final ViewModelInstanceNumber? mouth = vmi.number(
        AvatarRiveContract.propMouth,
      );
      expect(mouth, isNotNull);
      for (
        double v = AvatarRiveContract.mouthMin;
        v <= AvatarRiveContract.mouthMax;
        v++
      ) {
        mouth!.value = v;
        expect(mouth.value, v);
      }
    });

    test('v5 face numbers default to 0 and accept their range', () {
      for (final String name in <String>[
        ...AvatarRiveContract.actionUnitProps,
        AvatarRiveContract.propLipTuck,
        AvatarRiveContract.propTongueUp,
        AvatarRiveContract.propBreath,
        AvatarRiveContract.propRoll,
      ]) {
        final ViewModelInstanceNumber? n = vmi.number(name);
        expect(n, isNotNull, reason: name);
        expect(n!.value, 0, reason: name);
        n.value = 1;
        expect(n.value, 1, reason: name);
        n.value = 0;
      }
    });

    test('v6 side offsets are 14 numbers, default 0, range -1..1', () {
      expect(AvatarRiveContract.actionUnitSideProps, hasLength(14));
      for (final String name in AvatarRiveContract.actionUnitSideProps) {
        final ViewModelInstanceNumber? n = vmi.number(name);
        expect(n, isNotNull, reason: '$name is not a VM number');
        expect(n!.value, 0, reason: name);
        for (final double v in <double>[
          AvatarRiveContract.sideMin,
          AvatarRiveContract.sideMax,
        ]) {
          n.value = v;
          expect(n.value, v, reason: name);
        }
        n.value = 0;
      }
    });

    test('v7 light numbers, colours, lean and prop', () {
      for (final String name in <String>[
        ...AvatarRiveContract.lightNumberProps,
        AvatarRiveContract.propLean,
      ]) {
        final ViewModelInstanceNumber? n = vmi.number(name);
        expect(n, isNotNull, reason: '$name is not a VM number');
        n!.value = 0.5;
        expect(n.value, 0.5, reason: name);
      }
      // The direction is a viewer-space vector: both signs are accepted.
      for (final String name in <String>[
        AvatarRiveContract.propLightKeyX,
        AvatarRiveContract.propLightKeyY,
      ]) {
        final ViewModelInstanceNumber n = vmi.number(name)!;
        for (final double v in <double>[
          AvatarRiveContract.lightDirMin,
          AvatarRiveContract.lightDirMax,
        ]) {
          n.value = v;
          expect(n.value, v, reason: name);
        }
      }
      expect(vmi.number(AvatarRiveContract.propLean)!.value, 0.5);
      for (final String name in AvatarRiveContract.lightColorProps) {
        expect(vmi.color(name), isNotNull, reason: '$name is not a colour');
      }
      expect(
        vmi.enumerator(AvatarRiveContract.propProp)!.value,
        AvatarRiveContract.propValues.first,
        reason: 'prop defaults to none',
      );
    });

    test('v11: gestureId appends thumbsUp, count, grab after the M1 eight', () {
      expect(AvatarRiveContract.gestureIdValues.sublist(8, 11), <String>[
        'thumbsUp',
        'count',
        'grab',
      ]);
      final ViewModelInstanceEnum gesture = vmi.enumerator(
        AvatarRiveContract.propGestureId,
      )!;
      final String original = gesture.value;
      for (final String value in <String>['thumbsUp', 'count', 'grab']) {
        gesture.value = value;
        expect(gesture.value, value);
      }
      gesture.value = original;
    });

    test('v11: jacket, tabletWeather and tabletTemp defaults and ranges', () {
      final ViewModelInstanceBoolean? jacket = vmi.boolean(
        AvatarRiveContract.propJacket,
      );
      expect(jacket, isNotNull, reason: 'jacket is not a VM boolean');
      expect(jacket!.value, isFalse, reason: 'jacket defaults to false');
      jacket.value = true;
      expect(jacket.value, isTrue);
      jacket.value = false;
      expect(
        vmi.enumerator(AvatarRiveContract.propTabletWeather)!.value,
        'none',
        reason: 'tabletWeather defaults to none',
      );
      final ViewModelInstanceNumber? temp = vmi.number(
        AvatarRiveContract.propTabletTemp,
      );
      expect(temp, isNotNull, reason: 'tabletTemp is not a VM number');
      expect(temp!.value, 0, reason: 'tabletTemp defaults to 0');
      for (final double v in <double>[
        AvatarRiveContract.tabletTempMin,
        AvatarRiveContract.tabletTempMax,
        -9,
        49,
      ]) {
        temp.value = v;
        expect(temp.value, v);
      }
      temp.value = 0;
    });

    test('v11: a foley step event fires while the avatar walks out', () async {
      final RiveWidgetController walker = RiveWidgetController(
        file,
        artboardSelector: ArtboardSelector.byName(
          AvatarRiveContract.avatarArtboard,
        ),
        stateMachineSelector: StateMachineSelector.byName(
          AvatarRiveContract.avatarStateMachine,
        ),
      );
      final ViewModelInstance walkVmi = walker.dataBind(DataBind.auto());
      final List<String> kinds = <String>[];
      void onEvent(Event event) {
        if (event.name != AvatarRiveContract.eventFoley) {
          return;
        }
        final String? kind = event
            .stringProperty(AvatarRiveContract.avatarEventKindProperty)
            ?.value;
        if (kind != null) {
          kinds.add(kind);
        }
      }

      walker.stateMachine.addEventListener(onEvent);
      // settle at rest, then walk out
      for (int f = 0; f < 30; f++) {
        walker.stateMachine.advanceAndApply(1 / 60);
      }
      expect(kinds, isEmpty, reason: 'no foley at rest');
      walkVmi.enumerator(AvatarRiveContract.propPresence)!.value =
          'outOfScreen';
      for (int f = 0; f < 150; f++) {
        walker.stateMachine.advanceAndApply(1 / 60);
        await Future<void>.delayed(Duration.zero);
      }
      walker.stateMachine.removeEventListener(onEvent);
      expect(
        kinds,
        contains(AvatarRiveContract.foleyStep),
        reason: 'presence_walkOut fires step foley',
      );
      for (final String kind in kinds) {
        expect(AvatarRiveContract.foleyKinds, contains(kind));
      }
      walkVmi.dispose();
      walker.dispose();
    });

    test('v12: the tap zones are found by name; the eye follow covers '
        'the whole artboard', () {
      controller.stateMachine.advanceAndApply(0);
      final AvatarTapZones zones = AvatarTapZones(
        controller.artboard,
        controller.stateMachine,
        fit: RiveAvatarView.fit,
        alignment: RiveAvatarView.alignment,
      );
      expect(
        zones.found,
        isTrue,
        reason:
            '${AvatarTapZones.headZone} and ${AvatarTapZones.bodyZone} '
            'in avatar.riv',
      );
      // laid out at its own size, a local point is an artboard point
      const Size frame = Size(800, 1000);
      expect(zones.claims(const Offset(400, 360), frame), isTrue);
      expect(zones.claims(const Offset(400, 820), frame), isTrue);
      // above the head and beside the body: Rive's own hit test says yes
      // (the eye follow's full-artboard hit area), the zones say no
      for (final Offset free in <Offset>[
        const Offset(400, 40),
        const Offset(60, 500),
      ]) {
        expect(
          controller.stateMachine.hitTest(Vec2D.fromOffset(free)),
          isTrue,
          reason: 'the eye follow hears $free',
        );
        expect(zones.claims(free, frame), isFalse, reason: '$free is free');
      }
      zones.dispose();
    });

    test('v13: topTint and hatTint are colours, transparent by default', () {
      for (final String name in <String>[
        AvatarRiveContract.propTopTint,
        AvatarRiveContract.propHatTint,
      ]) {
        final ViewModelInstanceColor? tint = vmi.color(name);
        expect(tint, isNotNull, reason: '$name is not a VM colour');
        expect(tint!.value.a, 0, reason: '$name defaults to alpha 0');
      }
    });

    test('v13: gestureId ends with signature; each costume plays it and '
        'fires gesture_done', () async {
      expect(AvatarRiveContract.gestureIdValues.last, 'signature');
      for (final String costume in AvatarRiveContract.costumeValues) {
        final RiveWidgetController actor = RiveWidgetController(
          file,
          artboardSelector: ArtboardSelector.byName(
            AvatarRiveContract.avatarArtboard,
          ),
          stateMachineSelector: StateMachineSelector.byName(
            AvatarRiveContract.avatarStateMachine,
          ),
        );
        final ViewModelInstance actorVmi = actor.dataBind(DataBind.auto());
        final List<String> done = <String>[];
        void onEvent(Event event) {
          if (event.name != AvatarRiveContract.eventGestureDone) {
            return;
          }
          final String? id = event
              .stringProperty(AvatarRiveContract.avatarEventGestureIdProperty)
              ?.value;
          if (id != null) {
            done.add(id);
          }
        }

        actor.stateMachine.addEventListener(onEvent);
        actorVmi.enumerator(AvatarRiveContract.propCostume)!.value = costume;
        for (int f = 0; f < 10; f++) {
          actor.stateMachine.advanceAndApply(1 / 60);
        }
        actorVmi.enumerator(AvatarRiveContract.propGestureId)!.value =
            'signature';
        actorVmi.trigger(AvatarRiveContract.propGestureTrigger)!.trigger();
        // every signature lasts at most 1.2 s (72 frames)
        for (int f = 0; f < 100 && done.isEmpty; f++) {
          actor.stateMachine.advanceAndApply(1 / 60);
          await Future<void>.delayed(Duration.zero);
        }
        actor.stateMachine.removeEventListener(onEvent);
        expect(done, <String>['signature'], reason: 'costume $costume');
        actorVmi.dispose();
        actor.dispose();
      }
    });

    test('v13: MouthAnchor is found and follows the head', () {
      final RiveWidgetController head = RiveWidgetController(
        file,
        artboardSelector: ArtboardSelector.byName(
          AvatarRiveContract.avatarArtboard,
        ),
        stateMachineSelector: StateMachineSelector.byName(
          AvatarRiveContract.avatarStateMachine,
        ),
      );
      final ViewModelInstance headVmi = head.dataBind(DataBind.auto());
      final MouthAnchorReader reader = MouthAnchorReader(head.artboard);
      expect(reader.found, isTrue, reason: 'MouthAnchor in avatar.riv');
      Offset settle() {
        for (int f = 0; f < 40; f++) {
          head.stateMachine.advanceAndApply(1 / 60);
        }
        return reader.read()!;
      }

      final Offset rest = settle();
      // ignore: avoid_print
      print('MouthAnchor at rest: $rest');
      expect(rest.dx, inInclusiveRange(340, 460), reason: 'centred: $rest');
      expect(rest.dy, inInclusiveRange(300, 650), reason: 'on the face: $rest');
      headVmi.number(AvatarRiveContract.propYaw)!.value = 1;
      final Offset turned = settle();
      expect(
        (turned.dx - rest.dx).abs(),
        greaterThan(5),
        reason: 'yaw moves the mouth: $rest -> $turned',
      );
      headVmi.number(AvatarRiveContract.propYaw)!.value = 0;
      headVmi.number(AvatarRiveContract.propAuJawDrop)!.value = 1;
      final Offset open = settle();
      expect(
        open.dy,
        greaterThan(rest.dy + 1),
        reason: 'the jaw lowers the anchor: $rest -> $open',
      );
      reader.dispose();
      headVmi.dispose();
      head.dispose();
    });

    test('autoBlink defaults to true; blink is a trigger', () {
      final ViewModelInstanceBoolean? auto = vmi.boolean(
        AvatarRiveContract.propAutoBlink,
      );
      expect(auto, isNotNull);
      expect(auto!.value, isTrue);
      expect(vmi.trigger(AvatarRiveContract.propBlinkTrigger), isNotNull);
    });
  });

  group('scene files match the contract', () {
    for (final String sceneId in AvatarRiveContract.sceneIds) {
      test('$sceneId.riv: artboard, SM, SceneVM eventIds and props', () async {
        final File? loaded = await File.asset(
          AvatarRiveContract.sceneAssetPath(sceneId),
          riveFactory: Factory.rive,
        );
        expect(loaded, isNotNull, reason: '$sceneId.riv must load');
        final File file = loaded!;

        final Artboard? artboard = file.artboard(
          AvatarRiveContract.sceneArtboard,
        );
        expect(artboard, isNotNull);
        expect(
          artboard!.stateMachine(AvatarRiveContract.sceneStateMachine),
          isNotNull,
        );

        final RiveWidgetController controller = RiveWidgetController(
          file,
          artboardSelector: ArtboardSelector.byName(
            AvatarRiveContract.sceneArtboard,
          ),
          stateMachineSelector: StateMachineSelector.byName(
            AvatarRiveContract.sceneStateMachine,
          ),
        );
        final ViewModelInstance vmi = controller.dataBind(DataBind.auto());

        final Set<String> names = vmi.properties
            .map((ViewModelProperty p) => p.name)
            .toSet();
        expect(
          names,
          contains(AvatarRiveContract.scenePropEventId),
          reason: 'SceneVM.eventId missing in $sceneId',
        );
        expect(
          names,
          contains(AvatarRiveContract.scenePropEventTrigger),
          reason: 'SceneVM.event trigger missing in $sceneId',
        );

        // v7: parallax numbers (default 0, range -1..1) and the light rig.
        for (final String name in <String>[
          AvatarRiveContract.scenePropParallaxX,
          AvatarRiveContract.scenePropParallaxY,
        ]) {
          expect(names, contains(name), reason: 'SceneVM.$name in $sceneId');
          final ViewModelInstanceNumber n = vmi.number(name)!;
          expect(n.value, 0, reason: '$sceneId $name defaults to 0');
          for (final double v in <double>[
            AvatarRiveContract.lightDirMin,
            AvatarRiveContract.lightDirMax,
          ]) {
            n.value = v;
            expect(n.value, v, reason: '$sceneId $name');
          }
          n.value = 0;
        }
        // v8: steady rain intensity, 0..1, default 0.
        expect(
          names,
          contains(AvatarRiveContract.scenePropRain),
          reason: 'SceneVM.rain in $sceneId',
        );
        final ViewModelInstanceNumber rain = vmi.number(
          AvatarRiveContract.scenePropRain,
        )!;
        expect(rain.value, 0, reason: '$sceneId rain defaults to 0');
        for (final double v in <double>[0, 1]) {
          rain.value = v;
          expect(rain.value, v, reason: '$sceneId rain');
        }
        rain.value = 0;
        // v10: the time of day, 0..1, default 0.
        for (final String name in <String>[
          AvatarRiveContract.scenePropDaylight,
          AvatarRiveContract.scenePropDusk,
        ]) {
          expect(names, contains(name), reason: 'SceneVM.$name in $sceneId');
          final ViewModelInstanceNumber n = vmi.number(name)!;
          expect(n.value, 0, reason: '$sceneId $name defaults to 0');
          for (final double v in <double>[0, 1]) {
            n.value = v;
            expect(n.value, v, reason: '$sceneId $name');
          }
          n.value = 0;
        }
        for (final String name in AvatarRiveContract.sceneLightProps) {
          expect(names, contains(name), reason: 'SceneVM.$name in $sceneId');
        }
        // v11: fog (0..1) and the NPC (npc enum, npcX 0..1, npcLook -1..1),
        // all at the v10 look by default.
        final Map<String, List<double>> v11Numbers = <String, List<double>>{
          AvatarRiveContract.scenePropFog: <double>[0, 1],
          AvatarRiveContract.scenePropNpcX: <double>[0, 1],
          AvatarRiveContract.scenePropNpcLook: <double>[-1, 1],
        };
        v11Numbers.forEach((String name, List<double> range) {
          expect(names, contains(name), reason: 'SceneVM.$name in $sceneId');
          final ViewModelInstanceNumber n = vmi.number(name)!;
          expect(n.value, 0, reason: '$sceneId $name defaults to 0');
          for (final double v in range) {
            n.value = v;
            expect(n.value, v, reason: '$sceneId $name');
          }
          n.value = 0;
        });
        final ViewModelInstanceEnum? npc = vmi.enumerator(
          AvatarRiveContract.scenePropNpc,
        );
        expect(npc, isNotNull, reason: 'SceneVM.npc enum in $sceneId');
        expect(npc!.value, 'rest', reason: '$sceneId npc defaults to rest');
        for (final String value in AvatarRiveContract.npcValues) {
          npc.value = value;
          expect(npc.value, value, reason: '$sceneId npc rejected "$value"');
        }
        npc.value = 'rest';

        // v12: the second NPC slot (default away; only the beach draws it),
        // the moon phase (default -1: the moon as drawn before v12) and the
        // December dressing.
        final ViewModelInstanceEnum? npc2 = vmi.enumerator(
          AvatarRiveContract.scenePropNpc2,
        );
        expect(npc2, isNotNull, reason: 'SceneVM.npc2 enum in $sceneId');
        expect(npc2!.value, 'away', reason: '$sceneId npc2 defaults to away');
        for (final String value in AvatarRiveContract.npcValues) {
          npc2.value = value;
          expect(npc2.value, value, reason: '$sceneId npc2 rejected "$value"');
        }
        npc2.value = 'away';
        final Map<String, ({double rest, List<double> range})>
        v12Numbers = <String, ({double rest, List<double> range})>{
          AvatarRiveContract.scenePropNpc2X: (rest: 0, range: <double>[0, 1]),
          AvatarRiveContract.scenePropNpc2Look: (
            rest: 0,
            range: <double>[-1, 1],
          ),
          AvatarRiveContract.scenePropMoonPhase: (
            rest: AvatarRiveContract.moonPhaseDefault,
            range: <double>[
              AvatarRiveContract.moonPhaseMin,
              0.25,
              0.5,
              AvatarRiveContract.moonPhaseMax,
              AvatarRiveContract.moonPhaseDefault,
            ],
          ),
          AvatarRiveContract.scenePropFestive: (
            rest: 0,
            range: <double>[
              AvatarRiveContract.festiveMin,
              AvatarRiveContract.festiveMax,
            ],
          ),
          // v13: every scene declares night (the beach binds it)
          AvatarRiveContract.scenePropNight: (
            rest: 0,
            range: <double>[0, 0.5, 1],
          ),
        };
        // v14: the seasons, 0..1, default 0 (every scene declares them).
        v12Numbers[AvatarRiveContract.scenePropSpring] = (
          rest: 0,
          range: <double>[0, 0.5, 1],
        );
        v12Numbers[AvatarRiveContract.scenePropAutumn] = (
          rest: 0,
          range: <double>[0, 0.5, 1],
        );
        // v14: the quality tier, default ultra (the v13 look).
        final ViewModelInstanceEnum? tier = vmi.enumerator(
          AvatarRiveContract.scenePropTier,
        );
        expect(tier, isNotNull, reason: 'SceneVM.tier enum in $sceneId');
        expect(
          tier!.value,
          AvatarRiveContract.tierDefault,
          reason: '$sceneId tier defaults to ultra',
        );
        for (final String value in AvatarRiveContract.tierValues) {
          tier.value = value;
          expect(tier.value, value, reason: '$sceneId tier rejected "$value"');
        }
        tier.value = AvatarRiveContract.tierDefault;
        // v12 drag handle numbers: the scene's own, at their defaults
        // (trailFade 1), and none of another scene's.
        final SceneDragHandle handle = SceneDrags.of(
          AvatarScene.values.byName(sceneId),
        )!;
        expect(
          handle.numbers.map((DragNumber n) => n.name).toSet(),
          AvatarRiveContract.sceneDragProps[sceneId]!.toSet(),
          reason: '$sceneId: SceneDrags mirrors the contract',
        );
        for (final DragNumber n in handle.numbers) {
          v12Numbers[n.name] = (rest: n.value, range: _dragRange(n.name));
        }
        v12Numbers.forEach((
          String name,
          ({double rest, List<double> range}) spec,
        ) {
          expect(names, contains(name), reason: 'SceneVM.$name in $sceneId');
          final ViewModelInstanceNumber n = vmi.number(name)!;
          expect(n.value, spec.rest, reason: '$sceneId $name default');
          for (final double v in spec.range) {
            n.value = v;
            expect(n.value, v, reason: '$sceneId $name');
          }
          n.value = spec.rest;
        });
        final Set<String> foreignDrags = <String>{
          for (final List<String> own
              in AvatarRiveContract.sceneDragProps.values)
            ...own,
        }.difference(AvatarRiveContract.sceneDragProps[sceneId]!.toSet());
        for (final String name in foreignDrags) {
          expect(
            names,
            isNot(contains(name)),
            reason: '$sceneId declares only its own drag numbers ($name)',
          );
        }

        // The eventId enum holds exactly the contract's values, in order.
        final List<String> contractEvents =
            AvatarRiveContract.sceneEvents[sceneId]!;
        expect(
          file.enums.any((DataEnum e) => listEquals(e.values, contractEvents)),
          isTrue,
          reason:
              '$sceneId: no enum equals $contractEvents; file has '
              '${file.enums.map((DataEnum e) => '${e.name}: ${e.values}')}',
        );

        // Every eventId value for this scene must be accepted.
        final ViewModelInstanceEnum? eventId = vmi.enumerator(
          AvatarRiveContract.scenePropEventId,
        );
        expect(eventId, isNotNull);
        for (final String value in AvatarRiveContract.sceneEvents[sceneId]!) {
          eventId!.value = value;
          expect(
            eventId.value,
            value,
            reason: '$sceneId eventId rejected "$value"',
          );
        }

        // v9: the front artboard exactly where the contract says.
        final Artboard? front = file.artboard(
          AvatarRiveContract.sceneFrontArtboard,
        );
        if (AvatarRiveContract.sceneFrontScenes.contains(sceneId)) {
          expect(front, isNotNull, reason: '$sceneId SceneFront');
          expect(
            front!.stateMachine(AvatarRiveContract.sceneStateMachine),
            isNotNull,
            reason: '$sceneId SceneFront Main',
          );
          final RiveWidgetController frontController = RiveWidgetController(
            file,
            artboardSelector: ArtboardSelector.byName(
              AvatarRiveContract.sceneFrontArtboard,
            ),
            stateMachineSelector: StateMachineSelector.byName(
              AvatarRiveContract.sceneStateMachine,
            ),
          );
          final ViewModelInstance frontVmi = frontController.dataBind(
            DataBind.auto(),
          );
          for (final String name in <String>[
            AvatarRiveContract.scenePropRain,
            AvatarRiveContract.scenePropParallaxX,
            AvatarRiveContract.scenePropParallaxY,
          ]) {
            expect(
              frontVmi.number(name),
              isNotNull,
              reason: '$sceneId SceneFront $name',
            );
          }
          frontVmi.dispose();
          frontController.dispose();
          front.dispose();
        } else {
          expect(front, isNull, reason: '$sceneId has no SceneFront');
        }
        artboard.dispose();

        vmi.dispose();
        controller.dispose();
        file.dispose();
      });
    }
  });

  group('journey.riv matches the contract (v10)', () {
    test('artboard, SM and JourneyVM numbers and colours', () async {
      final File? loaded = await File.asset(
        AvatarRiveContract.journeyAssetPath,
        riveFactory: Factory.rive,
      );
      expect(loaded, isNotNull, reason: 'journey.riv must load');
      final File file = loaded!;
      final Artboard? artboard = file.artboard(
        AvatarRiveContract.journeyArtboard,
      );
      expect(artboard, isNotNull);
      expect(
        artboard!.stateMachine(AvatarRiveContract.journeyStateMachine),
        isNotNull,
      );
      final RiveWidgetController controller = RiveWidgetController(
        file,
        artboardSelector: ArtboardSelector.byName(
          AvatarRiveContract.journeyArtboard,
        ),
        stateMachineSelector: StateMachineSelector.byName(
          AvatarRiveContract.journeyStateMachine,
        ),
      );
      final ViewModelInstance vmi = controller.dataBind(DataBind.auto());
      for (final String name in <String>[
        AvatarRiveContract.journeyPropDoor,
        AvatarRiveContract.journeyPropPath,
        AvatarRiveContract.journeyPropPortal,
        AvatarRiveContract.journeyPropRocket,
        AvatarRiveContract.journeyPropOpen,
        AvatarRiveContract.journeyPropLift,
        // v11: the jacket on the door's peg
        AvatarRiveContract.journeyPropJacket,
      ]) {
        final ViewModelInstanceNumber? n = vmi.number(name);
        expect(n, isNotNull, reason: 'JourneyVM.$name');
        expect(n!.value, 0, reason: '$name defaults to 0');
        n.value = 1;
        expect(n.value, 1, reason: name);
        n.value = 0;
      }
      for (final String name in <String>[
        AvatarRiveContract.journeyPropLightKey,
        AvatarRiveContract.journeyPropLightAmbient,
      ]) {
        expect(vmi.color(name), isNotNull, reason: 'JourneyVM.$name');
      }
      controller.dispose();
      file.dispose();
    });
  });

  group('scene posters (v12)', () {
    for (final String sceneId in AvatarRiveContract.sceneIds) {
      test('$sceneId.webp exists, 540x960, within budget', () async {
        final ByteData data = await rootBundle.load(
          AvatarRiveContract.posterAssetPath(sceneId),
        );
        expect(data.lengthInBytes, greaterThan(0));
        expect(
          data.lengthInBytes,
          lessThanOrEqualTo(AvatarRiveContract.posterMaxBytes),
          reason: '$sceneId poster budget',
        );
        final ui.Codec codec = await ui.instantiateImageCodec(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        );
        final ui.FrameInfo frame = await codec.getNextFrame();
        expect(frame.image.width, AvatarRiveContract.posterWidth);
        expect(frame.image.height, AvatarRiveContract.posterHeight);
        frame.image.dispose();
        codec.dispose();
      });
    }
  });

  group('scene propIds on the real runtime (grid of taps)', () {
    for (final String sceneId in AvatarRiveContract.sceneIds) {
      testWidgets('$sceneId: every tap target is a contract propId', (
        WidgetTester tester,
      ) async {
        final AvatarScene scene = AvatarScene.values.byName(sceneId);
        final _Stage stage = _Stage();
        final Size box = _stageBox(tester);
        await tester.pumpWidget(_stageApp(scene, stage, box));
        await _waitLoaded(tester, stage, scene);

        final Map<String, Offset> hits = await _scanProps(tester, stage, box);
        expect(
          hits.keys.toSet(),
          AvatarRiveContract.sceneProps[sceneId]!.toSet(),
          reason: '$sceneId prop_tapped ids (first hits: $hits)',
        );
        await _unmount(tester);
      });
    }
  });

  group('v12 drag handles on the real runtime', () {
    testWidgets('livingRoom cord: pull past 0.6 fires lightsOff, springs '
        'back', (WidgetTester tester) async {
      await _pullTest(
        tester,
        AvatarScene.livingRoom,
        AvatarRiveContract.scenePropCord,
        SceneEvent.lightsOff,
        expectedFoley: <String>['click'],
      );
    });

    testWidgets('mountainHut rope: pull past 0.6 rings the bell, springs '
        'back', (WidgetTester tester) async {
      await _pullTest(
        tester,
        AvatarScene.mountainHut,
        AvatarRiveContract.scenePropRope,
        SceneEvent.bell,
        expectedFoley: <String>['click', 'bell'],
      );
    });

    testWidgets('campfire poke: the tip follows the finger, a fast stir '
        'flares, it eases out', (WidgetTester tester) async {
      const AvatarScene scene = AvatarScene.campfire;
      final _Stage stage = _Stage();
      final Size box = _stageBox(tester);
      await tester.pumpWidget(_stageApp(scene, stage, box));
      await _waitLoaded(tester, stage, scene);
      final PropDragController drags = stage.drags;
      final double scale = SceneDrags.coverScale(box);
      final Offset origin = tester.getTopLeft(find.byType(RiveSceneView));
      // Poke is absolute: start on the stick's tip.
      final Offset tip =
          origin + SceneDrags.toLocal(PropDragPhysics.pokeTip, box);
      expect(drags.readNumber(AvatarRiveContract.scenePropPoke), 0);

      final TestGesture gesture = await tester.startGesture(tip);
      Offset at = tip;
      // past the 3 px accept, then hold while the stick slides in (120 ms)
      at = await _stepTo(tester, gesture, at, tip + const Offset(4, 0), 2);
      await _live(tester, const Duration(milliseconds: 250));
      expect(
        drags.readNumber(AvatarRiveContract.scenePropPoke),
        greaterThan(0.95),
        reason: 'the stick shows while held',
      );
      // a slow stir: a 30 px circle (artboard) in 0.8 s, ~240 px/s
      const int steps = 48;
      for (int i = 1; i <= steps; i++) {
        final double a = 2 * math.pi * i / steps;
        final Offset target =
            tip + Offset(math.cos(a) - 1, math.sin(a)) * 30 * scale;
        at = await _stepTo(tester, gesture, at, target, 1);
      }
      at = await _stepTo(tester, gesture, at, tip + Offset(60, 40) * scale, 6);
      await _live(tester, const Duration(milliseconds: 150));
      final Offset finger = SceneDrags.toArtboard(at - origin, box);
      final double pokeX = drags.readNumber(AvatarRiveContract.scenePropPokeX)!;
      final double pokeY = drags.readNumber(AvatarRiveContract.scenePropPokeY)!;
      expect(pokeX, inInclusiveRange(-1, 1));
      expect(pokeY, inInclusiveRange(-1, 1));
      expect(
        pokeX,
        closeTo(
          ((finger.dx - PropDragPhysics.pokeTip.dx) /
                  PropDragPhysics.pokeRange.dx)
              .clamp(-1.0, 1.0),
          0.05,
        ),
        reason: 'the tip is under the finger (x)',
      );
      expect(
        pokeY,
        closeTo(
          ((finger.dy - PropDragPhysics.pokeTip.dy) /
                  PropDragPhysics.pokeRange.dy)
              .clamp(-1.0, 1.0),
          0.05,
        ),
        reason: 'the tip is under the finger (y)',
      );
      expect(pokeX, greaterThan(0.4), reason: 'the tip moved right');
      expect(
        stage.events,
        isNot(contains(SceneEvent.flare)),
        reason: 'a slow stir does not flare',
      );
      // a fast stir: back and forth over 120 px (artboard), 20 px every
      // 10 ms of real time (~2000 px/s; a pumped frame is too slow here)
      final Offset swing = Offset(20, 0) * scale;
      for (int i = 0; i < 48; i++) {
        at += (i ~/ 6).isEven ? -swing : swing;
        await gesture.moveTo(at);
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      await gesture.up();
      expect(stage.events, <SceneEvent>[SceneEvent.flare]);
      expect(stage.haptics, contains(DragHaptic.impact));
      // eased out (450 ms), then back to its defaults
      await _live(tester, const Duration(milliseconds: 900));
      expect(drags.readNumber(AvatarRiveContract.scenePropPoke), 0);
      expect(drags.readNumber(AvatarRiveContract.scenePropPokeX), 0);
      expect(drags.readNumber(AvatarRiveContract.scenePropPokeY), 0);
      await _unmount(tester);
    });

    testWidgets('beach sand: a stroke lays dots, bigWave washes them', (
      WidgetTester tester,
    ) async {
      const AvatarScene scene = AvatarScene.beach;
      final _Stage stage = _Stage();
      final Size box = _stageBox(tester);
      await tester.pumpWidget(_stageApp(scene, stage, box));
      await _waitLoaded(tester, stage, scene);
      final Rect rect = SceneDrags.of(scene)!.rect;
      await _trailStroke(
        tester,
        stage,
        box,
        Offset(rect.center.dx, rect.top + 40),
        Offset(rect.center.dx, rect.bottom - 40),
      );
      // the wave washes the sand (1.2 s), then the trail resets
      await tester.pumpWidget(
        _stageApp(
          scene,
          stage,
          box,
          sceneEvent: (sceneEvent: SceneEvent.bigWave, seq: 1),
        ),
      );
      await _live(tester, const Duration(milliseconds: 1700));
      expect(stage.drags.readNumber(AvatarRiveContract.scenePropTrailN), 0);
      expect(stage.drags.readNumber(AvatarRiveContract.scenePropTrailFade), 1);
      await _unmount(tester);
    });

    testWidgets('cafe wipe: a stroke lays dots on the window', (
      WidgetTester tester,
    ) async {
      const AvatarScene scene = AvatarScene.cafe;
      final _Stage stage = _Stage();
      final Size box = _stageBox(tester);
      await tester.pumpWidget(_stageApp(scene, stage, box));
      await _waitLoaded(tester, stage, scene);
      await _trailStroke(
        tester,
        stage,
        box,
        const Offset(350, 330),
        const Offset(730, 700),
      );
      await _unmount(tester);
    });

    testWidgets('deepSpace spin: a flick turns with inertia, a long drag '
        'wraps', (WidgetTester tester) async {
      await _spinTest(
        tester,
        AvatarScene.deepSpace,
        AvatarRiveContract.scenePropSpin,
        turns: 1.25,
      );
    });

    testWidgets('forestCabin pinwheel (v14): a flick turns with inertia, a '
        'long drag wraps', (WidgetTester tester) async {
      // leftward: the pinwheel sits by the right edge
      await _spinTest(
        tester,
        AvatarScene.forestCabin,
        AvatarRiveContract.scenePropPinwheel,
        turns: -0.75,
      );
    });

    testWidgets('trainCompartment chain (v14): pull past 0.6 blows the '
        'whistle, springs back', (WidgetTester tester) async {
      await _pullTest(
        tester,
        AvatarScene.trainCompartment,
        AvatarRiveContract.scenePropChain,
        SceneEvent.whistle,
        expectedFoley: <String>['click'],
      );
    });

    testWidgets('rooftop aim: a horizontal drag swivels and holds', (
      WidgetTester tester,
    ) async {
      await _aimTest(
        tester,
        AvatarScene.rooftop,
        AvatarRiveContract.scenePropAim,
      );
    });

    testWidgets('library ladder (v14): a horizontal drag slides and holds', (
      WidgetTester tester,
    ) async {
      await _aimTest(
        tester,
        AvatarScene.library,
        AvatarRiveContract.scenePropLadder,
      );
    });
  });

  group('the avatar over the scene (zone hit gate, v12)', () {
    testWidgets('head and body taps reach the avatar; scene props and the '
        'cord reach the scene through it', (WidgetTester tester) async {
      const AvatarScene scene = AvatarScene.livingRoom;
      final _Stage stage = _Stage();
      final Size box = _stageBox(tester);
      await tester.pumpWidget(_stageApp(scene, stage, box, withAvatar: true));
      await _waitLoaded(tester, stage, scene);
      for (int i = 0; i < 100 && _rive(tester, 'Avatar') == null; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(_rive(tester, 'Avatar'), isNotNull, reason: 'avatar.riv loaded');
      await _live(tester, const Duration(milliseconds: 500));
      final Offset origin = tester.getTopLeft(find.byType(RiveSceneView));

      // The avatar's zones: HitHead (400, 360) and HitBody (400, 820) in
      // its 800x1000 artboard, drawn contain + bottom-centre.
      for (final (String zone, Offset point) in <(String, Offset)>[
        (AvatarRiveContract.zoneHead, const Offset(400, 360)),
        (AvatarRiveContract.zoneBody, const Offset(400, 820)),
      ]) {
        stage.avatarTaps.clear();
        final int props = stage.props.length;
        _keepResumed();
        await tester.tapAt(origin + _avatarToLocal(point, box));
        _deliverEvents(tester);
        expect(stage.avatarTaps, <String>[zone], reason: '$zone tap');
        expect(
          stage.props.length,
          props,
          reason: 'the $zone tap does not reach the scene',
        );
      }

      // The cord (outside the avatar's zones) drags through the avatar.
      final Offset cord = stage.drags.handleCentre(box)!;
      expect(
        _inAvatarZone(cord, box),
        isFalse,
        reason: 'the cord is outside the avatar zones at this size',
      );
      final List<double> samples = await _sample(
        stage.drags,
        AvatarRiveContract.scenePropCord,
        () => tester.timedDragFrom(
          origin + cord,
          const Offset(0, 66),
          const Duration(milliseconds: 500),
        ),
      );
      expect(samples.reduce(math.max), greaterThan(0.6));
      expect(stage.events, <SceneEvent>[SceneEvent.lightsOff]);

      // Scene props outside the avatar's zones answer taps through it.
      stage.avatarTaps.clear();
      final Map<String, Offset> hits = await _scanProps(tester, stage, box);
      // ignore: avoid_print
      print(
        'through the avatar: $hits; avatar taps by zone: '
        '${<String, int>{for (final String z in stage.avatarTaps.toSet()) z: stage.avatarTaps.where((String t) => t == z).length}}',
      );
      expect(
        hits.keys.toSet().intersection(<String>{'plant', 'tv'}),
        isNotEmpty,
        reason: 'plant or tv reached through the avatar layer: $hits',
      );
      expect(stage.avatarTaps.toSet(), <String>{
        AvatarRiveContract.zoneHead,
        AvatarRiveContract.zoneBody,
      }, reason: 'the scan hit both avatar zones');
      await _unmount(tester);
    });
  });

  group('v13 tints render on rive_native (color blend)', () {
    /// Pixels of the avatar's torso that read blue (B > R + 30) in a
    /// portrait stage: the pink hoodie has none.
    Future<int> bluePixels(WidgetTester tester, Avatar avatar) async {
      final _Stage stage = _Stage();
      final Size box = _stageBox(tester);
      await tester.pumpWidget(
        _stageApp(
          AvatarScene.livingRoom,
          stage,
          box,
          withAvatar: true,
          avatar: avatar,
        ),
      );
      await _waitLoaded(tester, stage, AvatarScene.livingRoom);
      await _live(tester, const Duration(milliseconds: 800));
      final _Rgba frame = await _grab(tester);
      // the avatar's 800x1000 artboard, contained and bottom-centred
      final double scale = math.min(box.width / 800, box.height / 1000);
      final double left = (box.width - 800 * scale) / 2;
      final double top = box.height - 1000 * scale;
      int blue = 0;
      for (double y = 720; y < 980; y += 6) {
        for (double x = 260; x < 540; x += 6) {
          final List<double> c = frame.mean(
            Offset(left + x * scale, top + y * scale),
          );
          if (c[2] > c[0] + 30) {
            blue++;
          }
        }
      }
      await _unmount(tester);
      return blue;
    }

    testWidgets('a blue topTint turns the hoodie blue; a costume ignores it', (
      WidgetTester tester,
    ) async {
      final int plain = await bluePixels(tester, const Avatar());
      final int tinted = await bluePixels(
        tester,
        const Avatar(topTint: AvatarTint.blue),
      );
      final int costumed = await bluePixels(
        tester,
        const Avatar(topTint: AvatarTint.blue, costume: AvatarCostume.batman),
      );
      // ignore: avoid_print
      print(
        'blue torso samples: plain $plain, tinted $tinted, '
        'batman + tint $costumed',
      );
      expect(tinted, greaterThan(plain + 100), reason: 'the tint shows');
      expect(costumed, lessThan(plain + 20), reason: 'no tint on a costume');
    });
  });

  group('cafe wipe cuts the mist (rive_native)', () {
    testWidgets('a wiped dot clears the mist: the view shows through', (
      WidgetTester tester,
    ) async {
      const AvatarScene scene = AvatarScene.cafe;
      final _Stage stage = _Stage();
      final Size box = _stageBox(tester);
      await tester.pumpWidget(_stageApp(scene, stage, box));
      await _waitLoaded(tester, stage, scene);
      await _live(tester, const Duration(milliseconds: 500));
      final _Rgba rest = await _grab(tester);

      await _trailStroke(
        tester,
        stage,
        box,
        const Offset(350, 290),
        const Offset(730, 740),
      );
      await _live(tester, const Duration(milliseconds: 300));
      final _Rgba wiped = await _grab(tester);

      final int n = stage.drags
          .readNumber(AvatarRiveContract.scenePropTrailN)!
          .round();
      // M10: each dot is a hole in the mist (an isHole path under the
      // clockwise fill rule, rive/tools/scene_cafe.py `wipe_holes`); where
      // the runtime cuts it the view behind the glass shows, brighter or
      // darker than the mist: the pixel moves. A runtime that ignored the
      // hole would leave the mist unchanged.
      int cleared = 0;
      final List<String> log = <String>[];
      for (int i = 0; i < n; i++) {
        final Offset dot = Offset(
          stage.drags.readNumber(AvatarRiveContract.scenePropTrailX[i])!,
          stage.drags.readNumber(AvatarRiveContract.scenePropTrailY[i])!,
        );
        final Offset local = SceneDrags.toLocal(dot, box);
        final List<double> before = rest.mean(local);
        final List<double> after = wiped.mean(local);
        log.add(
          'dot $i $dot: ${before.map((double v) => v.round())} -> '
          '${after.map((double v) => v.round())}',
        );
        if (<int>[0, 1, 2].any((int c) => (before[c] - after[c]).abs() >= 12)) {
          cleared++;
        }
      }
      // ignore: avoid_print
      print(log.join('\n'));
      expect(n, greaterThanOrEqualTo(4));
      expect(cleared, greaterThanOrEqualTo(3), reason: 'the wipe shows\n$log');
      await _unmount(tester);
    });
  });
}

/// The test range of a v12 drag number (contract "Drag handles (v12)").
List<double> _dragRange(String name) {
  if (name.startsWith('trailX')) {
    return <double>[0, SceneDrags.artboard.width];
  }
  if (name.startsWith('trailY')) {
    return <double>[0, SceneDrags.artboard.height];
  }
  switch (name) {
    case AvatarRiveContract.scenePropTrailN:
      return <double>[0, AvatarRiveContract.trailMaxDots.toDouble()];
    case AvatarRiveContract.scenePropPokeX:
    case AvatarRiveContract.scenePropPokeY:
    case AvatarRiveContract.scenePropAim:
    case AvatarRiveContract.scenePropLadder:
      return <double>[-1, 1];
    default:
      // cord, rope, poke, spin, trailFade, pinwheel, chain
      return <double>[0, 0.5, 1];
  }
}

/// What a mounted stage heard.
class _Stage {
  final PropDragController drags = PropDragController();
  final List<String> props = <String>[];
  final List<SceneEvent> events = <SceneEvent>[];
  final List<DragHaptic> haptics = <DragHaptic>[];
  final List<String> foley = <String>[];
  final List<String> avatarTaps = <String>[];
}

final GlobalKey _stageKey = GlobalKey();

/// A portrait stage the size of the window's height (9:16, the scene
/// artboard's own ratio, so `Fit.cover` shows all of it).
Size _stageBox(WidgetTester tester) {
  final Size window = tester.view.physicalSize / tester.view.devicePixelRatio;
  final double height = math.min(window.height, 640).floorToDouble();
  return Size(
    height * SceneDrags.artboard.width / SceneDrags.artboard.height,
    height,
  );
}

/// The real scene view (real file, real drag controller) in the top-left
/// corner, optionally with the real avatar view as its `middle` (as Home
/// mounts it, minus the journey layer and the cubits: the avatar gets a
/// fixed default state and talking idle).
Widget _stageApp(
  AvatarScene scene,
  _Stage stage,
  Size box, {
  ({SceneEvent sceneEvent, int seq}) sceneEvent = (
    sceneEvent: SceneEvent.lightsOff,
    seq: 0,
  ),
  bool withAvatar = false,
  Avatar avatar = const Avatar(),
}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Align(
      alignment: Alignment.topLeft,
      child: RepaintBoundary(
        key: _stageKey,
        child: SizedBox.fromSize(
          size: box,
          child: RiveSceneView(
            scene: scene,
            sceneEvent: sceneEvent,
            dragController: stage.drags,
            onPropTapped: stage.props.add,
            onDragEvent: stage.events.add,
            onDragHaptic: stage.haptics.add,
            onDragFoley: stage.foley.add,
            middle: withAvatar
                ? RiveAvatarView(
                    avatarState: AvatarState(
                      avatar: avatar,
                      avatarConfig: const AvatarConfig(),
                      scene: scene,
                    ),
                    talkingState: const TalkingState.idle(),
                    onAvatarTapped: stage.avatarTaps.add,
                  )
                : null,
          ),
        ),
      ),
    ),
  );
}

/// Waits (real time) until [scene]'s file is loaded and its drag handle
/// attached, then lets it draw a few frames.
Future<void> _waitLoaded(
  WidgetTester tester,
  _Stage stage,
  AvatarScene scene,
) async {
  _keepResumed();
  for (int i = 0; i < 200 && stage.drags.scene != scene; i++) {
    await tester.pump(const Duration(milliseconds: 25));
  }
  expect(stage.drags.scene, scene, reason: '${scene.name}.riv loaded');
  await _live(tester, const Duration(milliseconds: 300));
}

/// Keeps the app resumed. The macOS test window can turn inactive mid-run
/// (it loses focus: seen about 30 s into a full run), and both Rive views
/// then pause their controllers, which ignore pointers while paused. These
/// tests are about drags and hit tests, not the lifecycle.
void _keepResumed() {
  final WidgetsBinding binding = WidgetsBinding.instance;
  if (binding.lifecycleState != AppLifecycleState.resumed) {
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  }
}

/// Unmounts the stage (the view lets go of the files).
Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

/// Lets [time] pass for real, frames running.
Future<void> _live(WidgetTester tester, Duration time) async {
  final Stopwatch clock = Stopwatch()..start();
  while (clock.elapsed < time) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// Moves [gesture] from [from] to [to] in [steps] moves, one frame (16 ms,
/// real time) apart. Returns [to].
Future<Offset> _stepTo(
  WidgetTester tester,
  TestGesture gesture,
  Offset from,
  Offset to,
  int steps,
) async {
  for (int i = 1; i <= steps; i++) {
    await gesture.moveTo(Offset.lerp(from, to, i / steps)!);
    await tester.pump(const Duration(milliseconds: 16));
  }
  return to;
}

/// [name] read back from the view model every 8 ms while [action] runs.
Future<List<double>> _sample(
  PropDragController drags,
  String name,
  Future<void> Function() action,
) async {
  final List<double> samples = <double>[];
  void read() {
    final double? v = drags.readNumber(name);
    if (v != null) {
      samples.add(v);
    }
  }

  read();
  final Timer timer = Timer.periodic(
    const Duration(milliseconds: 8),
    (Timer _) => read(),
  );
  await action();
  timer.cancel();
  read();
  return samples;
}

/// Distance between two wrapped 0..1 values.
double _circular(double a, double b) {
  final double d = (a - b).abs() % 1;
  return math.min(d, 1 - d);
}

/// A spin handle: a flick turns with inertia, a slow drag of [turns] (sign =
/// direction) wraps, within 0..1 all along.
Future<void> _spinTest(
  WidgetTester tester,
  AvatarScene scene,
  String spin, {
  required double turns,
}) async {
  final _Stage stage = _Stage();
  final Size box = _stageBox(tester);
  await tester.pumpWidget(_stageApp(scene, stage, box));
  await _waitLoaded(tester, stage, scene);
  final PropDragController drags = stage.drags;
  final double scale = SceneDrags.coverScale(box);
  final Offset centre =
      tester.getTopLeft(find.byType(RiveSceneView)) + drags.handleCentre(box)!;
  expect(drags.readNumber(spin), 0);

  // a flick: released while moving, the bands keep turning
  await tester.timedDragFrom(
    centre,
    Offset(turns.sign * 60, 0),
    const Duration(milliseconds: 120),
  );
  await tester.pump();
  final double atRelease = drags.readNumber(spin)!;
  final List<double> coasting = await _sample(
    drags,
    spin,
    () => _live(tester, const Duration(milliseconds: 1500)),
  );
  final double s1 = drags.readNumber(spin)!;
  expect(s1, isNot(0), reason: 'the flick turned the bands');
  expect(s1, inInclusiveRange(0, 1));
  expect(s1, lessThan(1));
  expect(
    _circular(s1, atRelease),
    greaterThan(0.01),
    reason: 'inertia carried the spin past the release',
  );
  for (final double v in coasting) {
    expect(v, inInclusiveRange(0, 1));
    expect(v, lessThan(1));
  }

  // a slow drag of [turns] turns, held still before the release: it wraps
  final double dx = turns * PropDragPhysics.spinPxPerTurn * scale;
  final TestGesture gesture = await tester.startGesture(centre);
  final int steps = (dx.abs() / 6).ceil();
  final List<double> wrapping = await _sample(drags, spin, () async {
    await _stepTo(tester, gesture, centre, centre + Offset(dx, 0), steps);
    await _live(tester, const Duration(milliseconds: 200));
    await gesture.up();
    await _live(tester, const Duration(milliseconds: 300));
  });
  final double s2 = drags.readNumber(spin)!;
  expect(
    _circular(s2, (s1 + turns) % 1),
    lessThan(0.02),
    reason: 'spin $s1 + $turns turns wraps to ${(s1 + turns) % 1}',
  );
  for (final double v in wrapping) {
    expect(v, inInclusiveRange(0, 1));
    expect(v, lessThan(1));
  }
  expect(stage.haptics, contains(DragHaptic.selection));
  await _unmount(tester);
}

/// An aim handle: a horizontal drag moves [aim] by rect.width artboard px
/// per unit and holds; far left clamps at -1.
Future<void> _aimTest(
  WidgetTester tester,
  AvatarScene scene,
  String aim,
) async {
  final _Stage stage = _Stage();
  final Size box = _stageBox(tester);
  await tester.pumpWidget(_stageApp(scene, stage, box));
  await _waitLoaded(tester, stage, scene);
  final PropDragController drags = stage.drags;
  final double scale = SceneDrags.coverScale(box);
  final Rect rect = SceneDrags.of(scene)!.rect;
  final Offset centre =
      tester.getTopLeft(find.byType(RiveSceneView)) + drags.handleCentre(box)!;
  expect(drags.readNumber(aim), 0);

  const double logical = 40;
  final TestGesture gesture = await tester.startGesture(centre);
  await _stepTo(tester, gesture, centre, centre + const Offset(logical, 0), 8);
  await _live(tester, const Duration(milliseconds: 150));
  await gesture.up();
  await _live(tester, const Duration(milliseconds: 100));
  final double held = drags.readNumber(aim)!;
  expect(
    held,
    closeTo(logical / scale / rect.width, 0.03),
    reason: 'rect.width artboard px per unit',
  );
  await _live(tester, const Duration(milliseconds: 600));
  expect(drags.readNumber(aim), held, reason: '$aim holds');

  // far left: clamped at -1
  await tester.timedDragFrom(
    centre,
    Offset(-1.5 * rect.width * scale, 0),
    const Duration(milliseconds: 500),
  );
  await _live(tester, const Duration(milliseconds: 300));
  expect(drags.readNumber(aim), -1);
  await _unmount(tester);
}

/// A pull: down 66 px (≥ 60, past 0.6 of the 100 artboard px travel at any
/// stage size here), released; the number goes over 0.6 while held, springs
/// back to ~0, and the action fires once.
Future<void> _pullTest(
  WidgetTester tester,
  AvatarScene scene,
  String number,
  SceneEvent action, {
  required List<String> expectedFoley,
}) async {
  final _Stage stage = _Stage();
  final Size box = _stageBox(tester);
  await tester.pumpWidget(_stageApp(scene, stage, box));
  await _waitLoaded(tester, stage, scene);
  final PropDragController drags = stage.drags;
  expect(drags.readNumber(number), 0, reason: '$number default');
  final Offset centre =
      tester.getTopLeft(find.byType(RiveSceneView)) + drags.handleCentre(box)!;

  final List<double> pulled = await _sample(
    drags,
    number,
    () => tester.timedDragFrom(
      centre,
      const Offset(0, 66),
      const Duration(milliseconds: 500),
    ),
  );
  expect(
    pulled.reduce(math.max),
    greaterThan(PropDragPhysics.pullFire),
    reason: '$number during the pull',
  );
  await _live(tester, const Duration(milliseconds: 900));
  expect(
    drags.readNumber(number),
    lessThan(0.02),
    reason: '$number springs back',
  );
  expect(stage.events, <SceneEvent>[action]);
  expect(stage.foley, expectedFoley);
  expect(stage.haptics.first, DragHaptic.selection);
  expect(stage.haptics, contains(DragHaptic.impact));
  expect(
    stage.props,
    isEmpty,
    reason: 'a pull that ends on a prop is not a tap',
  );
  await _unmount(tester);
}

/// A stroke across a trail handle from [from] to [to] (artboard px): dots
/// are laid (trailN >= 4), visible (trailFade ~0), on the stroke's line and
/// inside the handle's rect.
Future<void> _trailStroke(
  WidgetTester tester,
  _Stage stage,
  Size box,
  Offset from,
  Offset to,
) async {
  final PropDragController drags = stage.drags;
  final SceneDragHandle handle = drags.handle!;
  expect(drags.readNumber(AvatarRiveContract.scenePropTrailN), 0);
  expect(drags.readNumber(AvatarRiveContract.scenePropTrailFade), 1);
  final Offset origin = tester.getTopLeft(find.byType(RiveSceneView));
  final Offset start = origin + SceneDrags.toLocal(from, box);
  final Offset end = origin + SceneDrags.toLocal(to, box);
  await tester.timedDragFrom(
    start,
    end - start,
    const Duration(milliseconds: 700),
  );
  await _live(tester, const Duration(milliseconds: 250));
  final int n = drags.readNumber(AvatarRiveContract.scenePropTrailN)!.round();
  expect(n, greaterThanOrEqualTo(4), reason: '${handle.id} trailN');
  expect(n, lessThanOrEqualTo(AvatarRiveContract.trailMaxDots));
  expect(
    drags.readNumber(AvatarRiveContract.scenePropTrailFade),
    lessThan(0.05),
    reason: '${handle.id} dots visible',
  );
  for (int i = 0; i < n; i++) {
    final Offset dot = Offset(
      drags.readNumber(AvatarRiveContract.scenePropTrailX[i])!,
      drags.readNumber(AvatarRiveContract.scenePropTrailY[i])!,
    );
    expect(
      handle.rect.inflate(0.5).contains(dot),
      isTrue,
      reason: '${handle.id} dot $i $dot inside ${handle.rect}',
    );
    // on the stroke's line (the finger path, sampled at 60 Hz)
    final Offset d = to - from;
    final double off =
        ((dot - from).dx * d.dy - (dot - from).dy * d.dx).abs() / d.distance;
    expect(off, lessThan(6), reason: '${handle.id} dot $i $dot on the stroke');
  }
  expect(stage.haptics, contains(DragHaptic.selection));
}

/// The loaded [RiveWidget] controller showing [artboard] (null: none yet).
RiveWidgetController? _rive(WidgetTester tester, String artboard) {
  for (final RiveWidget w in tester.widgetList<RiveWidget>(
    find.byType(RiveWidget),
  )) {
    if (w.controller.artboard.name == artboard) {
      return w.controller;
    }
  }
  return null;
}

/// Delivers the Rive events the last pointers reported now (they are
/// otherwise handed to listeners at the next advance), so each tap's events
/// can be told apart.
void _deliverEvents(WidgetTester tester) {
  for (final String artboard in <String>[
    AvatarRiveContract.sceneArtboard,
    AvatarRiveContract.avatarArtboard,
  ]) {
    _rive(tester, artboard)?.stateMachine.advanceAndApply(0);
  }
}

/// Taps a 30 px grid over the whole scene artboard; returns every `propId`
/// heard with the first artboard point that hit it.
Future<Map<String, Offset>> _scanProps(
  WidgetTester tester,
  _Stage stage,
  Size box,
) async {
  const double step = 30;
  final Offset origin = tester.getTopLeft(find.byType(RiveSceneView));
  final Map<String, Offset> hits = <String, Offset>{};
  for (double y = step / 2; y < SceneDrags.artboard.height; y += step) {
    for (double x = step / 2; x < SceneDrags.artboard.width; x += step) {
      final int before = stage.props.length;
      _keepResumed();
      await tester.tapAt(origin + SceneDrags.toLocal(Offset(x, y), box));
      _deliverEvents(tester);
      for (final String id in stage.props.sublist(before)) {
        hits.putIfAbsent(id, () => Offset(x, y));
      }
    }
    await tester.pump();
  }
  return hits;
}

/// An avatar artboard point (800x1000, contain + bottom-centre) in the
/// stage box.
Offset _avatarToLocal(Offset point, Size box) {
  final double scale = math.min(
    box.width / AvatarRiveContract.journeyArtboardWidth,
    box.height / AvatarRiveContract.journeyArtboardHeight,
  );
  final Offset origin = Offset(
    (box.width - AvatarRiveContract.journeyArtboardWidth * scale) / 2,
    box.height - AvatarRiveContract.journeyArtboardHeight * scale,
  );
  return origin + point * scale;
}

/// Whether a stage [local] point is inside the avatar's HitHead ellipse
/// (400, 360, 300x360) or HitBody rect (400, 820, 460x380) at rest.
bool _inAvatarZone(Offset local, Size box) {
  final double scale = math.min(
    box.width / AvatarRiveContract.journeyArtboardWidth,
    box.height / AvatarRiveContract.journeyArtboardHeight,
  );
  final Offset origin = _avatarToLocal(Offset.zero, box);
  final Offset p = (local - origin) / scale;
  final double ex = (p.dx - 400) / 150;
  final double ey = (p.dy - 360) / 180;
  final bool head = ex * ex + ey * ey <= 1;
  final bool body = Rect.fromCenter(
    center: const Offset(400, 820),
    width: 460,
    height: 380,
  ).contains(p);
  return head || body;
}

/// The stage's rendered pixels (the Rive textures included).
class _Rgba {
  _Rgba(this.bytes, this.width, this.height);

  final Uint8List bytes;
  final int width;
  final int height;

  /// The mean RGB of the 3x3 pixels around [local].
  List<double> mean(Offset local) {
    final List<double> sum = <double>[0, 0, 0];
    int count = 0;
    for (int dy = -1; dy <= 1; dy++) {
      for (int dx = -1; dx <= 1; dx++) {
        final int x = local.dx.round() + dx;
        final int y = local.dy.round() + dy;
        if (x < 0 || y < 0 || x >= width || y >= height) {
          continue;
        }
        final int i = (y * width + x) * 4;
        for (int c = 0; c < 3; c++) {
          sum[c] += bytes[i + c];
        }
        count++;
      }
    }
    return sum.map((double s) => s / math.max(count, 1)).toList();
  }
}

/// Grabs the stage's repaint boundary (`OffsetLayer.toImage` includes the
/// Rive textures; see `support/frame_grabber.dart`) at 1 px per logical px.
Future<_Rgba> _grab(WidgetTester tester) async {
  await tester.pump();
  final RenderRepaintBoundary boundary = tester.renderObject(
    find.byKey(_stageKey),
  );
  final OffsetLayer layer = boundary.debugLayer! as OffsetLayer;
  final ui.Image image = await layer.toImage(Offset.zero & boundary.size);
  final ByteData data = (await image.toByteData())!;
  final _Rgba rgba = _Rgba(
    data.buffer.asUint8List(),
    image.width,
    image.height,
  );
  image.dispose();
  return rgba;
}
