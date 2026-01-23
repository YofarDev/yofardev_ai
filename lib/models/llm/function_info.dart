typedef FunctionCallback = Future<dynamic> Function(Map<String, dynamic> args);

class FunctionInfo {
  final String name;
  final String description;
  final List<Parameter> parameters;
  final FunctionCallback function;
  final Map<String, dynamic>? parametersCalled;

  FunctionInfo({
    required this.name,
    required this.description,
    required this.parameters,
    required this.function,
    this.parametersCalled,
  });
}

class Parameter {
  final String name;
  final String description;
  final String type; // 'string', 'number', 'boolean'
  final bool isRequired;

  Parameter({
    required this.name,
    required this.description,
    required this.type,
    this.isRequired = true,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'type': type,
      'description': description,
    };
  }
}
