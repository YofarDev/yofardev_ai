"""Preview-first repairs of missing Dart directive URIs.

Candidate matching is heuristic. A conservative header scanner skips nested
comments and reads whole string tokens, stopping at the first declaration.
Only exact static URI tokens can be changed; unsupported forms are left alone.
"""
from __future__ import annotations

from dataclasses import dataclass
import os
from pathlib import Path
import re
import shutil
import stat
import subprocess
import sys
import tempfile
from urllib.parse import quote, unquote, urlsplit


@dataclass(frozen=True)
class Token:
    text: str
    start: int
    end: int
    value: str | None = None


def next_token(source: str, offset: int) -> Token | None:
    """Read one header token, skipping whitespace and nested Dart comments."""
    size = len(source)
    while offset < size:
        if source[offset].isspace():
            offset += 1
        elif source.startswith('//', offset):
            newline = source.find('\n', offset)
            offset = size if newline < 0 else newline + 1
        elif source.startswith('/*', offset):
            depth = 1
            offset += 2
            while offset < size and depth:
                if source.startswith('/*', offset):
                    depth += 1
                    offset += 2
                elif source.startswith('*/', offset):
                    depth -= 1
                    offset += 2
                else:
                    offset += 1
            if depth:
                return None
        else:
            break
    if offset >= size:
        return None
    start = offset
    raw = source[offset] == 'r' and offset + 1 < size and source[offset + 1] in "'\""
    if raw:
        offset += 1
    if source[offset] in "'\"":
        delimiter = source[offset]
        if source.startswith(delimiter * 3, offset):
            delimiter *= 3
        offset += len(delimiter)
        chars: list[str] = []
        supported = True
        escapes = {'n': '\n', 'r': '\r', 't': '\t', 'b': '\b', 'f': '\f', 'v': '\v', '\\': '\\', "'": "'", '"': '"', '$': '$'}
        while offset < size and not source.startswith(delimiter, offset):
            char = source[offset]
            if not raw and char == '$':
                supported = False
            if not raw and char == '\\':
                offset += 1
                if offset >= size:
                    return None
                char = source[offset]
                if char in escapes:
                    chars.append(escapes[char])
                else:
                    # Conservatively skip hex/Unicode and unknown escapes.
                    supported = False
                    chars.append(char)
            else:
                chars.append(char)
            offset += 1
        if offset >= size:
            return None
        end = offset + len(delimiter)
        return Token(source[start:end], start, end, ''.join(chars) if supported else None)
    identifier = re.match(r'[a-zA-Z_$][a-zA-Z0-9_$]*', source[offset:])
    end = offset + (len(identifier[0]) if identifier else 1)
    return Token(source[start:end], start, end)


def directive_uris(source: str) -> list[Token]:
    """Collect static URI tokens from library-header directives only."""
    uris: list[Token] = []
    offset = 0
    while (keyword := next_token(source, offset)) is not None:
        if keyword.text not in ('library', 'import', 'export', 'part'):
            break
        offset = keyword.end
        first = next_token(source, offset)
        if first is None:
            break
        pending: list[Token] = []
        if keyword.text in ('import', 'export', 'part') and first.value is not None:
            pending.append(first)
        offset = first.end
        # Conditional expressions can contain strings too (== 'value'). Only
        # strings outside their parentheses can be branch URIs.
        depth = 0
        while first.text != ';':
            first = next_token(source, offset)
            if first is None:
                return uris
            if first.text == '(':
                depth += 1
            elif first.text == ')':
                depth -= 1
                if depth < 0:
                    return uris
            if keyword.text in ('import', 'export') and first.value is not None and depth == 0:
                pending.append(first)
            offset = first.end
        if depth:
            return uris
        uris.extend(pending)
    return uris


