#!/usr/bin/env bash

# Add localized strings to Flutter .arb files and regenerate localization files
# Usage: fstr.sh <keyName> <frString> <enString> [<keyName> <fr> <en>]... [projectPath]
#
# Any number of key/FR/EN triples is validated together, written in one pass,
# and followed by a single `flutter gen-l10n`.
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
# Colours only on an interactive terminal: agents, pipes and CI get plain text
# (ANSI escapes are pure noise in a captured log). NO_COLOR is honoured too.
if [ ! -t 1 ] || [ -n "${NO_COLOR:-}" ]; then
  GREEN=''; BLUE=''; RED=''; YELLOW=''; NC=''
fi

# Check arguments: triples, optionally followed by the project path.
usage() {
    echo "Usage: fstr.sh <keyName> <frString> <enString> [<keyName> <fr> <en>]... [projectPath]"
    echo ""
    echo "  keyName     - lowerCamelCase localization key (e.g. dashboardWelcome)"
    echo "  frString    - French translation (source of truth)"
    echo "  enString    - English translation"
    echo "  projectPath - Flutter project (defaults to the current directory)"
    echo ""
    echo "Example:"
    echo "  fstr.sh myNewKey \"Bonjour\" \"Hello\""
    echo "  fstr.sh titleKey \"Titre\" \"Title\" bodyKey \"Corps\" \"Body\""
}
if [ $# -lt 3 ] || [ $(( $# % 3 )) -eq 2 ]; then
    usage
    exit 1
fi
PROJECT_PATH="."
if [ $(( $# % 3 )) -eq 1 ]; then
    PROJECT_PATH="${!#}"
fi
TRIPLES=()
while [ $# -ge 3 ]; do
    TRIPLES+=("$1" "$2" "$3")
    shift 3
done

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
echo -e "${BLUE}Validating and adding $(( ${#TRIPLES[@]} / 3 )) key(s)...${NC}"
uv run python - "$FR_FILE" "$EN_FILE" "${TRIPLES[@]}" <<'EOF'
import json
import os
import re
import sys
import tempfile

fr_file, en_file = sys.argv[1], sys.argv[2]
triples = [tuple(sys.argv[i:i + 3]) for i in range(3, len(sys.argv), 3)]

def fail(msg):
    print(f"\n[!] {msg}", file=sys.stderr)
    sys.exit(1)

def placeholders(s):
    return sorted(set(re.findall(r"\{[a-zA-Z_][a-zA-Z0-9_]*\}", s)))

seen = set()
for key, fr_value, en_value in triples:
    # Key must be a valid Dart identifier (gen-l10n generates a getter from it)
    if not re.fullmatch(r"[a-z][a-zA-Z0-9]*", key):
        fail(f"Key '{key}' must be lowerCamelCase (e.g., dashboardWelcome).")
    if key in seen:
        fail(f"Key '{key}' is given twice.")
    seen.add(key)
    # FR and EN must use identical placeholders, or gen-l10n will fail later
    if placeholders(fr_value) != placeholders(en_value):
        fail(
            f"Placeholder mismatch between FR and EN strings for '{key}':\n"
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

for key, fr_value, en_value in triples:
    if key in fr_data:
        fail(f"Key '{key}' already exists in {os.path.basename(fr_file)}.")
    if key in en_data:
        fail(f"Key '{key}' already exists in {os.path.basename(en_file)}.")

# Insertion order: keep every existing entry (values and @key metadata) and
# append the new keys.
for key, fr_value, en_value in triples:
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

for key, fr_value, en_value in triples:
    print(f"    {key}: FR {fr_value!r} / EN {en_value!r}")
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

echo -e "${GREEN}✓ Added $(( ${#TRIPLES[@]} / 3 )) localization key(s).${NC}"
