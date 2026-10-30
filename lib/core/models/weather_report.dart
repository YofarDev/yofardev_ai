import 'dart:math' as math;

/// What the world needs from one OpenWeather `/weather` answer: the condition
/// (for the rain), the measured rain and the sun times (for the clock).
class WeatherReport {
  const WeatherReport({
    required this.conditionId,
    this.rainMmPerHour = 0,
    this.sunrise,
    this.sunset,
  });

  /// Parses OpenWeather 2.5 `/weather`: `weather[0].id`, optional `rain['1h']`
  /// and `sys.sunrise` / `sys.sunset` (unix seconds, UTC; kept as local times).
  factory WeatherReport.fromOpenWeather(Map<String, dynamic> json) {
    final List<dynamic> weather = json['weather'] as List<dynamic>;
    final int id = ((weather.first as Map<String, dynamic>)['id'] as num)
        .toInt();
    final Object? rain = json['rain'];
    final double mm = rain is Map<String, dynamic>
        ? (rain['1h'] as num?)?.toDouble() ?? 0
        : 0;
    final Object? sys = json['sys'];
    DateTime? sun(String key) {
      if (sys is! Map<String, dynamic>) {
        return null;
      }
      final num? seconds = sys[key] as num?;
      return seconds == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              seconds.toInt() * 1000,
              isUtc: true,
            ).toLocal();
    }

    return WeatherReport(
      conditionId: id,
      rainMmPerHour: mm,
      sunrise: sun('sunrise'),
      sunset: sun('sunset'),
    );
  }

  /// OpenWeather condition id (2xx thunderstorm … 8xx clear / clouds).
  final int conditionId;

  /// Measured rain over the last hour, mm (0 when the answer has none).
  final double rainMmPerHour;

  /// Local sunrise and sunset of the reported place, when known.
  final DateTime? sunrise;
  final DateTime? sunset;

  /// Steady rain the scenes should show, 0..1: the condition's level, or
  /// `rainMmPerHour / 4` when that is larger.
  double get rainIntensity {
    final double fromMm = (rainMmPerHour / 4).clamp(0.0, 1.0);
    return math.max(_conditionRain(conditionId), fromMm);
  }

  static double _conditionRain(int id) {
    if (id >= 200 && id < 300) {
      return 1.0;
    }
    if (id >= 300 && id < 400) {
      return 0.25;
    }
    if (id >= 500 && id < 600) {
      return switch (id) {
        500 => 0.4,
        501 => 0.6,
        511 => 0.6,
        >= 502 && <= 504 => 0.85,
        >= 520 && <= 531 => 0.85,
        _ => 0.6,
      };
    }
    return 0;
  }

  @override
  String toString() =>
      'WeatherReport(id: $conditionId, rain: $rainMmPerHour mm/h, '
      'sunrise: $sunrise, sunset: $sunset)';
}
