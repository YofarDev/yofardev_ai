import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/models/avatar_scene.dart';
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
            'lookId': 'cel',
            'scene': 'beach',
            'layout': 'dock',
            'composer': 'speaking',
            'tab': 'stage',
            'accentHueOverride': '120.5',
            'glassAlphaScale': '1.5',
            'radiusScaleOverride': '0.8',
          });
      expect(r.errorCode, isNull);
      expect(notifier.value.lookId, 'cel');
      expect(notifier.value.scene, AvatarScene.beach);
      expect(notifier.value.layout, LabLayout.dock);
      expect(notifier.value.composer, LabComposerState.speaking);
      expect(notifier.value.tab, LabTab.stage);
      expect(notifier.value.accentHueOverride, 120.5);
      expect(notifier.value.glassAlphaScale, 1.5);
      expect(notifier.value.radiusScaleOverride, 0.8);
      expect(_decode(r), notifier.value.toJson());
    });

    test('keeps untouched fields and clears overrides with "null"', () {
      final ValueNotifier<LabConfig> notifier = ValueNotifier<LabConfig>(
        LabConfig.initial.copyWith(accentHueOverride: 10),
      );
      labConfigureResponse(notifier, <String, String>{'lookId': 'storybook'});
      expect(notifier.value.accentHueOverride, 10);
      labConfigureResponse(notifier, <String, String>{
        'accentHueOverride': 'null',
      });
      expect(notifier.value.accentHueOverride, isNull);
      expect(notifier.value.lookId, 'storybook');
    });

    test('ignores the isolateId the VM service adds', () {
      final ValueNotifier<LabConfig> notifier = ValueNotifier<LabConfig>(
        LabConfig.initial,
      );
      final developer.ServiceExtensionResponse r = labConfigureResponse(
        notifier,
        <String, String>{'isolateId': 'isolates/1', 'lookId': 'cel'},
      );
      expect(r.errorCode, isNull);
      expect(notifier.value.lookId, 'cel');
    });

    for (final Map<String, String> bad in <Map<String, String>>[
      <String, String>{'lookId': 'nope'},
      <String, String>{'bogus': '1'},
      <String, String>{'scene': 'mars'},
      <String, String>{'accentHueOverride': 'abc'},
      <String, String>{'accentHueOverride': '400'},
      <String, String>{'glassAlphaScale': 'null'},
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

    test('returns an error when no lab is mounted', () {
      final developer.ServiceExtensionResponse r = labConfigureResponse(
        null,
        <String, String>{'lookId': 'cel'},
      );
      expect(r.errorCode, developer.ServiceExtensionResponse.extensionError);
    });
  });

  group('labStateResponse', () {
    test('returns the current config JSON', () {
      final ValueNotifier<LabConfig> notifier = ValueNotifier<LabConfig>(
        LabConfig.initial.copyWith(lookId: 'cel'),
      );
      expect(_decode(labStateResponse(notifier)), notifier.value.toJson());
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
