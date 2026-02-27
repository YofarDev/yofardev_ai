import 'package:equatable/equatable.dart';

abstract class SoundState extends Equatable {
  const SoundState();

  @override
  List<Object?> get props => <Object?>[];
}

class SoundInitial extends SoundState {
  const SoundInitial();
}

class SoundPlaying extends SoundState {
  final String soundName;

  const SoundPlaying(this.soundName);

  @override
  List<Object?> get props => <Object?>[soundName];
}

class SoundError extends SoundState {
  final String message;

  const SoundError(this.message);

  @override
  List<Object?> get props => <Object?>[message];
}
