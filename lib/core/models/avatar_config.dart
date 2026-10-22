import 'package:freezed_annotation/freezed_annotation.dart';

import 'avatar_mood.dart';
import 'avatar_scene.dart';
import 'sound_effects.dart';
import '../utils/app_utils.dart';
import '../utils/extensions.dart';
import '../utils/platform_utils.dart';
import 'chat.dart';
import 'voice_effect.dart';

part 'avatar_config.freezed.dart';
part 'avatar_config.g.dart';

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
    @Default(AvatarScene.defaultScene) AvatarScene background,
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
      background: sceneFromStoredBackground(map['background'] as String?),
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
    @SceneNameConverter() AvatarScene? background,
    AvatarHat? hat,
    AvatarTop? top,
    AvatarGlasses? glasses,
    AvatarSpecials? specials,
    AvatarCostume? costume,
    @SoundEffectConverter() SoundEffects? soundEffect,
    @MoodConverter() AvatarMood? mood,
  }) = _AvatarConfig;
  const AvatarConfig._();

  factory AvatarConfig.fromJson(Map<String, dynamic> json) =>
      _$AvatarConfigFromJson(json);

  // Backward compatibility: fromMap for existing code
  factory AvatarConfig.fromMap(Map<String, dynamic> map) {
    return AvatarConfig(
      background: maybeSceneFromStoredBackground(map['background'] as String?),
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
      mood: parseMood(map['mood']),
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

/// Validates a raw reply-JSON mood against [AvatarMood]; any non-null value
/// that is not a valid mood name falls back to [AvatarMood.neutral].
AvatarMood? parseMood(Object? raw) {
  if (raw == null) {
    return null;
  }
  if (raw is String) {
    return EnumUtils.firstOrNull(AvatarMood.values, raw) ?? AvatarMood.neutral;
  }
  return AvatarMood.neutral;
}

/// Stores/reads a scene as its name; legacy background names map when read
/// and unknown values mean "no change".
class SceneNameConverter implements JsonConverter<AvatarScene?, String?> {
  const SceneNameConverter();

  @override
  AvatarScene? fromJson(String? json) => maybeSceneFromStoredBackground(json);

  @override
  String? toJson(AvatarScene? object) {
    return object?.name;
  }
}

class MoodConverter implements JsonConverter<AvatarMood?, String?> {
  const MoodConverter();

  @override
  AvatarMood? fromJson(String? json) => parseMood(json);

  @override
  String? toJson(AvatarMood? object) {
    return object?.name;
  }
}

/// Legacy photo-background image path for a scene. Used only by the
/// PNG-era widgets that are still active before the B9 cut-over; each scene
/// id has a same-named v3 background jpeg.
extension SceneLegacyImageExtension on AvatarScene? {
  String getPath() {
    return AppUtils.fixAssetsPath(
      'assets/avatar/backgrounds/${this!.name}.jpeg',
    );
  }
}

/// The pool of scenes a new chat can be assigned at creation.
extension AvatarSceneNewChatPool on AvatarScene {
  static List<AvatarScene> get newChatPool =>
      List<AvatarScene>.unmodifiable(AvatarScene.values);

  /// Get a random scene from the new chat pool
  static AvatarScene getRandom() {
    final List<AvatarScene> pool = newChatPool;
    if (pool.isEmpty) {
      return AvatarScene.defaultScene;
    }
    return pool[DateTime.now().millisecondsSinceEpoch % pool.length];
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
          background: AvatarScene.livingRoom,
          hat: AvatarHat.frenchBeret,
          top: AvatarTop.longCoat,
        );
      case ChatPersona.psychologist:
        return const Avatar(
          background: AvatarScene.livingRoom,
          top: AvatarTop.blackSuitAndTie,
        );
      case ChatPersona.conservative:
        return const Avatar(
          background: AvatarScene.deepSpace,
          hat: AvatarHat.redMagaCap,
          top: AvatarTop.tshirt,
          glasses: AvatarGlasses.sunglasses,
        );
      case ChatPersona.coach:
        return const Avatar(
          background: AvatarScene.beach,
          hat: AvatarHat.backwardsCap,
          glasses: AvatarGlasses.sunglasses,
          top: AvatarTop.swimsuit,
        );
      case ChatPersona.doomer:
        return const Avatar(
          background: AvatarScene.livingRoom,
          top: AvatarTop.underwear,
        );
      case ChatPersona.geek:
        return const Avatar(
          background: AvatarScene.livingRoom,
          top: AvatarTop.pinkHoodie,
        );
      case ChatPersona.assistant:
        return const Avatar(
          background: AvatarScene.campfire,
          top: AvatarTop.pinkHoodie,
        );
      case ChatPersona.normal:
        return const Avatar(
          background: AvatarScene.campfire,
          top: AvatarTop.pinkHoodie,
        );
    }
  }
}
