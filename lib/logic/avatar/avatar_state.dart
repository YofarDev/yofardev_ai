import 'package:equatable/equatable.dart';

import '../../models/avatar.dart';

enum AvatarStatus { initial, ready }
enum AvatarStatusAnimation {initial, leaving, coming }

class AvatarState extends Equatable {
  final AvatarStatus status;
  final AvatarStatusAnimation statusAnimation;
  final double baseOriginalWidth;
  final double baseOriginalHeight;
  final double scaleFactor;
  final Avatar avatar;
  final AvatarConfig avatarConfig;
 
  const AvatarState({
    this.status = AvatarStatus.initial,
    this.statusAnimation = AvatarStatusAnimation.initial,
    this.baseOriginalWidth = 0,
    this.baseOriginalHeight = 0,
    this.scaleFactor = 1,
    this.avatar = const Avatar(),
    this.avatarConfig =  const AvatarConfig(),
  });

  @override
  List<Object> get props {
    return <Object>[
      status,
      statusAnimation,
      baseOriginalWidth,
      baseOriginalHeight,
      scaleFactor,
      avatar,
      avatarConfig,
    ];
  }

  AvatarState copyWith({
    AvatarStatus? status,
    AvatarStatusAnimation? statusAnimation,
    double? baseOriginalWidth,
    double? baseOriginalHeight,
    double? scaleFactor,
    Avatar? avatar,
    AvatarConfig? avatarConfig,
  }) {
    return AvatarState(
      status: status ?? this.status,
      statusAnimation: statusAnimation ?? this.statusAnimation,
      baseOriginalWidth: baseOriginalWidth ?? this.baseOriginalWidth,
      baseOriginalHeight: baseOriginalHeight ?? this.baseOriginalHeight,
      scaleFactor: scaleFactor ?? this.scaleFactor,
      avatar: avatar ?? this.avatar,
      avatarConfig: avatarConfig ?? this.avatarConfig,
    );
  }
}
