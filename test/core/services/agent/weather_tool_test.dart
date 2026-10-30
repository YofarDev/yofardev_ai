import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/models/weather_report.dart';
import 'package:yofardev_ai/core/models/performance/performance.dart';
import 'package:yofardev_ai/core/services/agent/weather_tool.dart';
import 'package:yofardev_ai/core/services/world/tablet_weather_source.dart';
import 'package:yofardev_ai/core/services/world/world_state_service.dart';

void main() {
  const WeatherReport report = WeatherReport(conditionId: 501);
  late List<String> fetchedLocations;
  late List<WeatherReport> reported;
  late List<WeatherReport> anyCity;
  late bool succeed;

  WeatherTool build() => WeatherTool(
    onOwnLocationReport: reported.add,
    onReport: anyCity.add,
    fetch: (String location, String apiKey) async {
      fetchedLocations.add(location);
      return succeed
          ? (json: '{"condition_id":501}', report: report)
          : (json: 'Error: boom', report: null);
    },
  );

  setUp(() {
    fetchedLocations = <String>[];
    reported = <WeatherReport>[];
    anyCity = <WeatherReport>[];
    succeed = true;
  });

  Future<String> run(WeatherTool tool, Map<String, dynamic> args) async =>
      tool.execute(args, <String, dynamic>{'apiKey': 'k'});

  test('an absent location reports and returns the json', () async {
    final String out = await run(build(), <String, dynamic>{});
    expect(out, '{"condition_id":501}');
    expect(reported, <WeatherReport>[report]);
    expect(fetchedLocations, <String>['current']);
  });

  test('empty and "current" (any case) report', () async {
    final WeatherTool tool = build();
    await run(tool, <String, dynamic>{'location': ''});
    await run(tool, <String, dynamic>{'location': '  '});
    await run(tool, <String, dynamic>{'location': 'Current'});
    await run(tool, <String, dynamic>{'location': 'CURRENT'});
    expect(reported.length, 4);
    expect(fetchedLocations, everyElement('current'));
  });

  test('another city never reports', () async {
    final String out = await run(build(), <String, dynamic>{
      'location': 'Tokyo',
    });
    expect(out, '{"condition_id":501}');
    expect(reported, isEmpty);
    expect(fetchedLocations, <String>['Tokyo']);
  });

  test('every successful call, any city, reaches onReport (the tablet; '
      'the world hears only its own location)', () async {
    final WeatherTool tool = build();
    await run(tool, <String, dynamic>{'location': 'Tokyo'});
    await run(tool, <String, dynamic>{});
    expect(anyCity, <WeatherReport>[report, report]);
    expect(reported, <WeatherReport>[report]);
    succeed = false;
    await run(tool, <String, dynamic>{'location': 'Tokyo'});
    expect(anyCity.length, 2);
  });

  test('a failed call does not report', () async {
    succeed = false;
    final String out = await run(build(), <String, dynamic>{});
    expect(out, 'Error: boom');
    expect(reported, isEmpty);
  });

  test('a missing key is an error and never fetches', () async {
    final String out = await build().execute(
      <String, dynamic>{},
      <String, dynamic>{},
    );
    expect(out, contains('not configured'));
    expect(fetchedLocations, isEmpty);
  });

  test('a throwing listener does not lose the answer', () async {
    final WeatherTool tool = WeatherTool(
      onOwnLocationReport: (WeatherReport r) => throw StateError('x'),
      onReport: (WeatherReport r) => throw StateError('y'),
      fetch: (String l, String k) async => (json: 'ok', report: report),
    );
    expect(await run(tool, <String, dynamic>{}), 'ok');
  });

  test(
    'Tokyo in fog reaches the tablet, never the world (M8 rulings 13-14)',
    () async {
      final WorldStateService world = WorldStateService();
      final TabletWeatherSource tablet = TabletWeatherSource();
      final List<TabletWeatherReading> readings = <TabletWeatherReading>[];
      tablet.readings.listen(readings.add);
      final WeatherTool tool = WeatherTool(
        onOwnLocationReport: world.applyWeather,
        onReport: tablet.report,
        fetch: (String location, String key) async => (
          json: '{}',
          report: WeatherReport(
            conditionId: location == 'current' ? 701 : 741,
            temperatureC: location == 'current' ? 9 : 14.6,
          ),
        ),
      );
      await run(tool, <String, dynamic>{'location': 'Tokyo'});
      await Future<void>.delayed(Duration.zero);
      expect(world.fog.value, 0);
      expect(world.rain.value, 0);
      expect(readings.single.glyph, TabletWeather.fog);
      expect(readings.single.roundedTemp, 15);
      // the user's own place moves the world
      await run(tool, <String, dynamic>{});
      expect(world.fog.value, 0.5);
      world.dispose();
      await tablet.dispose();
    },
  );
}
