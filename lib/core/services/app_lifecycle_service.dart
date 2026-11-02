import 'dart:async';

import '../models/app_lifecycle_event.dart';
import '../models/avatar_config.dart';
import '../models/avatar_mood.dart';
import '../models/chat.dart';
import '../models/chat_entry.dart';
import '../models/chat_status.dart';
import '../utils/logger.dart';

/// Service for coordinating cross-feature app lifecycle events using streams.
///
/// This service exposes broadcast streams that cubits can subscribe to.
/// The dependency direction is correct: cubits depend on the service interface,
/// not the other way around.
///
/// Responsibilities:
/// - Avatar update coordination when new chat entries arrive
/// - Talking state coordination during streaming
/// - Chat change coordination
class AppLifecycleService {
  AppLifecycleService();

  // Stream controllers for each lifecycle event type
  final StreamController<NewChatEntryPayload> _newChatEntryController =
      StreamController<NewChatEntryPayload>.broadcast();
  final StreamController<String> _chatChangedController =
      StreamController<String>.broadcast();
  final StreamController<ChatStatus> _streamingStateChangedController =
      StreamController<ChatStatus>.broadcast();
  final StreamController<AvatarChangeRequested>
  _avatarChangeRequestedController =
      StreamController<AvatarChangeRequested>.broadcast();
  final StreamController<AvatarMood> _moodController =
      StreamController<AvatarMood>.broadcast();
  final StreamController<ChatPersona> _personaController =
      StreamController<ChatPersona>.broadcast();

  // Public streams for cubits to subscribe to
  Stream<NewChatEntryPayload> get newChatEntryEvents =>
      _newChatEntryController.stream;
  Stream<String> get chatChangedEvents => _chatChangedController.stream;
  Stream<ChatStatus> get streamingStateChangedEvents =>
      _streamingStateChangedController.stream;
  Stream<AvatarChangeRequested> get avatarChangeRequestedEvents =>
      _avatarChangeRequestedController.stream;

  /// The mood declared by each reply that sets one (already validated;
  /// invalid values arrive as neutral). A reply without a mood keeps the
  /// previous one, so nothing is emitted for it.
  Stream<AvatarMood> get moodEvents => _moodController.stream;

  /// The persona of the current chat, announced whenever the current chat
  /// changes (M10 ruling 10): the avatar's body language follows it.
  Stream<ChatPersona> get personaEvents => _personaController.stream;

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

    // The reply's mood applies when the reply starts and persists until a
    // later reply sets a new one; no mood field means no change.
    if (avatarConfig.mood != null && !_moodController.isClosed) {
      _moodController.add(avatarConfig.mood!);
    }

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
            avatarConfig.costume != currentAvatarConfig.costume) ||
        (avatarConfig.topTint != null &&
            avatarConfig.topTint != currentAvatarConfig.topTint) ||
        (avatarConfig.hatTint != null &&
            avatarConfig.hatTint != currentAvatarConfig.hatTint);

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
        finalAvatarConfig.costume != null ||
        finalAvatarConfig.topTint != null ||
        finalAvatarConfig.hatTint != null) {
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

  /// Emit event when current chat changes.
  ///
  /// [TalkingCubit] and [AvatarCubit] subscribe.
  void emitChatChanged(String chatId) {
    _chatChangedController.add(chatId);
  }

  /// Emit a request to change the avatar of the currently open chat.
  ///
  /// [ChatCubit] subscribes to persist the change and trigger the animation.
  void emitAvatarChangeRequested(AvatarChangeRequested request) {
    _avatarChangeRequestedController.add(request);
  }

  /// Emit the persona of the chat that just became current.
  ///
  /// [ChatCubit] emits it; `AvatarCueService` turns it into the director's
  /// body-language profile.
  void emitPersonaChanged(ChatPersona persona) {
    if (_personaController.isClosed) {
      return;
    }
    _personaController.add(persona);
  }

  /// Dispose all stream controllers.
  ///
  /// Call this when the app is shutting down.
  void dispose() {
    _newChatEntryController.close();
    _chatChangedController.close();
    _streamingStateChangedController.close();
    _avatarChangeRequestedController.close();
    _moodController.close();
    _personaController.close();
  }
}
