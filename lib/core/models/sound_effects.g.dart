// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sound_effects.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SoundEffect _$SoundEffectFromJson(Map<String, dynamic> json) => _SoundEffect(
  name: json['name'] as String,
  path: json['path'] as String,
  volume: (json['volume'] as num?)?.toDouble() ?? 1.0,
);

Map<String, dynamic> _$SoundEffectToJson(_SoundEffect instance) =>
    <String, dynamic>{
      'name': instance.name,
      'path': instance.path,
      'volume': instance.volume,
    };
