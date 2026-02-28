# Architecture Standardization Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Restructure the yofardev_ai Flutter codebase to match the standardized feature-based architecture template, eliminating duplicate services, moving files to proper locations, and ensuring all files comply with size limits.

**Architecture:** Big bang migration with 7 phases: (1) Add tests as safety net, (2) Extract oversized files, (3) Directory restructure (ui→features, services→core/services, etc.), (4) Update imports, (5) Split BLoC/Cubit files, (6) Verification, (7) Cleanup.

**Tech Stack:** Flutter 3.8+, Dart, flutter_bloc, freezed, get_it (DI), shared_preferences, http

---

## Prerequisites

**Before starting:**
- Create a dedicated branch: `git checkout -b refactor/architecture-standardization`
- Ensure main branch is clean: `git status` (no uncommitted changes)
- Run tests: `flutter test` (establish baseline - expect 1 passing test)
- Note: We're adding tests first (TDD approach) to catch regressions during migration

**Key file locations for reference:**
- Current main entry: `lib/main.dart`
- Current chat feature: `lib/features/chat/`
- Current ui pages: `lib/ui/pages/`
- Current services: `lib/services/` and `lib/core/services/`

---

## Phase 1: Safety Net - Add Tests

### Task 1.1: Create ChatsCubit Unit Test

**Files:**
- Create: `test/features/chat/bloc/chats_cubit_test.dart`
- Reference: `lib/features/chat/bloc/chats_cubit.dart`

**Step 1: Create test file structure**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:yofardev_ai/features/chat/bloc/chats_cubit.dart';
import 'package:yofardev_ai/features/chat/bloc/chat_state.dart';
import 'package:yofardev_ai/services/chat_history_service.dart';
import 'package:yofardev_ai/services/settings_service.dart';
import 'package:yofardev_ai/repositories/yofardev_repository.dart';

@GenerateMocks([ChatHistoryService, SettingsService, YofardevRepository])
import 'chats_cubit_test.mocks.dart';

void main() {
  late ChatsCubit cubit;
  late MockChatHistoryService mockChatHistoryService;
  late MockSettingsService mockSettingsService;
  late MockYofardevRepository mockRepository;

  setUp(() {
    mockChatHistoryService = MockChatHistoryService();
    mockSettingsService = MockSettingsService();
    mockRepository = MockYofardevRepository();
    cubit = ChatsCubit(
      chatHistoryService: mockChatHistoryService,
      settingsService: mockSettingsService,
      yofardevRepository: mockRepository,
    );
  });

  tearDown(() {
    cubit.close();
  });

  group('ChatsCubit', () {
    test('initial state is ChatsState with defaults', () {
      expect(cubit.state, const ChatsState());
    });

    test('toggleFunctionCalling updates functionCallingEnabled', () {
      const bool initialValue = true;
      // Test toggle from true to false
      cubit.toggleFunctionCalling();
      expect(cubit.state.functionCallingEnabled, false);
      // Test toggle back to true
      cubit.toggleFunctionCalling();
      expect(cubit.state.functionCallingEnabled, true);
    });

    test('setCurrentLanguage updates currentLanguage', () async {
      when(mockSettingsService.setLanguage(any)).thenAnswer((_) async {});

      const String testLanguage = 'en';
      await cubit.setCurrentLanguage(testLanguage);

      expect(cubit.state.currentLanguage, testLanguage);
      verify(mockSettingsService.setLanguage(testLanguage)).called(1);
    });

    test('setSoundEffects updates soundEffectsEnabled', () async {
      when(mockSettingsService.setSoundEffects(any)).thenAnswer((_) async {});

      const bool testValue = true;
      await cubit.setSoundEffects(testValue);

      expect(cubit.state.soundEffectsEnabled, testValue);
      verify(mockSettingsService.setSoundEffects(testValue)).called(1);
    });

    test('setCurrentChat updates openedChat', () {
      final Chat testChat = Chat(id: 'test-chat');
      cubit.setOpenedChat(testChat);

      expect(cubit.state.openedChat, testChat);
    });
  });
}
```

**Step 2: Generate mocks**

Run: `flutter pub run build_runner build --delete-conflicting-outputs`
Expected: Creates `test/features/chat/bloc/chats_cubit_test.mocks.dart`

**Step 3: Run tests**

Run: `flutter test test/features/chat/bloc/chats_cubit_test.dart`
Expected: Some may fail due to missing implementations - that's OK, we're establishing baseline

**Step 4: Commit**

```bash
git add test/features/chat/bloc/chats_cubit_test.dart
git add test/features/chat/bloc/chats_cubit_test.mocks.dart
git commit -m "test: add ChatsCubit unit tests

- Test initial state, toggleFunctionCalling, setCurrentLanguage
- Test setSoundEffects, setCurrentChat, setOpenedChat
- Add mockito mocks for dependencies

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

### Task 1.2: Create AvatarCubit Unit Test

**Files:**
- Create: `test/features/avatar/bloc/avatar_cubit_test.dart`
- Reference: `lib/features/avatar/bloc/avatar_cubit.dart`

