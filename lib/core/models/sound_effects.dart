import 'package:freezed_annotation/freezed_annotation.dart';

part 'sound_effects.freezed.dart';
part 'sound_effects.g.dart';

@freezed
class SoundEffect with _$SoundEffect {
  const factory SoundEffect({
    required String name,
    required String path,
    @Default(1.0) double volume,
  }) = _SoundEffect;

  factory SoundEffect.fromJson(Map<String, dynamic> json) =>
      _$SoundEffectFromJson(json);
}
