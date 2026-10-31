import 'dart:math' as math;

/// What the world needs from one OpenWeather `/weather` answer: the condition
/// (for the rain and the fog), the measured rain and the sun times (for the clock), and
/// the temperature (for the tablet's weather card, M8) and the wind speed
/// (for the wind bed, M11).
class WeatherReport {
  const WeatherReport({
    required this.conditionId,
    this.rainMmPerHour = 0,
    this.sunrise,
    this.sunset,
    this.temperatureC,
    this.latitude,
    this.windSpeed,
  });

  /// Parses OpenWeather 2.5 `/weather`: `weather[0].id`, optional `rain['1h']`,
  /// `coord.lat`, `wind.speed` (m/s with metric units) and `sys.sunrise` /
  /// `sys.sunset` (unix seconds, UTC; kept as local times).
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

    final Object? main = json['main'];
    final double? temperature = main is Map<String, dynamic>
        ? (main['temp'] as num?)?.toDouble()
        : null;

    final Object? coord = json['coord'];
    final double? latitude = coord is Map<String, dynamic>
        ? (coord['lat'] as num?)?.toDouble()
        : null;

    final Object? wind = json['wind'];
    final Object? speed = wind is Map<String, dynamic> ? wind['speed'] : null;

    return WeatherReport(
      conditionId: id,
      rainMmPerHour: mm,
      sunrise: sun('sunrise'),
      sunset: sun('sunset'),
      temperatureC: temperature,
      latitude: latitude,
      windSpeed: speed is num ? speed.toDouble() : null,
    );
  }

  /// OpenWeather condition id (2xx thunderstorm … 8xx clear / clouds).
  final int conditionId;

  /// Measured rain over the last hour, mm (0 when the answer has none).
  final double rainMmPerHour;

  /// Local sunrise and sunset of the reported place, when known.
  final DateTime? sunrise;
  final DateTime? sunset;

  /// Measured temperature, °C (`main.temp` with metric units), when known.
  final double? temperatureC;

  /// Latitude of the reported place in degrees (north positive), when
  /// known: the moon is drawn mirrored south of the equator (M9 ruling 12).
  final double? latitude;

  /// Measured wind speed of the reported place, m/s (`wind.speed` with
  /// metric units), when known.
  final double? windSpeed;

  /// Wind speed at which the wind bed is at its loudest, m/s.
  static const double fullWindSpeed = 12;

  /// The wind the world should hear, 0..1: `windSpeed / 12` clamped (M11
  /// ruling 11), null when the speed is unknown.
  double? get windIntensity {
    final double? speed = windSpeed;
    if (speed == null || speed.isNaN) {
      return null;
    }
    return (speed / fullWindSpeed).clamp(0.0, 1.0);
  }

  /// Steady rain the scenes should show, 0..1: the condition's level, or
  /// `rainMmPerHour / 4` when that is larger.
  double get rainIntensity {
    final double fromMm = (rainMmPerHour / 4).clamp(0.0, 1.0);
    return math.max(_conditionRain(conditionId), fromMm);
  }

  /// Weather fog the scenes should show, 0..1 (M8 ruling 13): 701 mist 0.5,
  /// 711 smoke 0.3, 721 haze 0.35, 741 fog 1.0, 731 / 751 / 761 dust and
  /// sand 0.25, anything else 0.
  double get fogIntensity => switch (conditionId) {
    701 => 0.5,
    711 => 0.3,
    721 => 0.35,
    741 => 1.0,
    731 || 751 || 761 => 0.25,
    _ => 0,
  };

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
      'sunrise: $sunrise, sunset: $sunset, temp: $temperatureC, '
      'wind: $windSpeed m/s)';
}
