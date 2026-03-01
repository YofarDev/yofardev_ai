import 'package:freezed_annotation/freezed_annotation.dart';

part 'sound_effects.freezed.dart';
part 'sound_effects.g.dart';

// Backward compatibility: keep old enum during migration
enum SoundEffects {
  spookyTheme(path: 'assets/sounds/spooky_theme.mp3'),
  drumsRoll(path: 'assets/sounds/drums_roll.mp3'),
  crowdLaughing(path: 'assets/sounds/crowd_laughing.mp3'),
  audienceClapping(path: 'assets/sounds/audience_clapping.mp3'),
  glassBreak(path: 'assets/sounds/glass_break.mp3'),
  sadTrombone(path: 'assets/sounds/sad_trombone.mp3'),
  magicWand(path: 'assets/sounds/magic_wand.mp3'),
  frenchTheme(path: 'assets/sounds/french_theme.mp3'),
  batmanTheme(path: 'assets/sounds/batman_theme.mp3'),
  oldPhoneRingtone(path: 'assets/sounds/old_phone_ringtone.mp3'),
  policeSiren(path: 'assets/sounds/police_siren.mp3'),
  hallelujah(path: 'assets/sounds/hallelujah.mp3'),
  doorKnocking(path: 'assets/sounds/door_knocking.mp3'),
  asianTheme(path: 'assets/sounds/asian_theme.mp3'),
  robotWalking(path: 'assets/sounds/robot_walking.mp3'),
  uwu(path: 'assets/sounds/uwu.mp3'),
  christmasBells(path: 'assets/sounds/christmas_bells.mp3'),
  whoosh(path: 'assets/sounds/whoosh.mp3');

  final String path;
  const SoundEffects(this.path);

  String getPath() => path;
}

// Extension for backward compatibility
extension SoundEffectsExtension on SoundEffects {
  String getPath() => path;
}

@freezed
sealed class SoundEffect with _$SoundEffect {
  const factory SoundEffect({
    required String name,
    required String path,
    @Default(1.0) double volume,
  }) = _SoundEffect;

  factory SoundEffect.fromJson(Map<String, dynamic> json) =>
      _$SoundEffectFromJson(json);
}
