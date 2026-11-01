import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/models/performance/performance.dart';
import 'package:yofardev_ai/core/models/weather_report.dart';
import 'package:yofardev_ai/core/services/world/tablet_weather_source.dart';

void main() {
  test('relays every report with a temperature as a reading', () async {
    final TabletWeatherSource source = TabletWeatherSource();
    final List<TabletWeatherReading> readings = <TabletWeatherReading>[];
    source.readings.listen(readings.add);
    source.report(const WeatherReport(conditionId: 501, temperatureC: 18.2));
    source.report(const WeatherReport(conditionId: 800));
    await Future<void>.delayed(Duration.zero);
    expect(readings, <TabletWeatherReading>[
      const TabletWeatherReading(conditionId: 501, temperatureC: 18.2),
    ]);
    await source.dispose();
    // after dispose: ignored, never throws
    source.report(const WeatherReport(conditionId: 800, temperatureC: 1));
  });
}
