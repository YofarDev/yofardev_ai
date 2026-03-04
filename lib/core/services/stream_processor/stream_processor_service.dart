import 'dart:async';
import '../llm/llm_stream_chunk.dart';
import 'sentence_chunk.dart';
import 'json_stream_extractor.dart';
import 'sentence_splitter.dart';
import '../../../../core/utils/logger.dart';

/// Processes streaming LLM chunks and emits sentence chunks for TTS
class StreamProcessorService {
  final JsonStreamExtractor _jsonExtractor = JsonStreamExtractor();
  final SentenceSplitter _sentenceSplitter = SentenceSplitter();

  /// Process streaming LLM chunks and emit sentence chunks
  ///
  /// Returns a Stream of SentenceChunk ready for TTS generation
  Stream<SentenceChunk> processStream(
    Stream<LlmStreamChunk> llmChunks, {
    bool expectJson = true,
  }) async* {
    int sentenceIndex = 0;

    await for (final LlmStreamChunk chunk in llmChunks) {
      // Process chunk using when() and collect all resulting SentenceChunks
      final List<SentenceChunk> results = chunk.when(
        text: (String content, bool isComplete) {
          final List<SentenceChunk> chunks = <SentenceChunk>[];

          // Extract text from JSON if needed
          final String? extractedText = _jsonExtractor.extractText(
            content,
            expectJson: expectJson,
          );

          final String textToProcess = extractedText ?? content;

          // Extract complete sentences
          final List<String> sentences = _sentenceSplitter
              .extractCompleteSentences(textToProcess);

          // Add each sentence
          for (final String sentence in sentences) {
            if (sentence.trim().isNotEmpty) {
              AppLogger.debug(
                'Emitting sentence #$sentenceIndex: ${sentence.substring(0, sentence.length > 50 ? 50 : sentence.length)}...',
                tag: 'StreamProcessor',
              );
              chunks.add(
                SentenceChunk.sentence(text: sentence, index: sentenceIndex++),
              );
            }
          }

          // If stream is complete, flush any remaining content
          if (isComplete) {
            final List<String> remaining = _sentenceSplitter.flush();
            for (final String sentence in remaining) {
              if (sentence.trim().isNotEmpty) {
                chunks.add(
                  SentenceChunk.sentence(
                    text: sentence,
                    index: sentenceIndex++,
                  ),
                );
              }
            }

            // Try to extract any remaining JSON metadata
            if (expectJson && _jsonExtractor.hasBufferedContent) {
              final String buffered = _jsonExtractor.getBufferedContent();
              if (buffered.trim().isNotEmpty) {
                try {
                  // Last attempt to parse complete JSON
                  final String? finalText = _jsonExtractor.extractText(
                    buffered,
                    expectJson: true,
                  );
                  if (finalText != null && finalText.trim().isNotEmpty) {
                    chunks.add(
                      SentenceChunk.metadata(
                        json: <String, dynamic>{'response': finalText},
                      ),
                    );
                  }
                } catch (e) {
                  AppLogger.warning(
                    'Could not extract final JSON metadata',
                    tag: 'StreamProcessor',
                  );
                }
              }
            }

            chunks.add(const SentenceChunk.complete());
          }

          return chunks;
        },
        error: (String message) {
          AppLogger.error('Stream error: $message', tag: 'StreamProcessor');
          return <SentenceChunk>[SentenceChunk.error(message)];
        },
        complete: () {
          final List<SentenceChunk> chunks = <SentenceChunk>[];
          // Flush any remaining sentences
          final List<String> remaining = _sentenceSplitter.flush();
          for (final String sentence in remaining) {
            chunks.add(
              SentenceChunk.sentence(text: sentence, index: sentenceIndex++),
            );
          }
          chunks.add(const SentenceChunk.complete());
          return chunks;
        },
      );

      // Yield all collected chunks
      for (final SentenceChunk resultChunk in results) {
        yield resultChunk;
      }
    }

    // Reset state for next stream
    _jsonExtractor.clear();
    _sentenceSplitter.clear();
  }
}
