import 'package:freezed_annotation/freezed_annotation.dart';

part 'function_info.freezed.dart';

typedef FunctionCallback = Future<dynamic> Function(Map<String, dynamic> args);

extension FunctionInfoTools on List<FunctionInfo> {
  /// Converts to the OpenAI `tools` request format (shared by the non-streamed
  /// tool check and the streamed request body).
  List<Map<String, dynamic>> toOpenAiTools() {
    return map((FunctionInfo f) {
      return <String, dynamic>{
        'type': 'function',
        'function': <String, dynamic>{
          'name': f.name,
          'description': f.description,
          'parameters': <String, dynamic>{
            'type': 'object',
            'properties': Map<String, dynamic>.fromEntries(
              f.parameters.map(
                (Parameter p) => MapEntry<String, dynamic>(p.name, p.toMap()),
              ),
            ),
            'required': f.parameters
                .where((Parameter p) => p.isRequired)
                .map((Parameter p) => p.name)
                .toList(),
          },
        },
      };
    }).toList();
  }
}

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
