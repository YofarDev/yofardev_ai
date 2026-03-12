import 'package:freezed_annotation/freezed_annotation.dart';

part 'function_info.freezed.dart';

typedef FunctionCallback = Future<dynamic> Function(Map<String, dynamic> args);

@freezed
sealed class FunctionInfo with _$FunctionInfo {
  const FunctionInfo._();

  const factory FunctionInfo({
    required String name,
    required String description,
    required List<Parameter> parameters,
    required FunctionCallback function,
    Map<String, dynamic>? parametersCalled,
  }) = _FunctionInfo;
}

@freezed
sealed class Parameter with _$Parameter {
  const Parameter._();

  const factory Parameter({
    required String name,
    required String description,
    required String type,
    @Default(true) bool isRequired,
  }) = _Parameter;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{'type': type, 'description': description};
  }
}
