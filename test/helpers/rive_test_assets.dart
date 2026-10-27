import 'dart:io' as io;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Serves 4 non-Rive bytes for every `assets/rive/**.riv` key, so
/// `File.asset` resolves to null and Rive widgets show their fallback: the
/// flutter tester has no packaged `.riv` files, and decoding real Rive bytes
/// aborts the tester's native runtime.
///
/// Every other key is served from the unit-test asset folder, as the default
/// test handler does, so fonts and images still load (goldens need them).
void serveFakeRiveAssets() {
  final String? assetDir = io.Platform.environment['UNIT_TEST_ASSETS'];
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMessageHandler('flutter/assets', (ByteData? message) async {
        final String key = const StringCodec().decodeMessage(message)!;
        if (key.startsWith('assets/rive/') && key.endsWith('.riv')) {
          return ByteData(4);
        }
        if (assetDir == null) {
          return null;
        }
        final io.File file = io.File(p.join(assetDir, key));
        if (!file.existsSync()) {
          return null;
        }
        return Uint8List.fromList(file.readAsBytesSync()).buffer.asByteData();
      });
}
