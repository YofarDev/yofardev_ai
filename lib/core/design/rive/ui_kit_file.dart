import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:rive/rive.dart';

import '../../utils/logger.dart';
import 'ui_kit_contract.dart';

/// The shared `ui_kit.riv` file: decoded lazily on the first [load], then
/// shared by every UI-kit widget for the app's lifetime (never disposed).
///
/// A missing or corrupt file resolves to null — logged once — and every
/// widget keeps its Flutter fallback.
abstract final class UiKitFile {
  static const String _tag = 'UiKitFile';

  static Future<File?>? _file;

  /// The decoded file, or null when it is missing or cannot be decoded. The
  /// first call starts the decode; later calls share its future.
  static Future<File?> load() => _file ??= _decode();

  static Future<File?> _decode() async {
    try {
      final File? file = await File.asset(
        UiKitContract.assetPath,
        riveFactory: Factory.rive,
      );
      if (file == null) {
        AppLogger.warning(
          '${UiKitContract.assetPath} could not be decoded; the UI kit uses '
          'its Flutter fallbacks.',
          tag: _tag,
        );
      }
      return file;
    } catch (e) {
      // A missing asset throws a FlutterError (an Error, not an Exception):
      // any load failure must degrade to the fallbacks.
      AppLogger.warning(
        '${UiKitContract.assetPath} unavailable; the UI kit uses its Flutter '
        'fallbacks: $e',
        tag: _tag,
      );
      return null;
    }
  }

  /// Forgets the memoised load so the next [load] decodes again. Tests call
  /// it in `setUp` so no future outlives the test that created it.
  @visibleForTesting
  static void resetForTest() => _file = null;
}
