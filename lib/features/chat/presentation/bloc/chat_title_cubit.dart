import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/services/llm/llm_service.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/utils/logger.dart';

import '../../domain/models/chat.dart';
import '../../domain/models/chat_entry.dart';
import '../../domain/repositories/chat_repository.dart';
import 'chat_title_state.dart';

/// Cubit responsible for generating chat titles asynchronously
///
/// Separated from ChatsCubit to follow single responsibility principle.
/// Title generation is a fire-and-forget operation that doesn't block
/// the main chat UI.
class ChatTitleCubit extends Cubit<ChatTitleState> {
  ChatTitleCubit({
    required ChatRepository chatRepository,
    required LlmService llmService,
  }) : _chatRepository = chatRepository,
       _llmService = llmService,
       super(const ChatTitleState());

  final ChatRepository _chatRepository;
  final LlmService _llmService;

  /// Generate a title for a chat based on its first user message
  ///
  /// Only generates if:
  /// - Chat exists and has entries
  /// - Title hasn't been generated yet
  /// - Not already generating for this chat
  Future<void> generateTitle(String chatId, Chat chat) async {
    // Validation checks
    if (chat.titleGenerated || chat.entries.isEmpty) return;

    // Prevent duplicate generation attempts
    if (state.generatingChatIds.contains(chatId)) return;

    // Add to generating set
    emit(
      state.copyWith(
        generatingChatIds: <String>{...state.generatingChatIds, chatId},
      ),
    );

    try {
      final String firstUserMessage = _getFirstUserMessage(chat);
      if (firstUserMessage.isEmpty) return;

      // Initialize LLM service if needed
      await _llmService.init();

      final String? title = await _llmService.generateTitle(
        firstUserMessage,
        language: chat.language,
      );

      if (title != null && title.isNotEmpty && title.length <= 100) {
        final String sanitizedTitle = _sanitizeTitle(title);

        final Chat updatedChat = chat.copyWith(
          title: sanitizedTitle,
          titleGenerated: true,
        );

        await _chatRepository.updateChat(id: chatId, updatedChat: updatedChat);

        AppLogger.info(
          'Title generated for chat $chatId: $sanitizedTitle',
          tag: 'ChatTitle',
        );

        emit(
          state.copyWith(
            lastGeneratedTitle: TitleResult(
              chatId: chatId,
              title: sanitizedTitle,
            ),
          ),
        );
      } else {
        AppLogger.warning(
          'Generated title was invalid or too long: "$title" (${title?.length} chars)',
          tag: 'ChatTitle',
        );
      }
    } catch (e) {
      AppLogger.error(
        'Failed to generate title for chat $chatId',
        tag: 'ChatTitle',
        error: e,
      );
    } finally {
      // Remove from generating set
      final Set<String> updatedIds = state.generatingChatIds.toSet()
        ..remove(chatId);
      emit(state.copyWith(generatingChatIds: updatedIds));
    }
  }

  /// Check if title generation should be triggered for a chat
  ///
  /// Returns true if the chat has exactly one user message and
  /// the title hasn't been generated yet.
  bool shouldGenerateTitle(Chat chat) {
    final int userMessageCount = chat.entries
        .where((ChatEntry e) => e.entryType == EntryType.user)
        .length;
    return userMessageCount == 1 && !chat.titleGenerated;
  }

  String _getFirstUserMessage(Chat chat) {
    try {
      return chat.entries
              .where((ChatEntry e) => e.entryType == EntryType.user)
              .firstOrNull
              ?.body
              .getVisiblePrompt() ??
          '';
    } catch (e) {
      AppLogger.error(
        'Failed to extract first user message',
        tag: 'ChatTitle',
        error: e,
      );
      return '';
    }
  }

  String _sanitizeTitle(String title) {
    // Remove excessive whitespace
    String sanitized = title.replaceAll(RegExp(r'\s+'), ' ').trim();

    // Remove any quotes the LLM might have added
    sanitized = sanitized.replaceAll(RegExp(r'''^["']|["']$'''), '');

    // Truncate if still too long
    if (sanitized.length > 50) {
      sanitized = '${sanitized.substring(0, 47)}...';
    }

    return sanitized;
  }
}
