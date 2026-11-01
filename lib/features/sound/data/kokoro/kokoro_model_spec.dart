/// The Kokoro model the app downloads once, and the voices it speaks with.
///
/// Kokoro-82M v1.0 int8, packaged by sherpa-onnx (k2-fsa) on GitHub
/// releases. French uses `ff_siwis` (Kokoro's only French voice) through
/// espeak-ng; English uses `af_heart` through the English lexicons.
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
  static const int sidFrench = 30; // ff_siwis

  /// espeak-ng voice for French: the whole sentence goes through espeak.
  /// Must name a voice file in `espeak-ng-data/lang/` (`fr`; `fr-fr` is not
  /// one): sherpa-onnx aborts the process on an unknown voice.
  static const String espeakFrench = 'fr';
}
