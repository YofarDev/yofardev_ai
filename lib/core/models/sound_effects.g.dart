// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sound_effects.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$SoundEffectImpl _$$SoundEffectImplFromJson(Map<String, dynamic> json) =>
    _$SoundEffectImpl(
      name: json['name'] as String,
      path: json['path'] as String,
      volume: (json['volume'] as num?)?.toDouble() ?? 1.0,
    );

Map<String, dynamic> _$$SoundEffectImplToJson(_$SoundEffectImpl instance) =>
    <String, dynamic>{
      'name': instance.name,
      'path': instance.path,
      'volume': instance.volume,
    };
