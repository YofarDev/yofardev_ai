import 'package:flutter/material.dart';
import '../di/service_locator.dart';
import '../models/avatar_config.dart';
import '../models/chat_entry.dart';
import '../models/demo_script.dart';
import '../utils/logger.dart';
import '../../features/avatar/presentation/bloc/avatar_cubit.dart';
import '../../features/avatar/presentation/bloc/avatar_state.dart';
import '../../features/chat/presentation/bloc/chat_cubit.dart';
import '../../features/chat/presentation/bloc/chat_state.dart';
import '../../features/demo/data/repositories/demo_repository_impl.dart';
import '../../features/talking/presentation/bloc/talking_cubit.dart';
import '../../features/talking/presentation/bloc/talking_state.dart';
import '../../features/home/presentation/bloc/home_cubit.dart';
import '../../core/l10n/generated/app_localizations.dart';

/// Service for coordinating cross-feature app lifecycle events
///
/// Responsibilities:
/// - Avatar updates on new chat entries
/// - Talking state management during streaming
/// - Demo mode activation
/// - Chat change handling
/// - Volume fade control on avatar animations
/// - Waiting TTS loop control
class AppLifecycleService {
  AppLifecycleService({
    required HomeCubit homeCubit,
    required AvatarCubit avatarCubit,
    required TalkingCubit talkingCubit,
    required ChatCubit chatCubit,
  }) : _homeCubit = homeCubit,
       _avatarCubit = avatarCubit,
       _talkingCubit = talkingCubit,
       _chatCubit = chatCubit;

  final HomeCubit _homeCubit;
  final AvatarCubit _avatarCubit;
  final TalkingCubit _talkingCubit;
  final ChatCubit _chatCubit;

  /// Handle new chat entry - update avatar based on AI response content
  void onNewChatEntry(ChatEntry entry, String chatId) {
    // Only process yofardev (AI) entries
    if (entry.entryType != EntryType.yofardev) {
      AppLogger.debug(
        'Skipping non-yofardev entry: ${entry.entryType}',
        tag: 'AppLifecycleService',
      );
      return;
    }

    // Skip empty entries (e.g., initial streaming entry)
    if (entry.body.isEmpty) {
      AppLogger.debug(
        'Skipping empty entry (waiting for content)',
        tag: 'AppLifecycleService',
      );
      return;
    }

    // Extract avatar config from JSON safely
    final AvatarConfig avatarConfig = entry.getAvatarConfig();

    // Get current avatar state
    final AvatarState avatarState = _avatarCubit.state;
    final Avatar currentAvatar = avatarState.avatar;

    AppLogger.debug(
      'Current avatar: bg=${currentAvatar.background}, top=${currentAvatar.top}',
      tag: 'AppLifecycleService',
    );
    AppLogger.debug(
      'New avatar config: bg=${avatarConfig.background}, top=${avatarConfig.top}',
      tag: 'AppLifecycleService',
    );

    // Determine what changed and set appropriate animation
    final bool backgroundChanged =
        avatarConfig.background != null &&
        avatarConfig.background != currentAvatar.background;

    final bool clothesChanged =
        (avatarConfig.top != null && avatarConfig.top != currentAvatar.top) ||
        (avatarConfig.glasses != null &&
            avatarConfig.glasses != currentAvatar.glasses) ||
        (avatarConfig.hat != null && avatarConfig.hat != currentAvatar.hat) ||
        (avatarConfig.costume != null &&
            avatarConfig.costume != currentAvatar.costume);

    AppLogger.debug(
      'backgroundChanged=$backgroundChanged, clothesChanged=$clothesChanged',
      tag: 'AppLifecycleService',
    );

    // Set animation type based on what changed
    // Animations are now fully controlled client-side, not by the LLM
    AvatarConfig finalAvatarConfig = avatarConfig;
    if (backgroundChanged) {
      // Background change requires leave and comeback animation
      finalAvatarConfig = avatarConfig.copyWith(
        specials: AvatarSpecials.leaveAndComeBack,
      );
      AppLogger.debug(
        'Background changed, setting leaveAndComeBack animation',
        tag: 'AppLifecycleService',
      );
    } else if (clothesChanged) {
      // Clothes change requires outOfScreen animation (go down and up)
      finalAvatarConfig = avatarConfig.copyWith(
        specials: AvatarSpecials.outOfScreen,
      );
      AppLogger.debug(
        'Clothes changed, setting outOfScreen for animation',
        tag: 'AppLifecycleService',
      );
    }

    // Check if there's anything to update
    if (finalAvatarConfig.background != null ||
        finalAvatarConfig.top != null ||
        finalAvatarConfig.glasses != null ||
        finalAvatarConfig.hat != null ||
        finalAvatarConfig.costume != null) {
      AppLogger.debug(
        'Updating avatar with config: '
        'bg=${finalAvatarConfig.background}, '
        'top=${finalAvatarConfig.top}, '
        'glasses=${finalAvatarConfig.glasses}, '
        'hat=${finalAvatarConfig.hat}, '
        'costume=${finalAvatarConfig.costume}, '
        'specials=${finalAvatarConfig.specials}',
        tag: 'AppLifecycleService',
      );

      // Update AvatarCubit for animation and display
      _avatarCubit.onNewAvatarConfig(chatId, finalAvatarConfig);

      // Update ChatCubit to persist avatar to chat
      _chatCubit.updateAvatarOpenedChat(finalAvatarConfig);
    }
  }

