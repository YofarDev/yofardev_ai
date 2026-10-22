import 'dart:developer' as developer;

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

  final List<ViewModelInstanceValue> _resolvedProperties =
      <ViewModelInstanceValue>[];

  /// Sets an enum property by value name; falls back to the property index.
  void setEnum(String name, List<String> values, String value) {
    final int index = values.indexOf(value);
    if (index < 0) {
      developer.log('Unknown enum value "$value" for property "$name"');
      return;
    }
    final ViewModelInstanceEnum? enumProperty = _resolve(
      () => _viewModelInstance?.enumerator(name),
    );
    if (enumProperty != null) {
      enumProperty.value = value;
      return;
    }
    _setNumber(name, index.toDouble());
  }

  /// Sets a number property.
  void setNumber(String name, double value) => _setNumber(name, value);

  void _setNumber(String name, double value) {
    final ViewModelInstanceNumber? property = _resolve(
      () => _viewModelInstance?.number(name),
    );
    if (property != null) {
      property.value = value;
      return;
    }
    // Contract fallback: the same names as state-machine inputs when the file
    // ships no view model (CONTRACT.md). The inputs API is deprecated but is
    // the documented fallback path.
    // ignore: deprecated_member_use
    final NumberInput? input = _resolve(
      // ignore: deprecated_member_use
      () => controller.stateMachine.number(name),
    );
    if (input != null) {
      input.value = value;
      return;
    }
    developer.log('Rive property "$name" not found (number).');
  }

  /// Fires a trigger property.
  void fireTrigger(String name) {
    final ViewModelInstanceTrigger? property = _resolve(
      () => _viewModelInstance?.trigger(name),
    );
    if (property != null) {
      property.trigger();
      return;
    }
    // ignore: deprecated_member_use
    final TriggerInput? input = _resolve(
      // ignore: deprecated_member_use
      () => controller.stateMachine.trigger(name),
    );
    if (input != null) {
      input.fire();
      return;
    }
    developer.log('Rive property "$name" not found (trigger).');
  }

  /// Whether the view model could be bound at all.
  bool get hasViewModel => _viewModelInstance != null;

  T? _resolve<T>(T? Function() resolve) {
    final T? property = resolve();
    if (property != null && property is ViewModelInstanceValue) {
      _resolvedProperties.add(property);
    }
    return property;
  }

  /// Disposes the resolved property handles and the bound view model
  /// instance. The controller and file stay owned by the caller.
  void dispose() {
    for (final ViewModelInstanceValue property in _resolvedProperties) {
      property.dispose();
    }
    _resolvedProperties.clear();
    _viewModelInstance = null;
  }
}
