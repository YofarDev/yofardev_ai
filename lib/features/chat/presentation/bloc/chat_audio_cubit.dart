import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/utils/logger.dart';
import '../../../../core/utils/platform_utils.dart';
import '../../domain/services/waiting_sentences_cache_datasource.dart';
import 'chat_audio_state.dart';

/// Cubit responsible for managing waiting sentences for audio playback
///
/// Handles:
/// - Loading waiting sentences from cache
/// - Shuffling waiting sentences
/// - Removing played sentences
class ChatAudioCubit extends Cubit<ChatAudioState> {
  ChatAudioCubit() : super(ChatAudioState.initial());

  /// Loads waiting sentences from cache for the given language
  ///
  /// On web platforms, this is a no-op since audio caching is not supported.
  Future<void> prepareWaitingSentences(String language) async {
    if (PlatformUtils.checkPlatform() == 'Web') {
      emit(state.copyWith(initializing: false));
      return;
    }

    try {
      final List<Map<String, dynamic>>? cachedSentences =
          await WaitingSentencesCacheDatasource.getWaitingSentencesMap(
            language,
          );

      if (cachedSentences != null) {
        emit(
          state.copyWith(
            audioPathsWaitingSentences: cachedSentences,
            initializing: false,
          ),
        );
      } else {
        emit(state.copyWith(initializing: false));
      }
    } catch (e) {
      AppLogger.error(
        'Failed to load waiting sentences',
        tag: 'ChatAudioCubit',
        error: e,
      );
      emit(state.copyWith(initializing: false));
    }
  }

  /// Randomly shuffles the waiting sentences list
  void shuffleWaitingSentences() {
    final List<Map<String, dynamic>> list = List<Map<String, dynamic>>.from(
      state.audioPathsWaitingSentences,
    );
    list.shuffle();
    emit(state.copyWith(audioPathsWaitingSentences: list));
  }

  /// Removes a waiting sentence by its audio path
  void removeWaitingSentence(String audioPath) {
    final List<Map<String, dynamic>> currentList =
        List<Map<String, dynamic>>.from(state.audioPathsWaitingSentences);
    currentList.removeWhere(
      (Map<String, dynamic> element) => element['audioPath'] == audioPath,
    );
    emit(state.copyWith(audioPathsWaitingSentences: currentList));
  }
}
