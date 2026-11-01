import 'dart:async';

import 'package:audio_analyzer/audio_analyzer.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/avatar/presentation/bloc/avatar_cubit.dart';
import '../../features/avatar/data/datasources/avatar_local_datasource.dart';
import '../../features/avatar/data/repositories/avatar_repository_impl.dart';
import '../../features/avatar/domain/repositories/avatar_repository.dart';
import '../../features/avatar/domain/services/camera_director.dart';
import '../../features/avatar/domain/services/camera_feed.dart';
import '../../features/avatar/domain/services/face_performer.dart';
import '../../features/avatar/domain/services/idle_ladder.dart';
import '../../features/avatar/domain/services/npc_director.dart';
import '../../features/avatar/domain/services/npc_feed.dart';
import '../../features/avatar/domain/services/performance_director.dart';
import '../../features/chat/domain/repositories/global_memory_repository.dart';
import '../../features/chat/presentation/bloc/chat_tts_cubit.dart';
import '../../features/chat/presentation/bloc/chat_cubit.dart';
import '../../features/chat/domain/services/chat_entry_service.dart';
import '../../features/chat/domain/services/chat_title_service.dart';
import '../../features/chat/domain/services/global_memory_service.dart';
import '../../features/chat/data/datasources/chat_local_datasource.dart';
import '../../features/chat/data/datasources/global_memory_datasource.dart';
import '../../features/chat/data/repositories/global_memory_repository_impl.dart';
import '../../features/chat/data/repositories/yofardev_repository_impl.dart';
import '../../features/chat/domain/repositories/chat_repository.dart';
import '../../features/demo/presentation/bloc/demo_cubit.dart';
import '../../features/demo/domain/services/demo_service.dart';
import '../../features/demo/data/repositories/demo_repository_impl.dart';
import '../../features/demo/domain/repositories/demo_repository.dart';
import '../../features/home/presentation/bloc/home_cubit.dart';
import '../../features/settings/presentation/bloc/settings_cubit.dart';
import '../../features/settings/data/repositories/settings_repository_impl.dart';
import '../repositories/settings_repository.dart';
import '../../features/sound/presentation/bloc/sound_cubit.dart';
import '../../features/sound/data/datasources/kokoro_tts_datasource.dart';
import '../../features/sound/data/datasources/tts_datasource.dart';
import '../../features/sound/data/kokoro/kokoro_engine.dart';
import '../../features/sound/data/kokoro/kokoro_engine_factory.dart';
import '../../features/sound/data/kokoro/kokoro_model_store.dart';
import '../../features/sound/data/kokoro/kokoro_tts_service.dart';
import '../../features/sound/data/kokoro/model_archive_extractor.dart';
import '../../features/sound/domain/services/fallback_tts_synthesizer.dart';
import '../../features/sound/domain/services/tts_engine_status_service.dart';
import '../../features/sound/data/repositories/sound_repository_impl.dart';
import '../../features/sound/domain/services/tts_queue_service.dart';
import '../../features/sound/domain/services/tts_synthesizer.dart';
import '../../features/sound/domain/repositories/sound_repository.dart';
import '../../features/talking/data/repositories/talking_repository_impl.dart';
import '../../features/talking/domain/repositories/talking_repository.dart';
import '../../features/talking/domain/services/playback_clock.dart';
import '../../features/talking/domain/services/tts_playback_service.dart';
import '../../features/talking/presentation/bloc/caption_cubit.dart';
import '../../features/talking/presentation/bloc/talking_cubit.dart';
import '../../features/home/data/repositories/home_repository_impl.dart';
import '../services/app_lifecycle_service.dart';
import '../utils/platform_utils.dart';
import '../../features/home/domain/repositories/home_repository.dart';
import '../../features/settings/domain/repositories/locale_repository.dart';
import '../../features/settings/data/repositories/locale_repository_impl.dart';
import '../services/audio/audio_amplitude_service.dart';
import '../services/audio/ambient_bed_service.dart';
import '../services/audio/audio_player_service.dart';
import '../services/audio/foley_service.dart';
import '../services/audio/sound_effects_setting.dart';
import '../services/audio/interruption_service.dart';
import '../services/audio/voice_effects_service.dart';
import '../design/tokens/scene_lights.dart';
import '../models/avatar_scene.dart';
import '../models/failure.dart';
import '../models/result.dart';
import '../../features/avatar/domain/models/avatar_animation.dart';
import '../../features/avatar/domain/models/performance_intent.dart';
import '../models/weather_report.dart';
import '../services/agent/tool_registry.dart';
import '../services/agent/weather_service.dart';
import '../../features/avatar/domain/services/avatar_animation_service.dart';
import '../../features/avatar/domain/services/avatar_cue_service.dart';
import '../../features/avatar/domain/services/prop_reaction_service.dart';
import '../../features/demo/domain/services/demo_controller.dart';
import '../services/llm/fake_llm_service.dart';
import '../services/llm/llm_config_manager.dart';
import '../services/llm/llm_service.dart';
import '../services/llm/llm_service_interface.dart';
import '../services/llm/llm_streaming_service.dart';
import '../services/llm/llm_streaming_service_interface.dart';
import '../services/prompt_datasource.dart';
import '../services/motion/parallax_source.dart';
import '../services/motion/reduce_motion_source.dart';
import '../services/power/power_saver_source.dart';
import '../services/presence/composer_activity_service.dart';
import '../services/quality/frame_timing_source.dart';
import '../services/quality/quality_tier_service.dart';
import '../services/quality/thermal_source.dart';
import '../services/settings_local_datasource.dart';
import '../services/speech/speech_input_service.dart';
import '../services/speech/speech_to_text_input_service.dart';
import '../services/stream_processor/stream_processor_service.dart';
import '../services/world/tablet_weather_source.dart';
import '../services/world/world_lifecycle_observer.dart';
import '../services/world/world_state_service.dart';
import '../services/world/world_weather_sync.dart';
import '../../features/chat/domain/services/chat_streaming_service.dart';
import '../utils/logger.dart';

