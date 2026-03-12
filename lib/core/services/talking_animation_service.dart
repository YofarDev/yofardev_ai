import 'dart:async';

import 'package:flutter/foundation.dart';

sealed class TalkingCommand {
  const TalkingCommand();
}

class SetSpeakingCommand extends TalkingCommand {
  const SetSpeakingCommand();
}

class StopCommand extends TalkingCommand {
  const StopCommand();
}

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

class SetGeneratingCommand extends TalkingCommand {
  const SetGeneratingCommand();
}

class TalkingAnimationService {
  final StreamController<TalkingCommand> _controller =
      StreamController<TalkingCommand>.broadcast();

  Stream<TalkingCommand> get commands => _controller.stream;

  void setSpeaking() => _controller.add(const SetSpeakingCommand());

  void stop() => _controller.add(const StopCommand());

  void setGenerating() => _controller.add(const SetGeneratingCommand());

  void startAnimation(
    String audioPath,
    List<int> amplitudes,
    Duration audioDuration,
    VoidCallback onComplete,
  ) => _controller.add(
    StartAnimationCommand(audioPath, amplitudes, audioDuration, onComplete),
  );

  void dispose() => _controller.close();
}
