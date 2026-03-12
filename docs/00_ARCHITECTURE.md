# Architecture Overview

**Clean Architecture with layered approach**

```
lib/
├── main.dart                 # DI init only
├── core/                     # Shared across all features
│   ├── di/service_locator.dart    # ❗ ONLY DI wiring
│   ├── router/              # go_router config
│   ├── models/              # Shared domain models (freezed)
│   ├── services/            # Cross-cutting services
│   │   ├── agent/           # Function calling tools
│   │   ├── audio/           # TTS, playback
│   │   ├── llm/             # LLM abstraction
│   │   └── stream_processor/
│   ├── repositories/        # Shared repos
│   └── widgets/             # Shared widgets
└── features/                # ❗ NO cross-feature imports
    └── [feature]/
        ├── data/            # Repos impl, datasources
        ├── domain/          # Repos interfaces, services, models
        └── presentation/    # Cubits, states, screens
```

## Dependency Flow

```
Presentation → Domain → Data → Core Services
```

**Never reverse this direction.**

## Tech Stack

| Category | Lib |
|----------|-----|
| Framework | Flutter 3.8+ |
| State | flutter_bloc 9.1.1 |
| Models | freezed 3.2.5 |
| Errors | fpdart 1.2.0 |
| DI | get_it 9.2.1 |
| Routing | go_router 17.1.0 |
| TTS | supertonic_flutter 0.1.5 |

## 3 Critical Rules

### 1. Single DI Location
```dart
// ✅ service_locator.dart only
getIt.registerFactory<ChatCubit>(() => ChatCubit(...));

// ❌ Never in app.dart or screens
BlocProvider(create: (_) => ChatCubit(...))
```

### 2. No Cubit-to-Cubit Dependencies
```dart
// ❌ Wrong
class NotificationCubit {
  final AuthCubit _authCubit;
}

// ✅ Right - use domain service
class SessionService {
  void onUserLoggedIn(User user) {}
}
```

### 3. No Cross-Feature Imports
```dart
// ❌ Wrong
import '../../avatar/presentation/bloc/avatar_cubit.dart';

// ✅ Right - use core service
import '../../../../core/services/avatar_animation_service.dart';
```

## Key Patterns

### State: freezed Unions
```dart
@freezed
class ChatState with _$ChatState {
  const factory ChatState.initial() = _Initial;
  const factory ChatState.loading() = _Loading;
  const factory ChatState.success(Chat chat) = _Success;
  const factory ChatState.failure(String message) = _Failure;
}

// Exhaustive handling
state.when(
  initial: () => const InitialWidget(),
  loading: () => const LoadingWidget(),
  success: (chat) => ChatWidget(chat: chat),
  failure: (msg) => ErrorWidget(message: msg),
);
```

**freezed v3**: Requires `sealed` or `abstract` keyword

### Errors: Either<Failure, T>
```dart
// Repository
Future<Either<Failure, Chat>> getCurrentChat();

// Usage
result.fold(
  (error) => emit(state.copyWith(error: error.message)),
  (chat) => emit(state.copyWith(chat: chat)),
);
```

### Listeners: MultiBlocListener
```dart
// ✅ Always flat
MultiBlocListener(
  listeners: [
    BlocListener<ChatCubit, ChatState>(
      listener: (context, state) => state.whenOrNull(
        failure: (msg) => showErrorSnackBar(context, msg),
      ),
    ),
  ],
  child: Scaffold(...),
)
```

### Service → UI: Streams
```dart
// Service owns stream
class AvatarAnimationService {
  final _controller = StreamController<AvatarAnimation>.broadcast();
  Stream<AvatarAnimation> get animations => _controller.stream;
}

// Cubit subscribes
class AvatarCubit extends Cubit<AvatarState> {
  AvatarCubit(this._service) : super(...) {
    _sub = _service.animations.listen(_onAnimation);
  }
}
```

## Singleton vs Factory

| Singleton | Factory |
|-----------|---------|
| Shared state | Per-screen state |
| `registerLazySingleton` | `registerFactory` |

```dart
// Singleton - shared mutable state
getIt.registerLazySingleton<TtsService>(() => TtsService());

// Factory - fresh instance per screen
getIt.registerFactory<ChatCubit>(() => ChatCubit(...));
```

## File Size Limits

| Type | Max Lines |
|------|-----------|
| Widgets | 300 |
| Services | 400 |
| BLoCs/Cubits | 300 |

---

**Next**: See [01_FEATURES.md](01_FEATURES.md) for feature breakdown
