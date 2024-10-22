import 'dart:convert';

import 'package:equatable/equatable.dart';

import '../services/tts_service.dart';
import '../utils/extensions.dart';

enum AvatarBackgrounds {
  lake,
  beach,
  forest,
  street,
  sakuraTrees,
  library,
  classroom,
  mall,
  park,
  restaurant,
  bedroom,
  livingRoom,
  campfire,
  parisianCafe,
  office,
  japaneseGarden,
  snowyMountain,
  balconyViewOfCityByNight,
  cityscrape,
  tropicalIsland,
  swimmingPool,
  hallMansion,
  facadeMansion,
  artGallery,
  cinema,
}

enum AvatarTop { noHat, beanie, backwardsCap, frenchBeret, swimCap }

enum AvatarBottom { pinkHoodie, longCoat, tshirt, underwear, swimsuit }

enum AvatarGlasses { glasses, sunglasses }

enum AvatarSpecials { onScreen, outOfScreen }

enum AvatarCostume { none, batman, robocop, soubrette }

class Avatar extends Equatable {
  final AvatarBackgrounds background;
  final AvatarTop top;
  final AvatarBottom bottom;
  final AvatarGlasses glasses;
  final AvatarSpecials specials;
  final AvatarCostume costume;
  const Avatar({
    this.background = AvatarBackgrounds.snowyMountain,
    this.top = AvatarTop.noHat,
    this.bottom = AvatarBottom.pinkHoodie,
    this.glasses = AvatarGlasses.glasses,
    this.specials = AvatarSpecials.onScreen,
    this.costume = AvatarCostume.none,
  });

  @override
  List<Object> get props {
    return <Object>[
      background,
      top,
      bottom,
      glasses,
      specials,
      costume,
    ];
  }

  Avatar copyWith({
    AvatarBackgrounds? background,
    AvatarTop? top,
    AvatarBottom? bottom,
    AvatarGlasses? glasses,
    AvatarSpecials? specials,
    AvatarCostume? costume,
  }) {
    return Avatar(
      background: background ?? this.background,
      top: top ?? this.top,
      bottom: bottom ?? this.bottom,
      glasses: glasses ?? this.glasses,
      specials: specials ?? this.specials,
      costume: costume ?? this.costume,
    );
  }

  @override
  String toString() {
    return "Current Yofardev AI settings : [$background][$top][$bottom][$glasses][$specials][$costume]";
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'background': background.name,
      'top': top.name,
      'bottom': bottom.name,
      'glasses': glasses.name,
      'specials': specials.name,
      'costume': costume.name,
    };
  }

  factory Avatar.fromMap(Map<String, dynamic> map) {
    return Avatar(
      background: EnumUtils.deserialize(
        AvatarBackgrounds.values,
        map['background'] as String,
      ),
      top: EnumUtils.deserialize(AvatarTop.values, map['top'] as String),
      bottom: EnumUtils.deserialize(
        AvatarBottom.values,
        map['bottom'] as String,
      ),
      glasses: EnumUtils.deserialize(
        AvatarGlasses.values,
        map['glasses'] as String,
      ),
      specials: EnumUtils.deserialize(
        AvatarSpecials.values,
        map['specials'] as String,
      ),
      costume: EnumUtils.deserialize(
        AvatarCostume.values,
        map['costume'] as String,
      ),
    );
  }

  String toJson() => json.encode(toMap());

  factory Avatar.fromJson(String source) =>
      Avatar.fromMap(json.decode(source) as Map<String, dynamic>);
}

class AvatarConfig extends Equatable {
  final List<AvatarBackgrounds> backgrounds;
  final List<AvatarTop> top;
  final List<AvatarBottom> bottom;
  final List<AvatarGlasses> glasses;
  final List<AvatarSpecials> specials;
  final List<AvatarCostume> costume;

  const AvatarConfig({
    this.backgrounds = const <AvatarBackgrounds>[],
    this.top = const <AvatarTop>[],
    this.bottom = const <AvatarBottom>[],
    this.glasses = const <AvatarGlasses>[],
    this.specials = const <AvatarSpecials>[],
    this.costume = const <AvatarCostume>[],
  });

  @override
  List<Object> get props {
    return <Object>[
      backgrounds,
      top,
      bottom,
      glasses,
      specials,
      costume,
    ];
  }

  AvatarConfig copyWith({
    List<AvatarBackgrounds>? backgrounds,
    List<AvatarTop>? top,
    List<AvatarBottom>? bottom,
    List<AvatarGlasses>? glasses,
    List<AvatarSpecials>? specials,
    List<AvatarCostume>? costume,
  }) {
    return AvatarConfig(
      backgrounds: backgrounds ?? this.backgrounds,
      top: top ?? this.top,
      bottom: bottom ?? this.bottom,
      glasses: glasses ?? this.glasses,
      specials: specials ?? this.specials,
      costume: costume ?? this.costume,
    );
  }
}

extension AvatarExtensions on List<String> {
  AvatarConfig getAvatarConfig() {
    final List<AvatarBackgrounds> backgrounds = <AvatarBackgrounds>[];
    final List<AvatarTop> top = <AvatarTop>[];
    final List<AvatarBottom> bottom = <AvatarBottom>[];
    final List<AvatarGlasses> glasses = <AvatarGlasses>[];
    final List<AvatarSpecials> specials = <AvatarSpecials>[];
    final List<AvatarCostume> costume = <AvatarCostume>[];
    for (final String annotation in this) {
      final String str = annotation.replaceAll('[', '').replaceAll(']', '');
      final List<String> parts = str.split('.');
      if (parts.length == 2) {
        final String type = parts[0];
        final String value = parts[1];
        switch (type) {
          case 'AvatarBackgrounds':
            final AvatarBackgrounds? background =
                EnumByNameExtension.enumFromString(
              AvatarBackgrounds.values,
              value,
            );
            if (background != null) {
              backgrounds.add(background);
            }
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
              AvatarSpecials.values,
              value,
            );
            if (specialsAvatar != null) {
              specials.add(specialsAvatar);
            }
          case 'AvatarCostume':
            final AvatarCostume? costumeAvatar =
                EnumByNameExtension.enumFromString(
              AvatarCostume.values,
              value,
            );
            if (costumeAvatar != null) {
              costume.add(costumeAvatar);
            }
        }
      }
    }
    return AvatarConfig(
      backgrounds: backgrounds,
      top: top,
      bottom: bottom,
      glasses: glasses,
      specials: specials,
      costume: costume,
    );
  }
}

// EXTENSIONS

extension BgImagesExtension on AvatarBackgrounds? {
  String getPath() {
    return 'assets/avatar/backgrounds/${this!.name}.jpeg';
  }
}

extension CostumeExtension on AvatarCostume {
  VoiceEffect getVoiceEffect() {
    switch (this) {
      case AvatarCostume.batman:
        return VoiceEffect(
          pitch: 0.7,
          speedRate: 0.4,
        );
      case AvatarCostume.robocop:
        return VoiceEffect(
          pitch: 0.5,
          speedRate: 0.25,
        );
      default:
        return VoiceEffect(
          pitch: 1,
          speedRate: 0.5,
        );
    }
  }
}
