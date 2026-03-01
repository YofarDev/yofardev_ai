import 'package:freezed_annotation/freezed_annotation.dart';

part 'sound_effects.freezed.dart';
part 'sound_effects.g.dart';

// Backward compatibility: keep old enum during migration
enum SoundEffects {
  spookyTheme('assets/sounds/spooky_theme.mp3'),
  drumsRoll('assets/sounds/drums_roll.mp3'),
  crowdLaughing('assets/sounds/crowd_laughing.mp3'),
  audienceClapping('assets/sounds/audience_clapping.mp3'),
  glassBreak('assets/sounds/glass_break.mp3'),
  sadTrombone('assets/sounds/sad_trombone.mp3'),
  magicWand('assets/sounds/magic_wand.mp3'),
  frenchTheme('assets/sounds/french_theme.mp3'),
  batmanTheme('assets/sounds/batman_theme.mp3'),
  oldPhoneRingtone('assets/sounds/old_phone_ringtone.mp3'),
  policeSiren('assets/sounds/police_siren.mp3'),
  hallelujah('assets/sounds/hallelujah.mp3'),
  doorKnocking('assets/sounds/door_knocking.mp3'),
  asianTheme('assets/sounds/asian_theme.mp3'),
  robotWalking('assets/sounds/robot_walking.mp3'),
  uwu('assets/sounds/uwu.mp3'),
  christmasBells('assets/sounds/christmas_bells.mp3'),
  whoosh('assets/sounds/whoosh.mp3');

  final String path;
  const SoundEffects(this.path);

  String getPath() => path;

  /// Convert string to SoundEffects enum
  static SoundEffects? fromString(String value) {
    try {
      return SoundEffects.values.firstWhere(
        (SoundEffects e) => e.name == value,
      );
    } catch (_) {
      return null;
    }
  }
}

// Extension on String for backward compatibility
extension SoundEffectsStringExtension on String {
  SoundEffects? getSoundEffectFromString() => SoundEffects.fromString(this);
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
