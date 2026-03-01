import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/services/sound_service_interface.dart';
import 'sound_state.dart';

class SoundCubit extends Cubit<SoundState> {
  final ISoundService _soundService;

  SoundCubit({required ISoundService soundService})
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
