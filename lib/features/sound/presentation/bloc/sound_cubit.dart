import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/exception_mapper.dart';
import '../../../../core/models/failure.dart';
import '../../../../core/models/result.dart';
import '../../domain/repositories/sound_repository.dart';
import 'sound_state.dart';

class SoundCubit extends Cubit<SoundState> {
  final SoundRepository _soundRepository;

  SoundCubit({required SoundRepository soundRepository})
    : _soundRepository = soundRepository,
      super(const SoundInitial());

  Future<void> playSound(String soundName) async {
    try {
      emit(SoundPlaying(soundName));
      final Result<void> result = await _soundRepository.play(soundName);
      result.when(
        err: (Failure failure) {
          emit(SoundError(failure));
          emit(const SoundInitial());
        },
        ok: (_) {
          emit(const SoundInitial());
        },
      );
    } catch (e, st) {
      emit(
        SoundError(mapExceptionToFailure(e, stackTrace: st, tag: 'SoundCubit')),
      );
    }
  }
}
