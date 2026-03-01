import os

# Agent tools are in lib/core/services/agent/
# They need to import from the same directory without ../

agent_tools = [
    'lib/core/services/agent/alarm_tool.dart',
    'lib/core/services/agent/calculator_tool.dart',
    'lib/core/services/agent/character_counter_tool.dart',
    'lib/core/services/agent/google_search_tool.dart',
    'lib/core/services/agent/news_tool.dart',
    'lib/core/services/agent/weather_tool.dart',
    'lib/core/services/agent/web_reader_tool.dart',
]

for tool in agent_tools:
    if os.path.exists(tool):
        with open(tool, 'r') as f:
            content = f.read()

        original = content

        # Remove ../ prefix from imports that are in the same directory
        content = content.replace("import '../alarm_service.dart'", "import 'alarm_service.dart'")
        content = content.replace("import '../agent_tool.dart'", "import 'agent_tool.dart'")
        content = content.replace("import '../google_search_service.dart'", "import 'google_search_service.dart'")
        content = content.replace("import '../news_service.dart'", "import 'news_service.dart'")
        content = content.replace("import '../weather_service.dart'", "import 'weather_service.dart'")
        content = content.replace("import '../web_reader_tool.dart'", "import 'web_reader_tool.dart'")
        content = content.replace("import '../../../services/weather_service.dart'", "import 'weather_service.dart'")
        content = content.replace("import '../../../services/google_search_service.dart'", "import 'google_search_service.dart'")
        content = content.replace("import '../../../services/news_service.dart'", "import 'news_service.dart'")
        content = content.replace("import '../../../services/web_reader_service.dart'", "import 'web_reader_tool.dart'")

        if content != original:
            with open(tool, 'w') as f:
                f.write(content)
            print(f"Fixed: {tool}")

print("Fixed all agent tools!")
