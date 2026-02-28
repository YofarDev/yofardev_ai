// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'avatar_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$AvatarImpl _$$AvatarImplFromJson(Map<String, dynamic> json) => _$AvatarImpl(
  background:
      $enumDecodeNullable(_$AvatarBackgroundsEnumMap, json['background']) ??
      AvatarBackgrounds.lake,
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
);

Map<String, dynamic> _$$AvatarImplToJson(_$AvatarImpl instance) =>
    <String, dynamic>{
      'background': _$AvatarBackgroundsEnumMap[instance.background]!,
      'hat': _$AvatarHatEnumMap[instance.hat]!,
      'top': _$AvatarTopEnumMap[instance.top]!,
      'glasses': _$AvatarGlassesEnumMap[instance.glasses]!,
      'specials': _$AvatarSpecialsEnumMap[instance.specials]!,
      'costume': _$AvatarCostumeEnumMap[instance.costume]!,
    };

const _$AvatarBackgroundsEnumMap = {
  AvatarBackgrounds.lake: 'lake',
  AvatarBackgrounds.beach: 'beach',
  AvatarBackgrounds.forest: 'forest',
  AvatarBackgrounds.street: 'street',
  AvatarBackgrounds.sakuraTrees: 'sakuraTrees',
  AvatarBackgrounds.library: 'library',
  AvatarBackgrounds.classroom: 'classroom',
  AvatarBackgrounds.mall: 'mall',
  AvatarBackgrounds.park: 'park',
  AvatarBackgrounds.restaurant: 'restaurant',
  AvatarBackgrounds.bedroom: 'bedroom',
  AvatarBackgrounds.livingRoom: 'livingRoom',
  AvatarBackgrounds.campfire: 'campfire',
  AvatarBackgrounds.parisianCafe: 'parisianCafe',
  AvatarBackgrounds.office: 'office',
  AvatarBackgrounds.japaneseGarden: 'japaneseGarden',
  AvatarBackgrounds.snowyMountain: 'snowyMountain',
  AvatarBackgrounds.balconyViewOfCityByNight: 'balconyViewOfCityByNight',
  AvatarBackgrounds.cityscrape: 'cityscrape',
  AvatarBackgrounds.tropicalIsland: 'tropicalIsland',
  AvatarBackgrounds.swimmingPool: 'swimmingPool',
  AvatarBackgrounds.hallMansion: 'hallMansion',
  AvatarBackgrounds.facadeMansion: 'facadeMansion',
  AvatarBackgrounds.artGallery: 'artGallery',
  AvatarBackgrounds.cinema: 'cinema',
  AvatarBackgrounds.deepSpace: 'deepSpace',
  AvatarBackgrounds.christmasLivingRoom: 'christmasLivingRoom',
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

_$AvatarConfigImpl _$$AvatarConfigImplFromJson(Map<String, dynamic> json) =>
    _$AvatarConfigImpl(
      background: $enumDecodeNullable(
        _$AvatarBackgroundsEnumMap,
        json['background'],
      ),
      hat: $enumDecodeNullable(_$AvatarHatEnumMap, json['hat']),
      top: $enumDecodeNullable(_$AvatarTopEnumMap, json['top']),
      glasses: $enumDecodeNullable(_$AvatarGlassesEnumMap, json['glasses']),
      specials: $enumDecodeNullable(_$AvatarSpecialsEnumMap, json['specials']),
      costume: $enumDecodeNullable(_$AvatarCostumeEnumMap, json['costume']),
      soundEffect: const SoundEffectConverter().fromJson(
        json['soundEffect'] as String?,
      ),
    );

Map<String, dynamic> _$$AvatarConfigImplToJson(_$AvatarConfigImpl instance) =>
    <String, dynamic>{
      'background': _$AvatarBackgroundsEnumMap[instance.background],
      'hat': _$AvatarHatEnumMap[instance.hat],
      'top': _$AvatarTopEnumMap[instance.top],
      'glasses': _$AvatarGlassesEnumMap[instance.glasses],
      'specials': _$AvatarSpecialsEnumMap[instance.specials],
      'costume': _$AvatarCostumeEnumMap[instance.costume],
      'soundEffect': const SoundEffectConverter().toJson(instance.soundEffect),
    };
