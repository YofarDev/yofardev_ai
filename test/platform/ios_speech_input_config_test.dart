import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/services/speech/speech_to_text_input_service.dart';

/// iOS offers the Stage mic ([isSpeechInputSupported]), so its native
/// setup must be there: iOS kills an app that asks for speech recognition
/// without a usage string, and permission_handler reports every permission
/// as denied unless its macro is compiled in.
void main() {
  test('iOS offers speech input', () {
    expect(isSpeechInputSupported('iOS'), isTrue);
  });

  test('Info.plist explains the microphone and speech recognition', () {
    final String plist = File('ios/Runner/Info.plist').readAsStringSync();

    for (final String key in <String>[
      'NSMicrophoneUsageDescription',
      'NSSpeechRecognitionUsageDescription',
    ]) {
      expect(
        RegExp('<key>$key</key>\\s*<string>[^<]+</string>').hasMatch(plist),
        isTrue,
        reason: '$key needs a non-empty description',
      );
    }
  });

  test('the Podfile enables the permission_handler macros', () {
    final String podfile = File('ios/Podfile').readAsStringSync();

    expect(podfile, contains("'PERMISSION_MICROPHONE=1'"));
    expect(podfile, contains("'PERMISSION_SPEECH_RECOGNIZER=1'"));
    expect(podfile, contains("'GCC_PREPROCESSOR_DEFINITIONS'"));
  });
}
