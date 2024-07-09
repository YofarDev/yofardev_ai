enum SoundEffects {
  spookyTheme,
  drumsRoll,
  crowdLaughing,
  audienceClapping,
  glassBreak,
  sadTrombone,
  magicWand,
}

SoundEffects? getSoundEffectFromString(String soundEffectString) {
  final String enumString =
      soundEffectString.split('.').last.replaceAll('[', '').replaceAll(']', '');
  try {
    return SoundEffects.values.firstWhere(
      (SoundEffects e) => e.toString().split('.').last == enumString,
    );
  } catch (e) {
    return null;
  }
}

extension SoundEffectsExtension on SoundEffects {
  String getPath() {
    return 'assets/sound_effects/$name.wav';
  }
}
