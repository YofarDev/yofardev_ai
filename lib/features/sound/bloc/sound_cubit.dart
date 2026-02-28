import 'package:flutter_bloc/flutter_bloc.dart';
import 'sound_state.dart';

/// Abstract interface for SoundService to allow for dependency injection
abstract class SoundService {
  Future<void> playSound(String soundName);
}

class SoundCubit extends Cubit<SoundState> {
  final SoundService _soundService;

  SoundCubit({required SoundService soundService})
    : _soundService = soundService,
      super(const SoundInitial());

  Future<void> playSound(String soundName) async {
    try {
      emit(SoundPlaying(soundName));
      await _soundService.playSound(soundName);
      emit(const SoundInitial());
    } catch (e) {
      emit(SoundError(e.toString()));
    }
  }
}
