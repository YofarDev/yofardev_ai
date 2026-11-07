import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/models/avatar_config.dart';
import 'package:yofardev_ai/core/models/voice_effect.dart';

void main() {
  group('CostumeExtension.voiceEffect', () {
    const Map<AvatarCostume, VoiceEffect> expected =
        <AvatarCostume, VoiceEffect>{
          AvatarCostume.none: VoiceEffect.none,
          AvatarCostume.batman: VoiceEffect.batman,
          AvatarCostume.robocop: VoiceEffect.robocop,
          AvatarCostume.soubrette: VoiceEffect.none,
          AvatarCostume.singularity: VoiceEffect.none,
        };

    for (final MapEntry<AvatarCostume, VoiceEffect> entry in expected.entries) {
      test('${entry.key.name} speaks with ${entry.value.name}', () {
        expect(entry.key.voiceEffect, entry.value);
      });
    }
  });
}
