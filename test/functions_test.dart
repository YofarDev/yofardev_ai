import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:yofardev_ai/core/models/chat.dart';
import 'package:yofardev_ai/core/models/task_llm_config.dart';
import 'package:yofardev_ai/core/services/agent/calculator_tool.dart';
import 'package:yofardev_ai/core/services/agent/character_counter_tool.dart';
import 'package:yofardev_ai/features/settings/domain/repositories/settings_repository.dart';

class MockSettingsRepository implements SettingsRepository {
  @override
  Future<Either<Exception, String?>> getLanguage() async {
    return Right<Exception, String?>('en');
  }

  @override
  Future<Either<Exception, void>> setLanguage(String language) async {
    return const Right<Exception, void>(null);
  }

  @override
  Future<Either<Exception, bool>> getSoundEffects() async {
    return const Right<Exception, bool>(true);
  }

  @override
  Future<Either<Exception, void>> setSoundEffects(bool enabled) async {
    return const Right<Exception, void>(null);
  }

  @override
  Future<Either<Exception, String?>> getUsername() async {
    return const Right<Exception, String?>('User');
  }

  @override
  Future<Either<Exception, void>> setUsername(String username) async {
    return const Right<Exception, void>(null);
  }

  @override
  Future<Either<Exception, String>> getSystemPrompt() async {
    return const Right<Exception, String>('Test prompt');
  }

  @override
  Future<Either<Exception, void>> setSystemPrompt(String prompt) async {
    return const Right<Exception, void>(null);
  }

  @override
  Future<Either<Exception, String?>> getGoogleSearchKey() async {
    return const Right<Exception, String?>('');
  }

  @override
  Future<Either<Exception, void>> setGoogleSearchKey(String key) async {
    return const Right<Exception, void>(null);
  }

  @override
  Future<Either<Exception, String?>> getGoogleSearchEngineId() async {
    return const Right<Exception, String?>('');
  }

  @override
  Future<Either<Exception, void>> setGoogleSearchEngineId(String id) async {
    return const Right<Exception, void>(null);
  }

  @override
  Future<Either<Exception, bool>> getGoogleSearchEnabled() async {
    return const Right<Exception, bool>(false);
  }

  @override
  Future<Either<Exception, void>> setGoogleSearchEnabled(bool enabled) async {
    return const Right<Exception, void>(null);
  }

  @override
  Future<Either<Exception, String?>> getOpenWeatherKey() async {
    return const Right<Exception, String?>('');
  }

  @override
  Future<Either<Exception, void>> setOpenWeatherKey(String key) async {
    return const Right<Exception, void>(null);
  }

  @override
  Future<Either<Exception, bool>> getOpenWeatherEnabled() async {
    return const Right<Exception, bool>(false);
  }

  @override
  Future<Either<Exception, void>> setOpenWeatherEnabled(bool enabled) async {
    return const Right<Exception, void>(null);
  }

  @override
  Future<Either<Exception, String?>> getNewYorkTimesKey() async {
    return const Right<Exception, String?>('');
  }

  @override
  Future<Either<Exception, void>> setNewYorkTimesKey(String key) async {
    return const Right<Exception, void>(null);
  }

  @override
  Future<Either<Exception, bool>> getNewYorkTimesEnabled() async {
    return const Right<Exception, bool>(false);
  }

  @override
  Future<Either<Exception, void>> setNewYorkTimesEnabled(bool enabled) async {
    return const Right<Exception, void>(null);
  }

  @override
  Future<Either<Exception, ChatPersona>> getPersona() async {
    return Right<Exception, ChatPersona>(ChatPersona.assistant);
  }

  @override
  Future<Either<Exception, void>> setPersona(ChatPersona persona) async {
    return const Right<Exception, void>(null);
  }

  @override
  Future<Either<Exception, TaskLlmConfig>> getTaskLlmConfig() async {
    return Right<Exception, TaskLlmConfig>(TaskLlmConfig());
  }

  @override
  Future<Either<Exception, void>> setTaskLlmConfig(TaskLlmConfig config) async {
    return const Right<Exception, void>(null);
  }
}

void main() {
  final MockSettingsRepository mockSettingsRepository =
      MockSettingsRepository();

  group('CalculatorTool', () {
    test('should return the correct result for a valid expression', () async {
      final CalculatorTool tool = CalculatorTool();

      expect(
        await tool.execute(
          <String, dynamic>{'expression': '2 + 2'},
          settingsRepository: mockSettingsRepository,
        ),
        equals('4.0'),
      );
      expect(
        await tool.execute(
          <String, dynamic>{'expression': '123456*654332'},
          settingsRepository: mockSettingsRepository,
        ),
        equals('80781211392.0'),
      );
      expect(
        await tool.execute(
          <String, dynamic>{'expression': '10 / 2'},
          settingsRepository: mockSettingsRepository,
        ),
        equals('5.0'),
      );
      expect(
        await tool.execute(
          <String, dynamic>{'expression': '2^3'},
          settingsRepository: mockSettingsRepository,
        ),
        equals('8.0'),
      );
    });
  });

  group('CharacterCounterTool', () {
    test(
      'should return the correct count for a valid text and character',
      () async {
        final CharacterCounterTool tool = CharacterCounterTool();

        expect(
          await tool.execute(
            <String, dynamic>{
              'text': 'Hello, world!',
              'character': 'l',
            },
            settingsRepository: mockSettingsRepository,
          ),
          equals('3'),
        );
        expect(
          await tool.execute(
            <String, dynamic>{
              'text': 'Hello, world!',
              'character': 'o',
            },
            settingsRepository: mockSettingsRepository,
          ),
          equals('2'),
        );
        expect(
          await tool.execute(
            <String, dynamic>{
              'text': 'strawberry',
              'character': 'r',
            },
            settingsRepository: mockSettingsRepository,
          ),
          equals('3'),
        );
      },
    );
  });
}