**Step 1: Create test file structure**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/features/avatar/bloc/avatar_cubit.dart';
import 'package:yofardev_ai/features/avatar/bloc/avatar_state.dart';
import 'package:yofardev_ai/core/models/avatar_config.dart';

void main() {
  group('AvatarCubit', () {
    late AvatarCubit cubit;

    setUp(() {
      cubit = AvatarCubit();
    });

    tearDown(() {
      cubit.close();
    });

    test('initial state has default Avatar', () {
      expect(cubit.state.avatar, isA<Avatar>());
      expect(cubit.state.avatar.background, AvatarBackgrounds.lake);
    });

    test('loadAvatar updates state with provided Avatar', () {
      const Avatar testAvatar = Avatar(
        background: AvatarBackgrounds.beach,
        hat: AvatarHat.beanie,
      );

      cubit.loadAvatar('chat-id', testAvatar: testAvatar);

      expect(cubit.state.avatar.background, AvatarBackgrounds.beach);
      expect(cubit.state.avatar.hat, AvatarHat.beanie);
    });
  });
}
```

**Step 2: Run tests**

Run: `flutter test test/features/avatar/bloc/avatar_cubit_test.dart`
Expected: Establish baseline for AvatarCubit

**Step 3: Commit**

```bash
git add test/features/avatar/bloc/avatar_cubit_test.dart
git commit -m "test: add AvatarCubit unit tests

- Test initial state with default Avatar
- Test loadAvatar method

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

### Task 1.3: Create Widget Test for ai_text_input

**Files:**
- Create: `test/widgets/ai_text_input_test.dart`
- Reference: `lib/ui/widgets/ai_text_input.dart`

**Step 1: Create widget test file**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:yofardev_ai/widgets/ai_text_input.dart';
import 'package:yofardev_ai/features/chat/bloc/chats_cubit.dart';
import 'package:yofardev_ai/features/chat/bloc/chat_state.dart';
import 'package:yofardev_ai/features/avatar/bloc/avatar_cubit.dart';
import 'package:yofardev_ai/features/avatar/bloc/avatar_state.dart';
import 'package:yofardev_ai/logic/talking/talking_cubit.dart';
import 'package:yofardev_ai/logic/talking/talking_state.dart';

void main() {
  group('AiTextInput Widget', () {
    late ChatsCubit chatsCubit;
    late AvatarCubit avatarCubit;
    late TalkingCubit talkingCubit;

    setUp(() {
      chatsCubit = ChatsCubit(
        chatHistoryService: MockChatHistoryService(),
        settingsService: MockSettingsService(),
        yofardevRepository: MockYofardevRepository(),
      );
      avatarCubit = AvatarCubit();
      talkingCubit = TalkingCubit();
    });

    tearDown(() {
      chatsCubit.close();
      avatarCubit.close();
      talkingCubit.close();
    });

    Widget makeTestableWidget() {
      return MaterialApp(
        home: MultiBlocProvider(
          providers: [
            BlocProvider<ChatsCubit>.value(value: chatsCubit),
            BlocProvider<AvatarCubit>.value(value: avatarCubit),
            BlocProvider<TalkingCubit>.value(value: talkingCubit),
          ],
          child: const Scaffold(
            body: AiTextInput(),
          ),
        ),
      );
    }

    testWidgets('renders text input field', (WidgetTester tester) async {
      await tester.pumpWidget(makeTestableWidget());
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('shows error snackbar on chat error', (WidgetTester tester) async {
      await tester.pumpWidget(makeTestableWidget());

      // Emit error state
      chatsCubit.emit(chatsCubit.state.copyWith(
        status: ChatsStatus.error,
        errorMessage: 'Test error',
      ));
      await tester.pumpAndSettle();

      expect(find.text('Test error'), findsOneWidget);
    });
  });
}
```

**Step 2: Run tests**

Run: `flutter test test/widgets/ai_text_input_test.dart`
Expected: Widget renders correctly

**Step 3: Commit**

```bash
git add test/widgets/ai_text_input_test.dart
git commit -m "test: add AiTextInput widget tests

- Test widget renders text field
- Test error snackbar appears on error state

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

### Task 1.4: Create Integration Smoke Test

**Files:**
- Create: `test/integration/smoke_test.dart`

**Step 1: Create integration test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:yofardev_ai/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('App Smoke Tests', () {
    testWidgets('app launches successfully', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      expect(find.text('Yofardev AI'), findsOneWidget);
    });

    testWidgets('can navigate to settings', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Tap settings icon
      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();

      expect(find.text('Settings'), findsOneWidget);
    });
  });
}
```

**Step 2: Run smoke test**

Run: `flutter test integration_test/smoke_test.dart`
Expected: App launches and basic navigation works

**Step 3: Commit**

```bash
git add test/integration/smoke_test.dart
git commit -m "test: add integration smoke tests

- Test app launches successfully
- Test basic settings navigation

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Phase 2: Extract Oversized Components

