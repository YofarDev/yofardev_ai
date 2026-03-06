import 'dart:async';
import '../../utils/logger.dart';

/// Service for managing assistant interruption state
///
/// Broadcasts interruption events to all listeners via [interruptionStream].
/// Components should listen to this stream and handle their own cleanup.
class InterruptionService {
  final StreamController<void> _interruptionController =
      StreamController<void>.broadcast();
  bool _isInterrupted = false;

  /// Stream that broadcasts when interruption occurs
  Stream<void> get interruptionStream => _interruptionController.stream;

  /// Check if currently interrupted
  bool get isInterrupted => _isInterrupted;

  /// Trigger interruption (called by UI)
  ///
  /// Broadcasts interruption event to all listeners.
  /// Multiple interruptions are handled gracefully.
  Future<void> interrupt() async {
    try {
      AppLogger.debug('Interruption triggered', tag: 'InterruptionService');
      _isInterrupted = true;
      _interruptionController.add(null);
    } catch (e) {
      AppLogger.error(
        'Failed to trigger interruption',
        tag: 'InterruptionService',
        error: e,
      );
    }
  }

  /// Reset interruption state (called when starting new conversation)
  void reset() {
    AppLogger.debug('Interruption state reset', tag: 'InterruptionService');
    _isInterrupted = false;
  }

  /// Dispose resources
  void dispose() {
    _interruptionController.close();
  }
}
