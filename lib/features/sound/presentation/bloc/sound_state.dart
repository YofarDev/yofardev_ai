import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/models/failure.dart';

part 'sound_state.freezed.dart';

@freezed
sealed class SoundState with _$SoundState {
  const factory SoundState.initial() = SoundInitial;

  const factory SoundState.playing(String soundName) = SoundPlaying;

  const factory SoundState.error(Failure failure) = SoundError;
}
