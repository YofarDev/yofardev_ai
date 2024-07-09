
part of 'avatar_cubit.dart';

class AvatarState extends Equatable {
  final BgImages bgImage;
  const AvatarState({this.bgImage = BgImages.mountainsAndLake});

  @override
  List<Object> get props => <Object>[bgImage];

  AvatarState copyWith({
    BgImages? bgImage,
  }) {
    return AvatarState(
      bgImage: bgImage ?? this.bgImage,
    );
  }
}
