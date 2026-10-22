import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/models/{{FEATURE_SNAKE}}.dart';

part '{{FEATURE_SNAKE}}_dto.freezed.dart';
part '{{FEATURE_SNAKE}}_dto.g.dart';

/// Transport representation. The domain model does not know this class
/// exists: serialization and transport-specific shapes stay in the data
/// layer. Keep the conversion total and guarded — malformed payloads must
/// surface as typed failures at the repository boundary, never as exceptions
/// escaping into the domain.
@freezed
sealed class {{FEATURE_PASCAL}}Dto with _${{FEATURE_PASCAL}}Dto {
  const factory {{FEATURE_PASCAL}}Dto({
    required String id,
    required String name,
  }) = _{{FEATURE_PASCAL}}Dto;

  factory {{FEATURE_PASCAL}}Dto.fromJson(Map<String, dynamic> json) =>
      _${{FEATURE_PASCAL}}DtoFromJson(json);

  const {{FEATURE_PASCAL}}Dto._();

  {{FEATURE_PASCAL}} toDomain() {
    return {{FEATURE_PASCAL}}(
      id: id,
      name: name,
    );
  }
}