  /// Handle chat streaming state changes - control thinking animation
  void onStreamingStateChanged(ChatStatus status) {
    switch (status) {
      case ChatStatus.initial:
      case ChatStatus.creatingChat:
        // Do nothing
        break;
      case ChatStatus.loading:
      case ChatStatus.typing:
      case ChatStatus.streaming:
        // Show thinking animation while waiting for LLM response
        _talkingCubit.setLoadingStatus(true);
      case ChatStatus.success:
      case ChatStatus.loaded:
      case ChatStatus.updating:
        // Streaming completed successfully
        // Don't stop here - let TTS play and handle state transition
        break;
      case ChatStatus.error:
      case ChatStatus.interrupted:
        // Error or interruption - stop thinking animation
        _talkingCubit.stop();
        break;
    }
  }

  /// Handle avatar animation state changes - control volume fade
  Future<void> onAvatarAnimationChanged(
    AvatarStatusAnimation statusAnimation,
  ) async {
    if (statusAnimation == AvatarStatusAnimation.initial) return;

    await _homeCubit.startVolumeFade(
      statusAnimation != AvatarStatusAnimation.leaving,
    );
  }

  /// Handle talking state changes - control waiting TTS loop
  ///
  /// Requires [context] for showing snackbars on error
  void onTalkingStateChanged(TalkingState state, BuildContext context) {
    state.when(
      idle: (_) => _homeCubit.stopWaitingTtsLoop(),
      waiting: (_) => _homeCubit.startWaitingTtsLoop(),
      generating: (_) {
        // TTS generation - thinking animation shows
        // No action needed here, UI updates via state.shouldShowTalking
      },
      speaking: (_) => _homeCubit.stopWaitingTtsLoop(),
      error: (String message, _) {
        _homeCubit.stopWaitingTtsLoop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).errorWithMessage(message),
            ),
          ),
        );
      },
    );
  }

  /// Handle current chat change - stop talking and load new avatar
  void onChatChanged(String chatId) {
    _talkingCubit.stop();
    _avatarCubit.loadAvatar(chatId);
  }

  /// Handle demo script change - activate demo mode
  ///
  /// Requires [context] for showing snackbars
  Future<void> onDemoScriptChanged(
    DemoScript? script,
    BuildContext context,
  ) async {
    if (script == null) return;

    AppLogger.info(
      'Demo script changed to: ${script.name}',
      tag: 'AppLifecycleService',
    );

    // Get DemoService from service locator
    final DemoService demoService = getIt<DemoService>();
    final ChatState chatState = _chatCubit.state;

    AppLogger.info(
      'Calling activateDemo for chat: ${chatState.currentChat.id}',
      tag: 'AppLifecycleService',
    );

    await demoService.activateDemo(
      chatId: chatState.currentChat.id,
      script: script,
    );

    AppLogger.info(
      'Demo activated, FakeLlmService isActive: ${demoService.isActive}',
      tag: 'AppLifecycleService',
    );

    // Show snackbar to indicate demo mode is active
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).demoModeActivated(script.name),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}
