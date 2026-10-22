import '../../utils/logger.dart';

/// Logs prompt/cached token counts from an API `usage` object
///
/// Handles both OpenAI (`prompt_tokens_details.cached_tokens`) and
/// DeepSeek (`prompt_cache_hit_tokens`) cache reporting so prompt-cache
/// effectiveness is observable per request.
void logTokenUsage(dynamic usage) {
  if (usage is! Map<String, dynamic>) return;
  final int? promptTokens = (usage['prompt_tokens'] as num?)?.toInt();
  if (promptTokens == null) return;
  final Map<String, dynamic>? details =
      usage['prompt_tokens_details'] as Map<String, dynamic>?;
  final int? cachedTokens =
      (details?['cached_tokens'] as num?)?.toInt() ??
      (usage['prompt_cache_hit_tokens'] as num?)?.toInt();
  if (cachedTokens != null && cachedTokens > 0) {
    final int percent = (100 * cachedTokens / promptTokens).round();
    AppLogger.info(
      'LLM usage: prompt=$promptTokens cached=$cachedTokens ($percent%)',
      tag: 'LlmUsage',
    );
  } else {
    AppLogger.debug(
      'LLM usage: prompt=$promptTokens cached=0',
      tag: 'LlmUsage',
    );
  }
}
