import 'dart:async';

import 'package:flutter/foundation.dart';

/// Commands that can be sent to TalkingCubit via the animation service.
///
/// This decouples ChatTtsCubit from TalkingCubit by using a broadcast stream
/// instead of direct method calls.
sealed class TalkingCommand {
  const TalkingCommand();
}

/// Command to set the talking state to "speaking" (TTS is playing).
class SetSpeakingCommand extends TalkingCommand {
  const SetSpeakingCommand();
}

/// Command to stop all talking state and cancel animations.
class StopCommand extends TalkingCommand {
  const StopCommand();
}

/// Command to start amplitude-based lip-sync animation.
class StartAnimationCommand extends TalkingCommand {
  const StartAnimationCommand(
    this.audioPath,
    this.amplitudes,
    this.audioDuration,
    this.onComplete,
  );
  final String audioPath;
  final List<int> amplitudes;
  final Duration audioDuration;
  final VoidCallback onComplete;
}

/// Command to set the talking state to "generating" (thinking animation).
class SetGeneratingCommand extends TalkingCommand {
  const SetGeneratingCommand();
}

/// Service for coordinating talking/animation state between cubits.
///
/// Exposes a broadcast stream of [TalkingCommand]s. [TalkingCubit] subscribes
/// and reacts to commands. This removes the direct cubit-to-cubit dependency
/// between ChatTtsCubit and TalkingCubit.
///
/// The dependency arrow points inward only:
///   ChatTtsCubit → TalkingAnimationService → stream → TalkingCubit
class TalkingAnimationService {
  final StreamController<TalkingCommand> _controller =
      StreamController<TalkingCommand>.broadcast();

  /// Stream of commands that TalkingCubit subscribes to.
  Stream<TalkingCommand> get commands => _controller.stream;

  /// Request to set speaking state (TTS is currently playing).
  void setSpeaking() => _controller.add(const SetSpeakingCommand());

  /// Request to stop all talking state and animations.
  void stop() => _controller.add(const StopCommand());

  /// Request to set generating state (shows thinking animation).
  void setGenerating() => _controller.add(const SetGeneratingCommand());

  /// Request to start amplitude-based lip-sync animation.
  void startAnimation(
    String audioPath,
    List<int> amplitudes,
    Duration audioDuration,
    VoidCallback onComplete,
  ) => _controller.add(
    StartAnimationCommand(audioPath, amplitudes, audioDuration, onComplete),
  );

  /// Dispose the stream controller. Call during app shutdown.
  void dispose() => _controller.close();
}
