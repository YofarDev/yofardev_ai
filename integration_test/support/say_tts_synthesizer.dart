import 'dart:io';

import 'package:yofardev_ai/core/models/voice_effect.dart';
import 'package:yofardev_ai/features/sound/sound.dart';

/// A [TtsSynthesizer] backed by macOS `say` (M6 ruling 4): Supertonic's ONNX
/// models are not on this machine, so the capture harness speaks with
/// `say -v Samantha` into a 24 kHz 16-bit PCM WAV, which the app's own
/// amplitude, alignment and viseme analysis then read as usual.
///
/// Each WAV is also copied to [keep] as `NN.wav` and listed in [spoken]
/// (text and copy, in synthesis order), so the capture can mux the audio.
class SayTtsSynthesizer implements TtsSynthesizer {
  SayTtsSynthesizer(this.keep, {this.voice = 'Samantha'});

  final Directory keep;
  final String voice;
  final List<({String text, String file})> spoken =
      <({String text, String file})>[];

  int _n = 0;

  @override
  Future<String> synthesize({
    required String text,
    required String language,
    required VoiceEffect voiceEffect,
  }) async {
    final int n = _n++;
    final String path = '${Directory.systemTemp.path}/wow_say_$n.wav';
    final ProcessResult result = await Process.run('say', <String>[
      '-v',
      voice,
      '-o',
      path,
      '--file-format=WAVE',
      '--data-format=LEI16@24000',
      text,
    ]);
    if (result.exitCode != 0) {
      throw StateError('say failed: ${result.stderr}');
    }
    final String copy = '${keep.path}/${n.toString().padLeft(2, '0')}.wav';
    await File(path).copy(copy);
    spoken.add((text: text, file: copy));
    return path;
  }

  @override
  Future<void> delete(String path) async {
    final File file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }
}
