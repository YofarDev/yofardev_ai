# Coding Conventions

---

## State Management

### Use Cubit by Default
```dart
class MyCubit extends Cubit<MyState> {
  MyCubit() : super(MyState.initial());
}
```

### Use BLoC Only for Transformers
```dart
// Only when needing debounce/throttle
on<QueryChanged>(
  _onQueryChanged,
  transformer: (events, mapper) => events
      .debounceTime(const Duration(milliseconds: 300))
      .switchMap(mapper),
);
```

### freezed v3: Sealed or Abstract
```dart
// ✅ Requires sealed or abstract
@freezed
class ChatState with _$ChatState {
  const factory ChatState.initial() = _Initial;
}
```

### Union Types (Not Boolean Flags)
```dart
// ✅ Right
@freezed
class ChatState with _$ChatState {
  const factory ChatState.success() = _Success;
  const factory ChatState.failure(String message) = _Failure;
}

// ❌ Wrong
class ChatState {
  final bool isSuccess;
  final bool isFailure;
}
```

### Exhaustive Handling
```dart
state.when(
  initial: () => const InitialWidget(),
  loading: () => const LoadingWidget(),
  success: (chat) => ChatWidget(chat: chat),
  failure: (msg) => ErrorWidget(message: msg),
);
```

---

## Error Handling

### Either<Failure, T> Pattern
```dart
// Repository
Future<Either<Failure, Chat>> getCurrentChat();

// Usage
result.fold(
  (error) => emit(state.copyWith(error: error.message)),
  (chat) => emit(state.copyWith(chat: chat)),
);
```

**Never** return null on error.

---

## Dependency Injection

### Single Location: service_locator.dart
```dart
// ✅ All wiring here
getIt.registerFactory<ChatCubit>(() => ChatCubit(...));

// ❌ Never elsewhere
BlocProvider(create: (_) => ChatCubit(...))
```

### Singleton vs Factory

| Singleton | Factory |
|-----------|---------|
| Shared state | Per-screen |
| `registerLazySingleton` | `registerFactory` |

```dart
// Singleton - shared
getIt.registerLazySingleton<TtsService>(() => TtsService());

// Factory - per screen
getIt.registerFactory<ChatCubit>(() => ChatCubit(...));
```

### No Cubit-to-Cubit Dependencies
```dart
// ❌ Wrong
class NotificationCubit {
  final AuthCubit _authCubit;
}

// ✅ Right - domain service
class SessionService {
  void onUserLoggedIn(User user) {}
}
```

---

## Code Organization

### Feature Structure
```
[feature]/
├── data/           # Repos impl, datasources
├── domain/         # Repos interfaces, services, models
└── presentation/   # Cubits, states, screens
```

### Dependencies Flow Inward
```
presentation → domain → data → core
```

### No Cross-Feature Imports
```dart
// ❌ Wrong
import '../../avatar/presentation/bloc/avatar_cubit.dart';

// ✅ Right
import '../../../../core/services/avatar_animation_service.dart';
```

---

## File Size Limits

| Type | Max Lines |
|------|-----------|
| Widgets | 300 |
| Services | 400 |
| BLoCs/Cubits | 300 |

---

## Naming

| Type | Convention |
|------|------------|
| Files | `feature_name_cubit.dart` |
| Classes | `PascalCase` |
| Methods | `camelCase` |
| Private | `_prefix` |
| Constants | `lowerCamelCase` |

---

## Listener Pattern

### Always MultiBlocListener
```dart
// ✅ Flat
MultiBlocListener(
  listeners: [
    BlocListener<AuthCubit, AuthState>(
      listener: (context, state) => state.whenOrNull(
        authenticated: (_) => context.push('/home'),
      ),
    ),
  ],
  child: Scaffold(...),
)

// ❌ Nested
BlocListener(
  child: BlocListener(
    child: Scaffold(...),
  ),
)
```

### Navigate in Listeners, Not build()
```dart
// ❌ Wrong
@override
Widget build(BuildContext context) {
  if (state.isAuthenticated) context.push('/home');
  return Scaffold(...);
}

// ✅ Right
MultiBlocListener(
  listeners: [
    BlocListener<AuthCubit, AuthState>(
      listener: (context, state) => state.whenOrNull(
        authenticated: (_) => context.push('/home'),
      ),
    ),
  ],
  child: Scaffold(...),
)
```

---

## Deprecated APIs

### withOpacity → withValues
```dart
// ❌ Deprecated
color.withOpacity(0.5)

// ✅ Right
color.withValues(alpha: 0.5)
```

### Radio → RadioGroup
```dart
// ❌ Deprecated (after v3.32.0)
Radio(groupValue: ..., onChanged: ...)

// ✅ Right - Use RadioGroup ancestor
RadioGroup(
  value: _selectedValue,
  onChanged: (value) => setState(() => _selectedValue = value),
  child: Radio(value: value),
)
```

---

## Anti-Patterns

| ❌ Wrong | ✅ Right |
|---------|----------|
| Navigate in `build()` | Use `BlocListener` |
| Nested `BlocListener`s | Use `MultiBlocListener` |
| Services in widgets | Inject via `get_it` |
| Cross-feature imports | Route through `core/` |
| Manual cubit construction | `getIt<MyCubit>()` |
| Cubit depending on cubit | Domain service |
| `context.read` after `await` | Capture before await |
| Boolean state flags | freezed union types |

---

## Before Committing

```bash
flutter analyze
dart fix --apply
dart format .
```

---

**Back to**: [README.md](README.md)
