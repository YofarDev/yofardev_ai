import '../services/agent/tool_registry.dart';
import '../models/function_info.dart';

class FunctionsHelper {
  static List<FunctionInfo> get getFunctions => ToolRegistry.functionInfos;
}
