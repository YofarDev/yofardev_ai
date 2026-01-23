import '../logic/agent/tool_registry.dart';
import '../models/llm/function_info.dart';

class FunctionsHelper {
  static List<FunctionInfo> get getFunctions => ToolRegistry.functionInfos;
}
