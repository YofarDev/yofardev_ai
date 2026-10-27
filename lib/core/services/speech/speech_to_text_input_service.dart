import 'dart:async';

import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../utils/logger.dart';
import '../../utils/platform_utils.dart';
import 'speech_input_service.dart';

/// Maps the plugin's sound level onto 0–1.
///
/// Android (the primary target) reports an RMS level in dB that sits around
/// -2 in silence and peaks near 10 for loud speech, so `(level + 2) / 12`
/// spans the useful range; anything outside is clamped (iOS reports a
/// different scale and simply saturates at the ends).
double normaliseSoundLevel(double level) =>
    ((level + 2) / 12).clamp(0.0, 1.0).toDouble();

/// Whether speech input is offered on [platform] (a
/// [PlatformUtils.checkPlatform] value). `speech_to_text` crashes on macOS
/// in this app and has no Linux/web support worth shipping.
bool isSpeechInputSupported(String platform) => switch (platform) {
  'Android' || 'iOS' || 'Windows' => true,
  _ => false,
};

/// [SpeechInputService] over `speech_to_text` + `permission_handler`.
///
/// The microphone permission is requested on the first [start] (mobile only;
/// desktop has no runtime prompt) and the recognizer is initialised lazily
/// once. A session ends either through [stop]/[cancel] or on its own when
/// the plugin reports `done` (silence timeout); after that, [stop] still
/// returns the words heard.
///
/// `SpeechToText()` is a process-wide singleton shared with the chat details
/// input (AiTextInput). Its `initialize` callbacks only register on the
/// first call, so the status/error listeners are re-attached before every
/// listen.
class SpeechToTextInputService implements SpeechInputService {
  SpeechToTextInputService({
    SpeechToText? speechToText,
    String Function() platform = PlatformUtils.checkPlatform,
    Future<bool> Function()? requestMicrophonePermission,
  }) : _injectedSpeech = speechToText,
       _platform = platform,
       _requestMicrophonePermission =
           requestMicrophonePermission ?? _requestMicrophone;

  /// How long [stop] waits for the recognizer's final result (the plugin
  /// synthesises one after its own 2 s final timeout).
  static const Duration finalResultTimeout = Duration(milliseconds: 2500);

  final SpeechToText? _injectedSpeech;
  final String Function() _platform;
  final Future<bool> Function() _requestMicrophonePermission;

  final StreamController<double> _soundLevel =
      StreamController<double>.broadcast();
  final StreamController<String> _partialWords =
      StreamController<String>.broadcast();

  SpeechToText? _speech;
  bool _initialized = false;
  bool _permissionGranted = false;

  /// Words of the current (or last ended) session.
  String _words = '';

  /// Completes with the final words when the current session ends; null
  /// when no session was started since the last [stop]/[cancel].
  Completer<String>? _session;

  /// True once the plugin reported `listening` for the current session, so
  /// a late `done` from a previous session cannot end the new one.
  bool _sawListening = false;

  static Future<bool> _requestMicrophone() async {
    if (!PlatformUtils.isMobile()) return true;
    final PermissionStatus status = await Permission.microphone.request();
    return status.isGranted;
  }

  @override
  bool get isSupported => isSpeechInputSupported(_platform());

  @override
  Stream<double> get soundLevel => _soundLevel.stream;

  @override
  Stream<String> get partialWords => _partialWords.stream;

  @override
  Future<SpeechStartResult> start({required String localeId}) async {
    if (!isSupported) return SpeechStartResult.unavailable;
    if (_session != null && !_session!.isCompleted) {
      return SpeechStartResult.started;
    }

    if (!_permissionGranted) {
      _permissionGranted = await _requestMicrophonePermission();
      if (!_permissionGranted) return SpeechStartResult.permissionDenied;
    }

    final SpeechToText speech = _speech ??= _injectedSpeech ?? SpeechToText();
    try {
      if (!_initialized) {
        _initialized = await speech.initialize(
          onError: _onError,
          onStatus: _onStatus,
        );
        if (!_initialized) {
          // iOS also gates on the speech-recognition permission here.
          final bool hasPermission = await speech.hasPermission;
          return hasPermission
              ? SpeechStartResult.unavailable
              : SpeechStartResult.permissionDenied;
        }
      }

      _words = '';
      _sawListening = false;
      _session = Completer<String>();
      speech
        ..statusListener = _onStatus
        ..errorListener = _onError;
      await speech.listen(
        onResult: _onResult,
        onSoundLevelChange: (double level) =>
            _soundLevel.add(normaliseSoundLevel(level)),
        listenOptions: SpeechListenOptions(
          partialResults: true,
          localeId: localeId,
        ),
      );
      return SpeechStartResult.started;
    } catch (e, st) {
      AppLogger.error(
        'Speech input failed to start',
        tag: 'SpeechToTextInputService',
        error: e,
        stackTrace: st,
      );
      _endSession();
      _session = null;
      return SpeechStartResult.unavailable;
    }
  }

  @override
  Future<String> stop() async {
    final Completer<String>? session = _session;
    if (session == null) return '';
    if (!session.isCompleted) {
      try {
        await _speech?.stop();
      } catch (e) {
        AppLogger.error(
          'Speech input failed to stop',
          tag: 'SpeechToTextInputService',
          error: e,
        );
        _endSession();
      }
    }
    final String words = await session.future.timeout(
      finalResultTimeout,
      onTimeout: () => _words,
    );
    _endSession();
    _session = null;
    return words;
  }

  @override
  Future<void> cancel() async {
    final Completer<String>? session = _session;
    _session = null;
    _words = '';
    if (session != null && !session.isCompleted) {
      session.complete('');
    }
    _soundLevel.add(0);
    try {
      await _speech?.cancel();
    } catch (e) {
      AppLogger.error(
        'Speech input failed to cancel',
        tag: 'SpeechToTextInputService',
        error: e,
      );
    }
  }

  void _onResult(SpeechRecognitionResult result) {
    if (_session == null) return;
    _words = result.recognizedWords;
    _partialWords.add(_words);
    if (result.finalResult) _endSession();
  }

  void _onStatus(String status) {
    switch (status) {
      case SpeechToText.listeningStatus:
        _sawListening = true;
      case SpeechToText.notListeningStatus:
        _soundLevel.add(0);
      case SpeechToText.doneStatus:
        if (_sawListening) _endSession();
    }
  }

  void _onError(SpeechRecognitionError error) {
    AppLogger.warning(
      'Speech recognition error: ${error.errorMsg}',
      tag: 'SpeechToTextInputService',
    );
    if (error.permanent) _endSession();
  }

  /// Completes the current session with the words heard so far.
  void _endSession() {
    final Completer<String>? session = _session;
    if (session != null && !session.isCompleted) {
      session.complete(_words);
      _soundLevel.add(0);
    }
  }
}
