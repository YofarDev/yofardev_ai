# AI Agent Documentation - Yofardev AI

> **Quick Start Guide for AI Agents and LLMs**

---

## 📚 Documentation Location

All project documentation is located in the **`docs/`** directory.

### Start Here

**👉 Read `docs/README.md` first**

This will give you:
- Overview of all documentation
- Quick start guide
- Common workflows
- Key concepts

---

## Documentation Index

| Document | Purpose | Quick Link |
|----------|---------|------------|
| **docs/README.md** | Documentation index | `docs/README.md` |
| **docs/00_ARCHITECTURE.md** | Architecture overview | `docs/00_ARCHITECTURE.md` |
| **docs/01_FEATURES.md** | Feature catalog | `docs/01_FEATURES.md` |
| **docs/02_SERVICES.md** | Core services | `docs/02_SERVICES.md` |
| **docs/03_DATA_FLOW.md** | Workflow diagrams | `docs/03_DATA_FLOW.md` |
| **docs/04_CONVENTIONS.md** | Coding standards | `docs/04_CONVENTIONS.md` |
| **docs/ARCHITECTURE_DIAGRAM.md** | Visual diagrams | `docs/ARCHITECTURE_DIAGRAM.md` |

---

## Quick Reference

### Technology Stack

- **Framework**: Flutter 3.8.0+
- **State**: flutter_bloc 9.1.1 (Cubit default)
- **Models**: freezed 3.2.5 (union types)
- **Errors**: fpdart 1.2.0 (Either<Failure, T>)
- **DI**: get_it 9.2.1
- **Routing**: go_router 17.1.0

### Critical Rules

1. **All DI in `lib/core/di/service_locator.dart`** - Never wire elsewhere
2. **No cubit-to-cubit dependencies** - Use domain services
3. **No cross-feature imports** - Route through `core/services/`

### Key Files

| File | Purpose | Lines |
|------|---------|-------|
| `lib/core/di/service_locator.dart` | All DI wiring | 228 |
| `lib/features/chat/presentation/bloc/chat_cubit.dart` | Main chat coordinator | 21.5K |
| `lib/core/services/agent/yofardev_agent.dart` | AI agent | 8.6K |
| `lib/core/services/audio/tts_queue_service.dart` | TTS queue | 5.5K |

### Common Operations

```dart
// Get any service
getIt<ServiceType>()

// State pattern (freezed)
@freezed
class ChatState with _$ChatState {
  const factory ChatState.initial() = _Initial;
  const factory ChatState.loading() = _Loading;
  const factory ChatState.success() = _Success;
  const factory ChatState.failure(String message) = _Failure;
}

// Error handling (fpdart)
Future<Either<Failure, Chat>> getCurrentChat();
result.fold(
  (error) => emit(state.copyWith(error: error.message)),
  (chat) => emit(state.copyWith(chat: chat)),
);
```

---

## Feature Structure

```
lib/features/
├── avatar/          # Avatar customization
├── chat/            # ❗ CORE: Chat, streaming, TTS
├── demo/            # Demo mode
├── home/            # Home screen
├── settings/        # App configuration
├── sound/           # Sound effects
└── talking/         # Lip-sync animation
```

---

## Next Steps

1. **Read `docs/README.md`** for full documentation
2. **Check `docs/00_ARCHITECTURE.md`** for architecture overview
3. **Reference `docs/04_CONVENTIONS.md`** before writing code

---

## Project Info

- **Name**: Yofardev AI
- **Version**: 3.0.0+6
- **Description**: Animated AI avatar with real-time chat
- **Architecture**: Clean Architecture (layered)

---

**Last Updated**: 2026-03-12
**Framework**: Flutter 3.8.0+