final GetIt getIt = GetIt.instance;

/// Registers every dependency. The overrides are seams for the macOS capture
/// harness (`integration_test/wow_capture_test.dart`, M6): [ttsSynthesizer]
/// replaces on-device TTS, [tools] the agent's tool list, [foleyPlayer]
/// the foley players (M8: the harness logs what played) and [haptics] the
/// haptics sink (M9: the harness logs the drag haptics). Production passes
/// none of them.
/// The app lifecycle observer that pauses the world clock and weather sync.
WorldLifecycleObserver? _worldObserver;

Future<void> setupServiceLocator({
  TtsSynthesizer? ttsSynthesizer,
  List<AgentTool>? tools,
  FoleyPlayer Function()? foleyPlayer,
  HapticsSink? haptics,
}) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();

  // ── Data sources (register early — no dependencies) ──
  getIt.registerLazySingleton<SettingsLocalDatasource>(
    () => SettingsLocalDatasource(),
  );
  getIt.registerLazySingleton<AvatarLocalDatasource>(
    () => AvatarLocalDatasource(),
  );
  getIt.registerLazySingleton<TtsDatasource>(() => TtsDatasource());
  // Kokoro, the default voice: a one-time ~132 MB model download from
  // GitHub releases (k2-fsa/sherpa-onnx), then fully on-device.
  getIt.registerLazySingleton<KokoroModelStore>(
    () => KokoroModelStore(
      client: http.Client(),
      extractor: const ArchivePackageExtractor(),
      supportDirectoryProvider: getApplicationSupportDirectory,
    ),
  );
  getIt.registerLazySingleton<KokoroEngine>(createKokoroEngine);
  getIt.registerLazySingleton<TtsEngineStatusService>(
    () => KokoroTtsService(
      store: getIt<KokoroModelStore>(),
      engine: getIt<KokoroEngine>(),
    ),
  );
  getIt.registerLazySingleton<KokoroTtsDatasource>(
    () => KokoroTtsDatasource(engine: getIt<KokoroEngine>()),
  );
  getIt.registerLazySingleton<InterruptionService>(() => InterruptionService());
  // The system's reduce-motion switch, followed live (M11 ruling 18): the
  // services below that are not widgets read it through here.
  getIt.registerLazySingleton<ReduceMotionSource>(
    ReduceMotionSource.platform,
    dispose: (ReduceMotionSource source) => source.dispose(),
  );
  // Lazy: no mic permission or recognizer setup until the first start().
  getIt.registerLazySingleton<SpeechInputService>(
    () => SpeechToTextInputService(),
    dispose: (SpeechInputService service) => service.dispose(),
  );

  // ── Core services (depend on datasources) ──
  getIt.registerLazySingleton<LlmConfigManager>(
    () =>
        LlmConfigManager(settingsDatasource: getIt<SettingsLocalDatasource>()),
  );
  getIt.registerLazySingleton<PromptDatasource>(
    () =>
        PromptDatasource(settingsDatasource: getIt<SettingsLocalDatasource>()),
  );
  getIt.registerLazySingleton<ChatLocalDatasource>(
    () => ChatLocalDatasource(
      settingsDatasource: getIt<SettingsLocalDatasource>(),
      promptDatasource: getIt<PromptDatasource>(),
    ),
  );
  getIt.registerLazySingleton<GlobalMemoryLocalDatasource>(
    () => GlobalMemoryLocalDatasource(),
  );

  // LLM services
  getIt.registerLazySingleton<LlmService>(() {
    final LlmService service = LlmService();
    service.setConfigManager(getIt<LlmConfigManager>());
    return service;
  });
  getIt.registerLazySingleton<FakeLlmService>(() => FakeLlmService());

  if (kDebugMode) {
    getIt.registerLazySingleton<LlmServiceInterface>(
      () => getIt<FakeLlmService>(),
    );
    AppLogger.info(
      'Registered FakeLlmService (debug mode)',
      tag: 'ServiceLocator',
    );
  } else {
    getIt.registerLazySingleton<LlmServiceInterface>(() => getIt<LlmService>());
    AppLogger.info(
      'Registered LlmService (release mode)',
      tag: 'ServiceLocator',
    );
  }

  getIt.registerLazySingleton<LlmStreamingServiceInterface>(
    () => LlmStreamingService(
      client: http.Client(),
      configManager: getIt<LlmConfigManager>(),
    ),
  );

  // Agent & tool registry
  getIt.registerLazySingleton<ToolRegistry>(
    () => ToolRegistry(
      appLifecycleService: getIt<AppLifecycleService>(),
      tools: tools,
      // Weather for the user's own location also moves the world's sky.
      onOwnLocationReport: (WeatherReport report) =>
          getIt<WorldStateService>().applyWeather(report),
      // Any city's weather shows on the tablet (M8 ruling 14), never in the
      // world.
      onWeatherReport: (WeatherReport report) =>
          getIt<TabletWeatherSource>().report(report),
    ),
  );
  getIt.registerLazySingleton<TabletWeatherSource>(
    TabletWeatherSource.new,
    dispose: (TabletWeatherSource source) => source.dispose(),
  );

  // ── Repositories (depend on datasources + services) ──
  getIt.registerLazySingleton<AvatarRepository>(
    () => AvatarRepositoryImpl(datasource: getIt<AvatarLocalDatasource>()),
  );
  getIt.registerLazySingleton<SettingsRepository>(
    () => SettingsRepositoryImpl(
      // The live setting the foley and the beds follow (M8).
      onSoundEffectsChanged: (bool enabled) =>
          getIt<SoundEffectsSetting>().set(enabled),
    ),
  );
  getIt.registerLazySingleton<ChatRepository>(
    () => YofardevRepositoryImpl(chatDatasource: getIt<ChatLocalDatasource>()),
  );
  getIt.registerLazySingleton<GlobalMemoryRepository>(
    () => GlobalMemoryRepositoryImpl(
      datasource: getIt<GlobalMemoryLocalDatasource>(),
    ),
  );
  getIt.registerLazySingleton<SoundRepository>(() => SoundRepositoryImpl());
  getIt.registerLazySingleton<TalkingRepository>(() => TalkingRepositoryImpl());
  getIt.registerLazySingleton<DemoRepository>(
    () => DemoRepositoryImpl(
      chatRepository: getIt<ChatRepository>(),
      avatarRepository: getIt<AvatarRepository>(),
    ),
  );
  getIt.registerLazySingleton<HomeRepository>(() => HomeRepositoryImpl());

  // ── Audio services ──
  getIt.registerLazySingleton<AudioAnalyzer>(() => AudioAnalyzer());
  getIt.registerLazySingleton<AudioPlayerService>(() => AudioPlayerService());
  getIt.registerLazySingleton<AudioAmplitudeService>(
    () => AudioAmplitudeService(),
  );
  getIt.registerLazySingleton<VoiceEffectsService>(() => VoiceEffectsService());
  // Foley, haptics and the ambient beds (moonshot M8 rulings 10-12): they
  // follow the sound-effects setting (loaded below) and pause with the app.
  getIt.registerLazySingleton<SoundEffectsSetting>(
    SoundEffectsSetting.new,
    dispose: (SoundEffectsSetting setting) => setting.dispose(),
  );
  getIt.registerLazySingleton<FoleyService>(
    () => FoleyService(
      createPlayer: foleyPlayer ?? AudioPlayersFoleyPlayer.new,
      haptics: haptics ?? const SystemHaptics(),
      enabled: getIt<SoundEffectsSetting>().enabled,
    ),
    dispose: (FoleyService foley) => foley.dispose(),
  );
  getIt.registerLazySingleton<TtsQueueService>(
    () => TtsQueueService(
      // Kokoro first; Supertonic while Kokoro is not ready, for languages
      // Kokoro lacks, or when a sentence fails. Not on Apple platforms:
      // there flutter_onnxruntime (Supertonic) binds to sherpa-onnx's older
      // ONNX Runtime and crashes the app, so those sentences stay text-only.
      ttsSynthesizer:
          ttsSynthesizer ??
          FallbackTtsSynthesizer(
            primary: getIt<KokoroTtsDatasource>(),
            fallback: _supertonicFallbackSupported
                ? getIt<TtsDatasource>()
                : null,
          ),
      interruptionService: getIt<InterruptionService>(),
      voiceEffectsService: getIt<VoiceEffectsService>(),
    ),
  );

  // ── Other services ──
  getIt.registerLazySingleton<LocaleRepository>(
    () => LocaleRepositoryImpl(prefs: prefs),
  );
  getIt.registerLazySingleton<StreamProcessorService>(
    () => StreamProcessorService(),
  );
  getIt.registerLazySingleton<FrameTimingSource>(
    () => SchedulerFrameTimingSource(),
  );
  // Moonshot M11: the thermal state through our own channel where the
  // native side implements it; elsewhere always nominal.
  getIt.registerLazySingleton<ThermalSource>(
    () =>
        !kIsWeb &&
            (defaultTargetPlatform == TargetPlatform.android ||
                defaultTargetPlatform == TargetPlatform.iOS ||
                defaultTargetPlatform == TargetPlatform.macOS)
        ? MethodChannelThermalSource()
        : const NominalThermalSource(),
  );
  // The effective tier = min(benchmark, thermal, battery saver, drift).
  getIt.registerLazySingleton<QualityTierService>(
    () => QualityTierService(
      timingSource: getIt<FrameTimingSource>(),
      settings: getIt<SettingsLocalDatasource>(),
      thermal: getIt<ThermalSource>(),
      power: getIt<PowerSaverSource>(),
    ),
    dispose: (QualityTierService quality) => quality.dispose(),
  );
  getIt.registerLazySingleton<PlaybackClock>(
    () => PlaybackClock(
      source: _AudioPlayerPositionSource(getIt<AudioPlayerService>()),
    ),
  );
  getIt.registerLazySingleton<TtsPlaybackService>(
    () => TtsPlaybackService(
      getIt<TalkingRepository>(),
      clock: getIt<PlaybackClock>(),
    ),
  );
  getIt.registerLazySingleton<AvatarAnimationService>(
    () => AvatarAnimationService(),
  );
  getIt.registerLazySingleton<PropReactionService>(() => PropReactionService());
  getIt.registerLazySingleton<ChatEntryService>(
    () => ChatEntryService(getIt<SettingsRepository>()),
  );
  getIt.registerLazySingleton<ChatTitleService>(
    () => ChatTitleService(
      chatRepository: getIt<ChatRepository>(),
      llmService: getIt<LlmServiceInterface>(),
    ),
  );
  getIt.registerLazySingleton<GlobalMemoryService>(
    () => GlobalMemoryService(
      memoryRepository: getIt<GlobalMemoryRepository>(),
      settingsRepository: getIt<SettingsRepository>(),
      llmService: getIt<LlmServiceInterface>(),
    ),
  );

  // ── Demo services (depend on repositories) ──
  getIt.registerLazySingleton<DemoController>(() => DemoController());
  getIt.registerLazySingleton<DemoService>(
    () => DemoService(
      repository: getIt<DemoRepository>(),
      demoController: getIt<DemoController>(),
      fakeLlmService: getIt<FakeLlmService>(),
    ),
  );

  // ── App lifecycle service (no cubit dependencies - cubits subscribe to service streams) ──
  getIt.registerLazySingleton<AppLifecycleService>(() => AppLifecycleService());

  // ── Cubits ──
  getIt.registerFactory<AvatarCubit>(
    () => AvatarCubit(
      getIt<AvatarRepository>(),
      getIt<AvatarAnimationService>(),
      getIt<AudioPlayerService>(),
      getIt<AppLifecycleService>(),
      getIt<PropReactionService>(),
      getIt<SoundRepository>(),
      director: getIt<PerformanceDirector>(),
      // Reduce motion turns a journey into a cross-fade cut (ruling 18).
      reduceMotion: () => getIt<ReduceMotionSource>().value,
    ),
  );
  getIt.registerFactory<TalkingCubit>(
    () => TalkingCubit(
      getIt<TalkingRepository>(),
      getIt<InterruptionService>(),
      getIt<TtsPlaybackService>(),
      getIt<AppLifecycleService>(),
      getIt<TtsQueueService>(),
    ),
  );
  getIt.registerFactory<CaptionCubit>(
    () => CaptionCubit(
      playbackService: getIt<TtsPlaybackService>(),
      interruptionService: getIt<InterruptionService>(),
      settingsRepository: getIt<SettingsRepository>(),
    ),
  );
  getIt.registerFactory<ChatTtsCubit>(
    () => ChatTtsCubit(
      ttsQueueManager: getIt<TtsQueueService>(),
      audioAmplitudeService: getIt<AudioAmplitudeService>(),
      audioPlayerService: getIt<AudioPlayerService>(),
      interruptionService: getIt<InterruptionService>(),
      ttsPlaybackService: getIt<TtsPlaybackService>(),
    ),
  );
  getIt.registerLazySingleton<ChatStreamingService>(
    () => ChatStreamingService(
      chatRepository: getIt<ChatRepository>(),
      llmService: getIt<LlmServiceInterface>(),
      streamProcessor: getIt<StreamProcessorService>(),
      promptDatasource: getIt<PromptDatasource>(),
      interruptionService: getIt<InterruptionService>(),
      chatEntryService: getIt<ChatEntryService>(),
      ttsQueueManager: getIt<TtsQueueService>(),
      toolRegistry: getIt<ToolRegistry>(),
      settingsRepository: getIt<SettingsRepository>(),
      globalMemoryService: getIt<GlobalMemoryService>(),
    ),
  );
  getIt.registerFactory<ChatCubit>(
    () => ChatCubit(
      chatRepository: getIt<ChatRepository>(),
      settingsRepository: getIt<SettingsRepository>(),
      avatarAnimationService: getIt<AvatarAnimationService>(),
      chatTitleService: getIt<ChatTitleService>(),
      chatStreamingService: getIt<ChatStreamingService>(),
      appLifecycleService: getIt<AppLifecycleService>(),
      globalMemoryService: getIt<GlobalMemoryService>(),
      demoService: getIt<DemoService>(),
    ),
  );

  // Eagerly created: it must be subscribed to TTS playback events and the
  // streaming cue channel from startup, or cues fired before the first
  // subscription would be lost.
  getIt.registerLazySingleton<PerformanceDirector>(
    () => PerformanceDirector(
      now: DateTime.now,
      tabletWeather: getIt<TabletWeatherSource>().readings,
    ),
  );
  getIt.registerLazySingleton<ComposerActivityService>(
    ComposerActivityService.new,
    dispose: (ComposerActivityService service) => service.dispose(),
  );
  getIt.registerLazySingleton<PowerSaverSource>(
    BatteryPowerSaverSource.new,
    dispose: (PowerSaverSource source) async {
      if (source is BatteryPowerSaverSource) {
        await source.dispose();
      }
    },
  );
  // Parallax: the accelerometer's tilt on phones; elsewhere (desktop, web)
  // the stage reports the pointer. Zero under reduce motion and battery saver.
  getIt.registerLazySingleton<ParallaxSource>(
    () => ParallaxSource(
      accel: PlatformUtils.isMobile()
          ? accelerometerEventStream(
              samplingPeriod: SensorInterval.gameInterval,
            )
          : null,
      reduceMotion: () => getIt<ReduceMotionSource>().value,
      power: getIt<PowerSaverSource>(),
      // The scene view turns it on while a diorama is on screen.
      active: false,
    ),
    dispose: (ParallaxSource source) => source.dispose(),
  );
  // The world the scenes show: rain and the time of day. The weather tool
  // (own location) and WorldWeatherSync feed it; the minute clock runs while
  // the app is in the foreground (WorldLifecycleObserver, below).
  getIt.registerLazySingleton<WorldStateService>(
    () => WorldStateService(now: DateTime.now),
    dispose: (WorldStateService world) => world.dispose(),
  );
  // Refreshes the user's own weather every 30 min, but never asks for the
  // location permission, never calls without an OpenWeather key and stays
  // quiet under battery saver.
  getIt.registerLazySingleton<WorldWeatherSync>(
    () => WorldWeatherSync(
      world: getIt<WorldStateService>(),
      power: getIt<PowerSaverSource>(),
      readApiKey: () async {
        final SettingsRepository settings = getIt<SettingsRepository>();
        final bool enabled = (await settings.getOpenWeatherEnabled()).when(
          err: (Failure failure) => false,
          ok: (bool value) => value,
        );
        if (!enabled) {
          return null;
        }
        return (await settings.getOpenWeatherKey()).when(
          err: (Failure failure) => null,
          ok: (String? key) => key,
        );
      },
      hasLocationPermission: () async {
        final LocationPermission permission =
            await Geolocator.checkPermission();
        return permission == LocationPermission.whileInUse ||
            permission == LocationPermission.always;
      },
      fetchOwnLocation: (String apiKey) async =>
          (await WeatherService.fetchCurrentWeather(
            'current',
            apiKey,
            allowPermissionPrompt: false,
          )).report,
    ),
    dispose: (WorldWeatherSync sync) => sync.dispose(),
  );
  getIt.registerLazySingleton<IdleLadder>(
    () => IdleLadder(
      now: DateTime.now,
      power: getIt<PowerSaverSource>(),
      reduceMotion: () => getIt<ReduceMotionSource>().value,
    ),
    dispose: (IdleLadder ladder) => ladder.dispose(),
  );
  getIt.registerLazySingleton<AvatarCueService>(
    () => AvatarCueService(
      playbackService: getIt<TtsPlaybackService>(),
      animationService: getIt<AvatarAnimationService>(),
      streamingCues: getIt<ChatStreamingService>().streamingCues,
      director: getIt<PerformanceDirector>(),
      moods: getIt<AppLifecycleService>().moodEvents,
      // The current chat's persona sets the body language (M10 ruling 10).
      personas: getIt<AppLifecycleService>().personaEvents,
      toolActivity: getIt<ChatStreamingService>().toolActivity,
      composer: getIt<ComposerActivityService>().activity,
      idleLadder: getIt<IdleLadder>(),
    ),
  );
  getIt<AvatarCueService>();
  unawaited(getIt<IdleLadder>().start());
  // App-lifetime world: the clock and the weather sync run while the app is in
  // the foreground and pause with it (the harness has no key: no call).
  getIt<WorldStateService>().start();
  getIt<WorldWeatherSync>().start();
  // One observer, however often setup runs (tests, the capture harness); it
  // resolves the current singletons when it fires.
  _worldObserver ??= WorldLifecycleObserver(
    onResume: () {
      getIt<WorldStateService>().start();
      getIt<WorldWeatherSync>().start();
      getIt<FoleyService>().setPaused(false);
      getIt<AmbientBedService>().setPaused(false);
    },
    onPause: () {
      getIt<WorldStateService>().pause();
      getIt<WorldWeatherSync>().pause();
      getIt<FoleyService>().setPaused(true);
      getIt<AmbientBedService>().setPaused(true);
    },
  );
  WidgetsFlutterBinding.ensureInitialized()
    ..removeObserver(_worldObserver!)
    ..addObserver(_worldObserver!);
  // Eager for the same reason: it must see every intent and playback event.
  getIt.registerLazySingleton<FacePerformer>(
    () => FacePerformer(
      intents: getIt<PerformanceDirector>().intents,
      playback: getIt<TtsPlaybackService>().events,
      speechPosition: () => getIt<TtsPlaybackService>().speechPosition,
    ),
  );
  getIt<FacePerformer>();
  // The camera director (moonshot M7): eager, so it sees every sentence from
  // the start. Reduce motion is read here and kept current by the Home stage;
  // the talking phase comes from the Home stage too.
  getIt.registerLazySingleton<CameraDirector>(
    () =>
        CameraDirector(now: DateTime.now)
          ..setReduceMotion(getIt<ReduceMotionSource>().value),
    dispose: (CameraDirector camera) => camera.dispose(),
  );
  getIt.registerLazySingleton<CameraFeed>(
    () => CameraFeed(
      camera: getIt<CameraDirector>(),
      playback: getIt<TtsPlaybackService>().events,
      intents: getIt<PerformanceDirector>().intents,
      animations: getIt<AvatarAnimationService>().animations,
      emotion: () => getIt<PerformanceDirector>().current.emotion,
      tier: getIt<QualityTierService>().current,
      tierChanges: getIt<QualityTierService>().changes,
    ),
    dispose: (CameraFeed feed) => feed.dispose(),
  );
  getIt<CameraFeed>();
  // The scene NPCs (moonshot M8): eager like the camera, so the feed hears
  // every sentence, scene event and tier change from the start. The scene,
  // the talking phase, reduce motion and the pokes come from the Home stage.
  getIt.registerLazySingleton<NpcDirector>(
    () => NpcDirector(now: DateTime.now),
    dispose: (NpcDirector npc) => npc.dispose(),
  );
  getIt.registerLazySingleton<NpcFeed>(
    () => NpcFeed(
      npc: getIt<NpcDirector>(),
      intents: getIt<PerformanceDirector>().intents,
      playback: getIt<TtsPlaybackService>().events,
      animations: getIt<AvatarAnimationService>().animations,
      userMessages: getIt<ChatStreamingService>().userMessages,
      rain: getIt<WorldStateService>().rain,
      tier: getIt<QualityTierService>().current,
      tierChanges: getIt<QualityTierService>().changes,
    ),
    dispose: (NpcFeed feed) => feed.dispose(),
  );
  getIt<NpcFeed>();
  // Reduce motion followed live by the services that are not widgets (M11
  // ruling 18): the parallax reads 0, the idle ladder holds, the camera
  // locks medium and the NPCs jump as soon as the switch flips. (The Home
  // stage also pushes MediaQuery's flag to the camera and the NPCs.)
  getIt<ReduceMotionSource>().addListener(() {
    final bool reduce = getIt<ReduceMotionSource>().value;
    getIt<ParallaxSource>().refresh();
    getIt<IdleLadder>().tick();
    getIt<CameraDirector>().setReduceMotion(reduce);
    getIt<NpcDirector>().setReduceMotion(reduce);
  });
  getIt<NpcDirector>().setReduceMotion(getIt<ReduceMotionSource>().value);
  getIt.registerLazySingleton<AmbientBedService>(
    () => AmbientBedService(
      createPlayer: AudioPlayersBedPlayer.new,
      enabled: getIt<SoundEffectsSetting>().enabled,
      flickerOf: (AvatarScene scene) => SceneLights.of(scene).flicker,
      rain: getIt<WorldStateService>().rain,
      speaking: getIt<PerformanceDirector>().intents
          .map((PerformanceIntent intent) => intent.speaking)
          .distinct(),
      flares: getIt<AvatarAnimationService>().animations
          .where(
            (AvatarAnimation animation) =>
                animation is AvatarAnimationSceneEvent &&
                animation.sceneEvent == SceneEvent.flare,
          )
          .map((AvatarAnimation _) {}),
      // M11 ruling 11: the wind bed follows the own-location report's wind
      wind: getIt<WorldStateService>().wind,
      gusts: getIt<AvatarAnimationService>().animations
          .where(
            (AvatarAnimation animation) =>
                animation is AvatarAnimationSceneEvent &&
                animation.sceneEvent == SceneEvent.gust,
          )
          .map((AvatarAnimation _) {}),
      assetAvailable: bundledAssetExists,
    ),
    dispose: (AmbientBedService beds) => beds.dispose(),
  );
  unawaited(
    getIt<SettingsRepository>().getSoundEffects().then(
      (Result<bool> result) => result.when(
        err: (Failure failure) {},
        ok: (bool enabled) => getIt<SoundEffectsSetting>().set(enabled),
      ),
    ),
  );

  getIt.registerFactory<DemoCubit>(
    () => DemoCubit(
      demoController: getIt<DemoController>(),
      demoService: getIt<DemoService>(),
    ),
  );
  getIt.registerFactory<SoundCubit>(
    () => SoundCubit(soundRepository: getIt<SoundRepository>()),
  );
  getIt.registerFactory<SettingsCubit>(
    () => SettingsCubit(
      settingsRepository: getIt<SettingsRepository>(),
      llmService: getIt<LlmServiceInterface>(),
      globalMemoryRepository: getIt<GlobalMemoryRepository>(),
      ttsEngineStatusService: getIt<TtsEngineStatusService>(),
    ),
  );
  getIt.registerFactory<HomeCubit>(
    () => HomeCubit(getIt<HomeRepository>(), getIt<AppLifecycleService>()),
  );
}

