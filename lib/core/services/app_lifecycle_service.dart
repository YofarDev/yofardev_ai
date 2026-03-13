import 'dart:async';

import '../models/app_lifecycle_event.dart';
import '../models/avatar_config.dart';
import '../models/chat_entry.dart';
import '../models/demo_script.dart';
import '../utils/logger.dart';
import '../../features/avatar/presentation/bloc/avatar_state.dart';
import '../../features/chat/presentation/bloc/chat_state.dart';
import '../../features/talking/presentation/bloc/talking_state.dart';

/// Service for coordinating cross-feature app lifecycle events using streams.
///
/// This service exposes broadcast streams that cubits can subscribe to.
/// The dependency direction is correct: cubits depend on the service interface,
/// not the other way around.
///
/// Responsibilities:
/// - Avatar update coordination when new chat entries arrive
/// - Talking state coordination during streaming
/// - Demo mode activation
/// - Chat change coordination
/// - Volume fade coordination on avatar animations
/// - Waiting TTS loop coordination
class AppLifecycleService {
  AppLifecycleService();

  // Stream controllers for each lifecycle event type
  final StreamController<NewChatEntryPayload> _newChatEntryController =
      StreamController<NewChatEntryPayload>.broadcast();
  final StreamController<String> _chatChangedController =
      StreamController<String>.broadcast();
  final StreamController<ChatStatus> _streamingStateChangedController =
      StreamController<ChatStatus>.broadcast();
  final StreamController<AvatarStatusAnimation>
  _avatarAnimationChangedController =
      StreamController<AvatarStatusAnimation>.broadcast();
  final StreamController<TalkingState> _talkingStateChangedController =
      StreamController<TalkingState>.broadcast();
  final StreamController<DemoScript> _demoScriptChangedController =
      StreamController<DemoScript>.broadcast();

  // Public streams for cubits to subscribe to
  Stream<NewChatEntryPayload> get newChatEntryEvents =>
      _newChatEntryController.stream;
  Stream<String> get chatChangedEvents => _chatChangedController.stream;
  Stream<ChatStatus> get streamingStateChangedEvents =>
      _streamingStateChangedController.stream;
  Stream<AvatarStatusAnimation> get avatarAnimationChangedEvents =>
      _avatarAnimationChangedController.stream;
  Stream<TalkingState> get talkingStateChangedEvents =>
      _talkingStateChangedController.stream;
  Stream<DemoScript> get demoScriptChangedEvents =>
      _demoScriptChangedController.stream;

  /// Emit event when a new chat entry is created.
  ///
  /// The service determines the appropriate avatar animation based on what changed,
  /// then emits an event with both the entry and the determined avatar configuration.
  void emitNewChatEntry(
    ChatEntry entry,
    String chatId,
    AvatarConfig currentAvatarConfig,
  ) {
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

    AppLogger.debug(
      'Current avatar: bg=${currentAvatarConfig.background}, top=${currentAvatarConfig.top}',
      tag: 'AppLifecycleService',
    );
    AppLogger.debug(
      'New avatar config: bg=${avatarConfig.background}, top=${avatarConfig.top}',
      tag: 'AppLifecycleService',
    );

    // Determine what changed and set appropriate animation
    final bool backgroundChanged =
        avatarConfig.background != null &&
        avatarConfig.background != currentAvatarConfig.background;

    final bool clothesChanged =
        (avatarConfig.top != null &&
            avatarConfig.top != currentAvatarConfig.top) ||
        (avatarConfig.glasses != null &&
            avatarConfig.glasses != currentAvatarConfig.glasses) ||
        (avatarConfig.hat != null &&
            avatarConfig.hat != currentAvatarConfig.hat) ||
        (avatarConfig.costume != null &&
            avatarConfig.costume != currentAvatarConfig.costume);

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
        'Emitting new chat entry event with config: '
        'bg=${finalAvatarConfig.background}, '
        'top=${finalAvatarConfig.top}, '
        'glasses=${finalAvatarConfig.glasses}, '
        'hat=${finalAvatarConfig.hat}, '
        'costume=${finalAvatarConfig.costume}, '
        'specials=${finalAvatarConfig.specials}',
        tag: 'AppLifecycleService',
      );

      // Emit event for cubits to handle
      _newChatEntryController.add(
        NewChatEntryPayload(
          entry: entry,
          chatId: chatId,
          newAvatarConfig: finalAvatarConfig,
        ),
      );
    }
  }

  /// Emit event when chat streaming state changes.
  ///
  /// [TalkingCubit] subscribes to control thinking animation.
  void emitStreamingStateChanged(ChatStatus status) {
    _streamingStateChangedController.add(status);
  }

  /// Emit event when avatar animation state changes.
  ///
  /// [HomeCubit] subscribes to control volume fade.
  void emitAvatarAnimationChanged(AvatarStatusAnimation statusAnimation) {
    _avatarAnimationChangedController.add(statusAnimation);
  }

  /// Emit event when talking state changes.
  ///
  /// [HomeCubit] subscribes to control waiting TTS loop.
  void emitTalkingStateChanged(TalkingState state) {
    _talkingStateChangedController.add(state);
  }

  /// Emit event when current chat changes.
  ///
  /// [TalkingCubit] and [AvatarCubit] subscribe.
  void emitChatChanged(String chatId) {
    _chatChangedController.add(chatId);
  }

  /// Emit event when demo script changes.
  ///
  /// [ChatCubit] subscribes to activate demo mode.
  void emitDemoScriptChanged(DemoScript script) {
    _demoScriptChangedController.add(script);
  }

  /// Dispose all stream controllers.
  ///
  /// Call this when the app is shutting down.
  void dispose() {
    _newChatEntryController.close();
    _chatChangedController.close();
    _streamingStateChangedController.close();
    _avatarAnimationChangedController.close();
    _talkingStateChangedController.close();
    _demoScriptChangedController.close();
  }
}
