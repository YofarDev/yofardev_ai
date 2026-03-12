# Data Flow & Workflows

---

## Workflow 1: Sending a Message

```
User → ChatCubit.sendMessage()
     ├─→ Emit streaming state
     ├─→ ChatEntryService.createUserEntry()
     └─→ YofardevAgent.ask()
          ├─→ Check function calling (ToolRegistry)
          ├─→ Execute tools if needed
          ├─→ LlmService.promptModel()
          └─→ Return entries[]
               └─→ StreamProcessorService (chunks)
                    └─→ ChatTtsCubit.enqueueTts() (per sentence)
                         └─→ TtsQueueService (generate)
                              └─→ AudioPlayerService (play)
                                   └─→ TalkingCubit.startTalking()
                                        └─→ AvatarCubit (animations)
```

### Function Calling Flow
```
User: "What's the weather in Paris?"
  ↓
YofardevAgent.ask()
  ↓
LlmService.checkFunctionsCalling() → Returns: weather_tool
  ↓
ToolRegistry.executeTool() → WeatherService.getWeather("Paris")
  ↓
Augment prompt: "What's the weather... [System: weather tool executed. Result: 15°C]"
  ↓
LlmService.promptModel() → "The weather in Paris is 15°C..."
  ↓
Return [function_call_entry, response_entry]
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
