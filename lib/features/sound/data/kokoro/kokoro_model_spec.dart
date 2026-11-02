/// The Kokoro model the app downloads once, and the voices it speaks with.
///
/// Kokoro-82M v1.0 int8, packaged by sherpa-onnx (k2-fsa) on GitHub
/// releases. English uses `af_heart` through the English lexicons. French
/// has one voice in Kokoro (`ff_siwis`, female); the app speaks it with a
/// blend of `ff_siwis` and the male `im_nicola` style (see
/// [voiceBlendSources]), through espeak-ng.
abstract final class KokoroModelSpec {
  static const String modelId = 'kokoro-int8-multi-lang-v1_0';
  static const String downloadUrl =
      'https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/'
      'kokoro-int8-multi-lang-v1_0.tar.bz2';

  /// Compressed archive size (bytes), shown before and during the download.
  static const int downloadBytes = 132353410;

  /// Files and folders that must exist after extraction.
  static const List<String> requiredPaths = <String>[
    'model.int8.onnx',
    'voices.bin',
    'tokens.txt',
    'lexicon-us-en.txt',
    'espeak-ng-data',
  ];

  /// Speaker ids in `voices.bin` (order fixed by sherpa-onnx's
  /// `scripts/kokoro/v1.0/generate_voices_bin.py`).
  static const int sidEnglish = 3; // af_heart
  static const int sidFrench = voiceBlendSlot;

  /// Slots in `voices.bin` (sherpa-onnx's metadata says 54; the Chinese
  /// males 49-52 are unused by the app, so one is repurposed).
  static const int voiceCount = 54;

  /// Floats per speaker: 510 style rows of 256.
  static const int voiceFloats = 510 * 256;

  /// The French voice lives in this slot (was `zm_yunxi`, unused): a
  /// weighted average of the style tensors in [voiceBlendSources]. 30 %
  /// `ff_siwis` keeps the French prosody, 70 % `im_nicola` (male Italian)
  /// brings the pitch down to a ~125 Hz median (`ff_siwis` alone: ~204 Hz).
  static const int voiceBlendSlot = 50;

  /// Source slot → weight (weights sum to 1): `ff_siwis` 30, `im_nicola` 36.
  static const Map<int, double> voiceBlendSources = <int, double>{
    30: 0.3,
    36: 0.7,
  };

  /// espeak-ng voice for French: the whole sentence goes through espeak.
  /// Must name a voice file in `espeak-ng-data/lang/` (`fr`; `fr-fr` is not
  /// one): sherpa-onnx aborts the process on an unknown voice.
  static const String espeakFrench = 'fr';
}
