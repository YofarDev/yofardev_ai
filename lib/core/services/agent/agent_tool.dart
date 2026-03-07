import '../../models/function_info.dart';

/// Abstract base class for all tools (functions) the agent can use.
abstract class AgentTool {
  /// The unique name of the tool (e.g., 'setAlarm').
  String get name;

  /// A description of what the tool does, used by the LLM.
  String get description;

  /// The parameters required by this tool.
  List<Parameter> get parameters;

  /// The configuration keys required by this tool from settings.
  /// Returns a map where keys are the setting keys (e.g., 'googleSearchKey')
  /// and values are the parameter names that will be used in execute().
  /// Tools that don't need any API keys should return an empty map.
  Map<String, String> get requiredConfigKeys;

  /// Executes the tool with the provided arguments and configuration values.
  ///
  /// [args] The arguments passed from the LLM function call.
  /// [configValues] A map of configuration values fetched from settings.
  /// The keys in this map match the values returned by [requiredConfigKeys].
  Future<dynamic> execute(
    Map<String, dynamic> args,
    Map<String, dynamic> configValues,
  );

  /// Converts this tool to the [FunctionInfo] format required by `LlmService`.
  ///
  /// Note: This creates a placeholder function that will be replaced during
  /// actual execution by the agent. The actual execution happens via the
  /// execute() method with the proper configValues parameter.
  FunctionInfo toFunctionInfo() {
    return FunctionInfo(
      name: name,
      description: description,
      parameters: parameters,
      function: (Map<String, dynamic> args) async {
        // This is a placeholder - actual execution is handled by YofardevAgent
        throw UnimplementedError(
          'FunctionInfo.function should not be called directly. '
          'Use AgentTool.execute() instead.',
        );
      },
    );
  }
}
