"""Render feature templates with explicit values; never evaluate shell code.

Single file:  render_feature.py TEMPLATE [KEY VALUE]...      (prints to stdout)
Batch:        render_feature.py --batch JOBFILE

A batch job file holds NUL-separated jobs: MODE OUTPUT TEMPLATE PAIRS
followed by PAIRS key/value pairs. MODE is `w` (write) or `a` (append, in
order). Every job is rendered and validated before any file is written.
"""
from __future__ import annotations

from pathlib import Path
import re
import sys

PATTERN = re.compile(r'\{\{([A-Z][A-Z0-9_]*)\}\}')


def render(template: str, values: dict[str, str]) -> str:
    source = Path(template).read_text(encoding='utf-8')
    missing = set(PATTERN.findall(source)) - values.keys()
    if missing:
        raise ValueError(f'{template}: missing template values: ' + ', '.join(sorted(missing)))
    return PATTERN.sub(lambda match: values[match[1]], source)


def batch(job_file: str) -> int:
    fields = Path(job_file).read_bytes().decode('utf-8').split('\0')
    if fields and fields[-1] == '':
        fields.pop()
    outputs: dict[str, str] = {}
    i = 0
    try:
        while i < len(fields):
            mode, output, template, pairs = fields[i:i + 4]
            i += 4
            count = int(pairs)
            flat = fields[i:i + 2 * count]
            i += 2 * count
            text = render(template, dict(zip(flat[0::2], flat[1::2])))
            if mode == 'w':
                outputs[output] = text
            elif mode == 'a':
                outputs[output] = outputs.get(output, '') + text
            else:
                raise ValueError(f'unknown mode {mode!r}')
    except (ValueError, OSError) as error:
        print(error, file=sys.stderr)
        return 1
    for output, text in outputs.items():
        Path(output).write_text(text, encoding='utf-8')
    return 0


def main(args: list[str]) -> int:
    if len(args) == 2 and args[0] == '--batch':
        return batch(args[1])
    if not args or len(args) % 2 != 1:
        print('Usage: render_feature.py TEMPLATE [KEY VALUE]... | --batch JOBFILE', file=sys.stderr)
        return 1
    try:
        sys.stdout.write(render(args[0], dict(zip(args[1::2], args[2::2]))))
    except (ValueError, OSError) as error:
        print(error, file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
