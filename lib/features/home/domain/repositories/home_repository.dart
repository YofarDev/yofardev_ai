import 'dart:ui';
import 'package:flutter/foundation.dart';

/// Repository interface for home feature operations
abstract class HomeRepository {
  /// Play TTS audio with the given path
  Future<void> playTts(
    String audioPath, {
    bool removeFile = true,
    bool soundEffectsEnabled = true,
    VoidCallback? onComplete,
  });

  /// Stop any currently playing TTS audio
  Future<void> stopTts();

  /// Start volume fade in or out for avatar animations.
  ///
  /// [fadeIn] - true to fade volume up (avatar returning),
  ///            false to fade volume down (avatar leaving)
  Future<void> startVolumeFade(bool fadeIn);

  /// Dispose resources
  void dispose();
}
