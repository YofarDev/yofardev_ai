import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:yofardev_ai/core/models/app_lifecycle_event.dart';
import 'package:yofardev_ai/core/models/avatar_scene.dart';
import 'package:yofardev_ai/core/models/avatar_config.dart';
import 'package:yofardev_ai/core/models/function_info.dart';
import 'package:yofardev_ai/core/services/agent/avatar_tool.dart';
import 'package:yofardev_ai/core/services/app_lifecycle_service.dart';

void main() {
  late final GetIt getIt;
  late AppLifecycleService lifecycleService;

  setUpAll(() {
    getIt = GetIt.instance;
  });

  setUp(() {
    lifecycleService = AppLifecycleService();
    getIt.registerSingleton<AppLifecycleService>(lifecycleService);
  });

  tearDown(() {
    getIt.reset();
    lifecycleService.dispose();
  });

  group('AvatarTool - LLM Function Calling for Background/Clothes', () {
    late AvatarTool tool;

    setUp(() {
      tool = AvatarTool(lifecycleService);
    });

    // Test 1: Tool exists and has correct schema
    test('tool exists with name "change_avatar"', () {
      expect(tool.name, equals('change_avatar'));
      expect(tool.description, isNotEmpty);
    });

    // Test 2: Schema declares all avatar parameters
    test('schema declares background parameter', () {
      final Parameter backgroundParam = tool.parameters.firstWhere(
        (Parameter p) => p.name == 'background',
      );
      expect(backgroundParam.name, equals('background'));
      expect(backgroundParam.type, equals('string'));
    });

    test('schema declares hat parameter', () {
      final Parameter hatParam = tool.parameters.firstWhere(
        (Parameter p) => p.name == 'hat',
      );
      expect(hatParam.name, equals('hat'));
      expect(hatParam.type, equals('string'));
    });

    test('schema declares top parameter', () {
      final Parameter topParam = tool.parameters.firstWhere(
        (Parameter p) => p.name == 'top',
      );
      expect(topParam.name, equals('top'));
      expect(topParam.type, equals('string'));
    });

    // Test 3: Happy path - LLM changes background
    test('execute changes background when called by LLM', () async {
      // Arrange
      final List<AvatarChangeRequested> events = <AvatarChangeRequested>[];
      final StreamSubscription<AvatarChangeRequested> sub = lifecycleService
          .avatarChangeRequestedEvents
          .listen(events.add);

      // Act - This simulates LLM calling: change_avatar(background="beach")
      final String result = await tool.execute(
        <String, String>{'background': 'beach'},
        <String, dynamic>{}, // No config values needed
      );

      // Assert
      expect(result, isA<String>());
      expect(result, contains('Successfully changed'));
      expect(events, hasLength(1));
      expect(events.single.newConfig.background, equals(AvatarScene.beach));
      expect(events.single.backgroundOnly, isTrue);
      await sub.cancel();
    });

    // Test 4: Happy path - LLM changes clothes (hat)
    test('execute changes hat when called by LLM', () async {
      // Arrange
      final List<AvatarChangeRequested> events = <AvatarChangeRequested>[];
      final StreamSubscription<AvatarChangeRequested> sub = lifecycleService
          .avatarChangeRequestedEvents
          .listen(events.add);

      // Act - This simulates LLM calling: change_avatar(hat="frenchBeret")
      final String result = await tool.execute(<String, String>{
        'hat': 'frenchBeret',
      }, <String, dynamic>{});

      // Assert
      expect(result, isA<String>());
      expect(result, contains('Successfully changed'));
      expect(events, hasLength(1));
      expect(events.single.newConfig.hat, equals(AvatarHat.frenchBeret));
      expect(events.single.backgroundOnly, isFalse);
      await sub.cancel();
    });

    // Test 5: LLM changes multiple fields at once
    test('execute changes background and clothes together', () async {
      // Arrange
      final List<AvatarChangeRequested> events = <AvatarChangeRequested>[];
      final StreamSubscription<AvatarChangeRequested> sub = lifecycleService
          .avatarChangeRequestedEvents
          .listen(events.add);

      // Act - LLM calls: change_avatar(background="beach", hat="beanie")
      final String result = await tool.execute(<String, String>{
        'background': 'beach',
        'hat': 'beanie',
      }, <String, dynamic>{});

      // Assert
      expect(result, isA<String>());
      expect(result, contains('Successfully changed'));
      expect(events, hasLength(1));
      expect(events.single.newConfig.background, equals(AvatarScene.beach));
      expect(events.single.newConfig.hat, equals(AvatarHat.beanie));
      expect(events.single.backgroundOnly, isFalse);
      await sub.cancel();
    });

    // Test 6: Invalid background value returns error (not crash)
    test('execute returns error message for invalid background', () async {
      // Act - LLM calls with invalid value
      final String result = await tool.execute(<String, String>{
        'background': 'mars_colony',
      }, <String, dynamic>{});

      // Assert - Should not throw
      expect(result, isA<String>());
      expect(result, contains('Error'));
      expect(result, contains('Invalid background'));
    });

    // Test 7: Tool never throws, always returns result
    test('execute returns error message when emit fails', () async {
      // Arrange - Service disposed so emit throws
      lifecycleService.dispose();

      // Act
      final String result = await tool.execute(<String, String>{
        'background': 'beach',
      }, <String, dynamic>{});

      // Assert - Tool should catch and return error result
      expect(result, isA<String>());
      expect(result, contains('Error'));
    });

    // Test 8: No config keys required
    test('requires no API configuration', () {
      expect(tool.requiredConfigKeys, isEmpty);
    });

    // Test 9: Converts to FunctionInfo correctly
    test('toFunctionInfo creates valid FunctionInfo', () {
      final FunctionInfo functionInfo = tool.toFunctionInfo();

      expect(functionInfo.name, equals('change_avatar'));
      expect(functionInfo.description, isNotEmpty);
      expect(functionInfo.parameters.length, greaterThan(0));
    });

    // Test 10: Request includes leaveAndComeBack animation for background change
    test('configWithAnimation has leaveAndComeBack for background', () async {
      // Arrange
      final List<AvatarChangeRequested> events = <AvatarChangeRequested>[];
      final StreamSubscription<AvatarChangeRequested> sub = lifecycleService
          .avatarChangeRequestedEvents
          .listen(events.add);

      // Act
      await tool.execute(<String, String>{
        'background': 'beach',
      }, <String, dynamic>{});

      // Assert
      expect(
        events.single.configWithAnimation.specials,
        equals(AvatarSpecials.leaveAndComeBack),
      );
      expect(
        events.single.configWithAnimation.background,
        equals(AvatarScene.beach),
      );
      await sub.cancel();
    });

    // Test 11: Request includes outOfScreen animation for clothes changes
    test('configWithAnimation has outOfScreen for clothes', () async {
      // Arrange
      final List<AvatarChangeRequested> events = <AvatarChangeRequested>[];
      final StreamSubscription<AvatarChangeRequested> sub = lifecycleService
          .avatarChangeRequestedEvents
          .listen(events.add);

      // Act
      await tool.execute(<String, String>{
        'top': 'longCoat',
      }, <String, dynamic>{});

      // Assert
      expect(
        events.single.configWithAnimation.specials,
        equals(AvatarSpecials.outOfScreen),
      );
      expect(events.single.configWithAnimation.top, equals(AvatarTop.longCoat));
      await sub.cancel();
    });

    // Test 12: Emits actual avatar config (without animation specials) for persistence
    test(
      'newConfig is the actual avatar config, not the animation config',
      () async {
        // Arrange
        final List<AvatarChangeRequested> events = <AvatarChangeRequested>[];
        final StreamSubscription<AvatarChangeRequested> sub = lifecycleService
            .avatarChangeRequestedEvents
            .listen(events.add);

        // Act
        await tool.execute(<String, String>{
          'background': 'beach',
          'top': 'longCoat',
        }, <String, dynamic>{});

        // Assert
        // The config persisted should NOT have animation specials
        expect(events.single.newConfig.background, equals(AvatarScene.beach));
        expect(events.single.newConfig.top, equals(AvatarTop.longCoat));
        expect(
          events.single.newConfig.specials,
          isNull,
        ); // No animation special
        await sub.cancel();
      },
    );

    // Test 13: Background-only change sets backgroundOnly
    test('background-only change sets backgroundOnly', () async {
      // Arrange
      final List<AvatarChangeRequested> events = <AvatarChangeRequested>[];
      final StreamSubscription<AvatarChangeRequested> sub = lifecycleService
          .avatarChangeRequestedEvents
          .listen(events.add);

      // Act
      await tool.execute(<String, String>{
        'background': 'beach',
      }, <String, dynamic>{});

      // Assert
      expect(events.single.backgroundOnly, isTrue);
      await sub.cancel();
    });

    // Test 14: Multiple changes do not set backgroundOnly
    test('multiple changes do not set backgroundOnly', () async {
      // Arrange
      final List<AvatarChangeRequested> events = <AvatarChangeRequested>[];
      final StreamSubscription<AvatarChangeRequested> sub = lifecycleService
          .avatarChangeRequestedEvents
          .listen(events.add);

      // Act
      await tool.execute(<String, String>{
        'background': 'beach',
        'hat': 'beanie',
      }, <String, dynamic>{});

      // Assert
      expect(events.single.backgroundOnly, isFalse);
      await sub.cancel();
    });
  });

  group('AvatarTool schema matches the Dart enums', () {
    late AvatarTool tool;

    setUp(() {
      tool = AvatarTool(lifecycleService);
    });

    test('background options are exactly the AvatarScene values', () {
      final Parameter parameter = tool.parameters.firstWhere(
        (Parameter p) => p.name == 'background',
      );
      for (final AvatarScene scene in AvatarScene.values) {
        expect(parameter.description, contains(scene.name));
      }
      expect(parameter.description, isNot(contains('snowyMountain')));
      expect(parameter.description, isNot(contains('pirate')));
    });

    test('hat options are exactly the AvatarHat values', () {
      final Parameter parameter = tool.parameters.firstWhere(
        (Parameter p) => p.name == 'hat',
      );
      for (final AvatarHat hat in AvatarHat.values) {
        expect(parameter.description, contains(hat.name));
      }
      expect(parameter.description, isNot(contains('crown')));
    });

    test('top options are exactly the AvatarTop values', () {
      final Parameter parameter = tool.parameters.firstWhere(
        (Parameter p) => p.name == 'top',
      );
      for (final AvatarTop top in AvatarTop.values) {
        expect(parameter.description, contains(top.name));
      }
      expect(parameter.description, isNot(contains('space_suit')));
    });

    test('glasses options are exactly the AvatarGlasses values', () {
      final Parameter parameter = tool.parameters.firstWhere(
        (Parameter p) => p.name == 'glasses',
      );
      for (final AvatarGlasses glasses in AvatarGlasses.values) {
        expect(parameter.description, contains(glasses.name));
      }
      expect(parameter.description, isNot(contains('monocle')));
    });

    test('costume options are exactly the AvatarCostume values', () {
      final Parameter parameter = tool.parameters.firstWhere(
        (Parameter p) => p.name == 'costume',
      );
      for (final AvatarCostume costume in AvatarCostume.values) {
        expect(parameter.description, contains(costume.name));
      }
      expect(parameter.description, isNot(contains('pirate')));
    });

    test('topTint and hatTint options are exactly the AvatarTint values', () {
      for (final String name in <String>['topTint', 'hatTint']) {
        final Parameter parameter = tool.parameters.firstWhere(
          (Parameter p) => p.name == name,
        );
        expect(parameter.type, 'string');
        expect(parameter.isRequired, isFalse);
        expect(
          parameter.description,
          contains(
            'Options: ${AvatarTint.values.map((AvatarTint t) => t.name).join(', ')}',
          ),
          reason: name,
        );
      }
    });

    test('a tint is a clothes change: the avatar walks off and back', () async {
      final List<AvatarChangeRequested> events = <AvatarChangeRequested>[];
      final StreamSubscription<AvatarChangeRequested> sub = lifecycleService
          .avatarChangeRequestedEvents
          .listen(events.add);
      final String result = await tool.execute(<String, dynamic>{
        'topTint': 'teal',
        'hatTint': 'Pink',
      }, <String, dynamic>{});
      await Future<void>.delayed(Duration.zero);
      expect(result, startsWith('Successfully changed'));
      expect(events, hasLength(1));
      expect(events.single.newConfig.topTint, AvatarTint.teal);
      expect(events.single.newConfig.hatTint, AvatarTint.pink);
      expect(events.single.newConfig.top, isNull);
      expect(
        events.single.configWithAnimation.specials,
        AvatarSpecials.outOfScreen,
      );
      expect(events.single.backgroundOnly, isFalse);
      await sub.cancel();
    });

    test('an unknown tint is an error and changes nothing', () async {
      final List<AvatarChangeRequested> events = <AvatarChangeRequested>[];
      final StreamSubscription<AvatarChangeRequested> sub = lifecycleService
          .avatarChangeRequestedEvents
          .listen(events.add);
      final String result = await tool.execute(<String, dynamic>{
        'topTint': 'chartreuse',
      }, <String, dynamic>{});
      await Future<void>.delayed(Duration.zero);
      expect(result, startsWith('Error: Invalid topTint'));
      expect(events, isEmpty);
      await sub.cancel();
    });

    test('execute accepts every enum value name for each parameter', () async {
      final List<(String, List<String>)> cases = <(String, List<String>)>[
        (
          'background',
          AvatarScene.values.map((AvatarScene v) => v.name).toList(),
        ),
        ('hat', AvatarHat.values.map((AvatarHat v) => v.name).toList()),
        ('top', AvatarTop.values.map((AvatarTop v) => v.name).toList()),
        (
          'glasses',
          AvatarGlasses.values.map((AvatarGlasses v) => v.name).toList(),
        ),
        (
          'costume',
          AvatarCostume.values.map((AvatarCostume v) => v.name).toList(),
        ),
        (
          'specials',
          AvatarSpecials.values.map((AvatarSpecials v) => v.name).toList(),
        ),
        ('topTint', AvatarTint.values.map((AvatarTint v) => v.name).toList()),
        ('hatTint', AvatarTint.values.map((AvatarTint v) => v.name).toList()),
      ];
      for (final (String, List<String>) entry in cases) {
        for (final String value in entry.$2) {
          final String result = await tool.execute(<String, dynamic>{
            entry.$1: value,
          }, <String, dynamic>{});
          expect(
            result,
            startsWith('Successfully changed'),
            reason: '${entry.$1}=$value should be accepted, got: $result',
          );
        }
      }
    });
  });
}
