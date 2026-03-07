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

  /// Dispose resources
  void dispose();
}
