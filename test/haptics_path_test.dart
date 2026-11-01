import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The one file that may call Flutter's `HapticFeedback`: `FoleyService`'s
/// sink (`SystemHaptics`). Everything else reaches it through
/// `FoleyService.haptic` / `propTap`, behind the sound-effects setting.
const String hapticsSink = 'lib/core/services/audio/foley_service.dart';

/// Why [line] is a haptic path other than the sink's `HapticFeedback`
/// (null: it is not one). [inSink] is true for the sink's own file.
String? forbiddenHaptic(String line, {required bool inSink}) {
  final String code = line.split('//').first;
  if (RegExp(
    r"package:(vibration|vibrate|flutter_vibrate|haptic_feedback)",
  ).hasMatch(code)) {
    return 'a vibration plugin';
  }
  if (RegExp(r'\bVibration\b|\bVibrate\b').hasMatch(code)) {
    return 'a vibration plugin API';
  }
  if (RegExp(r'vibrate\s*\(', caseSensitive: false).hasMatch(code)) {
    return 'a direct vibrate call (HapticFeedback.vibrate included)';
  }
  if (RegExp(r"""['"]HapticFeedback\.""").hasMatch(code) ||
      RegExp(
        r"""MethodChannel\([^)]*(vibrat|haptic)""",
        caseSensitive: false,
      ).hasMatch(code)) {
    return 'a platform channel to the vibrator';
  }
  if (!inSink && RegExp(r'\bHapticFeedback\b').hasMatch(code)) {
    return 'HapticFeedback outside FoleyService (bypasses the setting)';
  }
  return null;
}

/// M11 ruling 22: every haptic goes through Flutter's `HapticFeedback` in
/// `FoleyService`'s sink, so the system's haptics switch (Android
/// `performHapticFeedback` without the ignore-global flag, iOS
/// `UIFeedbackGenerator`) and the app's sound-effects setting both win.
void main() {
  test('no vibration path in lib/ other than the FoleyService sink', () {
    final List<String> violations = <String>[];
    for (final File file in Directory(
      'lib',
    ).listSync(recursive: true).whereType<File>()) {
      final String path = file.path.replaceAll('\\', '/');
      if (!path.endsWith('.dart') || path.contains('/generated/')) {
        continue;
      }
      final List<String> lines = file.readAsLinesSync();
      for (int i = 0; i < lines.length; i++) {
        final String? why = forbiddenHaptic(
          lines[i],
          inSink: path == hapticsSink,
        );
        if (why != null) {
          violations.add('$path:${i + 1}: $why');
        }
      }
    }
    expect(violations, isEmpty);
  });

  test('the sink uses only selectionClick and lightImpact', () {
    // code only: the doc comments name the paths it must not take
    final String sink = File(
      hapticsSink,
    ).readAsLinesSync().map((String line) => line.split('//').first).join('\n');
    final Iterable<String> calls = RegExp(
      r'HapticFeedback\.(\w+)',
    ).allMatches(sink).map((RegExpMatch m) => m.group(1)!);
    expect(calls.toSet(), <String>{'selectionClick', 'lightImpact'});
  });

  test('the rule catches deliberate violations (fixture)', () {
    expect(
      forbiddenHaptic(
        "import 'package:vibration/vibration.dart';",
        inSink: false,
      ),
      isNotNull,
    );
    expect(forbiddenHaptic('Vibration.vibrate();', inSink: false), isNotNull);
    expect(
      forbiddenHaptic('HapticFeedback.vibrate();', inSink: true),
      isNotNull,
    );
    expect(
      forbiddenHaptic('HapticFeedback.lightImpact();', inSink: false),
      isNotNull,
    );
    expect(
      forbiddenHaptic(
        "SystemChannels.platform.invokeMethod('HapticFeedback.vibrate');",
        inSink: true,
      ),
      isNotNull,
    );
    expect(
      forbiddenHaptic('HapticFeedback.lightImpact();', inSink: true),
      isNull,
    );
    expect(
      forbiddenHaptic('foley.haptic(DragHaptic.impact);', inSink: false),
      isNull,
    );
    expect(
      forbiddenHaptic('// HapticFeedback.vibrate()', inSink: false),
      isNull,
    );
  });
}
