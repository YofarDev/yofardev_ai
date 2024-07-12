import 'package:equatable/equatable.dart';

import '../../models/avatar.dart';

enum AvatarStatus { initial, ready }

class AvatarState extends Equatable {
  final AvatarStatus status;
  final double baseOriginalWidth;
  final double baseOriginalHeight;
  final double scaleFactor;
  final Avatar avatar;
 
  const AvatarState({
    this.status = AvatarStatus.initial,
    this.baseOriginalWidth = 0,
    this.baseOriginalHeight = 0,
    this.scaleFactor = 1,
    this.avatar = const Avatar(),
  });

  @override
  List<Object> get props {
    return <Object>[
      status,
      baseOriginalWidth,
      baseOriginalHeight,
      scaleFactor,
      avatar,
    ];
  }

  AvatarState copyWith({
    AvatarStatus? status,
    double? baseOriginalWidth,
    double? baseOriginalHeight,
    double? scaleFactor,
    Avatar? avatar,
  }) {
    return AvatarState(
      status: status ?? this.status,
      baseOriginalWidth: baseOriginalWidth ?? this.baseOriginalWidth,
      baseOriginalHeight: baseOriginalHeight ?? this.baseOriginalHeight,
      scaleFactor: scaleFactor ?? this.scaleFactor,
      avatar: avatar ?? this.avatar,
    );
  }
}
