import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yofardev_ai/core/di/service_locator.dart';
import 'package:yofardev_ai/core/repositories/settings_repository.dart';
import 'package:yofardev_ai/core/services/agent/tool_registry.dart';
import 'package:yofardev_ai/core/services/app_lifecycle_service.dart';
import 'package:yofardev_ai/core/services/audio/interruption_service.dart';
import 'package:yofardev_ai/core/services/llm/llm_service_interface.dart';
import 'package:yofardev_ai/core/services/settings_local_datasource.dart';
import 'package:yofardev_ai/features/avatar/avatar.dart';
import 'package:yofardev_ai/features/avatar/data/datasources/avatar_local_datasource.dart';
import 'package:yofardev_ai/features/chat/chat.dart';
import 'package:yofardev_ai/features/chat/data/datasources/chat_local_datasource.dart';
import 'package:yofardev_ai/features/chat/data/datasources/global_memory_datasource.dart';
import 'package:yofardev_ai/features/chat/domain/services/chat_streaming_service.dart';
import 'package:yofardev_ai/features/chat/domain/services/global_memory_service.dart';
import 'package:yofardev_ai/features/demo/demo.dart';
import 'package:yofardev_ai/features/home/domain/repositories/home_repository.dart';
import 'package:yofardev_ai/features/home/presentation/bloc/home_cubit.dart';
import 'package:yofardev_ai/features/settings/settings.dart';
import 'package:yofardev_ai/features/sound/data/datasources/tts_datasource.dart';
import 'package:yofardev_ai/features/sound/domain/repositories/sound_repository.dart';
import 'package:yofardev_ai/features/sound/domain/services/tts_queue_service.dart';
import 'package:yofardev_ai/features/sound/presentation/bloc/sound_cubit.dart';
import 'package:yofardev_ai/features/talking/domain/repositories/talking_repository.dart';
import 'package:yofardev_ai/features/talking/presentation/bloc/talking_cubit.dart';

/// DI smoke test: the whole pure-Dart graph registers and resolves.
///
/// Deliberate scope exclusion: instance methods of plugin-backed audio types
/// (AudioPlayerService, AudioAmplitudeService, VoiceEffectsService,
/// TtsDatasource) touch platform channels when *used*; here they are only
/// constructed, which is safe. If construction itself ever needs a channel,
/// exclude that one type here with a comment naming the plugin.
void main() {
  test('service locator resolves the pure-Dart dependency graph', () async {
    // HomeRepositoryImpl constructs an audioplayers AudioPlayer, which reads
    // an EventChannel at construction; the test binding provides a mock
    // binary messenger so no real platform channel is touched.
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await setupServiceLocator();

    // Datasources / repositories
    expect(getIt<ChatRepository>(), isNotNull);
    expect(getIt<SettingsRepository>(), isNotNull);
    expect(getIt<AvatarRepository>(), isNotNull);
    expect(getIt<GlobalMemoryRepository>(), isNotNull);
    expect(getIt<LocaleRepository>(), isNotNull);
    expect(getIt<HomeRepository>(), isNotNull);
    expect(getIt<SoundRepository>(), isNotNull);
    expect(getIt<TalkingRepository>(), isNotNull);
    expect(getIt<DemoRepository>(), isNotNull);

    // Cross-feature domain services
    expect(getIt<ToolRegistry>(), isNotNull);
    expect(getIt<LlmServiceInterface>(), isNotNull);
    expect(getIt<ChatStreamingService>(), isNotNull);
    expect(getIt<GlobalMemoryService>(), isNotNull);
    expect(getIt<AvatarAnimationService>(), isNotNull);
    expect(getIt<AvatarCueService>(), isNotNull);
    expect(getIt<TtsQueueService>(), isNotNull);
    expect(getIt<AppLifecycleService>(), isNotNull);
    expect(getIt<InterruptionService>(), isNotNull);
    expect(getIt<DemoService>(), isNotNull);

    // Datasources resolve too (constructed lazily via services above)
    expect(getIt<SettingsLocalDatasource>(), isNotNull);
    expect(getIt<AvatarLocalDatasource>(), isNotNull);
    expect(getIt<ChatLocalDatasource>(), isNotNull);
    expect(getIt<GlobalMemoryLocalDatasource>(), isNotNull);
    expect(getIt<TtsDatasource>(), isNotNull);

    // Every cubit (registerFactory) constructs
    expect(getIt<ChatCubit>(), isNotNull);
    expect(getIt<ChatTtsCubit>(), isNotNull);
    expect(getIt<SettingsCubit>(), isNotNull);
    expect(getIt<AvatarCubit>(), isNotNull);
    expect(getIt<DemoCubit>(), isNotNull);
    expect(getIt<HomeCubit>(), isNotNull);
    expect(getIt<SoundCubit>(), isNotNull);
    expect(getIt<TalkingCubit>(), isNotNull);
  });
}
