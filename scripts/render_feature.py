"""Render a feature template with explicit values; never evaluate shell code."""
from __future__ import annotations

from pathlib import Path
import re
import sys


def main(args: list[str]) -> int:
    if not args or len(args) % 2 != 1:
        print('Usage: render_feature.py TEMPLATE [KEY VALUE]...', file=sys.stderr)
        return 1
    values: dict[str, str] = dict(zip(args[1::2], args[2::2]))
    source = Path(args[0]).read_text(encoding='utf-8')
    pattern = re.compile(r'\{\{([A-Z][A-Z0-9_]*)\}\}')
    missing = set(pattern.findall(source)) - values.keys()
    if missing:
        print('Missing template values: ' + ', '.join(sorted(missing)), file=sys.stderr)
        return 1
    sys.stdout.write(pattern.sub(lambda match: values[match[1]], source))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
