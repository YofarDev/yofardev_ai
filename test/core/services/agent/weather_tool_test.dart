import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/models/weather_report.dart';
import 'package:yofardev_ai/core/services/agent/weather_tool.dart';

void main() {
  const WeatherReport report = WeatherReport(conditionId: 501);
  late List<String> fetchedLocations;
  late List<WeatherReport> reported;
  late bool succeed;

  WeatherTool build() => WeatherTool(
    onOwnLocationReport: reported.add,
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
      fetch: (String l, String k) async => (json: 'ok', report: report),
    );
    expect(await run(tool, <String, dynamic>{}), 'ok');
  });
}
