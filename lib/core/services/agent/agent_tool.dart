import '../../models/function_info.dart';

/// Abstract base class for all tools (functions) the agent can use.
abstract class AgentTool {
  /// The unique name of the tool (e.g., 'setAlarm').
  String get name;

  /// A description of what the tool does, used by the LLM.
  String get description;

  /// The parameters required by this tool.
  List<Parameter> get parameters;

  /// Executes the tool with the provided arguments.
  Future<dynamic> execute(Map<String, dynamic> args);

  /// Converts this tool to the [FunctionInfo] format required by `LlmService`.
  FunctionInfo toFunctionInfo() {
    return FunctionInfo(
      name: name,
      description: description,
      parameters: parameters,
      function: (Map<String, dynamic> args) => execute(args),
    );
  }
}
