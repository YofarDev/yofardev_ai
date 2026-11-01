import 'dart:ui' show Color;

import 'package:flutter/foundation.dart' show visibleForTesting;

import 'package:rive/rive.dart';

import '../../utils/logger.dart';

/// Property access layer for one bound Rive artboard.
///
/// The contract prefers data binding (`<Artboard>VM` view models); if a file
/// has no exported view model, or a property is missing from it, the same
/// property names are used against state-machine inputs instead (enum →
/// number = index, number → number, boolean → boolean, trigger → trigger).
/// Colors have no input equivalent: a missing color property is only logged.
/// This mirrors the fallback rule in `rive/CONTRACT.md` and keeps view code
/// free of runtime-version concerns.
///
/// Owns nothing but the resolved property handles: the caller owns the
/// [RiveWidgetController] and the [File]. Call [dispose] before disposing
/// those.
class RiveVmBinding {
  /// Creates a binding for [controller], attempting auto data binding once.
  RiveVmBinding(this.controller) {
    try {
      _viewModelInstance = controller.dataBind(DataBind.auto());
    } on RiveDataBindException catch (e, st) {
      AppLogger.debug(
        'Rive data binding unavailable, falling back to state machine '
        'inputs: ${e.message}',
        tag: _tag,
        error: e,
        stackTrace: st,
      );
      _viewModelInstance = null;
    }
  }

  static const String _tag = 'RiveVmBinding';

  final RiveWidgetController controller;

  ViewModelInstance? _viewModelInstance;

  /// Property handles resolved once per name, misses included (stored as
  /// null) so a missing property is not looked up again on every rebuild.
  /// Views push their state on every rebuild — the mouth alone changes many
  /// times a second while talking — so lookups must not repeat.
  final Map<String, ViewModelInstanceEnum?> _enums =
      <String, ViewModelInstanceEnum?>{};
  final Map<String, ViewModelInstanceNumber?> _numbers =
      <String, ViewModelInstanceNumber?>{};
  final Map<String, ViewModelInstanceBoolean?> _booleans =
      <String, ViewModelInstanceBoolean?>{};
  final Map<String, ViewModelInstanceColor?> _colors =
      <String, ViewModelInstanceColor?>{};
  final Map<String, ViewModelInstanceTrigger?> _triggers =
      <String, ViewModelInstanceTrigger?>{};
  // ignore: deprecated_member_use
  final Map<String, NumberInput?> _numberInputs = <String, NumberInput?>{};
  // ignore: deprecated_member_use
  final Map<String, BooleanInput?> _booleanInputs = <String, BooleanInput?>{};
  // ignore: deprecated_member_use
  final Map<String, TriggerInput?> _triggerInputs = <String, TriggerInput?>{};

  /// Last written values (an unchanged value is not written again) and the
  /// names already reported as missing (each is logged once).
  final RiveWriteMemo _memo = RiveWriteMemo();

  /// Sets an enum property by value name; falls back to the property index.
  void setEnum(String name, List<String> values, String value) {
    final int index = values.indexOf(value);
    if (index < 0) {
      if (_memo.firstReport('$name=$value')) {
        AppLogger.warning(
          'Unknown enum value "$value" for property "$name"',
          tag: _tag,
        );
      }
      return;
    }
    if (_memo.isUnchanged(name, value)) {
      return;
    }
    final ViewModelInstanceEnum? enumProperty = _enums.putIfAbsent(
      name,
      () => _viewModelInstance?.enumerator(name),
    );
    if (enumProperty != null) {
      enumProperty.value = value;
      _memo.record(name, value);
      return;
    }
    if (_writeNumberInput(name, index.toDouble())) {
      _memo.record(name, value);
    }
  }

  /// Sets a number property.
  void setNumber(String name, double value) {
    if (_memo.isUnchanged(name, value)) {
      return;
    }
    final ViewModelInstanceNumber? property = _numbers.putIfAbsent(
      name,
      () => _viewModelInstance?.number(name),
    );
    if (property != null) {
      property.value = value;
      _memo.record(name, value);
      return;
    }
    if (_writeNumberInput(name, value)) {
      _memo.record(name, value);
    }
  }

  /// The view model's number [name] as the file holds it now (null when it
  /// has no such property): a read-back, for the real-runtime tests.
  double? numberValue(String name) =>
      _numbers.putIfAbsent(name, () => _viewModelInstance?.number(name))?.value;

  /// The view model's colour [name] as the file holds it now (null when it
  /// has no such property): a read-back, for the in-app captures.
  Color? colorValue(String name) =>
      _colors.putIfAbsent(name, () => _viewModelInstance?.color(name))?.value;

