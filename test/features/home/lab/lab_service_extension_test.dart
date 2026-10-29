import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/models/avatar_scene.dart';
import 'package:yofardev_ai/core/models/performance/avatar_prop.dart';
import 'package:yofardev_ai/core/services/world/world_state_service.dart';
import 'package:yofardev_ai/features/avatar/avatar.dart';
import 'package:yofardev_ai/features/home/widgets/lab/lab_config.dart';
import 'package:yofardev_ai/features/home/widgets/lab/lab_service_extension.dart';

Map<String, Object?> _decode(developer.ServiceExtensionResponse r) =>
    (jsonDecode(r.result!) as Map<dynamic, dynamic>).cast<String, Object?>();

void main() {
  group('labConfigureResponse', () {
    test('merges params into the notifier and returns the new config', () {
      final ValueNotifier<LabConfig> notifier = ValueNotifier<LabConfig>(
        LabConfig.initial,
      );
      final developer.ServiceExtensionResponse r =
          labConfigureResponse(notifier, <String, String>{
            'scene': 'beach',
            'layout': 'dock',
            'composer': 'speaking',
            'tab': 'surfaces',
            'accentHueOverride': '120.5',
            'glassAlphaScale': '1.5',
            'radiusScaleOverride': '0.8',
            'panelCollapsed': 'true',
          });
      expect(r.errorCode, isNull);
      expect(notifier.value.scene, AvatarScene.beach);
      expect(notifier.value.layout, LabLayout.dock);
      expect(notifier.value.composer, LabComposerState.speaking);
      expect(notifier.value.tab, LabTab.surfaces);
      expect(notifier.value.accentHueOverride, 120.5);
      expect(notifier.value.glassAlphaScale, 1.5);
      expect(notifier.value.radiusScaleOverride, 0.8);
      expect(notifier.value.panelCollapsed, isTrue);
      expect(_decode(r), notifier.value.toJson());

      labConfigureResponse(notifier, <String, String>{
        'panelCollapsed': 'false',
      });
      expect(notifier.value.panelCollapsed, isFalse);
    });

    test('keeps untouched fields and clears overrides with "null"', () {
      final ValueNotifier<LabConfig> notifier = ValueNotifier<LabConfig>(
        LabConfig.initial.copyWith(accentHueOverride: 10),
      );
      labConfigureResponse(notifier, <String, String>{'scene': 'campfire'});
      expect(notifier.value.accentHueOverride, 10);
      labConfigureResponse(notifier, <String, String>{
        'accentHueOverride': 'null',
      });
      expect(notifier.value.accentHueOverride, isNull);
      expect(notifier.value.scene, AvatarScene.campfire);
    });

    test('rain sets the world state and shows in the response and state', () {
      final WorldStateService world = WorldStateService();
      addTearDown(world.dispose);
      final ValueNotifier<LabConfig> notifier = ValueNotifier<LabConfig>(
        LabConfig.initial,
      );
      final developer.ServiceExtensionResponse r = labConfigureResponse(
        notifier,
        <String, String>{'rain': '0.7', 'scene': 'beach'},
        world: world,
      );
      expect(r.errorCode, isNull);
      expect(world.rain.value, 0.7);
      expect(notifier.value.scene, AvatarScene.beach);
      expect(_decode(r)['rain'], 0.7);
      expect(_decode(labStateResponse(notifier, world: world))['rain'], 0.7);
    });

    for (final String bad in <String>['abc', '1.5', '-0.1', '']) {
      test('rain "$bad" is an error and changes nothing', () {
        final WorldStateService world = WorldStateService()..setRain(0.2);
        addTearDown(world.dispose);
        final ValueNotifier<LabConfig> notifier = ValueNotifier<LabConfig>(
          LabConfig.initial,
        );
        final developer.ServiceExtensionResponse r = labConfigureResponse(
          notifier,
          <String, String>{'rain': bad, 'scene': 'beach'},
          world: world,
        );
        expect(r.errorCode, developer.ServiceExtensionResponse.extensionError);
        expect(world.rain.value, 0.2);
        expect(notifier.value, LabConfig.initial);
      });
    }

    test('rain without a world is an error', () {
      final ValueNotifier<LabConfig> notifier = ValueNotifier<LabConfig>(
        LabConfig.initial,
      );
      final developer.ServiceExtensionResponse r = labConfigureResponse(
        notifier,
        <String, String>{'rain': '0.5'},
      );
      expect(r.errorCode, developer.ServiceExtensionResponse.extensionError);
    });

    test('ignores the isolateId the VM service adds', () {
      final ValueNotifier<LabConfig> notifier = ValueNotifier<LabConfig>(
        LabConfig.initial,
      );
      final developer.ServiceExtensionResponse r = labConfigureResponse(
        notifier,
        <String, String>{'isolateId': 'isolates/1', 'scene': 'beach'},
      );
      expect(r.errorCode, isNull);
      expect(notifier.value.scene, AvatarScene.beach);
    });

    for (final Map<String, String> bad in <Map<String, String>>[
      <String, String>{'lookId': 'storybook'},
      <String, String>{'bogus': '1'},
      <String, String>{'scene': 'mars'},
      <String, String>{'accentHueOverride': 'abc'},
      <String, String>{'accentHueOverride': '400'},
      <String, String>{'glassAlphaScale': 'null'},
      <String, String>{'panelCollapsed': 'maybe'},
      <String, String>{'face': '{"auJawDrop":2}'},
      <String, String>{'face': '{"nope":0}'},
      <String, String>{'face': '{"auJawDrop":'},
      <String, String>{'face': '[1]'},
      <String, String>{'prop': 'telescope'},
      <String, String>{'prop': ''},
      <String, String>{'parallax': '{"x":1.5}'},
      <String, String>{'parallax': '{"z":0.1}'},
      <String, String>{'parallax': '{"x":"left"}'},
      <String, String>{'parallax': '[0.1,0.2]'},
      <String, String>{'parallax': '{"x":'},
    ]) {
      test('returns an error and leaves the config alone for $bad', () {
        final ValueNotifier<LabConfig> notifier = ValueNotifier<LabConfig>(
          LabConfig.initial,
        );
        final developer.ServiceExtensionResponse r = labConfigureResponse(
          notifier,
          bad,
        );
        expect(r.errorCode, developer.ServiceExtensionResponse.extensionError);
        expect(r.result, isNull);
        expect(notifier.value, LabConfig.initial);
      });
    }

    test('prop and parallax round-trip through configure and state', () {
      final ValueNotifier<LabConfig> notifier = ValueNotifier<LabConfig>(
        LabConfig.initial,
      );
      final developer.ServiceExtensionResponse r = labConfigureResponse(
        notifier,
        <String, String>{
          'scene': 'campfire',
          'prop': 'tablet',
          'parallax': '{"x":0.5,"y":-0.25}',
        },
      );
      expect(r.errorCode, isNull);
      expect(notifier.value.prop, AvatarProp.tablet);
      expect(notifier.value.parallax, const Offset(0.5, -0.25));
      final Map<String, Object?> state = _decode(labStateResponse(notifier));
      expect(state['prop'], 'tablet');
      expect(state['parallax'], <String, Object?>{'x': 0.5, 'y': -0.25});
      expect(LabConfig.fromJson(state), notifier.value);

      // A missing axis is 0; the other params keep prop and parallax.
      labConfigureResponse(notifier, <String, String>{
        'parallax': '{"y":0.75}',
      });
      expect(notifier.value.parallax, const Offset(0, 0.75));
      labConfigureResponse(notifier, <String, String>{'scene': 'beach'});
      expect(notifier.value.prop, AvatarProp.tablet);

      labConfigureResponse(notifier, <String, String>{
        'prop': 'none',
        'parallax': 'null',
      });
      expect(notifier.value.prop, AvatarProp.none);
      expect(notifier.value.parallax, isNull);
    });

    test('a face object sets the lab face; null goes back to live', () {
      final ValueNotifier<LabConfig> notifier = ValueNotifier<LabConfig>(
        LabConfig.initial,
      );
      final developer.ServiceExtensionResponse r = labConfigureResponse(
        notifier,
        <String, String>{
          'face': '{"auJawDrop":0.5,"auBrowOuterUpR":0.3,"roll":0.2}',
        },
      );
      expect(r.errorCode, isNull);
      final FaceFrame face = notifier.value.face!;
      expect(face.au.jawDrop, 0.5);
      expect(face.right.browOuterUp, 0.3);
      expect(face.roll, 0.2);
      final Map<String, Object?> faceJson =
          (_decode(r)['face']! as Map<dynamic, dynamic>)
              .cast<String, Object?>();
      expect(faceJson['auBrowOuterUpR'], 0.3);
      expect(faceJson['blink'], 0);

      labConfigureResponse(notifier, <String, String>{'face': 'null'});
      expect(notifier.value.face, isNull);
    });

    test('a face without a blink count keeps the current one', () {
      final ValueNotifier<LabConfig> notifier = ValueNotifier<LabConfig>(
        LabConfig.initial.copyWith(
          face: LabFace.withBlink(LabFace.withBlink(LabFace.base)),
        ),
      );
      labConfigureResponse(notifier, <String, String>{
        'face': '{"auJawDrop":0.2}',
      });
      expect(notifier.value.face!.blinkSerial, 2);
      expect(notifier.value.face!.au.jawDrop, 0.2);
      labConfigureResponse(notifier, <String, String>{'face': '{"blink":3}'});
      expect(notifier.value.face!.blinkSerial, 3);
      expect(notifier.value.face!.au.jawDrop, 0);
    });

    test('returns an error when no lab is mounted', () {
      final developer.ServiceExtensionResponse r = labConfigureResponse(
        null,
        <String, String>{'scene': 'beach'},
      );
      expect(r.errorCode, developer.ServiceExtensionResponse.extensionError);
    });
  });

  group('labStateResponse', () {
    test('returns the current config JSON', () {
      final ValueNotifier<LabConfig> notifier = ValueNotifier<LabConfig>(
        LabConfig.initial.copyWith(scene: AvatarScene.campfire),
      );
      expect(_decode(labStateResponse(notifier)), notifier.value.toJson());
    });

    test('reports the lab face by contract names', () {
      final ValueNotifier<LabConfig> notifier = ValueNotifier<LabConfig>(
        LabConfig.initial.copyWith(
          face: LabFace.withValue(LabFace.base, 'auLidTightenL', -0.5),
        ),
      );
      final Map<String, Object?> state = _decode(labStateResponse(notifier));
      expect(state, notifier.value.toJson());
      expect((state['face']! as Map<dynamic, dynamic>)['auLidTightenL'], -0.5);
    });

    test('returns an error when no lab is mounted', () {
      expect(
        labStateResponse(null).errorCode,
        developer.ServiceExtensionResponse.extensionError,
      );
    });
  });

  group('registration', () {
    test('is idempotent and routes to the latest mounted notifier', () {
      final ValueNotifier<LabConfig> first = ValueNotifier<LabConfig>(
        LabConfig.initial,
      );
      final ValueNotifier<LabConfig> second = ValueNotifier<LabConfig>(
        LabConfig.initial,
      );
      registerUiLabExtensions(first);
      registerUiLabExtensions(second);
      expect(activeUiLabConfig, same(second));

      // Unmounting a lab that is no longer the active one changes nothing.
      unregisterUiLabExtensions(first);
      expect(activeUiLabConfig, same(second));
      unregisterUiLabExtensions(second);
      expect(activeUiLabConfig, isNull);
    });
  });
}
