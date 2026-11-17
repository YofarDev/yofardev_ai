// The onPlatformMessage wrap below uses a deprecated hook on purpose: it is
// the only seam that sees the engine's post-font-load systemFonts message in
// widget tests.

import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/utils/logger.dart';

// The onPlatformMessage wrap below uses a deprecated hook on purpose: it is
// the only seam that sees the engine's post-font-load systemFonts message in
// widget tests.
// ignore_for_file: deprecated_member_use

/// Runs around every test file (Flutter test convention).
///
/// Logging is off during tests: repositories log every mapped exception, and
/// with logging on a passing run prints tens of kilobytes that bury real
/// failures (and cost an agent its context). Re-enable it inside a single
/// test with `AppLogger.enabled = true;` when debugging.
///
/// The `flutter/systemFonts` platform message is dropped: the engine emits it
/// after every test font load (`loadFontFromList`), and material_ui's relayout
/// mixin reacts by scheduling a frame callback that outlives the disposed
/// test tree, which the framework reports as a spurious
/// "animation still running after the widget tree was disposed" failure. No
/// test needs live system-font updates.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  AppLogger.enabled = false;
  TestWidgetsFlutterBinding.ensureInitialized();
  final PlatformDispatcher dispatcher = PlatformDispatcher.instance;
  // The deprecated hook is the only seam that sees the engine's post-font-load
  // systemFonts message in widget tests.
  final void Function(String, ByteData?, PlatformMessageResponseCallback?)?
  previous = dispatcher.onPlatformMessage;
  void dispatch(
    String channel,
    ByteData? data,
    PlatformMessageResponseCallback? callback,
  ) {
    if (channel == 'flutter/systemFonts') {
      callback?.call(null);
      return;
    }
    previous?.call(channel, data, callback);
  }

  dispatcher.onPlatformMessage = dispatch;
  await testMain();
}
