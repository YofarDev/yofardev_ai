import 'dart:convert';

import 'package:equatable/equatable.dart';

import '../services/tts_service.dart';
import '../utils/app_utils.dart';
import '../utils/extensions.dart';
import '../utils/platform_utils.dart';
import 'chat.dart';
import 'sound_effects.dart';

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
  deepSpace,
  christmasLivingRoom,
}

enum AvatarHat {
  noHat,
  beanie,
  backwardsCap,
  frenchBeret,
  swimCap,
  santaHat,
  redMagaCap,
}

enum AvatarTop {
  pinkHoodie,
  longCoat,
  tshirt,
  underwear,
  swimsuit,
  christmasSweater,
  blackSuitAndTie,
}

enum AvatarGlasses { glasses, sunglasses }

enum AvatarSpecials { onScreen, outOfScreen, leaveAndComeBack }

enum AvatarCostume { none, batman, robocop, soubrette, singularity }

class Avatar extends Equatable {
  final AvatarBackgrounds background;
  final AvatarHat hat;
  final AvatarTop top;
  final AvatarGlasses glasses;
  final AvatarSpecials specials;
  final AvatarCostume costume;
  const Avatar({
    this.background = AvatarBackgrounds.lake,
    this.hat = AvatarHat.noHat,
    this.top = AvatarTop.pinkHoodie,
    this.glasses = AvatarGlasses.glasses,
    this.specials = AvatarSpecials.onScreen,
    this.costume = AvatarCostume.none,
  });

  @override
  List<Object> get props {
    return <Object>[
      background,
      hat,
      top,
      glasses,
      specials,
      costume,
    ];
  }

  Avatar copyWith({
    AvatarBackgrounds? background,
    AvatarHat? hat,
    AvatarTop? top,
    AvatarGlasses? glasses,
    AvatarSpecials? specials,
    AvatarCostume? costume,
  }) {
    return Avatar(
      background: background ?? this.background,
      hat: hat ?? this.hat,
      top: top ?? this.top,
      glasses: glasses ?? this.glasses,
      specials: specials ?? this.specials,
      costume: costume ?? this.costume,
    );
  }

