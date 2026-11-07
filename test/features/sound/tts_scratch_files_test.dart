import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/features/sound/data/datasources/tts_scratch_files.dart';

void main() {
  group('TtsScratchFiles.delete', () {
    late Directory tempDir;

    setUp(
      () => tempDir = Directory.systemTemp.createTempSync('tts_scratch_test'),
    );

    tearDown(() => tempDir.deleteSync(recursive: true));

    File touch(String name) =>
        File('${tempDir.path}/$name')..writeAsBytesSync(<int>[1]);

    test('a played voice-effect copy takes its dry WAV with it', () async {
      final File dry = touch('1730000000000.wav');
      final File processed = touch('1730000000000_fx.wav');

      await TtsScratchFiles.delete(processed.path);

      expect(processed.existsSync(), isFalse);
      expect(dry.existsSync(), isFalse);
    });

    test('a voice-effect copy whose dry WAV is gone still goes', () async {
      final File processed = touch('1730000000000_fx.wav');

      await TtsScratchFiles.delete(processed.path);

      expect(processed.existsSync(), isFalse);
    });

    test('a plain WAV goes alone', () async {
      final File played = touch('1730000000000.wav');
      final File other = touch('1730000000001.wav');

      await TtsScratchFiles.delete(played.path);

      expect(played.existsSync(), isFalse);
      expect(other.existsSync(), isTrue);
    });
  });
}
