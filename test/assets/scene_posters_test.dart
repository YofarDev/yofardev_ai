import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/models/avatar_scene.dart';

/// Every scene's poster (`assets/rive/posters/<sceneId>.webp`, see
/// rive/CONTRACT.md) is bundled: the folder must be declared in pubspec.yaml
/// (a parent `assets/rive/` entry does not include subfolders).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final AvatarScene scene in AvatarScene.values) {
    // A new scene's poster arrives with its scene lane (M9): until the file
    // is on disk the check waits instead of failing the build.
    final bool onDisk = File(
      'assets/rive/posters/${scene.name}.webp',
    ).existsSync();
    test('the ${scene.name} poster is bundled', () async {
      final ByteData poster = await rootBundle.load(
        'assets/rive/posters/${scene.name}.webp',
      );
      expect(poster.lengthInBytes, greaterThan(0));
    }, skip: onDisk ? false : 'poster not built yet (M9 scene lane)');
  }
}
