import 'dart:developer' as developer;

import 'package:flutter/foundation.dart' show visibleForTesting;

import 'package:rive/rive.dart';

/// Property access layer for one bound Rive artboard.
///
/// The contract prefers data binding (`<Artboard>VM` view models); if a file
/// has no exported view model, or a property is missing from it, the same
/// property names are used against state-machine inputs instead (enum →
/// number = index, trigger → trigger). This mirrors the fallback rule in
/// `rive/CONTRACT.md` and keeps view code free of runtime-version concerns.
///
/// Owns nothing but the resolved property handles: the caller owns the
/// [RiveWidgetController] and the [File]. Call [dispose] before disposing
/// those.
class AvatarRiveBinding {
  /// Creates a binding for [controller], attempting auto data binding once.
  AvatarRiveBinding(this.controller) {
    try {
      _viewModelInstance = controller.dataBind(DataBind.auto());
    } on RiveDataBindException catch (e, st) {
      developer.log(
        'Rive data binding unavailable, falling back to state machine '
        'inputs: ${e.message}',
        error: e,
        stackTrace: st,
      );
      _viewModelInstance = null;
    }
  }

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
  final Map<String, ViewModelInstanceTrigger?> _triggers =
      <String, ViewModelInstanceTrigger?>{};
  // ignore: deprecated_member_use
  final Map<String, NumberInput?> _numberInputs = <String, NumberInput?>{};
  // ignore: deprecated_member_use
  final Map<String, TriggerInput?> _triggerInputs = <String, TriggerInput?>{};

  /// Last value written per property name; an unchanged value is not
  /// written again.
  final Map<String, Object> _lastValues = <String, Object>{};

  /// Names already reported as missing, so each is logged once.
  final Set<String> _reportedMissing = <String>{};

  /// Sets an enum property by value name; falls back to the property index.
  void setEnum(String name, List<String> values, String value) {
    final int index = values.indexOf(value);
    if (index < 0) {
      developer.log('Unknown enum value "$value" for property "$name"');
      return;
    }
    if (_lastValues[name] == value) {
      return;
    }
    final ViewModelInstanceEnum? enumProperty = _enums.putIfAbsent(
      name,
      () => _viewModelInstance?.enumerator(name),
    );
    if (enumProperty != null) {
      enumProperty.value = value;
      _lastValues[name] = value;
      return;
    }
    if (_writeNumberInput(name, index.toDouble())) {
      _lastValues[name] = value;
    }
  }

  /// Sets a number property.
  void setNumber(String name, double value) {
    if (_lastValues[name] == value) {
      return;
    }
    final ViewModelInstanceNumber? property = _numbers.putIfAbsent(
      name,
      () => _viewModelInstance?.number(name),
    );
    if (property != null) {
      property.value = value;
      _lastValues[name] = value;
      return;
    }
    if (_writeNumberInput(name, value)) {
      _lastValues[name] = value;
    }
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
      return;
    }
    _reportMissing(name, 'trigger');
  }

  /// Whether the view model could be bound at all.
  bool get hasViewModel => _viewModelInstance != null;

  /// The bound view model instance, for reading values back in tests.
  @visibleForTesting
  ViewModelInstance? get viewModelInstance => _viewModelInstance;

  void _reportMissing(String name, String kind) {
    if (_reportedMissing.add(name)) {
      developer.log('Rive property "$name" not found ($kind).');
    }
  }

  /// Disposes the resolved property handles and the bound view model
  /// instance. The controller and file stay owned by the caller.
  void dispose() {
    for (final ViewModelInstanceValue? property in <ViewModelInstanceValue?>[
      ..._enums.values,
      ..._numbers.values,
      ..._triggers.values,
    ]) {
      property?.dispose();
    }
    _enums.clear();
    _numbers.clear();
    _triggers.clear();
    _numberInputs.clear();
    _triggerInputs.clear();
    _lastValues.clear();
    _viewModelInstance = null;
  }
}
