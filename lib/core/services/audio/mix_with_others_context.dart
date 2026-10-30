import 'package:audioplayers/audioplayers.dart';

/// The audio context of the sound-effect players (foley, ambient beds):
/// they never take audio focus (Android: `AudioFocus.none`) and mix with
/// other audio (iOS: `mixWithOthers`), so a footstep or a rain bed cannot
/// pause the TTS player or the user's music. The TTS player keeps the
/// default context.
///
/// Note: on iOS the audio session is app-wide, so setting this on any player
/// applies it to the TTS player as well; there the TTS then mixes too.
AudioContext mixWithOthersContext() =>
    AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers).build();
