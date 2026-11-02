import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:yofardev_ai/features/sound/data/kokoro/kokoro_model_paths.dart';
import 'package:yofardev_ai/features/sound/data/kokoro/kokoro_model_spec.dart';
import 'package:yofardev_ai/features/sound/data/kokoro/voice_blender.dart';

void main() {
  const int slotCount = 6;
  const int slotFloats = 4;
  const KokoroVoiceBlender subject = KokoroVoiceBlender(
    slot: 4,
    sources: <int, double>{1: 0.25, 2: 0.75},
    slotCount: slotCount,
    slotFloats: slotFloats,
  );

  late Directory root;
  late KokoroModelPaths paths;

  Float32List slot(int index) {
    final Uint8List bytes = File(paths.voices).readAsBytesSync();
    return Float32List.sublistView(
      bytes,
      index * slotFloats * 4,
      (index + 1) * slotFloats * 4,
    );
  }

  setUp(() {
    root = Directory.systemTemp.createTempSync('voice_blender_test');
    paths = KokoroModelPaths(root.path);
    // Slot n holds n, n+0.5, n+1, n+1.5.
    final Float32List voices = Float32List(slotCount * slotFloats);
    for (int s = 0; s < slotCount; s++) {
      for (int i = 0; i < slotFloats; i++) {
        voices[s * slotFloats + i] = s + i * 0.5;
      }
    }
    File(paths.voices).writeAsBytesSync(voices.buffer.asUint8List());
  });

  tearDown(() => root.deleteSync(recursive: true));

  test(
    'writes the weighted average into the slot, sources untouched',
    () async {
      await subject.apply(paths);

      final Float32List blend = slot(4);
      for (int i = 0; i < slotFloats; i++) {
        expect(
          blend[i],
          closeTo(0.25 * (1 + i * 0.5) + 0.75 * (2 + i * 0.5), 1e-6),
        );
      }
      expect(slot(1), <double>[1, 1.5, 2, 2.5]);
      expect(slot(2), <double>[2, 2.5, 3, 3.5]);
      expect(slot(5), <double>[5, 5.5, 6, 6.5]);
      expect(
        File(paths.voices).lengthSync(),
        slotCount * slotFloats * Float32List.bytesPerElement,
      );
    },
  );

  test('a second run changes nothing (marker)', () async {
    await subject.apply(paths);
    final List<int> first = File(paths.voices).readAsBytesSync();
    // Mutating the slot would show if it were rewritten.
    final RandomAccessFile file = File(
      paths.voices,
    ).openSync(mode: FileMode.append);
    file.setPositionSync(4 * slotFloats * 4);
    file.writeFromSync(Uint8List(4));
    file.closeSync();

    await subject.apply(paths);

    expect(File(paths.voices).readAsBytesSync()[4 * slotFloats * 4], 0);
    expect(File(paths.voices).readAsBytesSync(), isNot(first));
  });

  test('a changed recipe is applied again', () async {
    await subject.apply(paths);
    const KokoroVoiceBlender other = KokoroVoiceBlender(
      slot: 4,
      sources: <int, double>{1: 1},
      slotCount: slotCount,
      slotFloats: slotFloats,
    );

    await other.apply(paths);

    expect(slot(4), <double>[1, 1.5, 2, 2.5]);
  });

  test('a voices.bin of the wrong size is refused and left unmarked', () async {
    File(paths.voices).writeAsBytesSync(Uint8List(100));

    await expectLater(
      subject.apply(paths),
      throwsA(isA<FileSystemException>()),
    );
    expect(File(p.join(root.path, '.voice-blend')).existsSync(), isFalse);
  });

  test('the shipped recipe: sources sum to 1, slot is the French sid', () {
    expect(
      KokoroModelSpec.voiceBlendSources.values.reduce(
        (double a, double b) => a + b,
      ),
      closeTo(1, 1e-9),
    );
    expect(KokoroModelSpec.sidFrench, KokoroModelSpec.voiceBlendSlot);
    expect(
      KokoroModelSpec.voiceBlendSources.keys,
      isNot(contains(KokoroModelSpec.voiceBlendSlot)),
    );
    expect(
      KokoroModelSpec.voiceBlendSlot,
      lessThan(KokoroModelSpec.voiceCount),
    );
  });
}
