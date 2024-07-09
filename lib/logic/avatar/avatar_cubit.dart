import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/bg_images.dart';
import '../../services/avatar_service.dart';

part 'avatar_state.dart';

class AvatarCubit extends Cubit<AvatarState> {
  AvatarCubit() : super(const AvatarState());


  void getBgImage() async {
    final BgImages bgImage = await AvatarService().getCurrentBg();
    emit(state.copyWith(bgImage: bgImage));
  }


  void setBgImage(BgImages bgImage) async {
    emit(state.copyWith(bgImage: bgImage));
     await AvatarService().setCurrentBg(bgImage);
  }
}
