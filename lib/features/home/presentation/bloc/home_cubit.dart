import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/repositories/home_repository.dart';
import 'home_state.dart';

/// HomeCubit manages home page specific state and actions
class HomeCubit extends Cubit<HomeState> {
  HomeCubit(this._repository) : super(const HomeState());

  final HomeRepository _repository;

  /// Initialize the home cubit
  Future<void> initialize() async {
    emit(state.copyWith(isInitialized: true));
  }

  /// Start volume fade in or out for avatar animations
  Future<void> startVolumeFade(bool fadeIn) async {
    emit(state.copyWith(isFading: fadeIn));
    await _repository.startVolumeFade(fadeIn);
  }

  /// Start the waiting TTS loop
  void startWaitingTtsLoop() {
    emit(state.copyWith(isPlayingWaitingLoop: true));
  }

  /// Stop the waiting TTS loop
  void stopWaitingTtsLoop() {
    emit(state.copyWith(isPlayingWaitingLoop: false));
  }

  /// Play TTS with the given audio path
  Future<void> playTts(
    String audioPath, {
    bool removeFile = true,
    bool soundEffectsEnabled = true,
    VoidCallback? onComplete,
  }) async {
    await _repository.playTts(
      audioPath,
      removeFile: removeFile,
      soundEffectsEnabled: soundEffectsEnabled,
      onComplete: onComplete,
    );
  }

  @override
  Future<void> close() async {
    _repository.dispose();
    super.close();
  }
}