/// Post-registration bootstrap: data migrations and optional warmup.
/// Lives here (not in main.dart) so main.dart never imports feature internals.
Future<void> bootstrapApp() async {
  // Run chat data migration (previously called from main.dart).
  await getIt<ChatLocalDatasource>().init();

  // Quality-tier probe: load the stored tier and probe in the background
  // when none is stored. Startup never waits for it.
  unawaited(getIt<QualityTierService>().init());

  // TTS warmup: startup must never be blocked by it. Kokoro installs (the
  // first launch downloads its model) and loads in the background; until it
  // is ready, Supertonic speaks, so it warms up only when Kokoro's model is
  // not on disk yet.
  if (PlatformUtils.checkPlatform() != 'Web') {
    unawaited(getIt<TtsEngineStatusService>().install());
    if (_supertonicFallbackSupported) {
      unawaited(_warmUpFallbackVoice());
    }
  }
}

/// Supertonic (flutter_onnxruntime) shares sherpa-onnx's ONNX Runtime only
/// on Android (`android/app/build.gradle` aligns them); on macOS and iOS its
/// ORT 1.28 wrapper binds to sherpa's 1.24 library and crashes the app.
bool get _supertonicFallbackSupported =>
    PlatformUtils.checkPlatform() == 'Android';

Future<void> _warmUpFallbackVoice() async {
  try {
    if (await getIt<KokoroModelStore>().isInstalled()) return;
    await TtsDatasource.initSupertonic();
  } catch (_) {
    // Startup should never be blocked by optional TTS warmup.
  }
}

/// Adapts the core [AudioPlayerService] to the talking feature's
/// [PlaybackPositionSource] (core may not import features, so the feature
/// interface is implemented here, in the composition root).
class _AudioPlayerPositionSource implements PlaybackPositionSource {
  _AudioPlayerPositionSource(this._audioPlayerService);

  final AudioPlayerService _audioPlayerService;

  @override
  Future<Duration?> currentPosition() => _audioPlayerService.currentPosition();
}
