import 'package:freezed_annotation/freezed_annotation.dart';

part 'sound_state.freezed.dart';

@freezed
sealed class SoundState with _$SoundState {
  const factory SoundState.initial() = SoundInitial;

  const factory SoundState.playing(String soundName) = SoundPlaying;

  const factory SoundState.error(String message) = SoundError;
}
