import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/models/avatar_config.dart';
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

    test('fog sets the world state and shows in the response (M8)', () {
      final WorldStateService world = WorldStateService();
      addTearDown(world.dispose);
      final ValueNotifier<LabConfig> notifier = ValueNotifier<LabConfig>(
        LabConfig.initial,
      );
      final developer.ServiceExtensionResponse r = labConfigureResponse(
        notifier,
        <String, String>{'fog': '0.6'},
        world: world,
      );
      expect(r.errorCode, isNull);
      expect(world.fog.value, 0.6);
      expect(_decode(r)['fog'], 0.6);
      expect(_decode(labStateResponse(notifier, world: world))['fog'], 0.6);
      // a bad fog leaves the rain alone too
      final developer.ServiceExtensionResponse bad = labConfigureResponse(
        notifier,
        <String, String>{'rain': '0.5', 'fog': '2'},
        world: world,
      );
      expect(bad.errorCode, developer.ServiceExtensionResponse.extensionError);
      expect(world.rain.value, 0);
      expect(world.fog.value, 0.6);
      expect(
        labConfigureResponse(notifier, <String, String>{
          'fog': '0.5',
        }).errorCode,
        developer.ServiceExtensionResponse.extensionError,
      );
    });

    test('npc poses the scene NPC by hand and clears with null (M8)', () {
      final ValueNotifier<LabConfig> notifier = ValueNotifier<LabConfig>(
        LabConfig.initial,
      );
      final developer.ServiceExtensionResponse r = labConfigureResponse(
        notifier,
        <String, String>{'npc': '{"npc":"notice","npcX":0.5,"npcLook":-1}'},
      );
      expect(r.errorCode, isNull);
      expect(
        notifier.value.npc,
        const NpcIntent(npc: NpcState.notice, npcX: 0.5, npcLook: -1),
      );
      expect(_decode(r)['npc'], <String, Object?>{
        'npc': 'notice',
        'npcX': 0.5,
        'npcLook': -1.0,
      });
      labConfigureResponse(notifier, <String, String>{'npc': '{"npcX":1}'});
      expect(notifier.value.npc, const NpcIntent(npcX: 1));
      for (final String bad in <String>[
        '{"npc":"sleep"}',
        '{"npcX":2}',
        '{"npcLook":-3}',
        '{"other":1}',
        '[1]',
      ]) {
        expect(
          labConfigureResponse(notifier, <String, String>{
            'npc': bad,
          }).errorCode,
          developer.ServiceExtensionResponse.extensionError,
          reason: bad,
        );
      }
      expect(notifier.value.npc, const NpcIntent(npcX: 1));
      labConfigureResponse(notifier, <String, String>{'npc': 'null'});
      expect(notifier.value.npc, isNull);
    });

    test('npc2 poses the gulls by state name or object, null clears (M9)', () {
      final ValueNotifier<LabConfig> notifier = ValueNotifier<LabConfig>(
        LabConfig.initial.copyWith(scene: AvatarScene.beach),
      );
      expect(notifier.value.npc2, isNull);
      expect(
        labConfigureResponse(notifier, <String, String>{
          'npc2': 'react',
        }).errorCode,
        isNull,
      );
      expect(notifier.value.npc2, const NpcIntent(npc: NpcState.react));
      labConfigureResponse(notifier, <String, String>{'npc2': 'move'});
      expect(
        notifier.value.npc2,
        const NpcIntent(npc: NpcState.move, npcX: 0.5),
      );
      labConfigureResponse(notifier, <String, String>{'npc2': 'away'});
      expect(notifier.value.npc2, const NpcIntent(npc: NpcState.away));
      final developer.ServiceExtensionResponse r = labConfigureResponse(
        notifier,
        <String, String>{'npc2': '{"npc":"move","npcX":0.8,"npcLook":0.5}'},
      );
      expect(
        notifier.value.npc2,
        const NpcIntent(npc: NpcState.move, npcX: 0.8, npcLook: 0.5),
      );
      expect(_decode(r)['npc2'], <String, Object?>{
        'npc': 'move',
        'npcX': 0.8,
        'npcLook': 0.5,
      });
      // npc is untouched by npc2
      expect(notifier.value.npc, isNull);
      labConfigureResponse(notifier, <String, String>{'npc2': 'null'});
      expect(notifier.value.npc2, isNull);
      labConfigureResponse(notifier, <String, String>{'npc2': 'idle'});
      labConfigureResponse(notifier, <String, String>{'npc2': ''});
      expect(notifier.value.npc2, isNull);
      for (final String bad in <String>[
        'sleep',
        '{"npc":"sleep"}',
        '{"npcX":2}',
        '{"bogus":1}',
      ]) {
        final developer.ServiceExtensionResponse e = labConfigureResponse(
          notifier,
          <String, String>{'npc2': bad},
        );
        expect(
          e.errorCode,
          developer.ServiceExtensionResponse.extensionError,
          reason: bad,
        );
      }
      expect(notifier.value.npc2, isNull);
    });

    group('the sky params (M9)', () {
      late ValueNotifier<LabConfig> notifier;
      late WorldStateService world;
      setUp(() {
        notifier = ValueNotifier<LabConfig>(LabConfig.initial);
        world = WorldStateService(now: () => DateTime(2026, 10, 26, 21, 15));
      });
      tearDown(() => world.dispose());

      test(
        'moonPhase and festive are held, and null returns to the calendar',
        () {
          final developer.ServiceExtensionResponse r = labConfigureResponse(
            notifier,
            <String, String>{'moonPhase': '0.25', 'festive': '1'},
            world: world,
          );
          expect(r.errorCode, isNull);
          expect(world.moonPhase.value, 0.25);
          expect(world.festive.value, 1);
          expect(_decode(r)['moonPhase'], 0.25);
          expect(_decode(r)['festive'], 1);
          expect(
            _decode(labStateResponse(notifier, world: world))['moonPhase'],
            0.25,
          );
          labConfigureResponse(notifier, <String, String>{
            'moonPhase': '-1',
          }, world: world);
          expect(world.moonPhase.value, -1, reason: '-1 = as drawn');
          labConfigureResponse(notifier, <String, String>{
            'moonPhase': 'null',
            'festive': '',
          }, world: world);
          expect(world.moonPhase.value, closeTo(0.5, 1 / 29.53));
          expect(world.festive.value, 0);
        },
      );

      test('date pins the clock date and keeps the time of day', () {
        final developer.ServiceExtensionResponse r = labConfigureResponse(
          notifier,
          <String, String>{'date': '2026-12-24'},
          world: world,
        );
        expect(r.errorCode, isNull);
        expect(world.localNow, DateTime(2026, 12, 24, 21, 15));
        expect(world.festive.value, 1);
        expect(world.localDay.value, DateTime(2026, 12, 24));
        expect(_decode(r)['date'], '2026-12-24');
        expect(
          _decode(labStateResponse(notifier, world: world))['date'],
          '2026-12-24',
        );
        labConfigureResponse(notifier, <String, String>{
          'date': 'null',
        }, world: world);
        expect(world.localNow, DateTime(2026, 10, 26, 21, 15));
        expect(world.festive.value, 0);
      });

      test('a date moves the moon: the known full moons are full', () {
        labConfigureResponse(notifier, <String, String>{
          'date': '2026-11-24',
        }, world: world);
        expect(world.moonPhase.value, closeTo(0.5, 1 / 29.53));
      });

      for (final Map<String, String> bad in <Map<String, String>>[
        <String, String>{'moonPhase': '1.5'},
        <String, String>{'moonPhase': '-2'},
        <String, String>{'moonPhase': 'full'},
        <String, String>{'festive': '2'},
        <String, String>{'festive': '-0.1'},
        <String, String>{'date': '2026-13-01'},
        <String, String>{'date': '2026-02-30'},
        <String, String>{'date': '24/12/2026'},
        <String, String>{'date': '2026-12-24T10:00'},
      ]) {
        test('$bad is an error and changes nothing', () {
          final developer.ServiceExtensionResponse r = labConfigureResponse(
            notifier,
            <String, String>{...bad, 'scene': 'beach'},
            world: world,
          );
          expect(
            r.errorCode,
            developer.ServiceExtensionResponse.extensionError,
          );
          expect(notifier.value.scene, isNot(AvatarScene.beach));
          expect(world.moonPhase.value, closeTo(0.5, 1 / 29.53));
          expect(world.festive.value, 0);
          expect(world.localNow, DateTime(2026, 10, 26, 21, 15));
        });
      }

      test('without a world they are errors', () {
        for (final Map<String, String> params in <Map<String, String>>[
          <String, String>{'moonPhase': '0.5'},
          <String, String>{'festive': '1'},
          <String, String>{'date': '2026-12-24'},
        ]) {
          expect(
            labConfigureResponse(notifier, params).errorCode,
            developer.ServiceExtensionResponse.extensionError,
            reason: '$params',
          );
        }
      });
    });

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

    test('shot frames the camera and rejects unknown names', () {
      final ValueNotifier<LabConfig> notifier = ValueNotifier<LabConfig>(
        LabConfig.initial,
      );
      for (final String name in <String>[
        'medium',
        'closeUp',
        'propInsert',
        'wide',
      ]) {
        final developer.ServiceExtensionResponse r = labConfigureResponse(
          notifier,
          <String, String>{'shot': name},
        );
        expect(r.errorCode, isNull);
        expect(notifier.value.shot.name, name);
        expect(_decode(labStateResponse(notifier))['shot'], name);
      }
      labConfigureResponse(notifier, <String, String>{'shot': 'closeUp'});
      final developer.ServiceExtensionResponse bad = labConfigureResponse(
        notifier,
        <String, String>{'shot': 'dolly'},
      );
      expect(bad.errorCode, developer.ServiceExtensionResponse.extensionError);
      expect(notifier.value.shot.name, 'closeUp');
    });

    test('topTint and hatTint tint the stage avatar; unknown names are '
        'errors (M10)', () {
      final ValueNotifier<LabConfig> notifier = ValueNotifier<LabConfig>(
        LabConfig.initial,
      );
      expect(notifier.value.topTint, AvatarTint.none);
      final developer.ServiceExtensionResponse r = labConfigureResponse(
        notifier,
        <String, String>{'topTint': 'teal', 'hatTint': 'pink'},
      );
      expect(r.errorCode, isNull);
      expect(notifier.value.topTint, AvatarTint.teal);
      expect(notifier.value.hatTint, AvatarTint.pink);
      final Map<String, Object?> state = _decode(labStateResponse(notifier));
      expect(state['topTint'], 'teal');
      expect(state['hatTint'], 'pink');
      // another key keeps them
      labConfigureResponse(notifier, <String, String>{'scene': 'beach'});
      expect(notifier.value.topTint, AvatarTint.teal);
      final developer.ServiceExtensionResponse bad = labConfigureResponse(
        notifier,
        <String, String>{'topTint': 'chartreuse'},
      );
      expect(bad.errorCode, developer.ServiceExtensionResponse.extensionError);
      expect(notifier.value.topTint, AvatarTint.teal);
      labConfigureResponse(notifier, <String, String>{'topTint': 'none'});
      expect(notifier.value.topTint, AvatarTint.none);
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
