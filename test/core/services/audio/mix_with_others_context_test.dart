import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/services/audio/mix_with_others_context.dart';

void main() {
  test('the effects context takes no audio focus on Android', () {
    expect(mixWithOthersContext().android.audioFocus, AndroidAudioFocus.none);
  });

  test('the effects context mixes with other audio on iOS', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final AudioContextIOS ios = mixWithOthersContext().iOS;
    expect(ios.options, contains(AVAudioSessionOptions.mixWithOthers));
  });
}
