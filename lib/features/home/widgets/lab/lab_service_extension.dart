// ignore-l10n: debug — the UI lab is debug-only; its strings are hardcoded.
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

import '../../../../core/services/world/world_state_service.dart';
import '../../../../core/utils/logger.dart';
import '../../../avatar/avatar.dart';
import 'lab_config.dart';

const String _tag = 'UiLabExtension';

/// `ext.yofardev.uiLab.configure`: merges the given params into the config.
const String uiLabConfigureExtension = 'ext.yofardev.uiLab.configure';

/// `ext.yofardev.uiLab.state`: returns the current config.
const String uiLabStateExtension = 'ext.yofardev.uiLab.state';

const Set<String> _numericKeys = <String>{
  'accentHueOverride',
  'glassAlphaScale',
  'radiusScaleOverride',
};

const Set<String> _boolKeys = <String>{'panelCollapsed'};

/// Keys whose value is a JSON document (`null`/empty clears it).
const Set<String> _jsonKeys = <String>{'face', 'parallax', 'npc'};

/// Params the VM service adds to every call; never part of the config.
const Set<String> _vmParams = <String>{'isolateId'};

bool _registered = false;
ValueNotifier<LabConfig>? _active;
WorldStateService? _activeWorld;

/// The config of the lab currently mounted, or null. Exposed for tests.
@visibleForTesting
ValueNotifier<LabConfig>? get activeUiLabConfig => _active;

developer.ServiceExtensionResponse _error(String message) {
  return developer.ServiceExtensionResponse.error(
    developer.ServiceExtensionResponse.extensionError,
    jsonEncode(<String, String>{'message': message}),
  );
}

developer.ServiceExtensionResponse _ok(
  LabConfig config, [
  WorldStateService? world,
]) => developer.ServiceExtensionResponse.result(
  jsonEncode(<String, Object?>{
    ...config.toJson(),
    _rainKey: ?world?.rain.value,
    _fogKey: ?world?.fog.value,
    _moonPhaseKey: ?world?.moonPhase.value,
    _festiveKey: ?world?.festive.value,
    _dateKey: ?(world == null ? null : _formatDate(world.localDay.value)),
  }),
);

/// The world-state params: not part of [LabConfig], they go to
/// [WorldStateService.setRain] and [WorldStateService.setFog].
const String _rainKey = 'rain';
const String _fogKey = 'fog';

/// The sky params (M9), also world state: `moonPhase` (-1 = the moon as
/// drawn before v12, 0..1 a phase, `null` back to the calendar), `festive`
/// (0..1, `null` back to the calendar) and `date` (`YYYY-MM-DD` pins the
/// clock's date and keeps its time of day, `null` unpins the clock).
const String _moonPhaseKey = 'moonPhase';
const String _festiveKey = 'festive';
const String _dateKey = 'date';

String _formatDate(DateTime day) =>
    '${day.year.toString().padLeft(4, '0')}-'
    '${day.month.toString().padLeft(2, '0')}-'
    '${day.day.toString().padLeft(2, '0')}';

/// A parsed override param: [given] false when the param was absent,
/// [value] null when it asked to clear the override.
typedef _Override<T> = ({bool given, T? value});

bool _clears(String value) => value.isEmpty || value == 'null';

/// Parses an override param (`moonPhase` or `festive`): a number in
/// [min]..[max], or empty / `null` to clear; needs [world].
_Override<double> _overrideParam(
  String key,
  String? value,
  double min,
  double max,
  WorldStateService? world,
) {
  if (value == null) {
    return (given: false, value: null);
  }
  if (world == null) {
    throw FormatException('"$key" needs the world state service');
  }
  if (_clears(value)) {
    return (given: true, value: null);
  }
  final double? number = double.tryParse(value);
  if (number == null || number < min || number > max) {
    throw FormatException(
      '"$key" must be a number in $min..$max or null, got "$value"',
    );
  }
  return (given: true, value: number);
}

final RegExp _datePattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

