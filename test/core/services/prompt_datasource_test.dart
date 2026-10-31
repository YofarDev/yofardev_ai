import 'dart:io';

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

  test('the tints are listed; the signature move is not an LLM cue', () async {
    when(() => settings.getBaseSystemPrompt('en')).thenAnswer(
      (_) async => r'$PERSONA tints: $tintList gestures: $gestureList',
    );
    final String prompt = await promptOn(DateTime(2026, 6, 1));
    expect(
      prompt,
      contains(
        'tints: none, red, orange, yellow, green, teal, blue, purple, pink, '
        'grey, ',
      ),
    );
    expect(prompt, contains('grab, '));
    expect(prompt, isNot(contains('signature')));
  });

  test('the ten scenes and their events are listed (M11)', () async {
    when(() => settings.getBaseSystemPrompt('en')).thenAnswer(
      (_) async => r'$PERSONA scenes: $backgroundList events: $sceneEventList',
    );
    final String prompt = await promptOn(DateTime(2026, 6, 1));
    expect(
      prompt,
      contains(
        'scenes: livingRoom, campfire, beach, deepSpace, cafe, rooftop, '
        'mountainHut, forestCabin, trainCompartment, library, ',
      ),
    );
    expect(
      prompt,
      contains('forestCabin: gust, fireflies, rain, lanternFlicker, ; '),
    );
    expect(
      prompt,
      contains('trainCompartment: tunnel, whistle, station, rain, ; '),
    );
    expect(
      prompt,
      contains('library: lightning, bookFlutter, clockChime, rain, ; '),
    );
  });

  test('both shipped prompts list the tints', () {
    for (final String lang in <String>['en', 'fr']) {
      final String text = File(
        'assets/txt/system_prompt_$lang.txt',
      ).readAsStringSync();
      expect(text, contains(r'$tintList'), reason: lang);
      expect(text, contains('topTint'), reason: lang);
      expect(text, contains('hatTint'), reason: lang);
    }
  });

  test('the note comes after the regular prompt, which is unchanged', () async {
    final String plain = await promptOn(DateTime(2026, 6, 1));
    final String december = await promptOn(DateTime(2026, 12, 3));
    expect(december, startsWith(plain));
    expect(december.length, greaterThan(plain.length));
  });
}
