import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/models/app_lifecycle_event.dart';
import '../../../../core/models/avatar_config.dart';
import '../../../../core/repositories/avatar_repository.dart';
import '../../../../core/res/app_constants.dart';
import '../../../../core/services/app_lifecycle_service.dart';
import '../../../../core/services/audio/audio_player_service.dart';
import '../../../../core/services/avatar_animation_service.dart';
import '../../../../core/utils/logger.dart';
import '../../../../core/models/chat.dart';
import '../../domain/models/avatar_animation.dart';
import 'avatar_state.dart';

class AvatarCubit extends Cubit<AvatarState> {
  AvatarCubit(
    this._avatarRepository,
    this._animationService,
    this._audioPlayerService,
    this._appLifecycleService,
  ) : super(const AvatarState(avatar: Avatar(), avatarConfig: AvatarConfig())) {
    // Subscribe to animation events from the service
    _animationSubscription = _animationService.animations.listen(
      _handleAnimationEvent,
      onError: (Object error) {
        AppLogger.error(
          'Animation stream error',
          tag: 'AvatarCubit',
          error: error,
        );
      },
    );

    // Subscribe to app lifecycle events
    _lifecycleSubscription = _appLifecycleService.newChatEntryEvents.listen(
      _handleNewChatEntryEvent,
      onError: (Object error) {
        AppLogger.error(
          'Lifecycle stream error',
          tag: 'AvatarCubit',
          error: error,
        );
      },
    );

    _chatChangedSubscription = _appLifecycleService.chatChangedEvents.listen(
      _handleChatChangedEvent,
      onError: (Object error) {
        AppLogger.error(
          'Chat changed stream error',
          tag: 'AvatarCubit',
          error: error,
        );
      },
    );
  }

  final AvatarRepository _avatarRepository;
  final AvatarAnimationService _animationService;
  final AudioPlayerService _audioPlayerService;
  final AppLifecycleService _appLifecycleService;
  StreamSubscription<AvatarAnimation>? _animationSubscription;
  StreamSubscription<NewChatEntryPayload>? _lifecycleSubscription;
  StreamSubscription<String>? _chatChangedSubscription;

  /// Handle animation events from the service.
  void _handleAnimationEvent(AvatarAnimation event) {
    AppLogger.debug(
      'AvatarCubit: received animation event: $event',
      tag: 'AvatarCubit',
    );
    event.when(
      clothes: (bool goingDown) => onClothesAnimationChanged(goingDown),
      background: (BackgroundTransition transition) =>
          onBackgroundTransitionChanged(transition),
      updateConfig: (String chatId, AvatarConfig avatarConfig) {
        AppLogger.debug(
          'AvatarCubit: updateConfig event - chatId=$chatId, config=$avatarConfig',
          tag: 'AvatarCubit',
        );
        updateAvatarConfig(chatId, avatarConfig);
      },
    );
  }

  /// Handle new chat entry events from app lifecycle service.
  void _handleNewChatEntryEvent(NewChatEntryPayload payload) {
    onNewAvatarConfig(payload.chatId, payload.newAvatarConfig);
  }

  /// Handle chat changed events from app lifecycle service.
  void _handleChatChangedEvent(String chatId) {
    loadAvatar(chatId);
  }

  void _emitIfOpen(AvatarState newState) {
    if (isClosed) return;
    emit(newState);
  }

  void setValuesBasedOnScreenWidth({required double screenWidth}) {
    if (!screenWidth.isFinite || screenWidth <= 0) return;
    final double scaleFactor = screenWidth / AppConstants.avatarWidth;
    _emitIfOpen(
      state.copyWith(
        status: AvatarStatus.ready,
        baseOriginalWidth: AppConstants.avatarWidth,
        baseOriginalHeight: AppConstants.avatarHeight,
        scaleFactor: scaleFactor,
      ),
    );
  }

  void onScreenSizeChanged(double screenWidth) {
    if (!screenWidth.isFinite || screenWidth <= 0) return;
    if (!state.baseOriginalWidth.isFinite || state.baseOriginalWidth <= 0) {
      setValuesBasedOnScreenWidth(screenWidth: screenWidth);
      return;
    }
    final double scaleFactor = screenWidth / state.baseOriginalWidth;
    if (!scaleFactor.isFinite || scaleFactor <= 0) {
      setValuesBasedOnScreenWidth(screenWidth: screenWidth);
      return;
    }
    _emitIfOpen(state.copyWith(scaleFactor: scaleFactor));
  }

  void loadAvatar(String chatId) async {
    _emitIfOpen(state.copyWith(status: AvatarStatus.loading));
    final Either<Exception, Chat> result = await _avatarRepository.getChat(
      chatId,
    );
    if (isClosed) return;
    result.fold(
      (Exception error) {
        // This is expected for new chats - no custom avatar saved yet
        // Only set status to ready if dimensions are initialized
        if (state.baseOriginalHeight > 0) {
          _emitIfOpen(state.copyWith(status: AvatarStatus.ready));
        }
      },
      (Chat chat) {
        // Only set status to ready if dimensions are initialized
        if (state.baseOriginalHeight > 0) {
          _emitIfOpen(
            state.copyWith(avatar: chat.avatar, status: AvatarStatus.ready),
          );
        } else {
          _emitIfOpen(state.copyWith(avatar: chat.avatar));
        }
      },
    );
  }

