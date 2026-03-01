import '../../models/function_info.dart';

import 'agent_tool.dart';
import 'alarm_tool.dart';
import 'calculator_tool.dart';
import 'character_counter_tool.dart';
import 'google_search_tool.dart';
import 'news_tool.dart';
import 'weather_tool.dart';
import 'web_reader_tool.dart';

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
