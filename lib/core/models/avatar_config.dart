import 'package:freezed_annotation/freezed_annotation.dart';

import '../../models/sound_effects.dart';
import '../../utils/extensions.dart';

part 'avatar_config.freezed.dart';
part 'avatar_config.g.dart';

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

@freezed
class Avatar with _$Avatar {
  const Avatar._();

  const factory Avatar({
    @Default(AvatarBackgrounds.lake) AvatarBackgrounds background,
    @Default(AvatarHat.noHat) AvatarHat hat,
    @Default(AvatarTop.pinkHoodie) AvatarTop top,
    @Default(AvatarGlasses.glasses) AvatarGlasses glasses,
    @Default(AvatarSpecials.onScreen) AvatarSpecials specials,
    @Default(AvatarCostume.none) AvatarCostume costume,
  }) = _Avatar;

  factory Avatar.fromJson(Map<String, dynamic> json) =>
      _$AvatarFromJson(json);

  bool get hideBlinkingEyes => costume == AvatarCostume.singularity;

  bool get hideBaseAvatar => costume == AvatarCostume.singularity;

  bool get hideTalkingMouth => costume == AvatarCostume.singularity;

  bool get displaySunglasses =>
      glasses == AvatarGlasses.sunglasses && costume == AvatarCostume.none;
}

@freezed
class AvatarConfig with _$AvatarConfig {
  const AvatarConfig._();

  const factory AvatarConfig({
    AvatarBackgrounds? background,
    AvatarHat? hat,
    AvatarTop? top,
    AvatarGlasses? glasses,
    AvatarSpecials? specials,
    AvatarCostume? costume,
    @SoundEffectConverter() SoundEffects? soundEffect,
  }) = _AvatarConfig;

  factory AvatarConfig.fromJson(Map<String, dynamic> json) =>
      _$AvatarConfigFromJson(json);
}

class SoundEffectConverter implements JsonConverter<SoundEffects?, String?> {
  const SoundEffectConverter();

  @override
  SoundEffects? fromJson(String? json) {
    if (json == null) return null;
    return EnumUtils.firstOrNull(SoundEffects.values, json);
  }

  @override
  String? toJson(SoundEffects? object) {
    return object?.name;
  }
}
