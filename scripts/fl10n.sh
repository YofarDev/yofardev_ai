#!/usr/bin/env bash
# =============================================================================
# fl10n.sh
#
# Finds hardcoded user-visible strings that should be localized via
# AppLocalizations. Pairs with fstr.sh (which adds the keys once found).
#
# Skips (beyond imports/comments/generated files):
#   - Already localized strings (AppLocalizations.of(context).xxx)
#   - Logger/tag strings (AppLogger calls, `tag:` arguments)
#   - Interpolated strings starting with ${
#   - Route paths (/...), asset paths, URLs, emails, hex colours
#   - ANSI escape literals, snake_case/lowercase identifiers,
#     SCREAMING_SNAKE_CASE, pure numbers, single chars
#   - Strings inside throw/assert/RegExp/Uri contexts
#
# Usage:
#   ./fl10n.sh              # scan lib/
#   ./fl10n.sh --test       # scan lib/ + test/
#
# Requires: uv (for the embedded Python scanner)
# =============================================================================

set -euo pipefail

# -- Flags --------------------------------------------------------------------
INCLUDE_TEST=false
for arg in "$@"; do
  case $arg in
    --test) INCLUDE_TEST=true ;;
    *) echo "Unknown argument: $arg  (supported: --test)"; exit 1 ;;
  esac
done

# -- Colours ------------------------------------------------------------------
GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; DIM='\033[2m'; RESET='\033[0m'

ok() { echo -e "${GREEN}[ ok ]${RESET} $*"; }

# -- Find project root --------------------------------------------------------
PROJECT_ROOT=""
dir="$PWD"
while [[ "$dir" != "/" ]]; do
  [[ -f "$dir/pubspec.yaml" ]] && PROJECT_ROOT="$dir" && break
  dir="$(dirname "$dir")"
done
[[ -z "$PROJECT_ROOT" ]] && echo "Could not find pubspec.yaml." && exit 1

cd "$PROJECT_ROOT"
LIB_DIR="$PROJECT_ROOT/lib"
TEST_DIR="$PROJECT_ROOT/test"

[[ ! -d "$LIB_DIR" ]] && echo "No lib/ directory found." && exit 1

log() { echo -e "${CYAN}[info]${RESET} $*"; }
log "Project root: $PROJECT_ROOT"
if [[ "$INCLUDE_TEST" == true ]]; then
  log "Scanning lib/ and test/"
else
  log "Scanning lib/ only  (use --test to include test/)"
fi

# -- Collect dart files -------------------------------------------------------
SCAN_DIRS=("$LIB_DIR")
[[ "$INCLUDE_TEST" == true ]] && [[ -d "$TEST_DIR" ]] && SCAN_DIRS+=("$TEST_DIR")

# Portable collection loop (no `mapfile`): the shipped helpers must run under
# macOS's stock Bash 3.2 as well as modern Bash — see docs/compatibility.md.
DART_FILES=()
while IFS= read -r f; do
  DART_FILES+=("$f")
done < <(
  find "${SCAN_DIRS[@]}" -type f -name "*.dart" \
    ! -path "*/l10n/*" \
    ! -name "*.g.dart" \
    ! -name "*.freezed.dart" \
    ! -name "*.gen.dart" \
  | sort
)

log "Found ${#DART_FILES[@]} dart files to scan."
echo ""

# -- Scan (single Python pass; env carries the file list) ----------------------
# The Python heredoc runs at TOP LEVEL with its output redirected to a temp
# file. It must NOT sit inside a `$( )` command substitution: macOS's stock
# Bash 3.2 fails to parse quoted heredocs inside command substitutions whose
# body contains quotes or parentheses — see docs/compatibility.md.
SCAN_OUTPUT="$(mktemp)"
trap 'rm -f "$SCAN_OUTPUT"' EXIT

DART_FILES="$(printf '%s\n' ${DART_FILES[@]+"${DART_FILES[@]}"})" \
PROJECT_ROOT="$PROJECT_ROOT" \
uv run python << 'PYEOF' > "$SCAN_OUTPUT"
import os
import re

PROJECT_ROOT = os.environ["PROJECT_ROOT"]
dart_files = [f for f in os.environ["DART_FILES"].split("\n") if f.strip()]

