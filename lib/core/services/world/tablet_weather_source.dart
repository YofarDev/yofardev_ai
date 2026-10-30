import 'dart:async';

import '../../models/performance/tablet_weather.dart';
import '../../models/weather_report.dart';

/// Hands every successful weather lookup, for any city, to the performance
/// (M8 ruling 14): the director turns it into the tablet's weather card. The
/// world's rain and fog never come from here (own-location reports only).
///
/// Nothing leaves the device: it relays the report the weather tool already
/// fetched.
class TabletWeatherSource {
  final StreamController<TabletWeatherReading> _readings =
      StreamController<TabletWeatherReading>.broadcast();

  /// Every lookup with a condition and a temperature.
  Stream<TabletWeatherReading> get readings => _readings.stream;

  /// Relays [report]; one without a temperature is dropped (the card shows
  /// both or neither).
  void report(WeatherReport report) {
    final double? temperature = report.temperatureC;
    if (temperature == null || _readings.isClosed) {
      return;
    }
    _readings.add(
      TabletWeatherReading(
        conditionId: report.conditionId,
        temperatureC: temperature,
      ),
    );
  }

  Future<void> dispose() => _readings.close();
}
