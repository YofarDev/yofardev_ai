"""Wire a generated feature module into the app (used by fgen.sh).

Inserts, at the `// fgen:` markers:
  lib/core/di/service_locator.dart        import + register<Feature>Feature(getIt);
  lib/core/router/app_router.dart         import + ...<feature>Routes(getIt),
  lib/core/router/route_constants.dart    static const String <feature> = '/<snake>';
  test/core/di/service_locator_test.dart  imports + repository resolution check

Usage:
  fwire.py check APP_ROOT SNAKE PASCAL CAMEL PROJECT   # before generation
  fwire.py apply APP_ROOT SNAKE PASCAL CAMEL PROJECT   # after publishing

`check` exits 1 on a route-constant collision (nothing may be written).
`apply` wires every file whose marker exists and prints the exact manual edit
for any file without one; it exits 2 when something was left to do by hand.
Prints the paths it changed (one per line, prefixed `wired:`) so the caller
can format them.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path


def plan(snake: str, pascal: str, camel: str, project: str) -> list[dict]:
    module = f"features/{snake}/{snake}_module.dart"
    return [
        {
            "path": "lib/core/di/service_locator.dart",
            "marker": "// fgen:register-features",
            "imports": [f"import '../../{module}';"],
            "line": f"register{pascal}Feature(getIt);",
        },
        {
            "path": "lib/core/router/app_router.dart",
            "marker": "// fgen:routes",
            "imports": [f"import '../../{module}';"],
            "line": f"...{camel}Routes(getIt),",
        },
        {
            "path": "lib/core/router/route_constants.dart",
            "marker": "// fgen:route-constants",
            "imports": [],
            "line": f"static const String {camel} = '/{snake}';",
        },
        {
            "path": "test/core/di/service_locator_test.dart",
            "marker": "// fgen:resolve",
            "imports": [
                f"import 'package:{project}/features/{snake}/data/repositories/{snake}_repository_impl.dart';",
                f"import 'package:{project}/features/{snake}/domain/repositories/{snake}_repository.dart';",
            ],
            "line": f"expect(getIt<{pascal}Repository>(), isA<{pascal}RepositoryImpl>());",
        },
    ]


def add_imports(text: str, imports: list[str]) -> str:
    missing = [i for i in imports if i not in text]
    if not missing:
        return text
    lines = text.split("\n")
    last = -1
    n = 0
    while n < len(lines):
        if lines[n].startswith("import "):
            while n < len(lines) and ";" not in lines[n]:
                n += 1  # multi-line directive: run to its closing `;`
            last = n
        n += 1
    cr = "\r" if "\r\n" in text else ""  # keep the file's own line endings
    lines[last + 1:last + 1] = [m + cr for m in missing]
    return "\n".join(lines)


def main(argv: list[str]) -> int:
    if len(argv) != 6 or argv[0] not in {"check", "apply"}:
        print(__doc__, file=sys.stderr)
        return 64
    mode, root, snake, pascal, camel, project = argv
    app = Path(root)
    steps = plan(snake, pascal, camel, project)

    constants = app / "lib/core/router/route_constants.dart"
    if constants.exists() and re.search(
        rf"\bstatic const String {re.escape(camel)}\b", constants.read_text(newline="")
    ):
        print(f"Route constant 'Routes.{camel}' already exists in {constants}.", file=sys.stderr)
        return 1
    if mode == "check":
        return 0

    manual: list[str] = []
    for step in steps:
        path = app / step["path"]
        text = path.read_text(newline="") if path.exists() else ""
        eol = "\r\n" if "\r\n" in text else "\n"
        marker_line = next((ln.rstrip("\r") for ln in text.split("\n") if ln.strip() == step["marker"]), None)
        if marker_line is None:
            manual.append(
                f"  {step['path']}: no '{step['marker']}' marker. Add"
                + "".join(f"\n      {i}" for i in step["imports"])
                + f"\n      {step['line']}"
            )
            continue
        indent = marker_line[: len(marker_line) - len(marker_line.lstrip())]
        text = text.replace(marker_line, f"{indent}{step['line']}{eol}{marker_line}", 1)
        path.write_text(add_imports(text, step["imports"]), newline="")
        print(f"wired: {step['path']}")
    if manual:
        print("Wire these by hand (markers missing):", file=sys.stderr)
        print("\n".join(manual), file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
