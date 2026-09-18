# Data Flow & Workflows

---

## Workflow 1: Sending a Message

```
User → ChatCubit.sendMessage()
     ├─→ Emit streaming state
     ├─→ ChatEntryService.createUserEntry()
     └─→ ChatStreamingService.streamResponse()
          ├─→ LlmService.promptModelStream() (tools passed inline)
          │    ├─→ StreamProcessorService (sentence chunks)
          │    └─→ tool_call deltas? → ToolRegistry.executeTool()
          │         → append tool results → re-stream (max 3 rounds)
          └─→ per sentence:
               └─→ ChatTtsCubit.enqueueTts()
                    └─→ TtsQueueService (generate)
                         └─→ AudioPlayerService (play)
                              └─→ TalkingCubit.startTalking()
                                   └─→ AvatarCubit (animations)
```

### Function Calling Flow
```
User: "What's the weather in Paris?"
  ↓
ChatStreamingService.streamResponse() (streamed, tools inline)
  ↓
Stream carries tool_call deltas → weather_tool
  ↓
ToolRegistry.executeTool() → WeatherService.getWeather("Paris")
  ↓
Append assistant tool_calls + tool result messages → re-stream
  ↓
Answer streams sentence-by-sentence ("The weather in Paris is 15°C...")
```

---

## Workflow 2: Creating a New Chat

```
User → ChatCubit.createNewChat()
     ↓
AvatarAnimationService.playNewChatSequence()
     ├─→ onClothesAnimationChanged(true)  // Avatar drops
     ├─→ Wait 2s
     ├─→ onBackgroundTransitionChanged(sliding)  // Background slides
     ├─→ Wait 0.5s
     ├─→ updateAvatarConfig(chatId, config)
     └─→ onClothesAnimationChanged(false)  // Avatar rises
```

---

## Workflow 3: Audio Interruption

```
User clicks "Stop" / new message
  ↓
InterruptionService.interrupt()
  ├─→ TtsQueueService.clear()  // Cancel generation
  ├─→ AudioPlayerService.stop()  // Stop playback
  └─→ TalkingCubit.stopTalking()  // Reset animation
```

---

## Workflow 4: Changing Language

```
SettingsCubit.setLanguage('en')
  ↓
SettingsRepository → SettingsLocalDatasource
  ↓
SharedPreferences.setString('language', 'en')
  ↓
ChatCubit._loadSettings()
  ↓
state.currentLanguage = 'en'
  ↓
MyApp (BlocBuilder) → MaterialApp.router updates locale
```

---

## State Machines

### Chat Lifecycle
```
initial → init() → loading → getCurrentChat() → success
    ↑                                          │
    └──────────────── sendMessage() ──────────┘
                     │
                     ↓
              streaming (content: "")
                     │
                     ↓
              streaming (content: "...")
                     │
                     complete
                     ↓
                   success
```

### TTS Playback
```
idle → enqueueTts() → queued → generated → playing
    ↑                                         │
    │                                         │ complete
    └─────────────────────────────────────────┘

playing ──pauseTts()──→ paused ──resumeTts()──→ playing
```

---

## Data Persistence Flow

```
Presentation (Cubits)
  ↓
Domain (Repository Interfaces)
  ↓
Data (Repository Implementations)
  ↓
Datasources (LocalStorage, TTS, etc.)
  ↓
SharedPreferences / Files
```

---

## Quick Reference

| Action | Entry Point |
|--------|-------------|
| Send message | `ChatCubit.sendMessage()` |
| Create chat | `ChatCubit.createNewChat()` |
| TTS playback | `ChatTtsCubit.enqueueTts()` |
| Avatar anim | `AvatarAnimationService.playNewChatSequence()` |
| Interrupt | `InterruptionService.interrupt()` |

---

**Next**: See [04_CONVENTIONS.md](04_CONVENTIONS.md) for coding standards
