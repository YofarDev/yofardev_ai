import 'dart:async';

import 'package:mocktail/mocktail.dart';
import 'package:yofardev_ai/core/models/avatar_config.dart';
import 'package:yofardev_ai/core/models/chat.dart';
import 'package:yofardev_ai/core/repositories/settings_repository.dart';
import 'package:yofardev_ai/core/services/app_lifecycle_service.dart';
import 'package:yofardev_ai/core/services/audio/interruption_service.dart';
import 'package:yofardev_ai/features/avatar/avatar.dart';
import 'package:yofardev_ai/features/chat/domain/repositories/chat_repository.dart';
import 'package:yofardev_ai/features/chat/domain/services/chat_streaming_service.dart';
import 'package:yofardev_ai/features/chat/domain/services/chat_title_service.dart';
import 'package:yofardev_ai/features/chat/domain/services/global_memory_service.dart';
import 'package:yofardev_ai/features/chat/presentation/bloc/chat_cubit.dart';
import 'package:yofardev_ai/features/demo/demo.dart';
import 'package:yofardev_ai/features/talking/data/repositories/talking_repository_impl.dart';
import 'package:yofardev_ai/features/talking/talking.dart';

class _MockChatRepository extends Mock implements ChatRepository {}

class _MockSettingsRepository extends Mock implements SettingsRepository {}

class _MockAvatarAnimationService extends Mock
    implements AvatarAnimationService {}

class _MockChatTitleService extends Mock implements ChatTitleService {}

class _MockGlobalMemoryService extends Mock implements GlobalMemoryService {}

class _MockDemoService extends Mock implements DemoService {}

/// How the scripted reply ends.
enum ReplyEnd { success, error, thrown, interrupted }

/// A streaming service that waits for [release], then ends the reply as
/// [end] says (the "No LLM configuration selected" path for [ReplyEnd.error],
/// an exception before the service's own error path for [ReplyEnd.thrown]).
class ScriptedStreamingService extends Mock implements ChatStreamingService {
  ScriptedStreamingService(this.end, this.interruption);

  final ReplyEnd end;
  final InterruptionService interruption;
  final Completer<void> started = Completer<void>();
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
    started.complete();
    await release.future;
    switch (end) {
      case ReplyEnd.success:
        onStreamComplete(currentChat);
      case ReplyEnd.error:
        onError('No LLM configuration selected');
      case ReplyEnd.thrown:
        throw StateError('storage unavailable');
      case ReplyEnd.interrupted:
        await interruption.interrupt();
        onStreamComplete(currentChat);
    }
  }
}

/// A real [ChatCubit] and [TalkingCubit] sharing one [AppLifecycleService],
/// with a scripted streaming service.
class ReplyRig {
  ReplyRig(ReplyEnd end) {
    streaming = ScriptedStreamingService(end, interruption);
    final _MockGlobalMemoryService memory = _MockGlobalMemoryService();
    when(() => memory.updateMemory(any())).thenAnswer((_) async {});
    final _MockChatTitleService titles = _MockChatTitleService();
    when(() => titles.shouldGenerateTitle(any())).thenReturn(false);
    chat = ChatCubit(
      chatRepository: _MockChatRepository(),
      settingsRepository: _MockSettingsRepository(),
      avatarAnimationService: _MockAvatarAnimationService(),
      chatTitleService: titles,
      chatStreamingService: streaming,
      appLifecycleService: lifecycle,
      globalMemoryService: memory,
      demoService: _MockDemoService(),
    );
    talking = TalkingCubit(
      TalkingRepositoryImpl(),
      interruption,
      TtsPlaybackService(TalkingRepositoryImpl()),
      lifecycle,
    );
  }

  static void registerFallbacks() => registerFallbackValue(const Chat());

  final AppLifecycleService lifecycle = AppLifecycleService();
  final InterruptionService interruption = InterruptionService();
  late final ScriptedStreamingService streaming;
  late final ChatCubit chat;
  late final TalkingCubit talking;

  Future<void> close() async {
    await chat.close();
    await talking.close();
  }
}