  @override
  String toString() {
    return '"background": "${background.name}",\n"hat": "${hat.name}",\n"top": "${top.name}",\n"glasses": "${glasses.name}",\n"specials": "${specials.name}",\n"costume": "${costume.name}",';
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'background': background.name,
      'top': hat.name,
      'bottom': top.name,
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
      hat: EnumUtils.deserialize(AvatarHat.values, map['top'] as String),
      top: EnumUtils.deserialize(
        AvatarTop.values,
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

  bool get hideBlinkingEyes => costume == AvatarCostume.singularity;

  bool get hideBaseAvatar => costume == AvatarCostume.singularity;

  bool get hideTalkingMouth => costume == AvatarCostume.singularity;

  bool get displaySunglasses =>
      glasses == AvatarGlasses.sunglasses && costume == AvatarCostume.none;
}

class AvatarConfig extends Equatable {
  final AvatarBackgrounds? background;
  final AvatarHat? hat;
  final AvatarTop? top;
  final AvatarGlasses? glasses;
  final AvatarSpecials? specials;
  final AvatarCostume? costume;
  final SoundEffects? soundEffect;

  const AvatarConfig({
    this.background,
    this.hat,
    this.top,
    this.glasses,
    this.specials,
    this.costume,
    this.soundEffect,
  });

  factory AvatarConfig.fromMap(Map<String, dynamic> map) {
    return AvatarConfig(
      background: map['background'] != null
          ? EnumUtils.firstOrNull(
              AvatarBackgrounds.values,
              map['background'] as String,
            )
          : null,
      hat: map['hat'] != null
          ? EnumUtils.firstOrNull(AvatarHat.values, map['hat'] as String)
          : null,
      top: map['top'] != null
          ? EnumUtils.firstOrNull(AvatarTop.values, map['top'] as String)
          : null,
      glasses: map['glasses'] != null
          ? EnumUtils.firstOrNull(
              AvatarGlasses.values,
              map['glasses'] as String,
            )
          : null,
      specials: map['specials'] != null
          ? EnumUtils.firstOrNull(
              AvatarSpecials.values,
              map['specials'] as String,
            )
          : null,
      costume: map['costume'] != null
          ? EnumUtils.firstOrNull(
              AvatarCostume.values,
              map['costume'] as String,
            )
          : null,
      soundEffect: map['soundEffect'] != null
          ? EnumUtils.firstOrNull(
              SoundEffects.values,
              map['soundEffect'] as String,
            )
          : null,
    );
  }

  @override
  List<Object?> get props {
    return <Object?>[
      background,
      hat,
      top,
      glasses,
      specials,
      costume,
      soundEffect,
    ];
  }

  AvatarConfig copyWith({
    AvatarBackgrounds? background,
    AvatarHat? hat,
    AvatarTop? top,
    AvatarGlasses? glasses,
    AvatarSpecials? specials,
    AvatarCostume? costume,
    SoundEffects? soundEffect,
  }) {
    return AvatarConfig(
      background: background ?? this.background,
      hat: hat ?? this.hat,
      top: top ?? this.top,
      glasses: glasses ?? this.glasses,
      specials: specials ?? this.specials,
      costume: costume ?? this.costume,
      soundEffect: soundEffect ?? this.soundEffect,
    );
  }
}

// EXTENSIONS

extension BgImagesExtension on AvatarBackgrounds? {
  String getPath() {
    return AppUtils.fixAssetsPath(
      'assets/avatar/backgrounds/${this!.name}.jpeg',
    );
  }
}

extension CostumeExtension on AvatarCostume {
  VoiceEffect getVoiceEffect() {
    switch (this) {
      case AvatarCostume.batman:
        return VoiceEffect(
          pitch: PlatformUtils.checkPlatform() == 'Web' ? 0.1 : 0.7,
          speedRate: 0.4,
        );
      case AvatarCostume.robocop:
        return VoiceEffect(
          pitch: 0.5,
          speedRate: 0.25,
        );
      case AvatarCostume.singularity:
        return VoiceEffect(
          pitch: 0.6,
          speedRate: 0.6,
        );
      default:
        return VoiceEffect(
          pitch: 1,
          speedRate: PlatformUtils.checkPlatform() == 'Web' ? 1 : 0.5,
        );
    }
  }
}

extension ChatPersonaAvatar on ChatPersona {
  Avatar getDefaultAvatar() {
    switch (this) {
      case ChatPersona.philosopher:
        return const Avatar(
          background: AvatarBackgrounds.artGallery,
          hat: AvatarHat.frenchBeret,
          top: AvatarTop.longCoat,
        );
      case ChatPersona.psychologist:
        return const Avatar(
          background: AvatarBackgrounds.library,
          top: AvatarTop.blackSuitAndTie,
        );
      case ChatPersona.conservative:
        return const Avatar(
          background: AvatarBackgrounds.mall,
          hat: AvatarHat.redMagaCap,
          top: AvatarTop.tshirt,
          glasses: AvatarGlasses.sunglasses,
        );
      case ChatPersona.coach:
        return const Avatar(
          background: AvatarBackgrounds.swimmingPool,
          hat: AvatarHat.backwardsCap,
          glasses: AvatarGlasses.sunglasses,
          top: AvatarTop.swimsuit,
        );
      case ChatPersona.doomer:
        return const Avatar(
          background: AvatarBackgrounds.bedroom,
          top: AvatarTop.underwear,
        );
      case ChatPersona.geek:
        return const Avatar(
          background: AvatarBackgrounds.office,
          top: AvatarTop.christmasSweater,
        );
      default:
        final AvatarBackgrounds randomBg =
            EnumUtils.getRandomValue(AvatarBackgrounds.values);
        return Avatar(background: randomBg);
    }
  }
}
