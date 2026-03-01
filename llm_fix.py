import os

def fix_file(filepath, replacements):
    """Apply replacements to a file"""
    try:
        with open(filepath, 'r') as f:
            content = f.read()

        original = content

        for pattern, replacement in replacements:
            content = content.replace(pattern, replacement)

        if content != original:
            with open(filepath, 'w') as f:
                f.write(content)
            return True
        return False
    except Exception as e:
        print(f"Error: {e}")
        return False

# Fix tool_registry
fix_file('lib/core/services/agent/tool_registry.dart', [
    "import 'tools/alarm_tool.dart'", "import 'alarm_tool.dart'",
    "import 'tools/calculator_tool.dart'", "import 'calculator_tool.dart'",
    "import 'tools/character_counter_tool.dart'", "import 'character_counter_tool.dart'",
    "import 'tools/google_search_tool.dart'", "import 'google_search_tool.dart'",
    "import 'tools/news_tool.dart'", "import 'news_tool.dart'",
    "import 'tools/weather_tool.dart'", "import 'weather_tool.dart'",
    "import 'tools/web_reader_tool.dart'", "import 'web_reader_tool.dart'",
])
print("Fixed: tool_registry.dart")

# Fix yofardev_agent - remove llm/ subdirectory from paths
fix_file('lib/core/services/agent/yofardev_agent.dart', [
    "import '../../models/llm/llm_config.dart'", "import '../../models/llm_config.dart'",
    "import '../../models/llm/llm_message.dart'", "import '../../models/llm_message.dart'",
])
print("Fixed: yofardev_agent.dart")

# Fix all LLM service files
llm_files = [
    'lib/core/services/llm/fake_llm_service.dart',
    'lib/core/services/llm/llm_service.dart',
    'lib/core/services/llm/llm_api_helper.dart',
    'lib/core/services/llm/llm_function_calling.dart',
    'lib/core/services/llm/llm_service_interface.dart',
]

for llm_file in llm_files:
    if os.path.exists(llm_file):
        fix_file(llm_file, [
            "import '../../models/llm/function_info.dart'", "import '../../models/function_info.dart'",
            "import '../../models/llm/llm_config.dart'", "import '../../models/llm_config.dart'",
            "import '../../models/llm/llm_message.dart'", "import '../../models/llm_message.dart'",
        ])
        print(f"Fixed: {llm_file}")

# Fix chat_history_service - remove extra ../core/
fix_file('lib/core/services/chat_history_service.dart', [
    "import '../core/models/avatar_config.dart'", "import '../models/avatar_config.dart'",
])
print("Fixed: chat_history_service.dart")

# Fix demo_service - fix all the paths
fix_file('lib/core/services/demo_service.dart', [
    "import '../features/avatar/bloc/avatar_cubit.dart'", "import '../../features/avatar/bloc/avatar_cubit.dart'",
    "import '../features/chat/bloc/chats_cubit.dart'", "import '../../features/chat/bloc/chats_cubit.dart'",
    "import '../core/models/avatar_config.dart'", "import '../../models/avatar_config.dart'",
    "import '../models/demo_script.dart'", "import '../../features/demo/models/demo_script.dart'",
    "import '../services/fake_llm_service.dart'", "import '../llm/fake_llm_service.dart'",
])
print("Fixed: demo_service.dart")

# Fix yofardev_repository - fix demo_script path
fix_file('lib/core/repositories/yofardev_repository.dart', [
    "import '../models/demo_script.dart'", "import '../../features/demo/models/demo_script.dart'",
])
print("Fixed: yofardev_repository.dart")

print("\nAll LLM and service imports fixed!")
