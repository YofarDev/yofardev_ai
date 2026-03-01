import os
import re

def fix_agent_imports(filepath):
    with open(filepath, 'r') as f:
        content = f.read()

    original = content

    # Fix function_info imports
    content = re.sub(r"import '\.\./\.\./models/llm/function_info'", "import '../../models/function_info'", content)

    # Fix agent_tool imports (already correct, but ensure consistency)
    # Fix services imports within agent directory
    content = re.sub(r"import '\.\./\.\./\.\./services/alarm_service", "import '../alarm_service'", content)
    content = re.sub(r"import '\.\./\.\./\.\./services/google_search_service", "import '../google_search_service'", content)
    content = re.sub(r"import '\.\./\.\./\.\./services/news_service", "import '../news_service'", content)
    content = re.sub(r"import '\.\./\.\./services/weather_service", "import '../weather_service'", content)

    # Fix utils imports
    content = re.sub(r"import '\.\./utils/extensions", "import '../../utils/extensions'", content)
    content = re.sub(r"import '\.\./utils/logger", "import '../../utils/logger'", content)

    # Fix sound_effects import
    content = re.sub(r"import '\.\./models/sound_effects", "import '../../models/sound_effects'", content)

    if content != original:
        with open(filepath, 'w') as f:
            f.write(content)
        return True
    return False

# Fix imports in lib/core/services/agent
count = 0
for root, dirs, files in os.walk('lib/core/services/agent'):
    for file in files:
        if file.endswith('.dart'):
            filepath = os.path.join(root, file)
            if fix_agent_imports(filepath):
                count += 1
                print(f"Fixed: {filepath}")

print(f"Total agent files fixed: {count}")
