import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:yofardev_ai/core/di/service_locator.dart';
import 'package:yofardev_ai/core/models/avatar_config.dart';
import 'package:yofardev_ai/core/models/chat.dart';
import 'package:yofardev_ai/core/models/chat_entry.dart';
import 'package:yofardev_ai/core/models/llm_config.dart';
import 'package:yofardev_ai/core/services/llm/llm_service_interface.dart';
import 'package:yofardev_ai/features/chat/domain/services/chat_streaming_service.dart';

/// End-to-end smoke test against the configured LLM backend (DeepSeek).
///
/// Runs on macOS (`flutter test integration_test/llm_backend_smoke_test.dart
/// -d macos`). It boots the app's real service locator, verifies the active
/// LLM config, then drives one real streamed chat turn through
/// [ChatStreamingService] — the same pipeline the chat UI uses.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('real LLM backend streams a full chat turn', () async {
    await setupServiceLocator();
    await initializeDateFormatting('fr');
    await initializeDateFormatting('en');

    // 1. The active config must be a real backend, not a fake.
    await getIt<LlmServiceInterface>().init();
    final LlmConfig? config = getIt<LlmServiceInterface>().getCurrentConfig();
    expect(config, isNotNull, reason: 'no active LLM config in settings');
    // ignore: avoid_print
    print(
      'active LLM config: ${config!.label} model=${config.model} '
      'baseUrl=${config.baseUrl}',
    );

    // 2. One real streamed turn.
    final Completer<Chat> done = Completer<Chat>();
    final Chat chat = Chat(
      id: 'integration-smoke-${DateTime.now().millisecondsSinceEpoch}',
      systemPrompt: 'Tu es un assistant de test. Réponds en UNE phrase courte.',
      language: 'fr',
    );

    await getIt<ChatStreamingService>().streamResponse(
      prompt: 'Cite juste la ville où se trouve la tour Eiffel.',
      onlyText: true,
      avatar: const Avatar(),
      currentChat: chat,
      language: 'fr',
      onChatUpdated: (Chat updated) {},
      onStreamComplete: done.complete,
      onError: (String error) =>
          done.completeError(StateError('stream error: $error')),
    );

    final Chat finalChat = await done.future.timeout(
      const Duration(minutes: 2),
      onTimeout: () => throw TimeoutException('LLM stream never completed'),
    );

    final List<ChatEntry> replies = finalChat.entries
        .where((ChatEntry e) => e.entryType == EntryType.yofardev)
        .toList();
    expect(replies, isNotEmpty, reason: 'no assistant entry in final chat');
    final String body = replies.last.body.trim();
    // ignore: avoid_print
    print('assistant reply: $body');

    expect(body, isNotEmpty);
    expect(
      body.toLowerCase(),
      contains('paris'),
      reason: 'LLM reply should name Paris',
    );
  }, timeout: const Timeout(Duration(minutes: 3)));
}