# Lines matching any of these are skipped entirely
SKIP_LINE_PATTERNS = [
    r"^\s*//",                                # single-line comment
    r"^\s*\*",                                # block comment line
    r"^\s*import\s+['\"]",                    # import statement
    r"^\s*export\s+['\"]",                    # export statement
    r"^\s*part\s+['\"]",                      # part statement
    r"AppLogger\.(debug|info|warning|error)", # logger calls
    r"AppLocalizations\.of\(context\)",       # already localized
    r"\btag\s*:",                             # tag: 'SomeTag' arguments
    r"package:[a-z]",                         # package: references
    r"dart:[a-z]",                            # dart: references
    r"\.dart['\"]",                           # .dart file references
    r"RegExp\(",                              # regex patterns
    r"Uri\.",                                 # URI construction
    r"https?://",                             # URLs
    r"debugPrint\(|print\(",                  # prints
    r"throw\s+",                              # thrown messages (dev-facing)
    r"assert\(",                              # assertions
]

# Match source-text escape forms: \x1B[0m and \u001B[0m (literal backslash text)
ANSI_LITERAL = re.compile(r"(?:\\x1[Bb]|\\u001[Bb])\[[0-9;]*[A-Za-z]")

def should_skip_value(s):
    if not s or len(s) <= 1:
        return True                            # empty or single char
    if s.startswith("$"):
        return True                            # interpolation lead-in
    if re.fullmatch(r"[0-9.]+", s):
        return True                            # pure number
    if re.fullmatch(r"[a-z0-9_.]+", s):
        return True                            # lowercase identifier/key
    if re.fullmatch(r"[A-Z0-9_]+", s):
        return True                            # SCREAMING_SNAKE_CASE
    if s.startswith("/"):
        return True                            # route path
    if s.startswith("assets/"):
        return True                            # asset path
    if s.startswith("#") and re.fullmatch(r"#[0-9a-fA-F]{3,8}", s):
        return True                            # hex colour
    if re.fullmatch(r"[\W_]+", s):
        return True                            # only symbols/punctuation
    if ANSI_LITERAL.fullmatch(s):
        return True                            # ANSI escape literal
    if re.fullmatch(r"[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}", s):
        return True                            # email pattern
    return False

findings = []

for filepath in dart_files:
    rel = filepath.replace(PROJECT_ROOT + "/", "")
    try:
        with open(filepath, "r", encoding="utf-8") as f:
            lines = f.readlines()
    except Exception:
        continue

    in_logger_call = False
    in_block_comment = False

    for lineno, raw_line in enumerate(lines, start=1):
        line = raw_line.rstrip()

        if "/*" in line:
            in_block_comment = True
        if "*/" in line:
            in_block_comment = False
            continue
        if in_block_comment:
            continue

        # Multi-line AppLogger(...) calls
        if re.search(r"AppLogger\.(debug|info|warning|error)\s*\(", line):
            in_logger_call = True
        if in_logger_call:
            if ")" in line:
                in_logger_call = False
            continue

        if any(re.search(p, line) for p in SKIP_LINE_PATTERNS):
            continue

        for match in re.finditer(r"""(['"])((?:(?!\1)[^\\]|\\.)*)(\1)""", line):
            value = match.group(2)
            display = value.replace("\\n", " ").replace("\\t", " ").strip()
            if should_skip_value(display):
                continue
            findings.append((rel, lineno, display))

for rel, lineno, value in findings:
    print(f"{rel}\t{lineno}\t{value}")
PYEOF

# -- Format and display results -----------------------------------------------
TOTAL_FINDINGS=0
CURRENT_FILE=""

while IFS=$'\t' read -r filepath lineno value; do
  [[ -z "$filepath" ]] && continue
  (( TOTAL_FINDINGS++ )) || true

  if [[ "$filepath" != "$CURRENT_FILE" ]]; then
    echo -e "  ${BOLD}${CYAN}$filepath${RESET}"
    CURRENT_FILE="$filepath"
  fi

  echo -e "    ${DIM}L${lineno}${RESET}  ${YELLOW}\"$value\"${RESET}"

done < "$SCAN_OUTPUT"

# -- Summary ------------------------------------------------------------------
echo ""
echo -e "${BOLD}-- Summary ----------------------------------------------------------${RESET}"
if [[ $TOTAL_FINDINGS -eq 0 ]]; then
  ok "No unlocalized strings found."
else
  echo -e "  ${YELLOW}${BOLD}$TOTAL_FINDINGS potential unlocalized string(s) found.${RESET}"
  echo -e "  ${DIM}Review each — some may be intentional (domain messages, fake API data).${RESET}"
  echo -e "  ${DIM}To localize one: fstr <camelCaseKey> \"<fr>\" \"<en>\"${RESET}"
fi
echo ""
