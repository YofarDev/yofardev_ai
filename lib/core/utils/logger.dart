import 'package:flutter/foundation.dart';

enum LogLevel { none, debug, info, warning, error }

class AppLogger {
  AppLogger._();

  // Reset
  static const String _reset = '\x1B[0m';

  // Base colors
  static const String _grey = '\x1B[90m';
  static const String _white = '\x1B[97m';
  static const String _cyan = '\x1B[36m';
  static const String _brightCyan = '\x1B[96m';
  static const String _yellow = '\x1B[33m';
  static const String _brightYellow = '\x1B[93m';
  static const String _red = '\x1B[31m';
  static const String _brightRed = '\x1B[91m';
  static const String _green = '\x1B[32m';
  static const String _magenta = '\x1B[35m';

  // Styles
  static const String _bold = '\x1B[1m';
  static const String _dim = '\x1B[2m';
  static const String _italic = '\x1B[3m';

  // Background colors
  static const String _bgRed = '\x1B[41m';
  static const String _bgYellow = '\x1B[43m';

  static LogLevel minimumLevel = kDebugMode ? LogLevel.debug : LogLevel.warning;

  // ── Per-level color schemes ────────────────────────────────────────────────

  static String _timeColor(LogLevel level) => switch (level) {
    LogLevel.none => _reset,
    LogLevel.debug => _dim + _grey,
    LogLevel.info => _dim + _cyan,
    LogLevel.warning => _dim + _yellow,
    LogLevel.error => _dim + _red,
  };

  static String _levelColor(LogLevel level) => switch (level) {
    LogLevel.none => _reset,
    LogLevel.debug => _bold + _grey,
    LogLevel.info => _bold + _brightCyan,
    LogLevel.warning => _bold + _bgYellow + _white,
    LogLevel.error => _bold + _bgRed + _white,
  };

  static String _callerColor(LogLevel level) => switch (level) {
    LogLevel.none => _reset,
    LogLevel.debug => _green,
    LogLevel.info => _green,
    LogLevel.warning => _green,
    LogLevel.error => _green,
  };

  static String _tagColor(LogLevel level) => switch (level) {
    LogLevel.none => _reset,
    LogLevel.debug => _magenta,
    LogLevel.info => _magenta,
    LogLevel.warning => _bold + _magenta,
    LogLevel.error => _bold + _magenta,
  };

  static String _messageColor(LogLevel level) => switch (level) {
    LogLevel.none => _reset,
    LogLevel.debug => _grey,
    LogLevel.info => _white,
    LogLevel.warning => _brightYellow,
    LogLevel.error => _brightRed,
  };

  static String _levelEmoji(LogLevel level) => switch (level) {
    LogLevel.none => '   ',
    LogLevel.debug => '🐛 ',
    LogLevel.info => '💡 ',
    LogLevel.warning => '⚠️ ',
    LogLevel.error => '🔥 ',
  };

  // ── Public API ─────────────────────────────────────────────────────────────

  static void debug(
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _log(
      LogLevel.debug,
      message,
      tag: tag,
      error: error,
      stackTrace: stackTrace,
    );
  }

  static void info(String message, {String? tag}) {
    _log(LogLevel.info, message, tag: tag);
  }

  static void warning(String message, {String? tag}) {
    _log(LogLevel.warning, message, tag: tag);
  }

  static void error(
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _log(
      LogLevel.error,
      message,
      tag: tag,
      error: error,
      stackTrace: stackTrace,
    );
  }

  // ── Core ───────────────────────────────────────────────────────────────────

  static void _log(
    LogLevel level,
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (level.index < minimumLevel.index) return;

    final String? callerInfo = _resolveCallerInfo();

    final String timeColor = _timeColor(level);
    final String levelColor = _levelColor(level);
    final String callerColor = _callerColor(level);
    final String tagColor = _tagColor(level);
    final String messageColor = _messageColor(level);
    final String emoji = _levelEmoji(level);

    final String timeOnly = DateTime.now()
        .toIso8601String()
        .split('T')
        .last
        .split('.')
        .first;
    final String levelStr = ' ${level.name.toUpperCase()} ';
    final String caller = callerInfo ?? '';
    final String tagStr = tag != null
        ? '$tagColor [$_italic$tag$_reset$tagColor]$_reset'
        : '';

    // Each segment gets its own color, reset between them
    final StringBuffer buffer = StringBuffer()
      ..write('==> ')
      ..write('$timeColor[$timeOnly]$_reset ')
      ..write(emoji)
      ..write('$levelColor$levelStr$_reset ')
      ..write(caller.isNotEmpty ? '$callerColor$_italic($caller)$_reset' : '')
      ..write(tagStr)
      ..write('$_dim $_grey│$_reset ')
      ..write('$messageColor$message$_reset');

    debugPrint(buffer.toString());

    if (error != null) {
      debugPrint('$_italic$_dim${_callerColor(level)}  ┌─ Error$_reset');
      debugPrint('$_italic${_messageColor(level)}  └─ $error$_reset');
    }

    if (stackTrace != null) {
      debugPrint('$_dim$_grey  ┌─ StackTrace$_reset');
      final List<String> stLines = stackTrace.toString().trim().split('\n');
      for (int i = 0; i < stLines.length; i++) {
        final bool isLast = i == stLines.length - 1;
        debugPrint('$_dim$_grey  ${isLast ? '└─' : '├─'} ${stLines[i]}$_reset');
      }
    }
  }

  static String? _resolveCallerInfo() {
    final List<String> lines = StackTrace.current.toString().split('\n');
    for (final String line in lines) {
      if (line.contains('logger.dart')) continue;
      if (line.contains('#')) {
        final Match? match = RegExp(r'\(([^:]+):(\d+):\d+\)').firstMatch(line);
        if (match != null) {
          final String fileName = (match.group(1) ?? 'unknown').split('/').last;
          final String lineNumber = match.group(2) ?? '?';
          return '$fileName:$lineNumber';
        }
      }
    }
    return null;
  }
}