### Task 2.1: Extract Speech-to-Text Handler from ai_text_input

**Files:**
- Create: `lib/ui/widgets/ai_text_input/speech_to_text_handler.dart`
- Modify: `lib/ui/widgets/ai_text_input.dart`

**Step 1: Create speech handler class**

Create: `lib/ui/widgets/ai_text_input/speech_to_text_handler.dart`

```dart
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../utils/platform_utils.dart';

class SpeechToTextHandler {
  SpeechToText? _speechToText;
  bool _speechEnabled = false;

  bool get isSpeechListening => _speechToText?.isListening ?? false;
  bool get isSpeechEnabled => _speechEnabled;

  Future<void> initialize() async {
    if (PlatformUtils.checkPlatform() == 'Web') return;

    bool enable = false;
    if (PlatformUtils.checkPlatform() != 'MacOS') {
      final PermissionStatus status = await Permission.microphone.request();
      enable = status.isGranted;
    }

    if (enable) {
      _speechToText = SpeechToText();
      _speechEnabled = await _speechToText!.initialize();
    }
  }

  Future<void> startListening({
    required String localeId,
    required Function(SpeechRecognitionResult) onResult,
  }) async {
    if (_speechToText == null) return;

    await _speechToText!.listen(
      onResult: onResult,
      localeId: localeId,
      listenOptions: const SpeechListenOptions(partialResults: false),
    );
  }

  Future<void> stopListening() async {
    await _speechToText?.stop();
  }

  void dispose() {
    _speechToText = null;
  }
}
```

**Step 2: Refactor ai_text_input to use handler**

Modify: `lib/ui/widgets/ai_text_input.dart`

- Remove: `_speechToText` and `_speechEnabled` fields
- Add: `final SpeechToTextHandler _speechHandler = SpeechToTextHandler();`
- Replace: All speech-related calls with `_speechHandler` methods

**Step 3: Run tests**

Run: `flutter test test/widgets/ai_text_input_test.dart`
Expected: Tests still pass

**Step 4: Commit**

```bash
git add lib/ui/widgets/ai_text_input/
git commit -m "refactor(ai_text_input): extract SpeechToTextHandler

- Create separate SpeechToTextHandler class
- Reduce ai_text_input.dart by ~60 lines
- Maintain same functionality

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

### Task 2.2: Extract Image Picker Handler from ai_text_input

**Files:**
- Create: `lib/ui/widgets/ai_text_input/image_picker_handler.dart`
- Modify: `lib/ui/widgets/ai_text_input.dart`

**Step 1: Create image picker handler**

Create: `lib/ui/widgets/ai_text_input/image_picker_handler.dart`

```dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ImagePickerHandler {
  final ImagePicker _picker = ImagePicker();

  Future<File?> pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return null;
    return File(image.path);
  }

  void dispose() {
    // Cleanup if needed
  }
}
```

**Step 2: Refactor ai_text_input to use handler**

Modify: `lib/ui/widgets/ai_text_input.dart`

- Remove: Direct `_onImageSelected` logic
- Add: `final ImagePickerHandler _imageHandler = ImagePickerHandler();`
- Update: Image selection to use `_imageHandler`

**Step 3: Run tests**

Run: `flutter test`
Expected: All tests pass

**Step 4: Commit**

```bash
git add lib/ui/widgets/ai_text_input/
git commit -m "refactor(ai_text_input): extract ImagePickerHandler

- Create separate ImagePickerHandler class
- Reduce ai_text_input.dart by ~40 lines

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

### Task 2.3: Extract Settings Page Widgets

**Files:**
- Create: `lib/ui/pages/settings/widgets/settings_app_bar.dart`
- Create: `lib/ui/pages/settings/widgets/username_field.dart`
- Create: `lib/ui/pages/settings/widgets/persona_dropdown.dart`
- Create: `lib/ui/pages/settings/widgets/sound_effects_toggle.dart`
- Modify: `lib/ui/pages/settings/settings_page.dart`

**Step 1: Create settings app bar widget**

Create: `lib/ui/pages/settings/widgets/settings_app_bar.dart`

```dart
import 'package:flutter/material.dart';
import '../../../res/app_colors.dart';
import '../../l10n/localization_manager.dart';

class SettingsAppBar extends StatelessWidget {
  final VoidCallback onSave;

  const SettingsAppBar({super.key, required this.onSave});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            AppColors.surface.withValues(alpha: 0.9),
            AppColors.surface.withValues(alpha: 0.7),
          ],
        ),
        border: Border(
          bottom: BorderSide(
            color: AppColors.glassBorder.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(
            localized.settings,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: <Color>[
                  AppColors.success.withValues(alpha: 0.2),
                  AppColors.success.withValues(alpha: 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.success.withValues(alpha: 0.5),
                width: 1.5,
              ),
            ),
            child: IconButton(
              icon: const Icon(Icons.save),
              onPressed: onSave,
              tooltip: 'Save',
            ),
          ),
        ],
      ),
    );
  }
}
```

**Step 2: Create username field widget**

