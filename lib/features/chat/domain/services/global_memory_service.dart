import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../../../core/models/chat.dart';
import '../../../../core/models/chat_entry.dart';
import '../../../../core/models/failure.dart';
import '../../../../core/models/global_memory.dart';
import '../../../../core/models/llm_message.dart';
import '../../../../core/models/result.dart';
import '../../domain/repositories/global_memory_repository.dart';
import '../../../../core/repositories/settings_repository.dart';
import '../../../../core/services/llm/llm_service_interface.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/utils/logger.dart';

/// Service that maintains the global memory: facts about the user shared
/// across all chats.
///
/// Responsibilities:
/// - Build the cache-safe memory message injected at the END of LLM requests
///   (never into the system prompt, so the [system prompt | history] prefix
///   stays identical across turns and providers can reuse their prompt cache)
/// - Extract memory updates from the last conversation exchange after each
///   completed stream, mirroring [ChatTitleService]'s fire-and-forget pattern
class GlobalMemoryService {
  GlobalMemoryService({
    required GlobalMemoryRepository memoryRepository,
    required SettingsRepository settingsRepository,
    required LlmServiceInterface llmService,
  }) : _memoryRepository = memoryRepository,
       _settingsRepository = settingsRepository,
       _llmService = llmService;

  final GlobalMemoryRepository _memoryRepository;
  final SettingsRepository _settingsRepository;
  final LlmServiceInterface _llmService;

  bool _updateInProgress = false;

  /// Builds the system-role memory message to inject immediately before the
  /// last (current) user message. Returns null when memory is disabled or
  /// empty, so requests stay byte-identical to the pre-feature format.
  Future<LlmMessage?> buildMemoryMessage() async {
    final Result<bool> enabled = await _settingsRepository.getMemoryEnabled();
    if (enabled.getOrNull != true) return null;

    final GlobalMemory memory =
        (await _memoryRepository.getMemory()).getOrNull ?? GlobalMemory.empty();
    if (memory.isEmpty) return null;

    final StringBuffer block = StringBuffer(
      'Global memory about the user, gathered from previous conversations. '
      'Use it naturally to personalize your answers; do not recite it or '
      'mention that you have a memory unless the user asks.\n',
    );
    for (final GlobalMemoryItem item in memory.items) {
      block.writeln('- ${item.text}');
    }
    return LlmMessage(
      role: LlmMessageRole.system,
      body: block.toString().trimRight(),
    );
  }

  /// Updates the global memory from the last exchange of [chat].
  ///
  /// Fire-and-forget: any failure is logged and leaves the stored memory
  /// untouched. Skipped when the feature is disabled or an update is already
  /// running.
  Future<void> updateMemory(Chat chat) async {
    final Result<bool> enabled = await _settingsRepository.getMemoryEnabled();
    if (enabled.getOrNull != true) return;
    if (_updateInProgress) return;

    final String excerpt = _buildConversationExcerpt(chat);
    if (excerpt.isEmpty) return;

    _updateInProgress = true;
    try {
      final GlobalMemory current =
          (await _memoryRepository.getMemory()).getOrNull ??
          GlobalMemory.empty();

      await _llmService.init();
      final String? response = await _llmService.extractMemory(
        conversationExcerpt: excerpt,
        currentMemory: current.texts,
      );
      if (response == null) {
        AppLogger.warning(
          'Memory extraction returned no response, keeping current memory',
          tag: 'GlobalMemoryService',
        );
        return;
      }

      final List<String>? texts = _parseMemoryResponse(response);
      if (texts == null) {
        AppLogger.warning(
          'Memory extraction returned unparseable response, keeping current memory',
          tag: 'GlobalMemoryService',
        );
        return;
      }

      final GlobalMemory updated = _mergeTexts(texts, current);
      if (_sameTexts(updated, current)) {
        AppLogger.debug(
          'Memory unchanged after extraction',
          tag: 'GlobalMemoryService',
        );
        return;
      }

      final Result<void> saved = await _memoryRepository.saveMemory(updated);
      saved.when(
        err: (Failure failure) => AppLogger.error(
          'Failed to save global memory',
          tag: 'GlobalMemoryService',
          error: failure,
        ),
        ok: (_) => AppLogger.info(
          'Global memory updated: ${updated.items.length} items',
          tag: 'GlobalMemoryService',
        ),
      );
    } catch (e) {
      AppLogger.error(
        'Memory update failed, keeping current memory',
        tag: 'GlobalMemoryService',
        error: e,
      );
    } finally {
      _updateInProgress = false;
    }
  }

