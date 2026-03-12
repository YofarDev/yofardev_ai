# Core Services Catalog

```
core/services/
├── agent/                    # AI agent & function calling
├── audio/                    # TTS & playback
├── llm/                      # LLM abstraction
├── stream_processor/         # Stream chunking
├── avatar_animation_service.dart
├── demo_controller.dart
├── prompt_datasource.dart
└── settings_local_datasource.dart
```

---

## Agent Services

### YofardevAgent
**File**: `lib/core/services/agent/yofardev_agent.dart` (8.6K)

**Purpose**: Main AI agent, coordinates LLM + function calling

**Key Method**:
```dart
Future<List<ChatEntry>> ask({
  required Chat chat,
  required String userMessage,
  required String systemPrompt,
  bool functionCallingEnabled = true,
  required SettingsRepository settingsRepository,
})
```

**Workflow**: Check tools → Execute tools → Augment prompt → Get LLM response → Return entries

### ToolRegistry
**Available Tools**: weather, news, google_search, calculator, character_counter, alarm, web_reader

**Key Methods**:
- `getFunctionInfos(SettingsRepository)` - Get enabled tools
- `getTool(String name)` - Get tool by name
- `executeTool(AgentTool, params, settings)` - Execute tool

---

## Audio Services

### TtsQueueService
**File**: `lib/core/services/audio/tts_queue_service.dart` (5.5K)

**Purpose**: Priority-based TTS queue with background generation

**Key Methods**:
```dart
Future<void> enqueue({
  required String text,
  required String language,
  required VoiceEffect voiceEffect,
  TtsPriority priority = TtsPriority.normal,
})
void clear()
void setPaused(bool paused)
```

**Streams**: `audioStream: Stream<String>` - Emits generated audio paths

### Other Audio Services

| Service | Purpose | File |
|---------|---------|------|
| TtsService | Simple TTS wrapper | 0.7K |
| AudioPlayerService | Playback management | 2.9K |
| AudioAmplitudeService | Amplitude analysis | 1.2K |
| InterruptionService | Interruption coordination | 1.4K |

---

## LLM Services

### LlmService
**File**: `lib/core/services/llm/llm_service.dart` (12.9K)

**Supported**: OpenAI (GPT-3.5/4), Anthropic Claude, Local (Ollama, LM Studio)

**Key Methods**:
```dart
Future<void> init()
Future<String?> promptModel({...})
Future<(String, List<FunctionInfo>)> checkFunctionsCalling({...})
LlmConfig? getCurrentConfig()
```

### Other LLM Services

| Service | Purpose | File |
|---------|---------|------|
| LlmServiceInterface | Interface for real/fake injection | 2.5K |
| FakeLlmService | Fake LLM for testing/demo | 6.8K |
| LlmConfigManager | Config management | 4.9K |
| LlmStreamingService | Streaming responses | 4.7K |

---

## Stream Processing

### StreamProcessorService
**Purpose**: Splits streaming LLM responses into sentence chunks

**Key Method**:
```dart
Stream<SentenceChunk> processStream(Stream<String> stream)
```

---

## Avatar Services

### AvatarAnimationService
**File**: `lib/core/services/avatar_animation_service.dart` (1.3K)

**Purpose**: Orchestrates avatar animations across features

**Key Method**:
```dart
Future<void> playNewChatSequence(String chatId, AvatarConfig config)
// Sequence: drop → slide background → rise
```

**Dependency**: `AvatarCubit` (singleton) - exception to no-cubit-ref rule

---

## Data Sources

| Datasource | Purpose | Location |
|------------|---------|----------|
| PromptDatasource | System prompts | core/services/ |
| SettingsLocalDatasource | Settings storage | core/services/ |
| ChatLocalDatasource | Chat persistence | features/chat/data/ |
| AvatarLocalDatasource | Avatar storage | features/avatar/data/ |
| TtsDatasource | TTS engine wrapper | features/sound/data/ |

---

## Demo Services

### DemoController
**File**: `lib/core/services/demo_controller.dart` (1.9K)

**Purpose**: Demo mode control, fake LLM switching

**Key Methods**:
- `enableDemoMode()` - Switch to fake LLM
- `disableDemoMode()` - Switch to real LLM

---

## Service Registration

All in `lib/core/di/service_locator.dart`:

```dart
// LLM (conditional)
if (kDebugMode) {
  getIt.registerLazySingleton<LlmServiceInterface>(() => FakeLlmService());
} else {
  getIt.registerLazySingleton<LlmServiceInterface>(() => LlmService());
}

// Audio
getIt.registerLazySingleton<TtsQueueService>(...);
getIt.registerLazySingleton<AudioPlayerService>(...);

// Agent
getIt.registerLazySingleton<YofardevAgent>(...);

// Domain
getIt.registerLazySingleton<ChatEntryService>(...);
getIt.registerLazySingleton<AvatarAnimationService>(...);
```

---

## Dependency Graph

```
YofardevAgent
  ├── LlmService
  └── ToolRegistry
      ├── WeatherService
      ├── GoogleSearchService
      └── ... (other tools)

ChatCubit
  ├── ChatRepository
  ├── SettingsRepository
  ├── AvatarAnimationService → AvatarCubit
  ├── LlmServiceInterface
  ├── StreamProcessorService
  └── TtsQueueService
      ├── TtsDatasource
      └── InterruptionService

ChatTtsCubit
  ├── TtsQueueService
  ├── AudioAmplitudeService
  ├── AudioPlayerService
  └── TalkingCubit (singleton)
```

---

**Next**: See [03_DATA_FLOW.md](03_DATA_FLOW.md) for workflows
