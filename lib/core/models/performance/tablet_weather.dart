/// The glyph on the tablet's weather card (contract v11 `tabletWeather`).
/// `none` keeps the generic card.
enum TabletWeather {
  none,
  clear,
  clouds,
  rain,
  snow,
  storm,
  fog;

  /// The glyph of an OpenWeather condition id (M8 ruling 14): 2xx storm,
  /// 3xx / 5xx rain, 6xx snow, 7xx fog, 800 clear, 80x clouds; anything else
  /// keeps the generic card.
  static TabletWeather fromCondition(int id) {
    if (id >= 200 && id < 300) {
      return TabletWeather.storm;
    }
    if ((id >= 300 && id < 400) || (id >= 500 && id < 600)) {
      return TabletWeather.rain;
    }
    if (id >= 600 && id < 700) {
      return TabletWeather.snow;
    }
    if (id >= 700 && id < 800) {
      return TabletWeather.fog;
    }
    if (id == 800) {
      return TabletWeather.clear;
    }
    if (id > 800 && id < 810) {
      return TabletWeather.clouds;
    }
    return TabletWeather.none;
  }
}

/// One successful weather lookup, for any city: what the tablet shows.
class TabletWeatherReading {
  const TabletWeatherReading({
    required this.conditionId,
    required this.temperatureC,
  });

  /// OpenWeather condition id.
  final int conditionId;

  /// Measured temperature, °C.
  final double temperatureC;

  /// The card's glyph.
  TabletWeather get glyph => TabletWeather.fromCondition(conditionId);

  /// The card's readout: rounded and clamped to the contract's −40..50.
  int get roundedTemp =>
      temperatureC.isFinite ? temperatureC.round().clamp(-40, 50) : 0;

  @override
  bool operator ==(Object other) =>
      other is TabletWeatherReading &&
      other.conditionId == conditionId &&
      other.temperatureC == temperatureC;

  @override
  int get hashCode => Object.hash(conditionId, temperatureC);

  @override
  String toString() =>
      'TabletWeatherReading(id: $conditionId, $temperatureC °C)';
}
