import '../../../../core/services/llm/llm_service_interface.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/utils/logger.dart';
import '../models/chat.dart';
import '../models/chat_entry.dart';
import '../repositories/chat_repository.dart';

/// Service that handles chat title generation logic.
///
/// This service extracts the business logic for generating chat titles,
/// separating it from state management.
class ChatTitleService {
  /// Creates a new ChatTitleService.
  ChatTitleService({
    required ChatRepository chatRepository,
    required LlmServiceInterface llmService,
  }) : _chatRepository = chatRepository,
       _llmService = llmService;

  final ChatRepository _chatRepository;
  final LlmServiceInterface _llmService;

  /// Generate a title for a chat based on its first user message.
  ///
  /// This method performs the actual work of title generation:
  /// - Validates the chat and extracts the first user message
  /// - Calls the LLM service to generate a title
  /// - Sanitizes and updates the chat with the new title
  ///
  /// [chatId] - The ID of the chat to generate a title for
  /// [chat] - The chat object containing entries and metadata
  ///
  /// Returns the generated title if successful, null otherwise.
  Future<String?> generateTitle(String chatId, Chat chat) async {
    // Validation checks
    if (chat.titleGenerated || chat.entries.isEmpty) {
      AppLogger.debug(
        'Skipping title generation for chat $chatId: already generated or empty',
        tag: 'ChatTitleService',
      );
      return null;
    }

    try {
      final String firstUserMessage = _getFirstUserMessage(chat);
      if (firstUserMessage.isEmpty) {
        AppLogger.warning(
          'Cannot generate title: no user message found for chat $chatId',
          tag: 'ChatTitleService',
        );
        return null;
      }

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
          tag: 'ChatTitleService',
        );

        return sanitizedTitle;
      } else {
        AppLogger.warning(
          'Generated title was invalid or too long: "$title" (${title?.length} chars)',
          tag: 'ChatTitleService',
        );
        return null;
      }
    } catch (e) {
      AppLogger.error(
        'Failed to generate title for chat $chatId',
        tag: 'ChatTitleService',
        error: e,
      );
      return null;
    }
  }

  /// Check if title generation should be triggered for a chat.
  ///
  /// Returns true if the chat has exactly one user message and
  /// the title hasn't been generated yet. This ensures we generate
  /// titles early (after the first user message) but only once.
  ///
  /// [chat] - The chat to check
  ///
  /// Returns true if title generation should be triggered.
  bool shouldGenerateTitle(Chat chat) {
    final int userMessageCount = chat.entries
        .where((ChatEntry e) => e.entryType == EntryType.user)
        .length;
    return userMessageCount == 1 && !chat.titleGenerated;
  }

  /// Extract the first user message from a chat.
  ///
  /// [chat] - The chat to extract the message from
  ///
  /// Returns the visible prompt of the first user message, or empty string if not found.
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
        tag: 'ChatTitleService',
        error: e,
      );
      return '';
    }
  }

  /// Sanitize a generated title.
  ///
  /// Removes excessive whitespace, quotes, and truncates if too long.
  ///
  /// [title] - The raw title to sanitize
  ///
  /// Returns the sanitized title.
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
