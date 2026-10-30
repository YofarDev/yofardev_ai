import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yofardev_ai/core/models/chat.dart';
import 'package:yofardev_ai/core/services/prompt_datasource.dart';
import 'package:yofardev_ai/core/services/settings_local_datasource.dart';

class _MockSettings extends Mock implements SettingsLocalDatasource {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockSettings settings;

  setUp(() {
    settings = _MockSettings();
    when(() => settings.getLanguage()).thenAnswer((_) async => 'en');
    when(
      () => settings.getBaseSystemPrompt('en'),
    ).thenAnswer((_) async => r'$PERSONA hat: $hatList');
    when(() => settings.getUsername()).thenAnswer((_) async => null);
    when(
      () => settings.getPersona(),
    ).thenAnswer((_) async => ChatPersona.normal);
  });

  Future<String> promptOn(DateTime day) => PromptDatasource(
    settingsDatasource: settings,
    now: () => day,
  ).getSystemPrompt();

  test(
    'in December the prompt says the avatar is in its December outfit',
    () async {
      for (final DateTime day in <DateTime>[
        DateTime(2026, 12, 1),
        DateTime(2026, 12, 31, 23, 59),
      ]) {
        final String prompt = await promptOn(day);
        expect(prompt, contains('December'), reason: '$day');
        expect(prompt, contains('santaHat'));
        expect(prompt, contains('christmasSweater'));
      }
    },
  );

  test('the rest of the year the prompt has no December note', () async {
    for (final DateTime day in <DateTime>[
      DateTime(2026, 11, 30, 23, 59),
      DateTime(2027, 1, 1),
      DateTime(2027, 1, 5),
      DateTime(2026, 7, 14),
    ]) {
      final String prompt = await promptOn(day);
      expect(prompt, isNot(contains('December outfit')), reason: '$day');
    }
  });

  test('the note comes after the regular prompt, which is unchanged', () async {
    final String plain = await promptOn(DateTime(2026, 6, 1));
    final String december = await promptOn(DateTime(2026, 12, 3));
    expect(december, startsWith(plain));
    expect(december.length, greaterThan(plain.length));
  });
}
