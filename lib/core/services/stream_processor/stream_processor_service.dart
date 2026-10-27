import 'dart:async';
import '../llm/llm_stream_chunk.dart';
import 'sentence_chunk.dart';
import 'json_stream_extractor.dart';
import 'sentence_splitter.dart';
import '../../../../core/utils/logger.dart';

/// Processes streaming LLM chunks and emits sentence chunks for TTS
class StreamProcessorService {
  /// Process streaming LLM chunks and emit sentence chunks
  ///
  /// Returns a Stream of SentenceChunk ready for TTS generation
  Stream<SentenceChunk> processStream(
    Stream<LlmStreamChunk> llmChunks, {
    bool expectJson = true,
  }) async* {
    int sentenceIndex = 0;

    // Fresh per call: the service is a singleton but its extractors are
    // stateful, so two overlapping streams must never share buffers.
    final JsonStreamExtractor jsonExtractor = JsonStreamExtractor();
    final SentenceSplitter sentenceSplitter = SentenceSplitter();

    await for (final LlmStreamChunk chunk in llmChunks) {
      // Process chunk using when() and collect all resulting SentenceChunks
      final List<SentenceChunk> results = chunk.when(
        text: (String content, bool isComplete) {
          final List<SentenceChunk> chunks = <SentenceChunk>[];

          // Extract text from JSON if needed
          final String? extractedText = jsonExtractor.extractText(
            content,
            expectJson: expectJson,
          );

          final String textToProcess = extractedText ?? content;

          // Extract complete sentences
          final List<String> sentences = sentenceSplitter
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
            final List<String> remaining = sentenceSplitter.flush();
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

            // Include the full raw JSON if available
            if (expectJson) {
              final String fullJson = jsonExtractor.getRawContent();
              if (fullJson.trim().isNotEmpty) {
                chunks.add(
                  SentenceChunk.metadata(
                    json: <String, dynamic>{'fullJson': fullJson},
                  ),
                );
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
        reasoning: (String content) {
          // Chain-of-thought is never spoken; the caller taps the raw stream
          // to accumulate it for the thinking-mode round-trip.
          return const <SentenceChunk>[];
        },
        toolCallDelta:
            (int index, String? id, String? name, String? argumentsDelta) {
              // Tool-call fragments carry no speakable content; the caller taps
              // the raw stream to accumulate them.
              return const <SentenceChunk>[];
            },
        complete: () {
          final List<SentenceChunk> chunks = <SentenceChunk>[];
          // Flush any remaining sentences
          final List<String> remaining = sentenceSplitter.flush();
          for (final String sentence in remaining) {
            if (sentence.trim().isNotEmpty) {
              chunks.add(
                SentenceChunk.sentence(text: sentence, index: sentenceIndex++),
              );
            }
          }

          // Include the full raw JSON if available
          if (expectJson) {
            final String fullJson = jsonExtractor.getRawContent();
            if (fullJson.trim().isNotEmpty) {
              chunks.add(
                SentenceChunk.metadata(
                  json: <String, dynamic>{'fullJson': fullJson},
                ),
              );
            }
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
  }
}