  void _goAndComeBack(String chatId, AvatarConfig avatarConfig) async {
    // Preserve the original specials before animation changes the state
    final AvatarSpecials originalSpecials = state.avatar.specials;

    onAnimationStatusChanged(true);
    await Future<dynamic>.delayed(
      Duration(seconds: AppConstants.movingAvatarDuration),
    );
    if (isClosed) return;

    // Set animation to "coming" FIRST, then update avatar
    // This ensures background changes while avatar is coming back
    onAnimationStatusChanged(false);
    // Use original specials, not the animation trigger value
    final AvatarConfig updateConfig = avatarConfig.copyWith(
      specials: originalSpecials,
    );
    _updateAvatar(chatId, updateConfig);
  }

  void onAnimationStatusChanged(bool leaving) {
    _emitIfOpen(
      state.copyWith(
        statusAnimation: leaving
            ? AvatarStatusAnimation.leaving
            : AvatarStatusAnimation.coming,
        avatar: state.avatar.copyWith(
          specials: leaving
              ? AvatarSpecials.outOfScreen
              : AvatarSpecials.onScreen,
        ),
        previousSpecialsState: leaving
            ? AvatarSpecials.outOfScreen
            : AvatarSpecials.onScreen,
      ),
    );
  }

  void onClothesAnimationChanged(bool goingDown) {
    _emitIfOpen(
      state.copyWith(
        statusAnimation: goingDown
            ? AvatarStatusAnimation.dropping
            : AvatarStatusAnimation.rising,
        avatar: state.avatar.copyWith(
          specials: goingDown
              ? AvatarSpecials.outOfScreen
              : AvatarSpecials.onScreen,
        ),
        previousSpecialsState: goingDown
            ? AvatarSpecials.outOfScreen
            : AvatarSpecials.onScreen,
      ),
    );
  }

  void _goDownAndUp(String chatId, AvatarConfig avatarConfig) async {
    // Play whoosh sound effect via service
    unawaited(
      _audioPlayerService.playAsset('sound_effects/whoosh.wav', volume: 0.3),
    );

    // Preserve the original specials before animation changes the state
    final AvatarSpecials originalSpecials = state.avatar.specials;

    onClothesAnimationChanged(true); // dropping
    await Future<dynamic>.delayed(
      Duration(seconds: AppConstants.changingAvatarDuration),
    );
    if (isClosed) return;
    // Use original specials, not the animation trigger value
    final AvatarConfig updateConfig = avatarConfig.copyWith(
      specials: originalSpecials,
    );
    _updateAvatar(chatId, updateConfig);
    onClothesAnimationChanged(false); // rising
  }

  void onNewAvatarConfig(String chatId, AvatarConfig avatarConfig) async {
    AppLogger.debug(
      'onNewAvatarConfig called with specials: ${avatarConfig.specials}',
      tag: 'AvatarCubit',
    );

    _emitIfOpen(state.copyWith(statusAnimation: AvatarStatusAnimation.initial));

    if (avatarConfig.specials == AvatarSpecials.leaveAndComeBack) {
      AppLogger.debug('Using leaveAndComeBack animation', tag: 'AvatarCubit');
      _goAndComeBack(chatId, avatarConfig);
    } else if (avatarConfig.specials == AvatarSpecials.outOfScreen) {
      AppLogger.debug('Using goDownAndUp animation', tag: 'AvatarCubit');
      // Clothes change: use dropping/rising animation
      _goDownAndUp(chatId, avatarConfig);
    } else {
      AppLogger.debug(
        'No special animation, updating directly',
        tag: 'AvatarCubit',
      );
      if (avatarConfig.specials != null &&
          avatarConfig.specials != state.previousSpecialsState) {
        onAnimationStatusChanged(
          state.avatar.specials == AvatarSpecials.onScreen,
        );
        // we wait it's out of screen before to update appearance
        if (avatarConfig.specials == AvatarSpecials.outOfScreen) {
          await Future<dynamic>.delayed(
            Duration(seconds: AppConstants.movingAvatarDuration),
          );
          if (isClosed) return;
        }
      }
      _updateAvatar(chatId, avatarConfig);
    }
  }

  void _updateAvatar(String chatId, AvatarConfig avatarConfig) {
    final Avatar avatar = state.avatar.copyWith(
      hat: avatarConfig.hat ?? state.avatar.hat,
      top: avatarConfig.top ?? state.avatar.top,
      glasses: avatarConfig.glasses ?? state.avatar.glasses,
      specials: avatarConfig.specials ?? state.avatar.specials,
      background: avatarConfig.background ?? state.avatar.background,
      costume: avatarConfig.costume ?? state.avatar.costume,
    );
    _emitIfOpen(
      state.copyWith(
        avatar: avatar,
        previousSpecialsState:
            avatarConfig.specials ?? state.previousSpecialsState,
      ),
    );
    _avatarRepository.updateAvatar(chatId, avatar);
  }

  void toggleGlasses() {
    final AvatarGlasses glasses = state.avatar.glasses == AvatarGlasses.glasses
        ? AvatarGlasses.sunglasses
        : AvatarGlasses.glasses;
    emit(state.copyWith(avatar: state.avatar.copyWith(glasses: glasses)));
  }

  void onBackgroundTransitionChanged(BackgroundTransition transition) {
    _emitIfOpen(state.copyWith(backgroundTransition: transition));
  }

  void updateAvatarConfig(String chatId, AvatarConfig avatarConfig) {
    // Use onNewAvatarConfig to trigger animations based on specials
    onNewAvatarConfig(chatId, avatarConfig);
  }

  @override
  Future<void> close() async {
    await _animationSubscription?.cancel();
    await _lifecycleSubscription?.cancel();
    await _chatChangedSubscription?.cancel();
    return super.close();
  }
}
