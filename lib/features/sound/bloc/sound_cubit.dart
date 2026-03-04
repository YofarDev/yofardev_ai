import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fpdart/fpdart.dart';

import '../domain/repositories/sound_repository.dart';
import 'sound_state.dart';

class SoundCubit extends Cubit<SoundState> {
  final SoundRepository _soundRepository;

  SoundCubit({required SoundRepository soundRepository})
    : _soundRepository = soundRepository,
      super(const SoundInitial());

  Future<void> playSound(String soundName) async {
    try {
      emit(SoundPlaying(soundName));
      final Either<Exception, void> result = await _soundRepository.play(
        soundName,
      );
      result.fold(
        (Exception error) {
          emit(SoundError(error.toString()));
          emit(const SoundInitial());
        },
        (_) {
          emit(const SoundInitial());
        },
      );
    } catch (e) {
      emit(SoundError(e.toString()));
    }
  }
}
