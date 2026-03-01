import os
import re

def fix_imports(filepath):
    with open(filepath, 'r') as f:
        content = f.read()

    original = content

    # Fix llm subdirectory imports - files moved out of llm/ subdirectory
    content = re.sub(r"import '\.\./\.\./models/llm/function_info'", "import '../../models/function_info'", content)
    content = re.sub(r"import '\.\./\.\./models/llm/llm_message'", "import '../../models/llm_message'", content)
    content = re.sub(r"import '\.\./\.\./models/llm/llm_config'", "import '../../models/llm_config'", content)

    # Fix services imports
    content = re.sub(r"import '\.\./\.\./\.\./services/fake_llm_service", "import '../llm/fake_llm_service", content)
    content = re.sub(r"import '\.\./\.\./services/llm_service", "import '../llm/llm_service", content)
    content = re.sub(r"import '\.\./\.\./services/chat_history_service", "import '../chat_history_service", content)
    content = re.sub(r"import '\.\./\.\./services/settings_service", "import '../settings_service", content)
    content = re.sub(r"import '\.\./\.\./services/tts_service", "import '../tts_service", content)

    # Fix agent imports
    content = re.sub(r"import '\.\./\.\./logic/agent/yofardev_agent", "import '../agent/yofardev_agent", content)
    content = re.sub(r"import '\.\./\.\./logic/agent/tool_registry", "import '../agent/tool_registry", content)

    # Fix utils imports
    content = re.sub(r"import '\.\./\.\./\.\./utils/", "import '../../utils/", content)
    content = re.sub(r'import "\.\./\.\./\.\./utils/', 'import "../../utils/', content)
    content = re.sub(r"import '\.\./\.\./utils/", "import '../../utils/", content)

    if content != original:
        with open(filepath, 'w') as f:
            f.write(content)
        return True
    return False

# Fix imports in lib
count = 0
for root, dirs, files in os.walk('lib'):
    for file in files:
        if file.endswith('.dart'):
            filepath = os.path.join(root, file)
            if fix_imports(filepath):
                count += 1
                print(f"Fixed: {filepath}")

print(f"Total files fixed: {count}")