/// Parses the `date` param: `YYYY-MM-DD` (a real calendar day), or empty /
/// `null` to unpin; needs [world].
_Override<DateTime> _dateParam(String? value, WorldStateService? world) {
  if (value == null) {
    return (given: false, value: null);
  }
  if (world == null) {
    throw FormatException('"$_dateKey" needs the world state service');
  }
  if (_clears(value)) {
    return (given: true, value: null);
  }
  final RegExpMatch? match = _datePattern.firstMatch(value);
  if (match != null) {
    final int year = int.parse(match.group(1)!);
    final int month = int.parse(match.group(2)!);
    final int day = int.parse(match.group(3)!);
    final DateTime parsed = DateTime(year, month, day);
    if (parsed.year == year && parsed.month == month && parsed.day == day) {
      return (given: true, value: parsed);
    }
  }
  throw FormatException('"$_dateKey" must be YYYY-MM-DD or null, got "$value"');
}

/// Parses a world param (`rain` or `fog`): a number in 0..1, which needs
/// [world]. Null when [value] is null.
double? _worldParam(String key, String? value, WorldStateService? world) {
  if (value == null) {
    return null;
  }
  final double? number = double.tryParse(value);
  if (number == null || number < 0 || number > 1) {
    throw FormatException('"$key" must be a number in 0..1, got "$value"');
  }
  if (world == null) {
    throw FormatException('"$key" needs the world state service');
  }
  return number;
}

/// Converts service-extension string params into [LabConfig] JSON values:
/// numeric keys become numbers (`null`/empty clears an override), boolean
/// keys take `true`/`false`, `face` and `parallax` are decoded as JSON
/// (`null`/empty goes back to the live face / the live parallax), the rest
/// (`scene`, `prop`, ...) stay strings. Throws [FormatException]
/// on a non-numeric number, a non-boolean flag or malformed JSON.
Map<String, Object?> _paramsToJson(Map<String, String> params) {
  final Map<String, Object?> json = <String, Object?>{};
  params.forEach((String key, String value) {
    if (_vmParams.contains(key)) {
      return;
    }
    if (_boolKeys.contains(key)) {
      json[key] = switch (value) {
        'true' => true,
        'false' => false,
        _ => throw FormatException(
          '"$key" must be true or false, got "$value"',
        ),
      };
      return;
    }
    if (_jsonKeys.contains(key)) {
      json[key] = value.isEmpty ? null : jsonDecode(value);
      return;
    }
    if (key == 'npc2') {
      // a state name (`react`), an object like `npc`, or null
      json[key] = _clears(value)
          ? null
          : (value.trimLeft().startsWith('{') ? jsonDecode(value) : value);
      return;
    }
    if (!_numericKeys.contains(key)) {
      json[key] = value;
      return;
    }
    if (value.isEmpty || value == 'null') {
      json[key] = null;
      return;
    }
    final double? number = double.tryParse(value);
    if (number == null) {
      throw FormatException('"$key" must be a number, got "$value"');
    }
    json[key] = number;
  });
  return json;
}

