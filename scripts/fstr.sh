#!/usr/bin/env bash

# Add localized strings to Flutter .arb files and regenerate localization files
# Usage: add-l10n-string <keyName> <frString> <enString> [projectPath]
#
# Validates that the FR and EN strings use the same {placeholders} before
# touching either file (gen-l10n rejects mismatches), writes both arb files,
# then regenerates. Requires: uv, flutter.

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check arguments
if [ $# -lt 3 ]; then
    echo "Usage: add-l10n-string <keyName> <frString> <enString> [projectPath]"
    echo ""
    echo "Arguments:"
    echo "  keyName     - The localization key (camelCase, e.g., dashboardWelcome)"
    echo "  frString    - French translation (source of truth)"
    echo "  enString    - English translation"
    echo "  projectPath - Optional path to Flutter project (defaults to current directory)"
    echo ""
    echo "Example:"
    echo "  add-l10n-string myNewKey \"Bonjour\" \"Hello\""
    echo "  add-l10n-string myNewKey \"Bonjour\" \"Hello\" /path/to/project"
    exit 1
fi

KEY_NAME="$1"
FR_STRING="$2"
EN_STRING="$3"
PROJECT_PATH="${4:-.}"

# Resolve to absolute path
PROJECT_PATH=$(cd "$PROJECT_PATH" 2>/dev/null && pwd) || {
    echo -e "${RED}Error: Project path '$PROJECT_PATH' does not exist${NC}"
    exit 1
}

L10N_DIR="$PROJECT_PATH/lib/core/l10n"
FR_FILE="$L10N_DIR/app_localizations_fr.arb"
EN_FILE="$L10N_DIR/app_localizations_en.arb"

# Check if files exist
if [ ! -f "$FR_FILE" ]; then
    echo -e "${RED}Error: French ARB file not found at $FR_FILE${NC}"
    exit 1
fi

if [ ! -f "$EN_FILE" ]; then
    echo -e "${RED}Error: English ARB file not found at $EN_FILE${NC}"
    exit 1
fi

# Validate + add the key to both files. Nothing is written unless both files
# parse as strict JSON (no trailing commas, no duplicate keys), both roots are
# JSON objects, the key is absent from BOTH files, and the placeholder sets of
# FR/EN match. Each destination is then replaced from a staged temp file
# beside it — the two replacements are not a single atomic transaction, but a
# failure during preparation leaves both files untouched.
export ARB_FR_FILE="$FR_FILE"
export ARB_EN_FILE="$EN_FILE"
export ARB_KEY="$KEY_NAME"
export ARB_FR_VALUE="$FR_STRING"
export ARB_EN_VALUE="$EN_STRING"

echo -e "${BLUE}Validating and adding '$KEY_NAME'...${NC}"
uv run python - <<'EOF'
import json
import os
import re
import sys
import tempfile

fr_file = os.environ['ARB_FR_FILE']
en_file = os.environ['ARB_EN_FILE']
key = os.environ['ARB_KEY']
fr_value = os.environ['ARB_FR_VALUE']
en_value = os.environ['ARB_EN_VALUE']

def fail(msg):
    print(f"\n\033[0;31m[!] {msg}\033[0m", file=sys.stderr)
    sys.exit(1)

def placeholders(s):
    return sorted(set(re.findall(r"\{[a-zA-Z_][a-zA-Z0-9_]*\}", s)))

# Key must be a valid Dart identifier (gen-l10n generates a getter from it)
if not re.fullmatch(r"[a-z][a-zA-Z0-9]*", key):
    fail(f"Key '{key}' must be lowerCamelCase (e.g., dashboardWelcome).")

# FR and EN must use identical placeholders, or gen-l10n will fail later
if placeholders(fr_value) != placeholders(en_value):
    fail(
        "Placeholder mismatch between FR and EN strings:\n"
        f"    FR: {placeholders(fr_value) or 'none'}\n"
        f"    EN: {placeholders(en_value) or 'none'}"
    )

class DuplicateKeyError(Exception):
    pass

def reject_constant(value):
    raise ValueError(f"Non-JSON numeric constant: {value}")

def _object_pairs(pairs):
    result = {}
    for k, v in pairs:
        if k in result:
            raise DuplicateKeyError(k)
        result[k] = v
    return result

def load(path):
    """Strict JSON parse: values preserved verbatim, duplicate keys rejected
    so reserialization can never silently discard a translation."""
    with open(path, 'r', encoding='utf-8') as f:
        try:
            return json.load(f, object_pairs_hook=_object_pairs,
                             parse_constant=reject_constant)
        except DuplicateKeyError as e:
            fail(f"Duplicate JSON key '{e.args[0]}' in {path}.\n"
                 f"Fix the file manually, then retry.")
        except json.JSONDecodeError as e:
            fail(f"JSON Decode Error in {path}: {e}\nFix the file manually, then retry.")
        except ValueError as e:
            fail(f"Invalid JSON in {path}: {e}\nFix the file manually, then retry.")

def serialize(path, data):
    """Serialize to a staged temp file beside the destination; returns its path."""
    directory = os.path.dirname(path)
    fd, temp_path = tempfile.mkstemp(
        prefix=os.path.basename(path) + '.tmp-', dir=directory
    )
    try:
        with os.fdopen(fd, 'w', encoding='utf-8') as f:
            json.dump(data, f, ensure_ascii=False, indent=2, allow_nan=False)
            f.write('\n')
    except Exception:
        os.unlink(temp_path)
        raise
    return temp_path

# Validate BOTH files before writing either.
fr_data = load(fr_file)
en_data = load(en_file)

for path, data in ((fr_file, fr_data), (en_file, en_data)):
    if not isinstance(data, dict):
        fail(f"Root of {path} is not a JSON object.")

if key in fr_data:
    fail(f"Key '{key}' already exists in {os.path.basename(fr_file)}.")
if key in en_data:
    fail(f"Key '{key}' already exists in {os.path.basename(en_file)}.")

# Insertion order: keep every existing entry (values and @key metadata) and
# append the new key.
fr_data[key] = fr_value
en_data[key] = en_value

fr_tmp = serialize(fr_file, fr_data)
try:
    en_tmp = serialize(en_file, en_data)
except Exception:
    os.unlink(fr_tmp)
    raise

# Both serializations succeeded — replace the destinations.
os.replace(fr_tmp, fr_file)
os.replace(en_tmp, en_file)

print(f"    FR: {fr_value}")
print(f"    EN: {en_value}")
EOF

# Regenerate localization files
echo -e "${BLUE}Regenerating localization files...${NC}"
cd "$PROJECT_PATH"
if ! flutter gen-l10n; then
    echo ""
    echo -e "${YELLOW}⚠️  ARB files were updated but 'flutter gen-l10n' FAILED.${NC}"
    echo -e "${YELLOW}    Fix the error above, then re-run 'flutter gen-l10n' — the code will${NC}"
    echo -e "${YELLOW}    not compile with the new key until generation succeeds.${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Successfully added localization key: $KEY_NAME${NC}"
