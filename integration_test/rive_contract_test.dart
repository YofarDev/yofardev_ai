import 'package:flutter_test/flutter_test.dart';
import 'package:rive/rive.dart';
import 'package:yofardev_ai/features/avatar/presentation/rive/avatar_rive_contract.dart';

/// Keeps the `.riv` files in line with `rive/CONTRACT.md`: every name in
/// [AvatarRiveContract] must exist in the shipped assets.
///
/// Runs on macOS (`flutter test integration_test/rive_contract_test.dart
/// -d macos`). Rive listener event names can't be enumerated through the
/// runtime API, so only the data-binding surface is asserted: artboards,
/// state machines, view model property names, and every enum value (read
/// back after setting it).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
      };
      enumProperties.forEach((String property, List<String> values) {
        final ViewModelInstanceEnum? enumProperty = vmi.enumerator(property);
        expect(
          enumProperty,
          isNotNull,
          reason: '$property is not a VM enum property',
        );
        for (final String value in values) {
          enumProperty!.value = value;
          expect(
            enumProperty.value,
            value,
            reason: '$property rejected value "$value"',
          );
        }
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
        for (final String name in AvatarRiveContract.sceneLightProps) {
          expect(names, contains(name), reason: 'SceneVM.$name in $sceneId');
        }

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

        vmi.dispose();
        controller.dispose();
        file.dispose();
      });
    }
  });
}
