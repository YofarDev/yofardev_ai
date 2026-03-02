import 'dart:io';

void main() async {
  final Directory libDir = Directory('lib');

  final Map<String, String> replacements = <String, String>{
    // Core models → Feature domain models
    "'../models/chat.dart'": "'../../domain/models/chat.dart'",
    "'../models/chat_entry.dart'": "'../../domain/models/chat_entry.dart'",
    "'../models/avatar_config.dart'":
        "'../../domain/models/avatar_config.dart'",
    "'../models/demo_script.dart'": "'../../domain/models/demo_script.dart'",

    // Core services → Feature data sources
    "'../services/chat_history_service.dart'":
        "'../data/datasources/chat_local_datasource.dart'",
    "'../services/settings_service.dart'":
        "'../../../settings/data/datasources/settings_local_datasource.dart'",
    "'../services/cache_service.dart'":
        "'../data/datasources/avatar_cache_datasource.dart'",
    "'../services/prompt_service.dart'":
        "'../data/datasources/prompt_datasource.dart'",
    "'../services/tts_service.dart'":
        "'../../../sound/data/datasources/tts_datasource.dart'",

    // Core repositories → Feature repositories
    "'../repositories/yofardev_repository.dart'":
        "'../data/repositories/yofardev_repository_impl.dart'",

    // Cross-feature imports (from core to features)
    "'../../core/models/chat.dart'": "'../../../chat/domain/models/chat.dart'",
    "'../../core/models/chat_entry.dart'":
        "'../../../chat/domain/models/chat_entry.dart'",
    "'../../core/models/avatar_config.dart'":
        "'../../../avatar/domain/models/avatar_config.dart'",
    "'../../core/models/demo_script.dart'":
        "'../../../demo/domain/models/demo_script.dart'",
    "'../../core/models/sound_effects.dart'":
        "'../../../../../core/models/sound_effects.dart'",

    // From core going to features
    "'../models/chat.dart'": "'../../features/chat/domain/models/chat.dart'",
    "'../models/chat_entry.dart'":
        "'../../features/chat/domain/models/chat_entry.dart'",
    "'../models/avatar_config.dart'":
        "'../../features/avatar/domain/models/avatar_config.dart'",
    "'../models/demo_script.dart'":
        "'../../features/demo/domain/models/demo_script.dart'",

    // Demo services
    "'../services/demo_service.dart'":
        "'../data/repositories/demo_repository_impl.dart'",
    "'../services/demo_controller.dart'":
        "'../data/datasources/demo_controller.dart'",

    // Service locator updates
    "'../../features/demo/services/demo_service.dart'":
        "'../../features/demo/data/repositories/demo_repository_impl.dart'",
    "'../../features/demo/services/demo_controller.dart'":
        "'../../features/demo/data/datasources/demo_controller.dart'",
    "'../repositories/yofardev_repository.dart'":
        "'../../features/chat/data/repositories/yofardev_repository_impl.dart'",
    "'../services/agent/sound_service.dart'":
        "'../../features/sound/data/repositories/sound_repository_impl.dart'",
    "'../services/chat_history_service.dart'":
        "'../../features/chat/data/datasources/chat_local_datasource.dart'",
    "'../services/settings_service.dart'":
        "'../../features/settings/data/datasources/settings_local_datasource.dart'",
    "'../services/tts_service.dart'":
        "'../../features/sound/data/datasources/tts_datasource.dart'",

    // From core services to features
    "'../../models/chat.dart'": "'../../features/chat/domain/models/chat.dart'",
    "'../../models/chat_entry.dart'":
        "'../../features/chat/domain/models/chat_entry.dart'",
    "'../../models/avatar_config.dart'":
        "'../../features/avatar/domain/models/avatar_config.dart'",
    "'../../models/demo_script.dart'":
        "'../../features/demo/domain/models/demo_script.dart'",
  };

  await for (final FileSystemEntity entity in libDir.list(recursive: true)) {
    if (entity.path.endsWith('.dart')) {
      final File file = File(entity.path);
      String content = await file.readAsString();
      bool modified = false;

      for (final MapEntry<String, String> entry in replacements.entries) {
        if (content.contains(entry.key)) {
          content = content.replaceAll(entry.key, entry.value);
          modified = true;
        }
      }

      if (modified) {
        await file.writeAsString(content);
        print('✓ Updated: ${entity.path}');
      }
    }
  }

  print('\nImport fix complete!');
}
