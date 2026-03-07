import '../../models/function_info.dart';
import '../../../features/settings/domain/repositories/settings_repository.dart';

/// Abstract base class for all tools (functions) the agent can use.
abstract class AgentTool {
  /// The unique name of the tool (e.g., 'setAlarm').
  String get name;

  /// A description of what the tool does, used by the LLM.
  String get description;

  /// The parameters required by this tool.
  List<Parameter> get parameters;

  /// Executes the tool with the provided arguments.
  Future<dynamic> execute(
    Map<String, dynamic> args, {
    required SettingsRepository settingsRepository,
  });

  /// Converts this tool to the [FunctionInfo] format required by `LlmService`.
  ///
  /// Note: This creates a placeholder function that will be replaced during
  /// actual execution by the agent. The actual execution happens via the
  /// execute() method with the proper settingsRepository parameter.
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
