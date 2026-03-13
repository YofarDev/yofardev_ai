import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:get_it/get_it.dart';
import 'package:yofardev_ai/core/models/avatar_config.dart';
import 'package:yofardev_ai/core/models/chat.dart';
import 'package:yofardev_ai/core/models/function_info.dart';
import 'package:yofardev_ai/core/services/agent/avatar_tool.dart';
import 'package:yofardev_ai/core/services/avatar_animation_service.dart';
import 'package:yofardev_ai/features/avatar/domain/models/avatar_animation.dart';
import 'package:yofardev_ai/features/chat/presentation/bloc/chat_cubit.dart';
import 'package:yofardev_ai/features/chat/presentation/bloc/chat_state.dart';

class MockChatCubit extends Mock implements ChatCubit {
  @override
  Stream<ChatState> get stream => const Stream<ChatState>.empty();
}

class MockAvatarAnimationService extends Mock
    implements AvatarAnimationService {
  @override
  Stream<AvatarAnimation> get animations =>
      const Stream<AvatarAnimation>.empty();
}

void main() {
  late final GetIt getIt;
  late MockChatCubit mockCubit;
  late MockAvatarAnimationService mockAnimationService;

  setUpAll(() {
    // Initialize a test GetIt instance
    getIt = GetIt.instance;

    // Register fallback values for mocktail
    registerFallbackValue(AvatarBackgrounds.lake);
    registerFallbackValue(const AvatarConfig());
  });

  setUp(() {
    mockCubit = MockChatCubit();
    mockAnimationService = MockAvatarAnimationService();
    // Register the mocks in getIt
    getIt.registerSingleton<ChatCubit>(mockCubit);
    getIt.registerSingleton<AvatarAnimationService>(mockAnimationService);
  });

  tearDown(() {
    // Reset getIt after each test
    getIt.reset();
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
      when(
        () => mockCubit.updateBackgroundOpenedChat(any()),
      ).thenAnswer((_) async {});
      when(
        () => mockCubit.openedChat,
      ).thenReturn(const Chat(id: 'chat1', avatar: Avatar()));

      // Act - This simulates LLM calling: change_avatar(background="beach")
      final String result = await tool.execute(
        <String, String>{'background': 'beach'},
        <String, dynamic>{}, // No config values needed
      );

      // Assert
      expect(result, isA<String>());
      expect(result, contains('Successfully changed'));
      verify(
        () => mockCubit.updateBackgroundOpenedChat(AvatarBackgrounds.beach),
      ).called(1);
    });

    // Test 4: Happy path - LLM changes clothes (hat)
    test('execute changes hat when called by LLM', () async {
      // Arrange
      when(
        () => mockCubit.updateAvatarOpenedChat(any()),
      ).thenAnswer((_) async {});
      when(
        () => mockCubit.openedChat,
      ).thenReturn(const Chat(id: 'chat1', avatar: Avatar()));

      // Act - This simulates LLM calling: change_avatar(hat="frenchBeret")
      final String result = await tool.execute(<String, String>{
        'hat': 'frenchBeret',
      }, <String, dynamic>{});

      // Assert
      expect(result, isA<String>());
      expect(result, contains('Successfully changed'));
      verify(() => mockCubit.updateAvatarOpenedChat(any())).called(1);
    });

    // Test 5: LLM changes multiple fields at once
    test('execute changes background and clothes together', () async {
      // Arrange
      when(
        () => mockCubit.updateAvatarOpenedChat(any()),
      ).thenAnswer((_) async {});
      when(
        () => mockCubit.openedChat,
      ).thenReturn(const Chat(id: 'chat1', avatar: Avatar()));

      // Act - LLM calls: change_avatar(background="beach", hat="beanie")
      final String result = await tool.execute(<String, String>{
        'background': 'beach',
        'hat': 'beanie',
      }, <String, dynamic>{});

      // Assert
      expect(result, isA<String>());
      expect(result, contains('Successfully changed'));
      verify(() => mockCubit.updateAvatarOpenedChat(any())).called(1);
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
      verifyNever(() => mockCubit.updateBackgroundOpenedChat(any()));
    });

    // Test 7: Tool never throws, always returns result
    test('execute returns error message when cubit throws', () async {
      // Arrange - Cubit throws exception
      when(
        () => mockCubit.updateBackgroundOpenedChat(any()),
      ).thenThrow(Exception('Database error'));

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

    // Test 10: Triggers animation via AvatarAnimationService when background changes
    test(
      'emitUpdateConfig triggers animation with leaveAndComeBack for background',
      () async {
        // Arrange
        when(
          () => mockCubit.updateBackgroundOpenedChat(any()),
        ).thenAnswer((_) async {});
        when(
          () => mockCubit.openedChat,
        ).thenReturn(const Chat(id: 'chat1', avatar: Avatar()));

        // Act
        await tool.execute(<String, String>{
          'background': 'beach',
        }, <String, dynamic>{});

        // Assert
        final AvatarConfig captured =
            verify(
                  () => mockAnimationService.emitUpdateConfig(
                    'chat1',
                    captureAny(),
                  ),
                ).captured.single
                as AvatarConfig;

        expect(captured.specials, equals(AvatarSpecials.leaveAndComeBack));
        expect(captured.background, equals(AvatarBackgrounds.beach));
      },
    );

    // Test 11: Triggers animation with outOfScreen for clothes changes
    test(
      'emitUpdateConfig triggers animation with outOfScreen for clothes',
      () async {
        // Arrange
        when(
          () => mockCubit.updateAvatarOpenedChat(any()),
        ).thenAnswer((_) async {});
        when(
          () => mockCubit.openedChat,
        ).thenReturn(const Chat(id: 'chat1', avatar: Avatar()));

        // Act
        await tool.execute(<String, String>{
          'top': 'longCoat',
        }, <String, dynamic>{});

        // Assert
        final AvatarConfig captured =
            verify(
                  () => mockAnimationService.emitUpdateConfig(
                    'chat1',
                    captureAny(),
                  ),
                ).captured.single
                as AvatarConfig;

        expect(captured.specials, equals(AvatarSpecials.outOfScreen));
        expect(captured.top, equals(AvatarTop.longCoat));
      },
    );

    // Test 12: Passes actual avatar config (without animation specials) to ChatCubit
    test(
      'passes actual avatar config to ChatCubit, not animation config',
      () async {
        // Arrange
        when(
          () => mockCubit.updateAvatarOpenedChat(any()),
        ).thenAnswer((_) async {});
        when(
          () => mockCubit.openedChat,
        ).thenReturn(const Chat(id: 'chat1', avatar: Avatar()));

        // Act
        await tool.execute(<String, String>{
          'background': 'beach',
          'top': 'longCoat',
        }, <String, dynamic>{});

        // Assert
        // The config passed to ChatCubit should NOT have animation specials
        final AvatarConfig capturedConfig =
            verify(
                  () => mockCubit.updateAvatarOpenedChat(captureAny()),
                ).captured.single
                as AvatarConfig;

        expect(capturedConfig.background, equals(AvatarBackgrounds.beach));
        expect(capturedConfig.top, equals(AvatarTop.longCoat));
        expect(capturedConfig.specials, isNull); // No animation special
      },
    );

    // Test 13: Background-only change uses updateBackgroundOpenedChat
    test('background-only change calls updateBackgroundOpenedChat', () async {
      // Arrange
      when(
        () => mockCubit.openedChat,
      ).thenReturn(const Chat(id: 'chat1', avatar: Avatar()));

      // Act
      await tool.execute(<String, String>{
        'background': 'beach',
      }, <String, dynamic>{});

      // Assert
      verify(
        () => mockCubit.updateBackgroundOpenedChat(AvatarBackgrounds.beach),
      ).called(1);
      verifyNever(() => mockCubit.updateAvatarOpenedChat(any()));
    });

    // Test 14: Multiple changes use updateAvatarOpenedChat
    test('multiple changes use updateAvatarOpenedChat', () async {
      // Arrange
      when(
        () => mockCubit.openedChat,
      ).thenReturn(const Chat(id: 'chat1', avatar: Avatar()));

      // Act
      await tool.execute(<String, String>{
        'background': 'beach',
        'hat': 'beanie',
      }, <String, dynamic>{});

      // Assert
      verify(() => mockCubit.updateAvatarOpenedChat(any())).called(1);
      verifyNever(() => mockCubit.updateBackgroundOpenedChat(any()));
    });
  });
}
