import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:yofardev_ai/core/models/app_lifecycle_event.dart';
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
      tool = AvatarTool();
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
      final StreamSubscription<AvatarChangeRequested> sub =
          lifecycleService.avatarChangeRequestedEvents.listen(events.add);

      // Act - This simulates LLM calling: change_avatar(background="beach")
      final String result = await tool.execute(
        <String, String>{'background': 'beach'},
        <String, dynamic>{}, // No config values needed
      );

      // Assert
      expect(result, isA<String>());
      expect(result, contains('Successfully changed'));
      expect(events, hasLength(1));
      expect(events.single.newConfig.background, equals(AvatarBackgrounds.beach));
      expect(events.single.backgroundOnly, isTrue);
      await sub.cancel();
    });

    // Test 4: Happy path - LLM changes clothes (hat)
    test('execute changes hat when called by LLM', () async {
      // Arrange
      final List<AvatarChangeRequested> events = <AvatarChangeRequested>[];
      final StreamSubscription<AvatarChangeRequested> sub =
          lifecycleService.avatarChangeRequestedEvents.listen(events.add);

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
      final StreamSubscription<AvatarChangeRequested> sub =
          lifecycleService.avatarChangeRequestedEvents.listen(events.add);

      // Act - LLM calls: change_avatar(background="beach", hat="beanie")
      final String result = await tool.execute(<String, String>{
        'background': 'beach',
        'hat': 'beanie',
      }, <String, dynamic>{});

      // Assert
      expect(result, isA<String>());
      expect(result, contains('Successfully changed'));
      expect(events, hasLength(1));
      expect(events.single.newConfig.background, equals(AvatarBackgrounds.beach));
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
    test(
      'configWithAnimation has leaveAndComeBack for background',
      () async {
        // Arrange
        final List<AvatarChangeRequested> events = <AvatarChangeRequested>[];
        final StreamSubscription<AvatarChangeRequested> sub =
            lifecycleService.avatarChangeRequestedEvents.listen(events.add);

        // Act
        await tool.execute(<String, String>{
          'background': 'beach',
        }, <String, dynamic>{});

        // Assert
        expect(events.single.configWithAnimation.specials,
            equals(AvatarSpecials.leaveAndComeBack));
        expect(
            events.single.configWithAnimation.background,
            equals(AvatarBackgrounds.beach));
        await sub.cancel();
      },
    );

    // Test 11: Request includes outOfScreen animation for clothes changes
    test(
      'configWithAnimation has outOfScreen for clothes',
      () async {
        // Arrange
        final List<AvatarChangeRequested> events = <AvatarChangeRequested>[];
        final StreamSubscription<AvatarChangeRequested> sub =
            lifecycleService.avatarChangeRequestedEvents.listen(events.add);

        // Act
        await tool.execute(<String, String>{
          'top': 'longCoat',
        }, <String, dynamic>{});

        // Assert
        expect(events.single.configWithAnimation.specials,
            equals(AvatarSpecials.outOfScreen));
        expect(events.single.configWithAnimation.top, equals(AvatarTop.longCoat));
        await sub.cancel();
      },
    );

    // Test 12: Emits actual avatar config (without animation specials) for persistence
    test(
      'newConfig is the actual avatar config, not the animation config',
      () async {
        // Arrange
        final List<AvatarChangeRequested> events = <AvatarChangeRequested>[];
        final StreamSubscription<AvatarChangeRequested> sub =
            lifecycleService.avatarChangeRequestedEvents.listen(events.add);

        // Act
        await tool.execute(<String, String>{
          'background': 'beach',
          'top': 'longCoat',
        }, <String, dynamic>{});

        // Assert
        // The config persisted should NOT have animation specials
        expect(events.single.newConfig.background, equals(AvatarBackgrounds.beach));
        expect(events.single.newConfig.top, equals(AvatarTop.longCoat));
        expect(events.single.newConfig.specials, isNull); // No animation special
        await sub.cancel();
      },
    );

    // Test 13: Background-only change sets backgroundOnly
    test('background-only change sets backgroundOnly', () async {
      // Arrange
      final List<AvatarChangeRequested> events = <AvatarChangeRequested>[];
      final StreamSubscription<AvatarChangeRequested> sub =
          lifecycleService.avatarChangeRequestedEvents.listen(events.add);

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
      final StreamSubscription<AvatarChangeRequested> sub =
          lifecycleService.avatarChangeRequestedEvents.listen(events.add);

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
}
