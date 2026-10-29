// ignore-l10n: debug — the UI lab is debug-only; its strings are hardcoded.
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

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
const Set<String> _jsonKeys = <String>{'face'};

/// Params the VM service adds to every call; never part of the config.
const Set<String> _vmParams = <String>{'isolateId'};

bool _registered = false;
ValueNotifier<LabConfig>? _active;

/// The config of the lab currently mounted, or null. Exposed for tests.
@visibleForTesting
ValueNotifier<LabConfig>? get activeUiLabConfig => _active;

developer.ServiceExtensionResponse _error(String message) {
  return developer.ServiceExtensionResponse.error(
    developer.ServiceExtensionResponse.extensionError,
    jsonEncode(<String, String>{'message': message}),
  );
}

developer.ServiceExtensionResponse _ok(LabConfig config) =>
    developer.ServiceExtensionResponse.result(jsonEncode(config.toJson()));

/// Converts service-extension string params into [LabConfig] JSON values:
/// numeric keys become numbers (`null`/empty clears an override), boolean
/// keys take `true`/`false`, `face` is decoded as JSON (`null`/empty goes
/// back to the live face), the rest stay strings. Throws [FormatException]
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
developer.ServiceExtensionResponse labConfigureResponse(
  ValueNotifier<LabConfig>? notifier,
  Map<String, String> params,
) {
  if (notifier == null) {
    return _error('No UI lab is mounted. Open it first.');
  }
  try {
    final Map<String, Object?> json = _paramsToJson(params);
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
    return _ok(next);
  } on FormatException catch (e) {
    return _error(e.message);
  }
}

/// Handler of [uiLabStateExtension]: the current config as JSON.
developer.ServiceExtensionResponse labStateResponse(
  ValueNotifier<LabConfig>? notifier,
) {
  if (notifier == null) {
    return _error('No UI lab is mounted. Open it first.');
  }
  return _ok(notifier.value);
}

/// Makes [config] the lab the debug service extensions drive, registering the
/// extensions on first use. `registerExtension` throws when a name is
/// registered twice in an isolate, so registration happens once per isolate
/// and calls are routed to the currently mounted notifier. No-op outside
/// debug builds.
void registerUiLabExtensions(ValueNotifier<LabConfig> config) {
  if (!kDebugMode) {
    return;
  }
  _active = config;
  if (_registered) {
    return;
  }
  _registered = true;
  _register(
    uiLabConfigureExtension,
    (String method, Map<String, String> params) async =>
        labConfigureResponse(_active, params),
  );
  _register(
    uiLabStateExtension,
    (String method, Map<String, String> params) async =>
        labStateResponse(_active),
  );
}

/// Detaches [config] from the extensions, unless a newer lab already took
/// over.
void unregisterUiLabExtensions(ValueNotifier<LabConfig> config) {
  if (identical(_active, config)) {
    _active = null;
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
