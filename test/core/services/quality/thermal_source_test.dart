import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/services/quality/thermal_source.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ThermalLevel.parse', () {
    test('every name round-trips; anything else is nominal', () {
      for (final ThermalLevel level in ThermalLevel.values) {
        expect(ThermalLevel.parse(level.name), level);
      }
      expect(ThermalLevel.parse(null), ThermalLevel.nominal);
      expect(ThermalLevel.parse('serious'), ThermalLevel.nominal);
      expect(ThermalLevel.parse(3), ThermalLevel.nominal);
    });
  });

  group('MethodChannelThermalSource', () {
    const MethodChannel query = MethodChannel(
      MethodChannelThermalSource.methodChannelName,
    );

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(query, null);
    });

    test('a missing plugin reads nominal', () async {
      expect(await MethodChannelThermalSource().current, ThermalLevel.nominal);
    });

    test('current asks the native side', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(query, (MethodCall call) async {
            expect(call.method, MethodChannelThermalSource.currentMethod);
            return 'severe';
          });
      expect(await MethodChannelThermalSource().current, ThermalLevel.severe);
    });

    test('a platform error reads nominal', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(query, (MethodCall call) async {
            throw PlatformException(code: 'unavailable');
          });
      expect(await MethodChannelThermalSource().current, ThermalLevel.nominal);
    });

    test('without a plugin the changes stream just ends', () async {
      expect(await MethodChannelThermalSource().changes.isEmpty, isTrue);
    });

    test('changes stream the native names, distinct', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(query, (MethodCall call) async => 'light');
      const EventChannel events = EventChannel(
        MethodChannelThermalSource.eventChannelName,
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockStreamHandler(
            events,
            MockStreamHandler.inline(
              onListen: (Object? arguments, MockStreamHandlerEventSink sink) {
                sink
                  ..success('nominal')
                  ..success('moderate')
                  ..success('moderate')
                  ..success('critical')
                  ..endOfStream();
              },
            ),
          );
      final List<ThermalLevel> levels = await MethodChannelThermalSource()
          .changes
          .toList();
      expect(levels, <ThermalLevel>[
        ThermalLevel.nominal,
        ThermalLevel.moderate,
        ThermalLevel.critical,
      ]);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockStreamHandler(events, null);
    });
  });

  test('NominalThermalSource is nominal and silent', () async {
    const NominalThermalSource source = NominalThermalSource();
    expect(await source.current, ThermalLevel.nominal);
    expect(await source.changes.isEmpty, isTrue);
  });
}
