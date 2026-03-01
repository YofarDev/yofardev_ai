import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/utils/logger.dart';

/// HomeCubit manages home page specific state and actions
class HomeCubit extends Cubit<HomeState> {
  HomeCubit() : super(const HomeState()) {
    AppLogger.info('HomeCubit created', tag: 'HomeCubit');
  }

  /// Initialize the home cubit
  Future<void> initialize() async {
    AppLogger.info('Initializing HomeCubit', tag: 'HomeCubit');
    emit(state.copyWith(isInitialized: true));
  }

  /// Start volume fade in or out
  void startVolumeFade(bool fadeIn) {
    AppLogger.debug(
      'Starting volume fade: ${fadeIn ? "in" : "out"}',
      tag: 'HomeCubit',
    );
    emit(state.copyWith(isFading: fadeIn));
  }

  /// Start the waiting TTS loop
  void startWaitingTtsLoop() {
    AppLogger.debug('Starting waiting TTS loop', tag: 'HomeCubit');
    emit(state.copyWith(isPlayingWaitingLoop: true));
  }

  /// Stop the waiting TTS loop
  void stopWaitingTtsLoop() {
    AppLogger.debug('Stopping waiting TTS loop', tag: 'HomeCubit');
    emit(state.copyWith(isPlayingWaitingLoop: false));
  }

  /// Play TTS with the given audio path
  Future<void> playTts(
    String audioPath, {
    bool removeFile = true,
    bool soundEffectsEnabled = true,
    bool updateStatus = true,
    VoidCallback? onComplete,
  }) async {
    AppLogger.debug('Playing TTS: $audioPath', tag: 'HomeCubit');

    try {
      // This is a placeholder implementation
      // The actual TTS playing should be handled by the appropriate service
      if (onComplete != null) {
        onComplete();
      }
    } catch (e) {
      AppLogger.error('Error playing TTS', tag: 'HomeCubit', error: e);
    }
  }
}

/// Home state
class HomeState {
  final bool isInitialized;
  final bool isFading;
  final bool isPlayingWaitingLoop;

  const HomeState({
    this.isInitialized = false,
    this.isFading = false,
    this.isPlayingWaitingLoop = false,
  });

  HomeState copyWith({
    bool? isInitialized,
    bool? isFading,
    bool? isPlayingWaitingLoop,
  }) {
    return HomeState(
      isInitialized: isInitialized ?? this.isInitialized,
      isFading: isFading ?? this.isFading,
      isPlayingWaitingLoop: isPlayingWaitingLoop ?? this.isPlayingWaitingLoop,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HomeState &&
          runtimeType == other.runtimeType &&
          isInitialized == other.isInitialized &&
          isFading == other.isFading &&
          isPlayingWaitingLoop == other.isPlayingWaitingLoop;

  @override
  int get hashCode =>
      isInitialized.hashCode ^
      isFading.hashCode ^
      isPlayingWaitingLoop.hashCode;
}
