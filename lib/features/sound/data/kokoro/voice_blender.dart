import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../../../../core/utils/logger.dart';
import 'kokoro_model_paths.dart';
import 'kokoro_model_spec.dart';

/// Prepares the voices of an installed model before the engine loads it.
abstract class VoiceBlender {
  Future<void> apply(KokoroModelPaths paths);
}

/// Writes the French voice into `voices.bin`: the weighted average of the
/// source speakers' style tensors, stored in an unused slot. Idempotent
/// (a marker names the recipe it applied) and safe to interrupt (the sources
/// are never touched and the marker is written last).
class KokoroVoiceBlender implements VoiceBlender {
  const KokoroVoiceBlender({
    this.slot = KokoroModelSpec.voiceBlendSlot,
    this.sources = KokoroModelSpec.voiceBlendSources,
    this.slotCount = KokoroModelSpec.voiceCount,
    this.slotFloats = KokoroModelSpec.voiceFloats,
  });

  final int slot;
  final Map<int, double> sources;
  final int slotCount;
  final int slotFloats;

  static const String _markerName = '.voice-blend';

  String get _recipe =>
      'v1 slot=$slot ${sources.entries.map((MapEntry<int, double> e) => '${e.key}x${e.value}').join('+')}';

  @override
  Future<void> apply(KokoroModelPaths paths) async {
    final File marker = File(p.join(paths.root, _markerName));
    if (await marker.exists() && await marker.readAsString() == _recipe) {
      return;
    }
    final int slotBytes = slotFloats * Float32List.bytesPerElement;
    final RandomAccessFile voices = await File(
      paths.voices,
    ).open(mode: FileMode.append);
    try {
      if (await voices.length() != slotCount * slotBytes) {
        throw FileSystemException(
          'voices.bin is not $slotCount speakers of $slotFloats floats',
          paths.voices,
        );
      }
      final Float32List blend = Float32List(slotFloats);
      for (final MapEntry<int, double> source in sources.entries) {
        await voices.setPosition(source.key * slotBytes);
        final Uint8List bytes = Uint8List.fromList(
          await voices.read(slotBytes),
        );
        final Float32List style = bytes.buffer.asFloat32List(0, slotFloats);
        for (int i = 0; i < slotFloats; i++) {
          blend[i] += style[i] * source.value;
        }
      }
      await voices.setPosition(slot * slotBytes);
      await voices.writeFrom(blend.buffer.asUint8List());
      await voices.flush();
    } finally {
      await voices.close();
    }
    await marker.writeAsString(_recipe, flush: true);
    AppLogger.info('French voice blended (slot $slot)', tag: 'VoiceBlender');
  }
}
