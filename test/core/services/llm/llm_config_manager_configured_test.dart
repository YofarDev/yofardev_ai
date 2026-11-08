import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yofardev_ai/core/models/llm_config.dart';
import 'package:yofardev_ai/core/services/llm/llm_config_manager.dart';
import 'package:yofardev_ai/core/services/settings_local_datasource.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  LlmConfigManager manager() =>
      LlmConfigManager(settingsDatasource: SettingsLocalDatasource());

  test(
    'configured: unknown until init, then follows save and delete',
    () async {
      final LlmConfigManager configs = manager();
      expect(configs.configured.value, isNull);

      await configs.init();
      expect(configs.configured.value, isFalse);

      final LlmConfig config = LlmConfig.create(
        label: 'Mine',
        baseUrl: 'https://example.test/v1',
        apiKey: 'test-key',
        model: 'model',
      );
      await configs.saveConfig(config);
      expect(configs.configured.value, isTrue);

      await configs.deleteConfig(config.id);
      expect(configs.configured.value, isFalse);
    },
  );

  test('configured: true after init when a config is stored', () async {
    final LlmConfigManager first = manager();
    await first.init();
    await first.saveConfig(
      LlmConfig.create(
        label: 'Mine',
        baseUrl: 'https://example.test/v1',
        apiKey: 'test-key',
        model: 'model',
      ),
    );

    final LlmConfigManager second = manager();
    await second.init();
    expect(second.configured.value, isTrue);
  });
}
