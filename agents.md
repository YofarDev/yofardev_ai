# Yofardev AI - Agent Quick Start

> **Comprehensive docs in `docs/`**

## Navigation

```
docs/README.md              # Start here (index)
docs/00_ARCHITECTURE.md     # Architecture overview
docs/01_FEATURES.md         # Feature catalog
docs/02_SERVICES.md         # Services catalog
docs/03_DATA_FLOW.md        # Workflow diagrams
docs/04_CONVENTIONS.md      # Coding standards
```

## Tech Stack

Flutter 3.8+, flutter_bloc 9.1.1, freezed 3.2.5, fpdart 1.2.0, get_it 9.2.1, go_router 17.1.0

## Critical Rules

1. All DI in `lib/core/di/service_locator.dart`
2. No cubit-to-cubit dependencies (use domain services)
3. No cross-feature imports (route through `core/`)

## Key Files

| File | Purpose |
|------|---------|
| `lib/core/di/service_locator.dart` | DI wiring |
| `lib/features/chat/presentation/bloc/chat_cubit.dart` | Main chat coordinator |
| `lib/core/services/agent/yofardev_agent.dart` | AI agent |

## Quick Patterns

```dart
// Get service
getIt<ServiceType>()

// State (freezed v3 requires sealed/abstract)
@freezed
class ChatState with _$ChatState {
  const factory ChatState.initial() = _Initial;
  const factory ChatState.loading() = _Loading;
}

// Errors
Future<Either<Failure, Chat>> getCurrentChat();
```

---

**Version**: 3.0.0+6 | **Last Updated**: 2026-03-12
