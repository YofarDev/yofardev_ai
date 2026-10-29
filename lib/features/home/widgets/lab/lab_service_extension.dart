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
const Set<String> _jsonKeys = <String>{'face', 'parallax'};

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

developer.ServiceExtensionResponse _ok(LabConfig config, [double? rain]) =>
    developer.ServiceExtensionResponse.result(
      jsonEncode(<String, Object?>{...config.toJson(), _rainKey: ?rain}),
    );

/// The world-state param: not part of [LabConfig], it goes to
/// [WorldStateService.setRain].
const String _rainKey = 'rain';

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
/// `prop` is `none`, `tablet` or `newspaper`; `parallax` is
/// `{"x":0.5,"y":-0.2}` (each -1..1) or `null`. `rain` is a number in 0..1
/// handed to [world] ([WorldStateService.setRain]); it is rejected when no
/// [world] is given and, like any invalid input, leaves the config alone.
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
    final String? rainParam = configParams.remove(_rainKey);
    double? rain;
    if (rainParam != null) {
      rain = double.tryParse(rainParam);
      if (rain == null || rain < 0 || rain > 1) {
        throw FormatException(
          '"rain" must be a number in 0..1, got "$rainParam"',
        );
      }
      if (world == null) {
        throw const FormatException('"rain" needs the world state service');
      }
    }
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
    return _ok(next, world?.rain.value);
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
  return _ok(notifier.value, world?.rain.value);
}

/// Makes [config] the lab the debug service extensions drive, registering the
/// extensions on first use. `registerExtension` throws when a name is
/// registered twice in an isolate, so registration happens once per isolate
/// and calls are routed to the currently mounted notifier. No-op outside
/// debug builds. [world] receives the `rain` param.
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
