import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../utils/platform_utils.dart';

class SpeechToTextHandler {
  SpeechToText? _speechToText;
  bool _speechEnabled = false;

  bool get isSpeechListening => _speechToText?.isListening ?? false;
  bool get isSpeechEnabled => _speechEnabled;

  Future<void> initialize() async {
    if (PlatformUtils.checkPlatform() == 'Web') return;

    bool enable = false;
    if (PlatformUtils.checkPlatform() != 'MacOS') {
      final PermissionStatus status = await Permission.microphone.request();
      enable = status.isGranted;
    }

    if (enable) {
      _speechToText = SpeechToText();
      _speechEnabled = await _speechToText!.initialize();
    }
  }

  Future<void> startListening({
    required String localeId,
    required Function(SpeechRecognitionResult) onResult,
  }) async {
    if (_speechToText == null) return;

    await _speechToText!.listen(
      onResult: onResult,
      localeId: localeId,
      listenOptions: SpeechListenOptions(partialResults: false),
    );
  }

  Future<void> stopListening() async {
    await _speechToText?.stop();
  }

  void dispose() {
    _speechToText = null;
  }
}
