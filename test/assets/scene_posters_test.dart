import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/models/avatar_scene.dart';

/// Every scene's poster (`assets/rive/posters/<sceneId>.webp`, see
/// rive/CONTRACT.md) is bundled: the folder must be declared in pubspec.yaml
/// (a parent `assets/rive/` entry does not include subfolders).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final AvatarScene scene in AvatarScene.values) {
    test('the ${scene.name} poster is bundled', () async {
      final ByteData poster = await rootBundle.load(
        'assets/rive/posters/${scene.name}.webp',
      );
      expect(poster.lengthInBytes, greaterThan(0));
    });
  }
}