/// Handler of [uiLabConfigureExtension], kept pure for tests: merges
/// [params] into [notifier]'s config and returns the new config as JSON, or
/// an error response (and leaves the config alone) when no lab is mounted or
/// the input is invalid.
///
/// A `face` object replaces the whole lab face (missing names are 0), e.g.
/// `{"auJawDrop":0.5,"auBrowOuterUpR":0.3,"roll":0.2}`; without a `blink`
/// count it keeps the current one, so it never fires a blink by itself.
/// `prop` is `none`, `tablet` or `newspaper`; `shot` (`wide`, `medium`,
/// `closeUp` or `propInsert`) cuts the stage camera to that framing;
/// `parallax` is
/// `{"x":0.5,"y":-0.2}` (each -1..1) or `null`. `npc` poses the scene's NPC
/// by hand: `{"npc":"notice","npcX":0.5,"npcLook":-1}` (any key optional) or
/// `null` (back to rest). `npc2` poses the beach's gulls the same way, or
/// by a state name alone (`react`; `move` stands halfway) or `null` (the live
/// tree). `rain` and `fog` are numbers in 0..1 handed to
/// [world] ([WorldStateService.setRain], [WorldStateService.setFog]); they
/// are rejected when no [world] is given and, like any invalid input, leave
/// the config alone. So do the sky's params: `moonPhase` (-1..1: -1 the moon
/// as drawn, 0..1 a phase), `festive` (0..1) and `date` (`YYYY-MM-DD`), each
/// with `null` back to the calendar / the real clock.
developer.ServiceExtensionResponse labConfigureResponse(
  ValueNotifier<LabConfig>? notifier,
  Map<String, String> params, {
  WorldStateService? world,
}) {
  if (notifier == null) {
    return _error('No UI lab is mounted. Open it first.');
  }
  try {
    final Map<String, String> configParams = <String, String>{...params};
    final double? rain = _worldParam(
      _rainKey,
      configParams.remove(_rainKey),
      world,
    );
    final double? fog = _worldParam(
      _fogKey,
      configParams.remove(_fogKey),
      world,
    );
    final _Override<double> moon = _overrideParam(
      _moonPhaseKey,
      configParams.remove(_moonPhaseKey),
      -1,
      1,
      world,
    );
    final _Override<double> festive = _overrideParam(
      _festiveKey,
      configParams.remove(_festiveKey),
      0,
      1,
      world,
    );
    final _Override<DateTime> date = _dateParam(
      configParams.remove(_dateKey),
      world,
    );
    final Map<String, Object?> json = _paramsToJson(configParams);
    final Object? face = json['face'];
    final FaceFrame? current = notifier.value.face;
    if (face is Map<String, Object?> &&
        !face.containsKey(LabFace.blinkKey) &&
        current != null) {
      json['face'] = <String, Object?>{
        ...face,
        LabFace.blinkKey: current.blinkSerial,
      };
    }
    final Map<String, Object?> merged = <String, Object?>{
      ...notifier.value.toJson(),
      ...json,
    };
    final LabConfig next = LabConfig.fromJson(merged);
    notifier.value = next;
    if (rain != null) {
      world!.setRain(rain);
    }
    if (fog != null) {
      world!.setFog(fog);
    }
    if (moon.given) {
      world!.setMoonPhase(moon.value);
    }
    if (festive.given) {
      world!.setFestive(festive.value);
    }
    if (date.given) {
      final DateTime? day = date.value;
      final DateTime now = world!.localNow;
      world.pinClock(
        day == null
            ? null
            : DateTime(day.year, day.month, day.day, now.hour, now.minute),
      );
    }
    return _ok(next, world);
  } on FormatException catch (e) {
    return _error(e.message);
  }
}

/// Handler of [uiLabStateExtension]: the current config as JSON.
developer.ServiceExtensionResponse labStateResponse(
  ValueNotifier<LabConfig>? notifier, {
  WorldStateService? world,
}) {
  if (notifier == null) {
    return _error('No UI lab is mounted. Open it first.');
  }
  return _ok(notifier.value, world);
}

/// Makes [config] the lab the debug service extensions drive, registering the
/// extensions on first use. `registerExtension` throws when a name is
/// registered twice in an isolate, so registration happens once per isolate
/// and calls are routed to the currently mounted notifier. No-op outside
/// debug builds. [world] receives the `rain` and `fog` params.
void registerUiLabExtensions(
  ValueNotifier<LabConfig> config, {
  WorldStateService? world,
}) {
  if (!kDebugMode) {
    return;
  }
  _active = config;
  _activeWorld = world;
  if (_registered) {
    return;
  }
  _registered = true;
  _register(
    uiLabConfigureExtension,
    (String method, Map<String, String> params) async =>
        labConfigureResponse(_active, params, world: _activeWorld),
  );
  _register(
    uiLabStateExtension,
    (String method, Map<String, String> params) async =>
        labStateResponse(_active, world: _activeWorld),
  );
}

/// Detaches [config] from the extensions, unless a newer lab already took
/// over.
void unregisterUiLabExtensions(ValueNotifier<LabConfig> config) {
  if (identical(_active, config)) {
    _active = null;
    _activeWorld = null;
  }
}

void _register(String name, developer.ServiceExtensionHandler handler) {
  try {
    developer.registerExtension(name, handler);
  } on ArgumentError catch (e) {
    // Already registered by an earlier run of this isolate (hot restart).
    AppLogger.warning('Could not register $name: $e', tag: _tag);
  }
}
