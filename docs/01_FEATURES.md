# Feature Catalog

## Features Overview

| Feature | Purpose | Cubit |
|---------|---------|-------|
| **chat** | ❗ Core: Messaging, streaming, TTS | `ChatCubit` |
| **avatar** | Avatar customization | `AvatarCubit` |
| **talking** | Lip-sync animation | `TalkingCubit` (singleton) |
| **settings** | App configuration | `SettingsCubit` |
| **demo** | Demo mode | `DemoCubit` |
| **home** | Home screen | `HomeCubit` |
| **sound** | Sound effects | `SoundCubit` |

---

## Core Feature: chat

**File**: `lib/features/chat/presentation/bloc/chat_cubit.dart` (21.5K)

### Structure
```
chat/
├── data/
│   ├── datasources/chat_local_datasource.dart
│   └── repositories/yofardev_repository_impl.dart
├── domain/
│   ├── models/{chat, chat_entry}.dart
│   ├── repositories/chat_repository.dart
│   └── services/{chat_entry_service, chat_title_service}.dart
└── presentation/
    ├── bloc/{chat_cubit, chat_tts_cubit, chat_state}.dart
    └── screens/{chats_list, chat_details, image_full}.dart
```

### ChatCubit: Main Coordinator

**Dependencies** (all injected):
```dart
ChatCubit(
  chatRepository: ChatRepository,
  settingsRepository: SettingsRepository,
  avatarAnimationService: AvatarAnimationService,
  chatTitleService: ChatTitleService,
  llmService: LlmServiceInterface,
  streamProcessor: StreamProcessorService,
  promptDatasource: PromptDatasource,
  interruptionService: InterruptionService,
  chatEntryService: ChatEntryService,
  ttsQueueManager: TtsQueueService,
)
```

**Key Methods**:
- `init()` - Initialize chat system
- `sendMessage(prompt, attachedImage)` - Send user message
- `clearChat()` - Clear conversation
- `deleteChat(id)` - Delete chat
- `createNewChat()` - Create new chat

**State**:
```dart
@freezed
class ChatState with _$ChatState {
  const factory ChatState.initial() = _Initial;
  const factory ChatState.loading() = _Loading;
  const factory ChatState.success() = _Success;
  const factory ChatState.streaming(String content) = _Streaming;
  const factory ChatState.failure(String errorMessage) = _Failure;
}
```

### ChatTtsCubit: TTS-Specific State

**File**: `lib/features/chat/presentation/bloc/chat_tts_cubit.dart` (8.9K)

**Dependencies**:
```dart
ChatTtsCubit(
  ttsQueueManager: TtsQueueService,
  audioAmplitudeService: AudioAmplitudeService,
  audioPlayerService: AudioPlayerService,
  interruptionService: InterruptionService,
  talkingCubit: TalkingCubit,  // ❗ Singleton
)
```

**Key Methods**:
- `enqueueTts(text, language, voiceEffect)` - Queue TTS
- `playTts(audioPath)` - Play audio
- `pauseTts()` / `resumeTts()` - Playback control
- `stopTts()` - Stop and clear queue

### Domain Services

**ChatEntryService** - Creates formatted user entries with date/avatar config
**ChatTitleService** - Auto-generates chat titles via LLM

---

## Feature: avatar

**File**: `lib/features/avatar/presentation/bloc/avatar_cubit.dart` (7.0K)

**Responsibilities**: Avatar config, clothing/background animations

**Key Methods**:
- `updateAvatarConfig(chatId, config)` - Update avatar
- `onClothesAnimationChanged(isAnimating)` - Toggle animation
- `onBackgroundTransitionChanged(transition)` - Set background

### AvatarAnimationService

**File**: `lib/core/services/avatar_animation_service.dart` (1.3K)

**Purpose**: Cross-feature animation trigger (holds AvatarCubit reference - exception to rule)

```dart
Future<void> playNewChatSequence(String chatId, AvatarConfig config)
// 1. Avatar drops, 2. Background slides, 3. Avatar rises
```

---

## Feature: talking

**File**: `lib/features/talking/presentation/bloc/talking_cubit.dart` (6.6K)

**❗ MUST BE SINGLETON** - Shared between ChatTtsCubit and UI

**Responsibilities**: Lip-sync during TTS, amplitude-based mouth animation

**Key Methods**:
- `startTalking()` / `stopTalking()` - Animation control
- `onAmplitudeChanged(double)` - Update mouth position

---

## Feature: settings

**File**: `lib/features/settings/presentation/bloc/settings_cubit.dart` (10.4K)

**Responsibilities**: Language, sound effects, LLM config, function calling

**Key Methods**:
- `setLanguage(String)` - Change app language
- `setSoundEffects(bool)` - Toggle sounds
- `setFunctionCallingEnabled(bool)` - Toggle tools
- `updateLlmConfig(LlmConfig)` - Update LLM settings

---

## Feature: home

**File**: `lib/features/home/presentation/bloc/home_cubit.dart` (1.4K)

**Responsibilities**: Volume fade for animations, waiting TTS loop, TTS playback

---

## Feature: demo

**File**: `lib/core/services/demo_controller.dart`

**Purpose**: Demo mode with fake LLM, pre-built scenarios

---

## Feature: sound

**Responsibilities**: Sound effects, TTS engine wrapper

**Key Dependencies**: `TtsQueueService`, `AudioPlayerService`, `AudioAmplitudeService`, `InterruptionService`

---

## Feature Interactions

### Chat → Avatar → Talking Chain
```
ChatCubit.sendMessage()
  → YofardevAgent.ask()
  → ChatTtsCubit.enqueueTts()
  → TtsQueueService
  → AudioPlayerService
  → TalkingCubit.startTalking()
  → AvatarCubit (animations)
```

### Settings → All Features
Settings changes propagate via repository interfaces to all features.

---

**Next**: See [02_SERVICES.md](02_SERVICES.md) for service catalog
