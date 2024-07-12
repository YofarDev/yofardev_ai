import 'package:equatable/equatable.dart';

import '../utils/extensions.dart';

enum AvatarTop { noHat, beanie }

enum AvatarBottom { pinkHoodie, longCoat, tshirt }

enum AvatarGlasses { glasses, sunglasses }

enum AvatarSpecials { onScreen, outOfScreen }

class Avatar extends Equatable {
  final AvatarTop top;
  final AvatarBottom bottom;
  final AvatarGlasses glasses;
  final AvatarSpecials specials;
  const Avatar({
    this.top = AvatarTop.noHat,
    this.bottom = AvatarBottom.pinkHoodie,
    this.glasses = AvatarGlasses.glasses,
    this.specials = AvatarSpecials.onScreen,
  });

  @override
  List<Object> get props => <Object>[top, bottom, glasses, specials];

  Avatar copyWith({
    AvatarTop? top,
    AvatarBottom? bottom,
    AvatarGlasses? glasses,
    AvatarSpecials? specials,
  }) {
    return Avatar(
      top: top ?? this.top,
      bottom: bottom ?? this.bottom,
      glasses: glasses ?? this.glasses,
      specials: specials ?? this.specials,
    );
  }

  @override
  String toString() {
    return "Current settings : [$top][$bottom][$glasses][$specials]";
  }
}

final class AvatarConfig {
  final List<AvatarTop> top;
  final List<AvatarBottom> bottom;
  final List<AvatarGlasses> glasses;
  final List<AvatarSpecials> specials;

  AvatarConfig({
    this.top = const <AvatarTop>[],
    this.bottom = const <AvatarBottom>[],
    this.glasses = const <AvatarGlasses>[],
    this.specials = const <AvatarSpecials>[],
  });
}

extension AvatarExtensions on List<String> {
  AvatarConfig getAvatarConfig() {
    final List<AvatarTop> top = <AvatarTop>[];
    final List<AvatarBottom> bottom = <AvatarBottom>[];
    final List<AvatarGlasses> glasses = <AvatarGlasses>[];
    final List<AvatarSpecials> specials = <AvatarSpecials>[];
    for (final String annotation in this) {
      final String str = annotation.replaceAll('[', '').replaceAll(']', '');
      final List<String> parts = str.split('.');
      if (parts.length == 2) {
        final String type = parts[0];
        final String value = parts[1];
        switch (type) {
          case 'AvatarTop':
            final AvatarTop? topAvatar =
                EnumByNameExtension.enumFromString(AvatarTop.values, value);
            if (topAvatar != null) {
             top.add(topAvatar);
            }
          case 'AvatarBottom':
            final AvatarBottom? bottomAvatar =
                EnumByNameExtension.enumFromString(AvatarBottom.values, value);
            if (bottomAvatar != null) {
              bottom.add(bottomAvatar);
            }
          case 'AvatarGlasses':
            final AvatarGlasses? glassesAvatar =
                EnumByNameExtension.enumFromString(AvatarGlasses.values, value);
            if (glassesAvatar != null) {
              glasses.add(glassesAvatar);
            }
          case 'AvatarSpecials':
            final AvatarSpecials? specialsAvatar =
                EnumByNameExtension.enumFromString(
                    AvatarSpecials.values, value,);
            if (specialsAvatar != null) {
              specials.add(specialsAvatar);
            }
        }
      }
    }
    return AvatarConfig(
      top: top,
      bottom: bottom,
      glasses: glasses,
      specials: specials,
    );
  }
}
