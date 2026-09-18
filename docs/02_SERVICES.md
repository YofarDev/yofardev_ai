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

Tool detection and execution now happen inline in the streamed LLM call (see
`ChatStreamingService` in the chat feature); there is no separate agent class.

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
LlmConfig? getCurrentConfig()
```

### Other LLM Services

| Service | Purpose | File |
|---------|---------|------|
| LlmServiceInterface | Interface for real/fake injection | 2.5K |
| FakeLlmService | Fake LLM for testing/demo | 6.8K |
| LlmConfigManager | Config management | 4.9K |
| LlmStreamingService | Streaming responses | 4.7K |
| llm_usage_logger | Logs prompt/cached token counts (OpenAI + DeepSeek formats) | 0.6K |

### Prompt Caching

All requests use the OpenAI-compatible protocol where caching is automatic
(no `cache_control`). Two things make it effective:

1. **Stable prefix**: the system prompt is deterministic and global memory
   is injected at the END of the request (see GlobalMemoryService), never
   into the system prompt.
2. **Observability**: streaming requests send
   `stream_options: {include_usage: true}` and both request paths log
   `LLM usage: prompt=X cached=Y (Z%)` from the response usage object
   (OpenAI `prompt_tokens_details.cached_tokens` / DeepSeek
   `prompt_cache_hit_tokens`).

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

// Domain
getIt.registerLazySingleton<ChatEntryService>(...);
getIt.registerLazySingleton<AvatarAnimationService>(...);
```

---

## Dependency Graph

```
ChatStreamingService
  ├── LlmServiceInterface (streamed tool detection)
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
