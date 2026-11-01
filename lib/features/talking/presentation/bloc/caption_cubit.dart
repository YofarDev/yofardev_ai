import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/models/failure.dart';
import '../../../../core/models/result.dart';
import '../../../../core/repositories/settings_repository.dart';
import '../../../../core/services/audio/interruption_service.dart';
import '../../../../core/utils/logger.dart';
import '../../domain/services/tts_playback_service.dart';
import 'caption_state.dart';

/// Live captions: shows the text of the TTS sentence that is playing.
///
/// Sentences play back-to-back with a [SpeakingStoppedEvent] between each
/// pair, so a stop does not clear the caption at once: it starts a
/// [lingerDuration] timer that the next [CaptionEvent] cancels. An
/// interruption clears the caption immediately.
class CaptionCubit extends Cubit<CaptionState> {
  CaptionCubit({
    required TtsPlaybackService playbackService,
    required InterruptionService interruptionService,
    required SettingsRepository settingsRepository,
  }) : _settingsRepository = settingsRepository,
       super(const CaptionState()) {
    _eventSubscription = playbackService.events.listen(_onPlaybackEvent);
    _interruptionSubscription = interruptionService.interruptionStream.listen(
      (_) => _clear(),
    );
  }

  /// How long the last caption stays after speech stops.
  static const Duration lingerDuration = Duration(milliseconds: 1200);

  final SettingsRepository _settingsRepository;
  late final StreamSubscription<PlaybackEvent> _eventSubscription;
  late final StreamSubscription<void> _interruptionSubscription;
  Timer? _lingerTimer;

  /// Loads the persisted captions preference (stays on when unreadable).
  Future<void> init() async {
    final Result<bool> result = await _settingsRepository.getCaptionsEnabled();
    if (isClosed) return;
    result.when(
      err: (Failure failure) => AppLogger.error(
        'Failed to load captions preference',
        tag: 'CaptionCubit',
        error: failure,
      ),
      ok: (bool enabled) {
        if (enabled != state.enabled) {
          emit(state.copyWith(enabled: enabled));
        }
      },
    );
  }

  /// Flips captions on/off and persists the choice.
  Future<void> toggle() async {
    final bool enabled = !state.enabled;
    emit(state.copyWith(enabled: enabled));
    final Result<void> result = await _settingsRepository.setCaptionsEnabled(
      enabled,
    );
    result.when(
      err: (Failure failure) => AppLogger.error(
        'Failed to persist captions preference',
        tag: 'CaptionCubit',
        error: failure,
      ),
      ok: (_) {},
    );
  }

  void _onPlaybackEvent(PlaybackEvent event) {
    if (isClosed) return;
    switch (event) {
      case CaptionEvent(:final String text):
        _cancelLinger();
        emit(state.copyWith(text: text, seq: state.seq + 1));
      case SpeakingStoppedEvent():
        _cancelLinger();
        _lingerTimer = Timer(lingerDuration, _clear);
      case SpeakingStartedEvent():
      case MouthStateUpdatedEvent():
      case AnimationCompletedEvent():
      case CuesReachedEvent():
      case SpeechTimelineEvent() || SpeechPrerollEvent():
        break;
    }
  }

  void _clear() {
    _cancelLinger();
    if (isClosed || state.text == null) return;
    emit(state.copyWith(text: null));
  }

  void _cancelLinger() {
    _lingerTimer?.cancel();
    _lingerTimer = null;
  }

  @override
  Future<void> close() async {
    _cancelLinger();
    // Both cancels start now (no event slips in while the first resolves).
    await Future.wait(<Future<void>>[
      _eventSubscription.cancel(),
      _interruptionSubscription.cancel(),
    ]);
    await super.close();
  }
}
