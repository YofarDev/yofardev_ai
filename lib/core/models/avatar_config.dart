import 'package:freezed_annotation/freezed_annotation.dart';

import 'sound_effects.dart';
import '../utils/app_utils.dart';
import '../utils/extensions.dart';
import '../utils/platform_utils.dart';
import 'chat.dart';
import 'voice_effect.dart';

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
sealed class Avatar with _$Avatar {
  const factory Avatar({
    @Default(AvatarBackgrounds.lake) AvatarBackgrounds background,
    @Default(AvatarHat.noHat) AvatarHat hat,
    @Default(AvatarTop.pinkHoodie) AvatarTop top,
    @Default(AvatarGlasses.glasses) AvatarGlasses glasses,
    @Default(AvatarSpecials.onScreen) AvatarSpecials specials,
    @Default(AvatarCostume.none) AvatarCostume costume,
  }) = _Avatar;
  const Avatar._();

  factory Avatar.fromJson(Map<String, dynamic> json) => _$AvatarFromJson(json);

  // Backward compatibility: maintain weird field mappings from Equatable version
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'background': background.name,
      'top': hat.name, // Weird: hat maps to 'top'
      'bottom': top.name, // Weird: top maps to 'bottom'
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
      top: EnumUtils.deserialize(AvatarTop.values, map['bottom'] as String),
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

  @override
  String toString() {
    return '"background": "${background.name}",\n"hat": "${hat.name}",\n"top": "${top.name}",\n"glasses": "${glasses.name}",\n"specials": "${specials.name}",\n"costume": "${costume.name}",';
  }

  bool get hideBlinkingEyes => costume == AvatarCostume.singularity;

  bool get hideBaseAvatar => costume == AvatarCostume.singularity;

  bool get hideTalkingMouth => costume == AvatarCostume.singularity;

  bool get displaySunglasses =>
      glasses == AvatarGlasses.sunglasses && costume == AvatarCostume.none;
}

@freezed
sealed class AvatarConfig with _$AvatarConfig {
  const factory AvatarConfig({
    AvatarBackgrounds? background,
    AvatarHat? hat,
    AvatarTop? top,
    AvatarGlasses? glasses,
    AvatarSpecials? specials,
    AvatarCostume? costume,
    @SoundEffectConverter() SoundEffects? soundEffect,
  }) = _AvatarConfig;
  const AvatarConfig._();

  factory AvatarConfig.fromJson(Map<String, dynamic> json) =>
      _$AvatarConfigFromJson(json);

  // Backward compatibility: fromMap for existing code
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

// Extension methods for backward compatibility
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
        return VoiceEffect(pitch: 0.5, speedRate: 0.25);
      case AvatarCostume.singularity:
        return VoiceEffect(pitch: 0.6, speedRate: 0.6);
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
          background: AvatarBackgrounds.bedroom,
          top: AvatarTop.pinkHoodie,
        );
      case ChatPersona.assistant:
        return const Avatar(
          background: AvatarBackgrounds.lake,
          top: AvatarTop.pinkHoodie,
        );
      case ChatPersona.normal:
        return const Avatar(
          background: AvatarBackgrounds.lake,
          top: AvatarTop.pinkHoodie,
        );
    }
  }
}