Create: `lib/ui/pages/settings/widgets/username_field.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../res/app_colors.dart';
import '../../l10n/localization_manager.dart';

class UsernameField extends StatelessWidget {
  final TextEditingController controller;

  const UsernameField({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            AppColors.glassSurface.withValues(alpha: 0.12),
            AppColors.glassSurface.withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.glassBorder.withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: TextFormField(
            controller: controller,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.onSurface,
            ),
            decoration: InputDecoration(
              hintText: localized.username,
              hintStyle: TextStyle(
                color: AppColors.onSurface.withValues(alpha: 0.5),
              ),
              prefixIcon: Icon(
                Icons.person_outline,
                color: AppColors.onSurface.withValues(alpha: 0.7),
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

**Step 3: Create persona dropdown widget**

Create: `lib/ui/pages/settings/widgets/persona_dropdown.dart`

```dart
import 'package:flutter/material.dart';
import '../../../models/chat.dart';
import '../../l10n/localization_manager.dart';

class PersonaDropdown extends StatelessWidget {
  final ChatPersona value;
  final ValueChanged<ChatPersona> onChanged;

  const PersonaDropdown({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(localized.personaAssistant, style: const TextStyle(fontSize: 20)),
          DropdownButton<ChatPersona>(
            value: value,
            items: ChatPersona.values.map<DropdownMenuItem<ChatPersona>>((ChatPersona value) {
              return DropdownMenuItem<ChatPersona>(
                value: value,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(value.name.toUpperCase()),
                ),
              );
            }).toList(),
            onChanged: (ChatPersona? newValue) {
              if (newValue != null) onChanged(newValue);
            },
          ),
        ],
      ),
    );
  }
}
```

**Step 4: Create sound effects toggle widget**

Create: `lib/ui/pages/settings/widgets/sound_effects_toggle.dart`

```dart
import 'package:flutter/material.dart';
import '../../../res/app_colors.dart';
import '../../../models/sound_effects.dart';
import '../../l10n/localization_manager.dart';
import '../../widgets/settings/glassmorphic_switch.dart';

class SoundEffectsToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const SoundEffectsToggle({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            AppColors.glassSurface.withValues(alpha: 0.12),
            AppColors.glassSurface.withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.glassBorder.withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: <Color>[
                      AppColors.warning.withValues(alpha: 0.2),
                      AppColors.warning.withValues(alpha: 0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.volume_up_outlined,
                  color: AppColors.warning,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                localized.enableSoundEffects,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.onSurface,
                ),
              ),
            ],
          ),
          GlassmorphicSwitch(
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
```

**Step 5: Refactor settings_page to use new widgets**

Modify: `lib/ui/pages/settings/settings_page.dart`

- Replace inline widgets with: `SettingsAppBar`, `UsernameField`, `PersonaDropdown`, `SoundEffectsToggle`
- Settings page should now be ~150 lines

**Step 6: Run tests**

Run: `flutter test`
Expected: All tests pass

**Step 7: Commit**

```bash
git add lib/ui/pages/settings/
git commit -m "refactor(settings): extract widgets to reduce file size

- Create SettingsAppBar, UsernameField, PersonaDropdown, SoundEffectsToggle
- Reduce settings_page.dart from 308 to ~150 lines
- Improve code reusability and testability

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Phase 3: Directory Restructure (Big Bang Migration)

### Task 3.1: Move Chat Pages and Widgets to features/chat

**Files:**
- Move: `lib/ui/pages/chat/*` → `lib/features/chat/screens/`
- Move: `lib/ui/widgets/chat/*` → `lib/features/chat/widgets/`
- Move: `lib/ui/pages/chat/widgets/*` → `lib/features/chat/widgets/`

**Step 1: Create target directories**

```bash
mkdir -p lib/features/chat/screens
mkdir -p lib/features/chat/widgets
```

**Step 2: Move chat pages**

```bash
# Move pages
git mv lib/ui/pages/chat/chats_list_page.dart lib/features/chat/screens/chats_list_screen.dart
git mv lib/ui/pages/chat/chat_details_page.dart lib/features/chat/screens/chat_details_screen.dart
git mv lib/ui/pages/chat/image_full_screen.dart lib/features/chat/screens/image_full_screen.dart

# Move page widgets
git mv lib/ui/pages/chat/widgets/* lib/features/chat/widgets/

# Move chat widgets
git mv lib/ui/widgets/chat/* lib/features/chat/widgets/
```

**Step 3: Update imports in moved files**

For each moved file, update imports:

```dart
// OLD
import '../../ui/widgets/...';

// NEW
import '../../widgets/...';  // Same feature, no need for ui/ prefix
```

**Step 4: Update imports across codebase**

Run: `find lib -name "*.dart" -exec sed -i '' 's|lib/ui/pages/chat/|lib/features/chat/screens/|g' {} +`

**Step 5: Run analyzer**

Run: `flutter analyze`
Expected: May show import errors, fix in next steps

**Step 6: Commit**

```bash
git add lib/
git commit -m "refactor: move chat pages and widgets to features/chat

- Move lib/ui/pages/chat/* → lib/features/chat/screens/
- Move lib/ui/widgets/chat/* → lib/features/chat/widgets/
- Rename *_page.dart to *_screen.dart for consistency

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

### Task 3.2: Move Settings Pages and Widgets

**Files:**
- Move: `lib/ui/pages/settings/*` → `lib/features/settings/screens/`
- Move: `lib/ui/widgets/settings/*` → `lib/features/settings/widgets/`

**Step 1: Create target directories**

```bash
mkdir -p lib/features/settings/screens
mkdir -p lib/features/settings/widgets
mkdir -p lib/features/settings/screens/llm
```

**Step 2: Move settings files**

```bash
# Move main settings page
git mv lib/ui/pages/settings/settings_page.dart lib/features/settings/screens/settings_screen.dart

# Move LLM pages
git mv lib/ui/pages/settings/llm/* lib/features/settings/screens/llm/

# Move settings widgets
git mv lib/ui/widgets/settings/* lib/features/settings/widgets/
```

**Step 3: Update imports**

Update imports in moved files and across codebase.

**Step 4: Commit**

```bash
git add lib/
git commit -m "refactor: move settings pages and widgets to features/settings

- Move lib/ui/pages/settings/* → lib/features/settings/screens/
- Move lib/ui/widgets/settings/* → lib/features/settings/widgets/

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

### Task 3.3: Move Avatar, Demo, and Other Widgets

**Files:**
- Move: `lib/ui/widgets/avatar/*` → `lib/features/avatar/widgets/`
- Move: `lib/ui/widgets/demo/*` → `lib/features/demo/widgets/`
- Move: `lib/ui/widgets/ai_text_input/*` → `lib/features/chat/widgets/ai_text_input/`

**Step 1: Move avatar widgets**

```bash
git mv lib/ui/widgets/avatar/* lib/features/avatar/widgets/
```

**Step 2: Move demo widgets**

```bash
# Demo controls already exists in features/demo/widgets/
# Remove duplicate if exists
rm -f lib/ui/widgets/demo/demo_controls.dart
```

**Step 3: Move ai_text_input to chat feature**

```bash
mkdir -p lib/features/chat/widgets/ai_text_input
git mv lib/ui/widgets/ai_text_input/* lib/features/chat/widgets/ai_text_input/
```

**Step 4: Commit**

```bash
git add lib/
git commit -m "refactor: move avatar, demo, and ai_text_input widgets

- Move lib/ui/widgets/avatar/* → lib/features/avatar/widgets/
- Move lib/ui/widgets/ai_text_input/* → lib/features/chat/widgets/ai_text_input/
- Remove duplicate demo controls

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

### Task 3.4: Move Glassmorphic and Animation Widgets to Core

**Files:**
- Move: `lib/ui/widgets/glassmorphic/*` → `lib/core/widgets/glassmorphic/`
- Move: `lib/ui/widgets/animations/*` → `lib/core/widgets/animations/`

**Step 1: Create core widget directories**

```bash
mkdir -p lib/core/widgets/glassmorphic
mkdir -p lib/core/widgets/animations
```

**Step 2: Move glassmorphic widgets**

```bash
git mv lib/ui/widgets/glassmorphic/* lib/core/widgets/glassmorphic/
git mv lib/ui/widgets/glassmorphic_text_field.dart lib/core/widgets/glassmorphic/
git mv lib/ui/widgets/glassmorphic_icon_button.dart lib/core/widgets/glassmorphic/
```

**Step 3: Move animations**

```bash
git mv lib/ui/widgets/animations/* lib/core/widgets/animations/
```

**Step 4: Move remaining core widgets**

```bash
git mv lib/ui/widgets/constrained_width.dart lib/core/widgets/
git mv lib/ui/widgets/app_icon_button.dart lib/core/widgets/
git mv lib/ui/widgets/picker_buttons.dart lib/core/widgets/
git mv lib/ui/widgets/function_calling_button.dart lib/core/widgets/
git mv lib/ui/widgets/current_prompt_text.dart lib/core/widgets/
git mv lib/ui/widgets/home_buttons.dart lib/core/widgets/
```

**Step 5: Update imports across codebase**

Run: `find lib -name "*.dart" -exec sed -i '' 's|lib/ui/widgets/glassmorphic/|lib/core/widgets/glassmorphic/|g' {} +`

**Step 6: Commit**

```bash
git add lib/
git commit -m "refactor: move reusable widgets to core/widgets

- Move lib/ui/widgets/glassmorphic/* → lib/core/widgets/glassmorphic/
- Move lib/ui/widgets/animations/* → lib/core/widgets/animations/
- Move other reusable widgets to lib/core/widgets/

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

### Task 3.5: Move Home Page to Feature

**Files:**
- Move: `lib/ui/pages/home.dart` → `lib/features/home/screens/home_screen.dart`

**Step 1: Create home feature directory**

```bash
mkdir -p lib/features/home/screens
```

**Step 2: Move home page**

```bash
git mv lib/ui/pages/home.dart lib/features/home/screens/home_screen.dart
```

**Step 3: Update imports**

**Step 4: Commit**

```bash
git add lib/
git commit -m "refactor: move home page to features/home

- Move lib/ui/pages/home.dart → lib/features/home/screens/home_screen.dart

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

### Task 3.6: Move Services to Core Services

**Files:**
- Move: `lib/services/*.dart` → `lib/core/services/`
- Delete: `lib/services/llm_service.dart` (duplicate)
- Delete: `lib/services/fake_llm_service.dart` (duplicate)

**Step 1: Move main services**

```bash
git mv lib/services/settings_service.dart lib/core/services/
git mv lib/services/tts_service.dart lib/core/services/
git mv lib/services/chat_history_service.dart lib/core/services/
git mv lib/services/cache_service.dart lib/core/services/
git mv lib/services/demo_controller.dart lib/core/services/
git mv lib/services/demo_service.dart lib/core/services/
git mv lib/services/prompt_service.dart lib/core/services/
```

**Step 2: Create agent services directory**

```bash
mkdir -p lib/core/services/agent
git mv lib/services/news_service.dart lib/core/services/agent/
git mv lib/services/weather_service.dart lib/core/services/agent/
git mv lib/services/wikipedia_service.dart lib/core/services/agent/
git mv lib/services/google_search_service.dart lib/core/services/agent/
git mv lib/services/alarm_service.dart lib/core/services/agent/
git mv lib/services/sound_service.dart lib/core/services/agent/
```

**Step 3: Delete duplicate LLM services**

```bash
# Remove old duplicates (already exist in lib/core/services/llm/)
rm lib/services/llm_service.dart
rm lib/services/fake_llm_service.dart
```

**Step 4: Remove llm subdirectory if empty**

```bash
# llm/ subdirectory files are already in core/services/llm/
rm -rf lib/services/llm/
```

**Step 5: Update imports**

```bash
find lib -name "*.dart" -exec sed -i '' 's|lib/services/|lib/core/services/|g' {} +
find lib -name "*.dart" -exec sed -i '' 's|lib/core/services/agent/|lib/core/services/agent/|g' {} +
```

**Step 6: Commit**

```bash
git add lib/
git commit -m "refactor: move services to core/services

- Move lib/services/* → lib/core/services/
- Move agent tools to lib/core/services/agent/
- Delete duplicate llm_service.dart and fake_llm_service.dart

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

### Task 3.7: Consolidate Models

**Files:**
- Move: `lib/models/*` → `lib/core/models/`

**Step 1: Check for unique models in lib/models**

```bash
ls -la lib/models/
```

**Step 2: Move any unique models**

```bash
# Move models that don't exist in core/models
for file in lib/models/*.dart; do
  basename=$(basename "$file")
  if [ ! -f "lib/core/models/$basename" ]; then
    git mv "$file" "lib/core/models/"
  fi
done
```

**Step 3: Remove lib/models directory if empty**

```bash
rmdir lib/models/ 2>/dev/null || echo "Directory not empty, check contents"
```

**Step 4: Update imports**

```bash
find lib -name "*.dart" -exec sed -i '' 's|lib/models/|lib/core/models/|g' {} +
```

**Step 5: Commit**

```bash
git add lib/
git commit -m "refactor: consolidate models to core/models

- Move unique models from lib/models/ to lib/core/models/
- Remove lib/models/ directory
- Update all imports

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

### Task 3.8: Move Repositories to Core

**Files:**
- Move: `lib/repositories/*` → `lib/core/repositories/`

**Step 1: Move repositories**

```bash
mkdir -p lib/core/repositories
git mv lib/repositories/* lib/core/repositories/
```

**Step 2: Update imports**

```bash
find lib -name "*.dart" -exec sed -i '' 's|lib/repositories/|lib/core/repositories/|g' {} +
```

**Step 3: Commit**

```bash
git add lib/
git commit -m "refactor: move repositories to core/repositories

- Move lib/repositories/* → lib/core/repositories/
- Update all imports

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

### Task 3.9: Restructure Logic Directory

**Files:**
- Move: `lib/logic/agent/*` → `lib/core/services/agent/`
- Move: `lib/logic/talking/*` → `lib/features/talking/bloc/`
- Move: `lib/logic/home/*` → `lib/features/home/bloc/`

**Step 1: Move agent logic**

```bash
# Agent tools already in core/services/agent/
git mv lib/logic/agent/* lib/core/services/agent/
```

**Step 2: Move talking cubit**

```bash
mkdir -p lib/features/talking/bloc
git mv lib/logic/talking/* lib/features/talking/bloc/
```

**Step 3: Move home state**

```bash
mkdir -p lib/features/home/bloc
git mv lib/logic/home/* lib/features/home/bloc/
```

**Step 4: Update imports**

```bash
find lib -name "*.dart" -exec sed -i '' 's|lib/logic/agent/|lib/core/services/agent/|g' {} +
find lib -name "*.dart" -exec sed -i '' 's|lib/logic/talking/|lib/features/talking/bloc/|g' {} +
find lib -name "*.dart" -exec sed -i '' 's|lib/logic/home/|lib/features/home/bloc/|g' {} +
```

**Step 5: Commit**

```bash
git add lib/
git commit -m "refactor: restructure logic directory

- Move lib/logic/agent/* → lib/core/services/agent/
- Move lib/logic/talking/* → lib/features/talking/bloc/
- Move lib/logic/home/* → lib/features/home/bloc/

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

### Task 3.10: Move Utils and Res to Core

**Files:**
- Move: `lib/utils/*` → `lib/core/utils/`
- Move: `lib/res/*` → `lib/core/res/`

**Step 1: Move utils**

```bash
mkdir -p lib/core/utils
git mv lib/utils/* lib/core/utils/
```

**Step 2: Move res**

```bash
mkdir -p lib/core/res
git mv lib/res/* lib/core/res/
```

**Step 3: Update imports**

```bash
find lib -name "*.dart" -exec sed -i '' 's|lib/utils/|lib/core/utils/|g' {} +
find lib -name "*.dart" -exec sed -i '' 's|lib/res/|lib/core/res/|g' {} +
```

**Step 4: Commit**

```bash
git add lib/
git commit -m "refactor: move utils and res to core

- Move lib/utils/* → lib/core/utils/
- Move lib/res/* → lib/core/res/
- Update all imports

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

### Task 3.11: Remove Empty lib/ui Directory

**Files:**
- Delete: `lib/ui/` directory (should be empty or near-empty)

**Step 1: Check remaining files**

```bash
find lib/ui -type f -name "*.dart"
```

**Step 2: Remove any stragglers or delete directory**

```bash
# If empty or only contains遗留 files
rm -rf lib/ui/
```

**Step 3: Commit**

```bash
git add lib/
git commit -m "refactor: remove empty lib/ui directory

- All files migrated to features/ or core/
- Remove lib/ui/ directory

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Phase 4: Split BLoC/Cubit Files

### Task 4.1: Split ChatsCubit Files

**Files:**
- Modify: `lib/features/chat/bloc/chats_cubit.dart`
- Modify: `lib/features/chat/bloc/chat_state.dart`
- Create: `lib/features/chat/bloc/chat_event.dart`

**Step 1: Create chat_event.dart**

Create: `lib/features/chat/bloc/chat_event.dart`

```dart
import 'package:equatable/equatable.dart';
import '../../../core/models/avatar_config.dart';

abstract class ChatsEvent extends Equatable {
  const ChatsEvent();

  @override
  List<Object?> get props => <Object?>[];
}

class CreateNewChat extends ChatsEvent {
  final String chatId;

  const CreateNewChat(this.chatId);

  @override
  List<Object?> get props => <Object?>[chatId];
}

class UpdateAvatarOpenedChat extends ChatsEvent {
  final AvatarConfig avatarConfig;

  const UpdateAvatarOpenedChat(this.avatarConfig);

  @override
  List<Object?> get props => <Object?>[avatarConfig];
}

class ToggleFunctionCalling extends ChatsEvent {
  const ToggleFunctionCalling();
}
```

**Step 2: Remove part directive from chats_cubit**

Modify: `lib/features/chat/bloc/chats_cubit.dart`

- Remove: `part 'chat_state.dart';`
- Add: `import 'chat_state.dart';`

**Step 3: Make chat_state.dart standalone**

Modify: `lib/features/chat/bloc/chat_state.dart`

- Remove any dependencies on part directives
- Ensure all classes are properly exported

**Step 4: Update imports in files using ChatsCubit**

**Step 5: Run tests**

Run: `flutter test test/features/chat/bloc/`
Expected: Tests pass

**Step 6: Commit**

```bash
git add lib/features/chat/bloc/
git commit -m "refactor: split ChatsCubit into separate files

- Create chat_event.dart
- Remove part directives
- Make chat_state.dart standalone

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

### Task 4.2: Split AvatarCubit Files

**Files:**
- Modify: `lib/features/avatar/bloc/avatar_cubit.dart`
- Modify: `lib/features/avatar/bloc/avatar_state.dart`

**Step 1: Remove part directive from avatar_cubit**

Modify: `lib/features/avatar/bloc/avatar_cubit.dart`

- Remove: `part 'avatar_state.dart';`
- Add: `import 'avatar_state.dart';`

**Step 2: Make avatar_state.dart standalone**

**Step 3: Commit**

```bash
git add lib/features/avatar/bloc/
git commit -m "refactor: split AvatarCubit into separate files

- Remove part directive
- Make avatar_state.dart standalone

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

### Task 4.3: Split TalkingCubit Files

**Files:**
- Modify: `lib/features/talking/bloc/talking_cubit.dart`
- Modify: `lib/features/talking/bloc/talking_state.dart`

**Step 1: Remove part directives**

**Step 2: Commit**

```bash
git add lib/features/talking/bloc/
git commit -m "refactor: split TalkingCubit into separate files

- Remove part directive
- Make talking_state.dart standalone

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

### Task 4.4: Split Remaining Cubits

Repeat for:
- DemoCubit
- SoundCubit

**Step 1: Split DemoCubit**

**Step 2: Split SoundCubit**

**Step 3: Commit**

```bash
git add lib/features/
git commit -m "refactor: split remaining Cubits into separate files

- Split DemoCubit
- Split SoundCubit
- Remove all part directives from BLoC files

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Phase 5: Final Import Updates and Cleanup

### Task 5.1: Bulk Import Fix

**Step 1: Run dart fix**

```bash
dart fix --apply
```

**Step 2: Run formatter**

```bash
dart format .
```

**Step 3: Manual import cleanup**

Check for any remaining absolute import issues and fix manually.

**Step 4: Commit**

```bash
git add lib/
git commit -m "refactor: apply dart fixes and formatting

- Run dart fix --apply
- Run dart format .
- Clean up remaining import issues

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

### Task 5.2: Regenerate Freezed Files

**Step 1: Clean build**

```bash
flutter clean
flutter pub get
```

**Step 2: Regenerate**

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

**Step 3: Commit generated files**

```bash
git add lib/
git commit -m "refactor: regenerate freezed files after migration

- Run build_runner with --delete-conflicting-outputs
- Regenerate all .freezed.dart and .g.dart files

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Phase 6: Verification

### Task 6.1: Run Flutter Analyze

**Step 1: Analyze**

```bash
flutter analyze
```

**Expected:** Zero errors

**Step 2: Fix any issues**

If errors exist, fix them and re-run.

**Step 3: Note results for final report**

---

### Task 6.2: Run All Tests

**Step 1: Run unit tests**

```bash
flutter test
```

**Expected:** All tests pass

**Step 2: Run integration tests**

```bash
flutter test integration_test/
```

**Expected:** Smoke tests pass

**Step 3: Fix any failing tests**

---

### Task 6.3: Manual Smoke Test

**Step 1: Run app**

```bash
flutter run -d chrome  # or your preferred device
```

**Step 2: Verify:**
- [ ] App launches without crashes
- [ ] Can navigate to settings
- [ ] Can start a chat
- [ ] Avatar renders
- [ ] Settings save/load correctly
- [ ] Sound effects work (if enabled)

**Step 3: Document any issues**

---

## Phase 7: Final Cleanup

### Task 7.1: Remove Old Generated Files

**Step 1: Find old generated files**

```bash
find lib -name "*.freezed.dart" -o -name "*.g.dart" | sort
```

**Step 2: Verify all are in correct locations**

**Step 3: Commit**

```bash
git add lib/
git commit -m "refactor: cleanup old generated files

- Verify all .freezed.dart and .g.dart files in correct locations
- Remove any orphaned generated files

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

### Task 7.2: Update Test Imports

**Step 1: Update test file imports**

Update imports in test files to match new structure.

**Step 2: Run tests**

```bash
flutter test
```

**Step 3: Commit**

```bash
git add test/
git commit -m "refactor: update test imports after migration

- Update all test file imports to match new directory structure
- Verify all tests pass

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

### Task 7.3: Final Verification and Merge

**Step 1: Run complete test suite**

```bash
flutter analyze
flutter test
dart format . --output=none --set-exit-if-changed
```

**Expected:** All pass

**Step 2: Create merge commit summary**

Document what was done:
- ~70 files moved/restructured
- Tests added for safety
- Directory structure standardized
- All BLoC files split
- Zero analysis errors

**Step 3: Push to remote**

```bash
git push origin refactor/architecture-standardization
```

**Step 4: Create PR**

Create pull request with:
- Title: `refactor: architecture standardization`
- Description: Summarize changes
- Link to design doc

---

## Success Criteria Checklist

After completing all tasks, verify:

- [ ] All files under 300 lines (widgets/screens) or 400 lines (services)
- [ ] Single directory structure: `lib/features/` and `lib/core/`
- [ ] All BLoC/Cubit files fully separated (no part directives)
- [ ] Zero `flutter analyze` errors
- [ ] All tests passing (`flutter test`)
- [ ] App runs without crashes
- [ ] Core features functional (chat, settings, avatar)
- [ ] No `lib/ui/` directory remains
- [ ] No `lib/services/` directory remains
- [ ] All imports use relative paths correctly
- [ ] Freezed files regenerated successfully

---

## Troubleshooting

**Issue:** `flutter analyze` shows import errors

**Solution:** Check that:
1. File paths in imports match actual file locations
2. No circular imports exist
3. All necessary files were migrated

**Issue:** Tests fail after migration

**Solution:** Check that:
1. Test imports updated to match new structure
2. Mock generation ran successfully
3. Test setup code matches new locations

**Issue:** App crashes on launch

**Solution:** Check that:
1. `main.dart` imports are correct
2. Service locator (get_it) initialization updated
3. All providers/blocs are registered correctly

---

**Document Version:** 1.0
**Last Updated:** 2025-03-01
**Estimated Total Time:** 9-11 hours
