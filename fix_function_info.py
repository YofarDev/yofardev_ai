import os
import glob

# Fix all files in lib/core/services/agent
pattern = os.path.join('lib/core/services/agent', '*.dart')
files = glob.glob(pattern)

for filepath in files:
    with open(filepath, 'r') as f:
        content = f.read()

    original = content

    # Fix function_info imports
    content = content.replace("import '../../models/llm/function_info.dart'", "import '../../models/function_info.dart'")
    content = content.replace("import '../../../models/llm/function_info.dart'", "import '../../models/function_info.dart'")

    if content != original:
        with open(filepath, 'w') as f:
            f.write(content)
        print(f"Fixed: {filepath}")

print("Done fixing function_info imports")
