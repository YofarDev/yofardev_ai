#!/usr/bin/env bash
# Preview Dart import repairs; --apply edits URI tokens and verifies.
# Requires uv and Flutter. The helper uses only Python's standard library.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
command -v uv >/dev/null 2>&1 || { echo 'Error: uv is required.' >&2; exit 1; }
exec uv run --no-project "$SCRIPT_DIR/fimp.py" "$@"
