import os
import re
import glob

def fix_all_imports():
    """Fix all import paths across the codebase"""

    # Pattern: fix broken imports where .dart was moved outside quotes
    broken_import_pattern = re.compile(r"import '([^']+)'\.dart'")

    fixed_count = 0

    # Walk through all dart files
    for root, dirs, files in os.walk('lib'):
        for file in files:
            if not file.endswith('.dart'):
                continue

            filepath = os.path.join(root, file)

            try:
                with open(filepath, 'r') as f:
                    content = f.read()

                original = content

                # Fix broken imports like import '../service'.dart';
                def fix_broken_import(match):
                    return f"import '{match.group(1)}.dart'"

                content = broken_import_pattern.sub(fix_broken_import, content)

                if content != original:
                    with open(filepath, 'w') as f:
                        f.write(content)
                    fixed_count += 1
                    print(f"Fixed: {filepath}")

            except Exception as e:
                print(f"Error processing {filepath}: {e}")

    print(f"\nTotal files fixed: {fixed_count}")

def fix_duplicate_demo_script():
    """Fix the duplicate FakeLlmResponse issue"""

    # Check if there are two demo_script.dart files
    core_demo = 'lib/core/models/demo_script.dart'
    feature_demo = 'lib/features/demo/models/demo_script.dart'

    if os.path.exists(core_demo) and os.path.exists(feature_demo):
        print(f"\nFound duplicate demo_script.dart files:")
        print(f"  - {core_demo}")
        print(f"  - {feature_demo}")
        print("Removing core version, keeping feature version...")

        os.remove(core_demo)
        print("Removed core version")

if __name__ == '__main__':
    print("=== Starting comprehensive fix ===\n")
    fix_all_imports()
    fix_duplicate_demo_script()
    print("\n=== Fix complete ===")
