import 'package:freezed_annotation/freezed_annotation.dart';

part '{{FEATURE_SNAKE}}.freezed.dart';

@freezed
sealed class {{FEATURE_PASCAL}} with _${{FEATURE_PASCAL}} {
  const factory {{FEATURE_PASCAL}}({
    required String id,
    @Default('') String name,
  }) = _{{FEATURE_PASCAL}};
}
