import 'package:freezed_annotation/freezed_annotation.dart';

part 'llm_stream_chunk.freezed.dart';
part 'llm_stream_chunk.g.dart';

/// Represents a chunk of data from streaming LLM response
@freezed
sealed class LlmStreamChunk with _$LlmStreamChunk {
  /// A text chunk received from the stream
  const factory LlmStreamChunk.text({
    required String content,
    required bool isComplete,
  }) = _LlmStreamChunkText;

  /// An error occurred during streaming
  const factory LlmStreamChunk.error(String message) = _LlmStreamChunkError;

  /// A fragment of a streamed tool call (OpenAI `delta.tool_calls`).
  ///
  /// `arguments` arrives fragmented across chunks and must be concatenated
  /// per [index]; `id`/`name` usually arrive once on the first fragment.
  const factory LlmStreamChunk.toolCallDelta({
    required int index,
    String? id,
    String? name,
    String? argumentsDelta,
  }) = _LlmStreamChunkToolCallDelta;

  /// Stream completed successfully
  const factory LlmStreamChunk.complete() = _LlmStreamChunkComplete;

  factory LlmStreamChunk.fromJson(Map<String, dynamic> json) =>
      _$LlmStreamChunkFromJson(json);
}
