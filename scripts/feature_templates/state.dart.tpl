library;

import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/models/failure.dart';
import '../../domain/models/{{FEATURE_SNAKE}}.dart';

part '{{FEATURE_SNAKE}}_state.freezed.dart';

/// Union-state idiom for a load-lifecycle screen — see the
/// flutter-architecture skill for when to use this vs a flat state.
/// The error state carries the typed Failure, not a message: the UI derives
/// text at build time via core/l10n/failure_localization.dart.
@freezed
sealed class {{FEATURE_PASCAL}}State with _${{FEATURE_PASCAL}}State {
  const factory {{FEATURE_PASCAL}}State.initial() = _Initial;
  const factory {{FEATURE_PASCAL}}State.loading() = _Loading;
  const factory {{FEATURE_PASCAL}}State.loaded({{FEATURE_PASCAL}} data) = _Loaded;
  const factory {{FEATURE_PASCAL}}State.error({required Failure failure}) = _Error;
}
