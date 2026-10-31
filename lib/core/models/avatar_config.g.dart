// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'avatar_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Avatar _$AvatarFromJson(Map<String, dynamic> json) => _Avatar(
  background:
      $enumDecodeNullable(_$AvatarSceneEnumMap, json['background']) ??
      AvatarScene.defaultScene,
  hat: $enumDecodeNullable(_$AvatarHatEnumMap, json['hat']) ?? AvatarHat.noHat,
  top:
      $enumDecodeNullable(_$AvatarTopEnumMap, json['top']) ??
      AvatarTop.pinkHoodie,
  glasses:
      $enumDecodeNullable(_$AvatarGlassesEnumMap, json['glasses']) ??
      AvatarGlasses.glasses,
  specials:
      $enumDecodeNullable(_$AvatarSpecialsEnumMap, json['specials']) ??
      AvatarSpecials.onScreen,
  costume:
      $enumDecodeNullable(_$AvatarCostumeEnumMap, json['costume']) ??
      AvatarCostume.none,
  topTint:
      $enumDecodeNullable(
        _$AvatarTintEnumMap,
        json['topTint'],
        unknownValue: AvatarTint.none,
      ) ??
      AvatarTint.none,
  hatTint:
      $enumDecodeNullable(
        _$AvatarTintEnumMap,
        json['hatTint'],
        unknownValue: AvatarTint.none,
      ) ??
      AvatarTint.none,
);

Map<String, dynamic> _$AvatarToJson(_Avatar instance) => <String, dynamic>{
  'background': _$AvatarSceneEnumMap[instance.background]!,
  'hat': _$AvatarHatEnumMap[instance.hat]!,
  'top': _$AvatarTopEnumMap[instance.top]!,
  'glasses': _$AvatarGlassesEnumMap[instance.glasses]!,
  'specials': _$AvatarSpecialsEnumMap[instance.specials]!,
  'costume': _$AvatarCostumeEnumMap[instance.costume]!,
  'topTint': _$AvatarTintEnumMap[instance.topTint]!,
  'hatTint': _$AvatarTintEnumMap[instance.hatTint]!,
};

const _$AvatarSceneEnumMap = {
  AvatarScene.livingRoom: 'livingRoom',
  AvatarScene.campfire: 'campfire',
  AvatarScene.beach: 'beach',
  AvatarScene.deepSpace: 'deepSpace',
  AvatarScene.cafe: 'cafe',
  AvatarScene.rooftop: 'rooftop',
  AvatarScene.mountainHut: 'mountainHut',
  AvatarScene.forestCabin: 'forestCabin',
  AvatarScene.trainCompartment: 'trainCompartment',
  AvatarScene.library: 'library',
};

const _$AvatarHatEnumMap = {
  AvatarHat.noHat: 'noHat',
  AvatarHat.beanie: 'beanie',
  AvatarHat.backwardsCap: 'backwardsCap',
  AvatarHat.frenchBeret: 'frenchBeret',
  AvatarHat.swimCap: 'swimCap',
  AvatarHat.santaHat: 'santaHat',
  AvatarHat.redMagaCap: 'redMagaCap',
};

const _$AvatarTopEnumMap = {
  AvatarTop.pinkHoodie: 'pinkHoodie',
  AvatarTop.longCoat: 'longCoat',
  AvatarTop.tshirt: 'tshirt',
  AvatarTop.underwear: 'underwear',
  AvatarTop.swimsuit: 'swimsuit',
  AvatarTop.christmasSweater: 'christmasSweater',
  AvatarTop.blackSuitAndTie: 'blackSuitAndTie',
};

const _$AvatarGlassesEnumMap = {
  AvatarGlasses.glasses: 'glasses',
  AvatarGlasses.sunglasses: 'sunglasses',
};

const _$AvatarSpecialsEnumMap = {
  AvatarSpecials.onScreen: 'onScreen',
  AvatarSpecials.outOfScreen: 'outOfScreen',
  AvatarSpecials.leaveAndComeBack: 'leaveAndComeBack',
};

const _$AvatarCostumeEnumMap = {
  AvatarCostume.none: 'none',
  AvatarCostume.batman: 'batman',
  AvatarCostume.robocop: 'robocop',
  AvatarCostume.soubrette: 'soubrette',
  AvatarCostume.singularity: 'singularity',
};

const _$AvatarTintEnumMap = {
  AvatarTint.none: 'none',
  AvatarTint.red: 'red',
  AvatarTint.orange: 'orange',
  AvatarTint.yellow: 'yellow',
  AvatarTint.green: 'green',
  AvatarTint.teal: 'teal',
  AvatarTint.blue: 'blue',
  AvatarTint.purple: 'purple',
  AvatarTint.pink: 'pink',
  AvatarTint.grey: 'grey',
};

_AvatarConfig _$AvatarConfigFromJson(Map<String, dynamic> json) =>
    _AvatarConfig(
      background: const SceneNameConverter().fromJson(
        json['background'] as String?,
      ),
      hat: $enumDecodeNullable(_$AvatarHatEnumMap, json['hat']),
      top: $enumDecodeNullable(_$AvatarTopEnumMap, json['top']),
      glasses: $enumDecodeNullable(_$AvatarGlassesEnumMap, json['glasses']),
      specials: $enumDecodeNullable(_$AvatarSpecialsEnumMap, json['specials']),
      costume: $enumDecodeNullable(_$AvatarCostumeEnumMap, json['costume']),
      topTint: $enumDecodeNullable(
        _$AvatarTintEnumMap,
        json['topTint'],
        unknownValue: JsonKey.nullForUndefinedEnumValue,
      ),
      hatTint: $enumDecodeNullable(
        _$AvatarTintEnumMap,
        json['hatTint'],
        unknownValue: JsonKey.nullForUndefinedEnumValue,
      ),
      soundEffect: const SoundEffectConverter().fromJson(
        json['soundEffect'] as String?,
      ),
      mood: const MoodConverter().fromJson(json['mood'] as String?),
    );

Map<String, dynamic> _$AvatarConfigToJson(_AvatarConfig instance) =>
    <String, dynamic>{
      'background': const SceneNameConverter().toJson(instance.background),
      'hat': _$AvatarHatEnumMap[instance.hat],
      'top': _$AvatarTopEnumMap[instance.top],
      'glasses': _$AvatarGlassesEnumMap[instance.glasses],
      'specials': _$AvatarSpecialsEnumMap[instance.specials],
      'costume': _$AvatarCostumeEnumMap[instance.costume],
      'topTint': _$AvatarTintEnumMap[instance.topTint],
      'hatTint': _$AvatarTintEnumMap[instance.hatTint],
      'soundEffect': const SoundEffectConverter().toJson(instance.soundEffect),
      'mood': const MoodConverter().toJson(instance.mood),
    };