  /// The view model's enum [name] as the file holds it now (its value name;
  /// null when it has no such property): a read-back, for the in-app
  /// captures.
  String? enumValue(String name) => _enums
      .putIfAbsent(name, () => _viewModelInstance?.enumerator(name))
      ?.value;

  /// Sets a boolean property; falls back to a boolean state-machine input.
  void setBool(String name, bool value) {
    if (_memo.isUnchanged(name, value)) {
      return;
    }
    final ViewModelInstanceBoolean? property = _booleans.putIfAbsent(
      name,
      () => _viewModelInstance?.boolean(name),
    );
    if (property != null) {
      property.value = value;
      _memo.record(name, value);
      return;
    }
    // ignore: deprecated_member_use
    final BooleanInput? input = _booleanInputs.putIfAbsent(
      name,
      // ignore: deprecated_member_use
      () => controller.stateMachine.boolean(name),
    );
    if (input != null) {
      input.value = value;
      _memo.record(name, value);
      return;
    }
    _reportMissing(name, 'boolean');
  }

  /// Sets a color property. State machines have no color input, so a file
  /// without the view-model property only gets a one-time log.
  void setColor(String name, Color value) {
    if (_memo.isUnchanged(name, value)) {
      return;
    }
    final ViewModelInstanceColor? property = _colors.putIfAbsent(
      name,
      () => _viewModelInstance?.color(name),
    );
    if (property != null) {
      property.value = value;
      _memo.record(name, value);
      return;
    }
    _reportMissing(name, 'color');
  }

  /// Contract fallback: the same names as state-machine inputs when the file
  /// ships no view model (CONTRACT.md). The inputs API is deprecated but is
  /// the documented fallback path.
  bool _writeNumberInput(String name, double value) {
    // ignore: deprecated_member_use
    final NumberInput? input = _numberInputs.putIfAbsent(
      name,
      // ignore: deprecated_member_use
      () => controller.stateMachine.number(name),
    );
    if (input != null) {
      input.value = value;
      return true;
    }
    _reportMissing(name, 'number');
    return false;
  }

  /// Fires a trigger property.
  void fireTrigger(String name) {
    final ViewModelInstanceTrigger? property = _triggers.putIfAbsent(
      name,
      () => _viewModelInstance?.trigger(name),
    );
    if (property != null) {
      property.trigger();
      _fired++;
      return;
    }
    // ignore: deprecated_member_use
    final TriggerInput? input = _triggerInputs.putIfAbsent(
      name,
      // ignore: deprecated_member_use
      () => controller.stateMachine.trigger(name),
    );
    if (input != null) {
      input.fire();
      _fired++;
      return;
    }
    _reportMissing(name, 'trigger');
  }

  /// How many writes reached the artboard so far: values that changed, and
  /// fired triggers. Compare before and after a push to know whether it
  /// changed anything.
  int get writes => _memo.writes + _fired;
  int _fired = 0;

  /// Whether the view model could be bound at all.
  bool get hasViewModel => _viewModelInstance != null;

  /// The bound view model instance, for reading values back in tests.
  @visibleForTesting
  ViewModelInstance? get viewModelInstance => _viewModelInstance;

  void _reportMissing(String name, String kind) {
    if (_memo.firstReport(name)) {
      AppLogger.warning('Rive property "$name" not found ($kind).', tag: _tag);
    }
  }

  /// Disposes the resolved property handles and the bound view model
  /// instance. The controller and file stay owned by the caller.
  void dispose() {
    for (final ViewModelInstanceValue? property in <ViewModelInstanceValue?>[
      ..._enums.values,
      ..._numbers.values,
      ..._booleans.values,
      ..._colors.values,
      ..._triggers.values,
    ]) {
      property?.dispose();
    }
    _enums.clear();
    _numbers.clear();
    _booleans.clear();
    _colors.clear();
    _triggers.clear();
    _numberInputs.clear();
    _booleanInputs.clear();
    _triggerInputs.clear();
    _memo.clearValues();
    _viewModelInstance = null;
  }
}

/// The runtime-independent bookkeeping of [RiveVmBinding]: which value was
/// last written per property name, and which keys were already reported.
@visibleForTesting
class RiveWriteMemo {
  final Map<String, Object> _lastValues = <String, Object>{};
  final Set<String> _reported = <String>{};

  /// Whether [value] is the value last [record]ed for [name].
  bool isUnchanged(String name, Object value) => _lastValues[name] == value;

  /// Remembers [value] as written for [name].
  void record(String name, Object value) {
    _lastValues[name] = value;
    writes++;
  }

  /// How many values were actually written (unchanged pushes are skipped),
  /// so a caller can tell whether a push changed anything.
  int writes = 0;

  /// True the first time [key] is seen, false afterwards (log once).
  bool firstReport(String key) => _reported.add(key);

  /// Forgets the written values; reported keys stay reported.
  void clearValues() => _lastValues.clear();
}