def analyze(root: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(['flutter', 'analyze', '--no-pub'], cwd=root,
                          stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)


def read_source(path: Path) -> str:
    with path.open(encoding='utf-8', newline='') as stream:
        return stream.read()


def write_source(path: Path, content: str) -> None:
    descriptor, temporary = tempfile.mkstemp(prefix=path.name + '.tmp-', dir=path.parent)
    try:
        with os.fdopen(descriptor, 'w', encoding='utf-8', newline='') as stream:
            stream.write(content)
        os.chmod(temporary, stat.S_IMODE(path.stat().st_mode))
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def replacement(token: Token, uri: str) -> str:
    # Encode special filename characters so raw literals stay valid too.
    encoded = quote(uri, safe='/.:_-')
    raw_prefix = 'r' if token.text.startswith('r') else ''
    literal = token.text[len(raw_prefix):]
    delimiter = literal[0] * (3 if literal.startswith(literal[0] * 3) else 1)
    return raw_prefix + delimiter + encoded + delimiter


def main(args: list[str]) -> int:
    if len(args) > 1 or (args and args[0] not in ('--apply', '--dry-run')):
        print('Unknown or conflicting flags: use --apply or --dry-run.', file=sys.stderr)
        return 1
    apply = args == ['--apply']
    if shutil.which('flutter') is None:
        print('Error: flutter is required.', file=sys.stderr)
        return 1
    root = Path.cwd().resolve()
    while not (root / 'pubspec.yaml').is_file():
        if root == root.parent:
            print('Error: could not find pubspec.yaml.', file=sys.stderr)
            return 1
        root = root.parent
    match = re.search(r'^name:\s*[\"\']?([a-zA-Z0-9_]+)', (root / 'pubspec.yaml').read_text(), re.M)
    if match is None or not (root / 'lib').is_dir():
        print('Error: could not read application package name or find lib/.', file=sys.stderr)
        return 1
    package = match[1]
    print(f'Project root: {root}\nPackage name: {package}')
    if not apply:
        print('Preview only — nothing will be written. Pass --apply to apply.')
    initial = analyze(root)
    missing = re.compile(r"(?:Target of URI doesn't exist|URI target doesn't exist): '([^']+\.dart)'")
    location = re.compile(r'((?:lib|test)/[^:\n]+\.dart):\d+:\d+')
    diagnostics: dict[tuple[str, str], None] = {}
    for line in initial.stdout.splitlines():
        uri, importer = missing.search(line), location.search(line)
        if uri and importer:
            diagnostics[(importer[1], uri[1])] = None
    if initial.returncode and not diagnostics:
        print(initial.stdout)
        if 'issue' in initial.stdout or 'Error:' in initial.stdout or ' • ' in initial.stdout:
            print('Analysis reported issues outside supported import repairs.')
        else:
            print('Analyzer startup or infrastructure failure.')
        return 1

    proposals: dict[str, dict[str, str]] = {}
    sources: dict[str, str] = {}
    ambiguous = unresolved = unsupported = 0
    for importer, uri in diagnostics:
        parsed = urlsplit(uri)
        is_package = uri.startswith(f'package:{package}/')
        if parsed.scheme and not is_package:
            print(f'Unsupported external URI: {uri} <-- {importer}')
            unsupported += 1
            continue
        source_path = root / importer
        source = sources.setdefault(importer, read_source(source_path))
        if not any(token.value == uri for token in directive_uris(source)):
            print(f'Unsupported directive form: {uri} <-- {importer}')
            unsupported += 1
            continue
        basename = unquote(parsed.path).split('/')[-1]
        search_roots = [root / 'lib']
        if importer.startswith('test/') and (root / 'test').is_dir():
            search_roots.append(root / 'test')
        candidates = sorted({path.resolve() for directory in search_roots
                             for path in directory.rglob('*.dart') if path.name == basename
                             and path.resolve().is_relative_to(directory.resolve())})
        if not candidates:
            print(f'Unresolved: {basename} not found in ' + ('lib/' if importer.startswith('lib/') else 'lib/ or test/'))
            unresolved += 1
            continue
        if len(candidates) > 1:
            print(f'Ambiguous: {basename} <-- {importer}')
            for path in candidates:
                print('  ' + str(path.relative_to(root)))
            ambiguous += 1
            continue
        target = candidates[0]
        if is_package and target.is_relative_to(root / 'lib'):
            new_uri = f'package:{package}/{target.relative_to(root / "lib").as_posix()}'
        else:
            new_uri = os.path.relpath(target, source_path.parent).replace(os.sep, '/')
            if not new_uri.startswith('../') and uri.startswith('./'):
                new_uri = './' + new_uri
        proposals.setdefault(importer, {})[uri] = new_uri
        print(f'{importer}\n  - {uri}\n  + {new_uri}')

    applied = 0
    if apply:
        for importer, replacements in proposals.items():
            source = sources[importer]
            edits = [(token, replacements[token.value]) for token in directive_uris(source)
                     if token.value in replacements]
            for token, uri in reversed(edits):
                source = source[:token.start] + replacement(token, uri) + source[token.end:]
            write_source(root / importer, source)
            applied += len(edits)
            print(f'Applied: {importer} ({len(edits)} URI token(s))')
    print(f'Proposed: {sum(map(len, proposals.values()))}\nAmbiguous: {ambiguous}\nUnresolved: {unresolved}\nUnsupported: {unsupported}')
    if not apply:
        return 0
    final = analyze(root) if applied else initial
    if final.returncode or ambiguous or unresolved or unsupported:
        print(final.stdout)
        print(f'Verification FAILED. {applied} applied URI repair(s) RETAINED; unresolved issues remain.')
        return 1
    print('flutter analyze passes after repair.' if applied else 'flutter analyze passes; nothing to repair.')
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main(sys.argv[1:]))
    except (OSError, ValueError) as error:
        print(f'Error: {error}', file=sys.stderr)
        sys.exit(1)
