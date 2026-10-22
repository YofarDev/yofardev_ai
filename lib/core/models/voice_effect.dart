/// Voice effect configuration for TTS
class VoiceEffect {
  final double pitch;
  final double speedRate;

  const VoiceEffect({required this.pitch, required this.speedRate});

  VoiceEffect copyWith({double? pitch, double? speedRate}) {
    return VoiceEffect(
      pitch: pitch ?? this.pitch,
      speedRate: speedRate ?? this.speedRate,
    );
  }

  @override
  String toString() => 'VoiceEffect(pitch: $pitch, speedRate: $speedRate)';
}
