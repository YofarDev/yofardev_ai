import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:async';

import '../../../../core/services/app_lifecycle_service.dart';
import '../../domain/repositories/home_repository.dart';
import '../../../avatar/presentation/bloc/avatar_state.dart';
import '../../../talking/presentation/bloc/talking_state.dart';
import 'home_state.dart';

/// HomeCubit manages home page specific state and actions
class HomeCubit extends Cubit<HomeState> {
  HomeCubit(this._repository, this._appLifecycleService)
    : super(const HomeState()) {
    // Subscribe to avatar animation changes for volume fade
    _avatarAnimationSubscription = _appLifecycleService
        .avatarAnimationChangedEvents
        .listen(
          _handleAvatarAnimationChanged,
          onError: (Object error) {
            // Log error silently
          },
        );

    // Subscribe to talking state changes for waiting TTS loop
    _talkingStateSubscription = _appLifecycleService.talkingStateChangedEvents
        .listen(
          _handleTalkingStateChanged,
          onError: (Object error) {
            // Log error silently
          },
        );
  }

  final HomeRepository _repository;
  final AppLifecycleService _appLifecycleService;
  StreamSubscription<AvatarStatusAnimation>? _avatarAnimationSubscription;
  StreamSubscription<TalkingState>? _talkingStateSubscription;

  /// Handle avatar animation changes from app lifecycle service.
  ///
  /// Controls volume fade based on animation status.
  Future<void> _handleAvatarAnimationChanged(
    AvatarStatusAnimation statusAnimation,
  ) async {
    if (statusAnimation == AvatarStatusAnimation.initial) return;

    await startVolumeFade(statusAnimation != AvatarStatusAnimation.leaving);
  }

  /// Handle talking state changes from app lifecycle service.
  ///
  /// Controls waiting TTS loop based on talking state.
  void _handleTalkingStateChanged(TalkingState talkingState) {
    talkingState.when(
      idle: (_) => stopWaitingTtsLoop(),
      waiting: (_) => startWaitingTtsLoop(),
      generating: (_) {
        // TTS generation - thinking animation shows
        // No action needed here, UI updates via state.shouldShowTalking
      },
      speaking: (_) => stopWaitingTtsLoop(),
      error: (String message, _) => stopWaitingTtsLoop(),
    );
  }

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
    await _avatarAnimationSubscription?.cancel();
    await _talkingStateSubscription?.cancel();
    _repository.dispose();
    super.close();
  }
}
