import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:yofardev_ai/core/services/settings_local_datasource.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SettingsLocalDatasource datasource;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    datasource = SettingsLocalDatasource();
  });

  group('getBaseSystemPrompt', () {
    test('returns the stored custom prompt when one is saved', () async {
      await datasource.setBaseSystemPrompt('My custom prompt. \$PERSONA');

      final String prompt = await datasource.getBaseSystemPrompt('en');

      expect(prompt, 'My custom prompt. \$PERSONA');
    });

    test('falls back to the bundled asset when nothing is stored', () async {
      final String prompt = await datasource.getBaseSystemPrompt('en');

      expect(prompt, isNot(contains('My custom prompt')));
      expect(prompt, contains(r'$PERSONA'));
    });

    test('an empty stored value falls back to the bundled asset', () async {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('baseSystemPrompt', '');

      final String prompt = await datasource.getBaseSystemPrompt('en');

      expect(prompt, contains(r'$PERSONA'));
    });
  });
}
