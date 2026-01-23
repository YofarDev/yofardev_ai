import '../../models/llm/function_info.dart';

import 'agent_tool.dart';
import 'tools/alarm_tool.dart';
import 'tools/calculator_tool.dart';
import 'tools/character_counter_tool.dart';
import 'tools/google_search_tool.dart';
import 'tools/news_tool.dart';
import 'tools/weather_tool.dart';
import 'tools/web_reader_tool.dart';

export 'agent_tool.dart';

class ToolRegistry {
  static final List<AgentTool> _tools = <AgentTool>[
    AlarmTool(),
    WeatherTool(),
    NewsTool(),
    CharacterCounterTool(),
    CalculatorTool(),
    GoogleSearchTool(),
    WebReaderTool(),
  ];

  static List<AgentTool> get tools => List<AgentTool>.unmodifiable(_tools);

  static AgentTool? getTool(String name) {
    try {
      return _tools.firstWhere((AgentTool tool) => tool.name == name);
    } catch (_) {
      return null;
    }
  }

  /// Returns the list of FunctionInfo for LlmService
  static List<FunctionInfo> get functionInfos {
    return _tools.map((AgentTool t) => t.toFunctionInfo()).toList();
  }
}
