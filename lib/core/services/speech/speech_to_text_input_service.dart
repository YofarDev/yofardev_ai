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
/// Calls are serialized: a [start] issued while another is still pending
/// (permission dialog, initialize) shares that pending start, so `listen`
/// runs at most once; a [stop]/[cancel]/[dispose] issued while a start is
/// pending bumps [_generation], and the pending start then aborts with
/// [SpeechStartResult.cancelled] before opening the mic. The mic is never
/// left open without a caller able to stop it.
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
  bool _disposed = false;

  /// Bumped by [stop], [cancel] and [dispose]: a pending start compares it
  /// after every await and aborts when it changed.
  int _generation = 0;

  /// The start in flight, shared by overlapping [start] calls.
  Future<SpeechStartResult>? _pendingStart;

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
  Future<SpeechStartResult> start({required String localeId}) {
    if (_disposed || !isSupported) {
      return Future<SpeechStartResult>.value(SpeechStartResult.unavailable);
    }
    if (_session != null && !_session!.isCompleted) {
      return Future<SpeechStartResult>.value(SpeechStartResult.started);
    }
    final Future<SpeechStartResult>? pending = _pendingStart;
    if (pending != null) return pending;

    final Future<SpeechStartResult> started = _start(localeId, _generation);
    _pendingStart = started;
    return started.whenComplete(() {
      if (identical(_pendingStart, started)) _pendingStart = null;
    });
  }

  Future<SpeechStartResult> _start(String localeId, int generation) async {
    bool superseded() => generation != _generation;

    if (!_permissionGranted) {
      _permissionGranted = await _requestMicrophonePermission();
      if (superseded()) return SpeechStartResult.cancelled;
      if (!_permissionGranted) return SpeechStartResult.permissionDenied;
    }

    final SpeechToText speech = _speech ??= _injectedSpeech ?? SpeechToText();
    try {
      if (!_initialized) {
        _initialized = await speech.initialize(
          onError: _onError,
          onStatus: _onStatus,
        );
        if (superseded()) return SpeechStartResult.cancelled;
        if (!_initialized) {
          // iOS also gates on the speech-recognition permission here.
          final bool hasPermission = await speech.hasPermission;
          if (superseded()) return SpeechStartResult.cancelled;
          return hasPermission
              ? SpeechStartResult.unavailable
              : SpeechStartResult.permissionDenied;
        }
      }

      // Last check before the mic opens; nothing below awaits before the
      // session exists, so a stop()/cancel() from here on finds it.
      if (superseded()) return SpeechStartResult.cancelled;
      _words = '';
      _sawListening = false;
      _session = Completer<String>();
      speech
        ..statusListener = _onStatus
        ..errorListener = _onError;
      await speech.listen(
        onResult: _onResult,
        onSoundLevelChange: _onSoundLevel,
        listenOptions: SpeechListenOptions(
          partialResults: true,
          localeId: localeId,
        ),
      );
      return superseded()
          ? SpeechStartResult.cancelled
          : SpeechStartResult.started;
    } catch (e, st) {
      AppLogger.error(
        'Speech input failed to start',
        tag: 'SpeechToTextInputService',
        error: e,
        stackTrace: st,
      );
      if (!superseded()) {
        _endSession();
        _session = null;
      }
      return SpeechStartResult.unavailable;
    }
  }

  @override
  Future<String> stop() async {
    _generation++;
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
    if (identical(_session, session)) {
      _endSession();
      _session = null;
    }
    return words;
  }

  @override
  Future<void> cancel() async {
    _generation++;
    final Completer<String>? session = _session;
    _session = null;
    _words = '';
    if (session != null && !session.isCompleted) {
      session.complete('');
    }
    _addLevel(0);
    if (session == null) return;
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

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    await cancel();
    _disposed = true;
    await _soundLevel.close();
    await _partialWords.close();
  }

  void _onResult(SpeechRecognitionResult result) {
    if (_session == null || _session!.isCompleted) return;
    _words = result.recognizedWords;
    if (!_partialWords.isClosed) _partialWords.add(_words);
    if (result.finalResult) _endSession();
  }

  void _onSoundLevel(double level) => _addLevel(normaliseSoundLevel(level));

  void _onStatus(String status) {
    switch (status) {
      case SpeechToText.listeningStatus:
        _sawListening = true;
      case SpeechToText.notListeningStatus:
        _addLevel(0);
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

  void _addLevel(double level) {
    if (!_soundLevel.isClosed) _soundLevel.add(level);
  }

  /// Completes the current session with the words heard so far.
  void _endSession() {
    final Completer<String>? session = _session;
    if (session != null && !session.isCompleted) {
      session.complete(_words);
      _addLevel(0);
    }
  }
}
