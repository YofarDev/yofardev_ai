import 'dart:async';

import 'package:yofardev_ai/core/utils/logger.dart';

/// Runs around every test file (Flutter test convention).
///
/// Logging is off during tests: repositories log every mapped exception, and
/// with logging on a passing run prints tens of kilobytes that bury real
/// failures (and cost an agent its context). Re-enable it inside a single
/// test with `AppLogger.enabled = true;` when debugging.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  AppLogger.enabled = false;
  await testMain();
}
