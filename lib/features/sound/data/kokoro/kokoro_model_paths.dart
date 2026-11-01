import 'package:path/path.dart' as p;

/// Absolute paths into an installed Kokoro model folder.
class KokoroModelPaths {
  const KokoroModelPaths(this.root);

  final String root;

  String get model => p.join(root, 'model.int8.onnx');
  String get voices => p.join(root, 'voices.bin');
  String get tokens => p.join(root, 'tokens.txt');

  /// The American lexicon only: `af_heart` is an American voice (with the
  /// British one too, sherpa-onnx warns about every word in both).
  String get lexicon => p.join(root, 'lexicon-us-en.txt');
  String get dataDir => p.join(root, 'espeak-ng-data');
  String get dictDir => p.join(root, 'dict');
}
