import 'package:freezed_annotation/freezed_annotation.dart';

part 'sentence_chunk.freezed.dart';
part 'sentence_chunk.g.dart';

/// Result of processing streaming content
@freezed
sealed class SentenceChunk with _$SentenceChunk {
  /// A complete sentence extracted from the stream
  const factory SentenceChunk.sentence({
    required String text,
    required int index,
  }) = _SentenceChunkSentence;

  /// Complete metadata extracted from JSON response
  const factory SentenceChunk.metadata({required Map<String, dynamic> json}) =
      _SentenceChunkMetadata;

  /// Stream completed, no more chunks expected
  const factory SentenceChunk.complete() = _SentenceChunkComplete;

  /// An error occurred during processing
  const factory SentenceChunk.error(String message) = _SentenceChunkError;

  factory SentenceChunk.fromJson(Map<String, dynamic> json) =>
      _$SentenceChunkFromJson(json);
}
