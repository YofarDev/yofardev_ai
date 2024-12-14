import '../utils/app_utils.dart';

enum SoundEffects {
  spookyTheme,
  drumsRoll,
  crowdLaughing,
  audienceClapping,
  glassBreak,
  sadTrombone,
  magicWand,
  frenchTheme,
  batmanTheme,
  oldPhoneRingtone,
  policeSiren,
  hallelujah,
  doorKnocking,
  asianTheme,
  robotWalking,
  uwu,
  christmasBells,
}

extension SoundEffectsStrExtension on String {
  SoundEffects? getSoundEffectFromString() {
    final String enumString = 
        split('.')
        .last
        .replaceAll('[', '')
        .replaceAll(']', '');
    try {
      return SoundEffects.values.firstWhere(
        (SoundEffects e) => e.toString().split('.').last == enumString,
      );
    } catch (e) {
      return null;
    }
  }
}

extension SoundEffectsExtension on SoundEffects {
  String getPath() {
    return AppUtils.fixAssetsPath('assets/sound_effects/$name.wav');
  }
}