  /// Extracts the last user prompt and assistant answer of the chat as a
  /// bounded plain-text excerpt. Returns empty string when no exchange exists.
  String _buildConversationExcerpt(Chat chat) {
    final List<ChatEntry> entries = chat.entries
        .where(
          (ChatEntry e) =>
              e.entryType == EntryType.user ||
              e.entryType == EntryType.yofardev,
        )
        .toList();

    String? userText;
    String? assistantText;
    for (
      int i = entries.length - 1;
      i >= 0 && (userText == null || assistantText == null);
      i--
    ) {
      final ChatEntry entry = entries[i];
      final String visible = entry.body.getVisiblePrompt().trim();
      if (visible.isEmpty) continue;
      if (entry.entryType == EntryType.user && userText == null) {
        userText = visible;
      } else if (entry.entryType == EntryType.yofardev &&
          assistantText == null) {
        assistantText = visible;
      }
    }

    if (userText == null) return '';
    final StringBuffer excerpt = StringBuffer('User: $userText');
    if (assistantText != null) {
      excerpt.write('\nAssistant: $assistantText');
    }
    // Bound the excerpt so extraction cost stays constant regardless of
    // message length.
    return excerpt.toString().limitWords(400);
  }

  /// Parses the LLM's JSON response into the updated memory texts.
  ///
  /// Returns null when the response is not usable JSON of the expected shape;
  /// an explicit empty list is a valid result ("nothing memorable").
  List<String>? _parseMemoryResponse(String response) {
    String cleaned = response.trim();
    // Strip markdown code fences some models wrap around JSON.
    if (cleaned.startsWith('```')) {
      cleaned = cleaned
          .replaceAll(RegExp(r'^```[a-zA-Z]*\n?'), '')
          .replaceAll(RegExp(r'\n?```$'), '')
          .trim();
    }

    try {
      final dynamic decoded = jsonDecode(cleaned);
      final List<dynamic>? raw;
      if (decoded is Map<String, dynamic>) {
        raw = decoded['memory'] as List<dynamic>?;
      } else if (decoded is List<dynamic>) {
        raw = decoded;
      } else {
        raw = null;
      }
      if (raw == null) return null;
      return raw
          .map((dynamic e) => e.toString().trim())
          .where((String t) => t.isNotEmpty)
          .toList();
    } catch (e) {
      AppLogger.warning(
        'Failed to decode memory extraction response: $e',
        tag: 'GlobalMemoryService',
      );
      return null;
    }
  }

  /// Builds the updated [GlobalMemory] from LLM texts, keeping existing item
  /// ids for unchanged texts so deletions by id remain stable, and enforcing
  /// the caps and uniqueness the model was asked to respect.
  GlobalMemory _mergeTexts(List<String> texts, GlobalMemory current) {
    final Map<String, GlobalMemoryItem> existingByNormalizedText =
        <String, GlobalMemoryItem>{};
    for (final GlobalMemoryItem item in current.items) {
      existingByNormalizedText[_normalize(item.text)] = item;
    }

    final List<GlobalMemoryItem> items = <GlobalMemoryItem>[];
    final Set<String> seen = <String>{};
    const Uuid uuid = Uuid();
    for (final String text in texts) {
      final String bounded = text.length > GlobalMemory.maxItemLength
          ? '${text.substring(0, GlobalMemory.maxItemLength - 1)}…'
          : text;
      final String normalized = _normalize(bounded);
      if (normalized.isEmpty || seen.contains(normalized)) continue;
      seen.add(normalized);
      final GlobalMemoryItem? existing = existingByNormalizedText[normalized];
      items.add(
        existing ??
            GlobalMemoryItem(
              id: uuid.v4(),
              text: bounded,
              updatedAt: DateTime.now(),
            ),
      );
      if (items.length >= GlobalMemory.maxItems) break;
    }
    return GlobalMemory(items: items);
  }

  static bool _sameTexts(GlobalMemory a, GlobalMemory b) {
    if (a.items.length != b.items.length) return false;
    for (int i = 0; i < a.items.length; i++) {
      if (_normalize(a.items[i].text) != _normalize(b.items[i].text)) {
        return false;
      }
    }
    return true;
  }

  static String _normalize(String text) =>
      text.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}
