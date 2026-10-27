import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yofardev_ai/core/models/avatar_config.dart';
import 'package:yofardev_ai/core/models/chat.dart';
import 'package:yofardev_ai/core/repositories/settings_repository.dart';
import 'package:yofardev_ai/core/services/app_lifecycle_service.dart';
import 'package:yofardev_ai/features/avatar/avatar.dart';
import 'package:yofardev_ai/features/chat/domain/services/chat_streaming_service.dart';
import 'package:yofardev_ai/features/chat/domain/services/chat_title_service.dart';
import 'package:yofardev_ai/features/chat/domain/services/global_memory_service.dart';
import 'package:yofardev_ai/features/chat/domain/repositories/chat_repository.dart';
import 'package:yofardev_ai/features/chat/presentation/bloc/chat_cubit.dart';
import 'package:yofardev_ai/features/chat/presentation/bloc/chat_state.dart';
import 'package:yofardev_ai/features/demo/demo.dart';

class _MockChatRepository extends Mock implements ChatRepository {}

class _MockSettingsRepository extends Mock implements SettingsRepository {}

class _MockAvatarAnimationService extends Mock
    implements AvatarAnimationService {}

class _MockChatTitleService extends Mock implements ChatTitleService {}

class _MockGlobalMemoryService extends Mock implements GlobalMemoryService {}

class _MockDemoService extends Mock implements DemoService {}

/// Streaming service that reports one tool, lets the test observe the
/// cubit mid-tool, then completes the reply, or fails it when [fail] is
/// set — without reporting `null` itself, so the cubit must reset.
class _ToolStreamingService extends Mock implements ChatStreamingService {
  _ToolStreamingService({required this.fail});

  final bool fail;
  final Completer<void> toolStarted = Completer<void>();
  final Completer<void> release = Completer<void>();

  @override
  Future<void> streamResponse({
    required String prompt,
    required bool onlyText,
    String? attachedImage,
    required Avatar avatar,
    required Chat currentChat,
    required String language,
    bool functionCallingEnabled = true,
    required void Function(Chat updatedChat) onChatUpdated,
    required void Function(Chat finalChat) onStreamComplete,
    required void Function(String error) onError,
    void Function(String? toolName)? onToolActivity,
  }) async {
    onToolActivity?.call('getCurrentWeather');
    toolStarted.complete();
    await release.future;
    if (fail) {
      onError('boom');
    } else {
      onStreamComplete(currentChat);
    }
  }
}

void main() {
  setUpAll(() {
    registerFallbackValue(const Chat());
  });

  ChatCubit build(ChatStreamingService streaming) {
    final _MockGlobalMemoryService memory = _MockGlobalMemoryService();
    when(() => memory.updateMemory(any())).thenAnswer((_) async {});
    final _MockChatTitleService titles = _MockChatTitleService();
    when(() => titles.shouldGenerateTitle(any())).thenReturn(false);
    return ChatCubit(
      chatRepository: _MockChatRepository(),
      settingsRepository: _MockSettingsRepository(),
      avatarAnimationService: _MockAvatarAnimationService(),
      chatTitleService: titles,
      chatStreamingService: streaming,
      appLifecycleService: AppLifecycleService(),
      globalMemoryService: memory,
      demoService: _MockDemoService(),
    );
  }

  Future<void> runReply({required bool fail}) async {
    final _ToolStreamingService streaming = _ToolStreamingService(fail: fail);
    final ChatCubit cubit = build(streaming);

    final Future<void> reply = cubit.streamResponse(
      'Weather?',
      onlyText: true,
      avatar: const Avatar(),
      currentChat: const Chat(id: 'c1'),
      language: 'en',
    );
    await streaming.toolStarted.future;
    expect(cubit.state.activeTool, 'getCurrentWeather');

    streaming.release.complete();
    await reply;
    expect(cubit.state.activeTool, isNull);
    expect(cubit.state.status, fail ? ChatStatus.error : ChatStatus.success);

    await cubit.close();
  }

  test('activeTool is set while a tool runs, cleared on completion', () {
    return runReply(fail: false);
  });

  test('activeTool is cleared on error', () {
    return runReply(fail: true);
  });
}
