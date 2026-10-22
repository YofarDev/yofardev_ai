## CLI Tools

The following utility scripts are included in this app. Run them from the app
root. Bash and Flutter/Dart must be on `PATH`; `fgen`, `fstr`, `fl10n`, `fimp`,
and `remove_counter.sh` also require [uv](https://docs.astral.sh/uv/).

| Script | Purpose |
|--------|---------|
| `./scripts/fverify.sh` | **Quality Gate** (non-mutating): `dart format` check (never rewrites files — run `dart format .` yourself first), then `flutter analyze` + `flutter test` in one command. Run before finishing any change. |
| `./scripts/fgen.sh "name" [--with-service] [--with-dto]` | **Generate New Feature**: Creates Clean Architecture boilerplate (lean by default; optional layers via flags) and runs code generation. Refuses to overwrite an existing feature; snake_case or camelCase names. |
| `./scripts/fstr.sh "key" "FR" "EN" [project_path]` | **Add Localization**: Adds a new key to both French and English `.arb` files, then regenerates localization. Requires a new lowerCamelCase key, valid ARB JSON, and matching placeholders. Defaults to the current project. |
| `./scripts/fl10n.sh` | **Find Unlocalized Strings**: Scans `lib/` for hardcoded user-facing strings that should use `AppLocalizations`. |
| `./scripts/fanal.sh [project_path]` | **Audit**: Writes or overwrites `flutter_analysis.md` in the selected project (defaults to the current directory). Heuristic findings guide source review; they do not establish architecture violations. |
| `./scripts/fdead.sh` | **Potentially Unreferenced Files** (advisory only): reports files whose basename appears in no import/export/part statement. Never deletes anything — the textual scan cannot prove deletion is safe (conditional directives, custom entry points, and filename collisions can affect findings), so review every finding manually. |
| `./scripts/fimp.sh` / `./scripts/fimp.sh --apply` | **Fix Imports** (preview-first): with no flags, displays proposed repairs and writes nothing; `--apply` repairs unambiguous broken imports, then re-runs analysis and reports failure without rollback. Never repairs a `lib/` import into `test/`, and never gives a test helper a `package:` URI. |
| `./scripts/fcheck.sh [package_name]` | **Dependency Inventory** (review aid): compares dependencies with direct imports, or lists imports of one package. Results do not establish that a dependency is removable; inspect exports, indirect usage, code generation, assets and platform channels. |
| `./scripts/sync_skills.sh [--check] [--user]` | **Sync Skills**: Copies canonical top-level Markdown files from `.agents/skills` into matching skill directories in existing `.codex/skills/` targets. Missing target/skill directories are skipped and extras are retained. `--check` writes nothing and exits nonzero on drift. `--user` also targets existing `~/.agents/skills/` and `~/.claude/skills/` copies; use when user-level synchronization is requested. |
| `./remove_counter.sh` | **Remove Counter Demo**: Deletes the Counter feature and rewrites its demo wiring/tests. For freshly generated apps with the untouched example; see [Removing Example Code](#removing-example-code). |

The read-only scans (`fl10n`, `fdead`, `fcheck`, import preview, and skill drift
check) require judgment before acting on their output. `fanal` writes a report;
`fgen`, `fstr`, import apply, skill sync, and Counter removal modify files.

`scripts/fimp.py`, `scripts/render_feature.py`, and `scripts/feature_templates/`
are supporting assets used by the shell entry points. FlutterForge's
`scripts/verify_template.sh`, `tools/test_template.py`, and `personal_tools/`
are template-maintenance tools and are not shipped into this app.

## Development Commands

```bash
# Install dependencies
flutter pub get

# Generate localization files
flutter gen-l10n

# Run code generation (Freezed/JSON)
dart run build_runner build --delete-conflicting-outputs

# Run tests
flutter test

# Run the app
flutter run

# Prepare explicitly before finishing a change
dart fix --apply
dart format .
./scripts/fverify.sh
```

Resolve dependencies and regenerate localization/Freezed/JSON code above when
needed before verification. The gate checks formatting, analyzes, and runs
tests; it does not fix source or generate missing code. Any failed step exits
nonzero and must be resolved before finishing.

`fimp` edits static URI tokens in the library header, preserving comments,
strings, prefixes and combinators. It supports relative imports in both `lib/`
and `test/`, including conditional branches. Unsupported forms (such as
annotated directives or URI literals with hex/Unicode escapes) are reported
without edits. Preview is advisory; `--apply` exits nonzero when analysis fails
or a repair remains ambiguous, unresolved or unsupported. Candidate matching
uses filenames, so review every proposal before applying it.

Feature source templates live in `scripts/feature_templates/`; `fgen` renders
them with explicit values through `scripts/render_feature.py`, without shell
evaluation. Keep these assets alongside the scripts when sharing the tooling.

## Continuous Integration

`.github/workflows/flutter-ci.yml` runs on pull requests and pushes to `main`.
It installs the documented Flutter baseline, resolves packages, regenerates
localizations and Freezed/JSON code, then runs `scripts/fverify.sh`. CI checks
formatting and does not fix or reformat committed source. No secrets or signing
credentials are needed.

If your default branch has another name, update the push branch filter. To make
the quality gate mandatory for merges, configure branch protection or a ruleset
to require the `format check + analyze + test` check. The workflow file alone
does not enforce merge protection. The template workflow has been exercised
locally; confirm its first GitHub Actions run in your own repository.

## Adding a New Feature

To add a new feature, use the generation script:

```bash
./scripts/fgen.sh my_new_feature                           # lean default
./scripts/fgen.sh my_new_feature --with-service            # + placeholder domain service
./scripts/fgen.sh my_new_feature --with-dto                # + transport DTO + serialization
./scripts/fgen.sh my_new_feature --with-service --with-dto # full layout
./scripts/fgen.sh myNewFeature                             # camelCase also works
```

Layout is proportional to complexity:

- **Lean default** — only what a simple feature needs: freezed domain model
  (no JSON serialization), repository interface, placeholder data source (the
  external-I/O seam; it returns the domain model directly and does NOT
  represent a real transport schema), repository implementation with typed
  results and the exception mapper, cubit depending on the repository
  interface, union state, a single screen widget, and repository/cubit/screen
  tests.
- **`--with-dto`** — additionally generates the transport DTO (with JSON
  serialization), the DTO→domain conversion, and DTO mapping tests. Use it
  when a real transport representation exists (API payloads, cache schemas).
- **`--with-service`** — additionally inserts a placeholder domain service
  between the cubit and the repository, with tests. The placeholder must gain
  actual rules/coordination or be removed — a forwarding service is NOT
  mandatory architecture (compare `CounterService`, which owns real step and
  bounds behavior).

Generation contract:

- The script must run inside this application; the app root is resolved by
  walking up from the current directory (`pubspec.yaml` + `lib/`). There is no
  fallback project name.
- Feature names are normalized to snake_case and validated as Dart identifiers:
  empty values, path separators, `..`, punctuation, invalid starting
  characters and Dart reserved identifiers are rejected, and nothing is
  written for an invalid name.
- It refuses to run if the feature's `lib/features/<name>` or
  `test/features/<name>` directory already exists (symlinks included) — an
  existing feature is never partially overwritten.
- Files are rendered into a temporary directory and published only after
  validation. Screen localization keys are then added via `scripts/fstr.sh`
  (with a key-collision check); if that or `build_runner` fails, the published
  feature is kept, the incomplete state is reported, and the script exits
  non-zero.

After generation, follow the steps the script prints: register the dependencies in
`lib/core/di/service_locator.dart`, add the route in `lib/core/router/app_router.dart`
(the route builder provides the cubit — the generated screen is a pure consumer),
update `test/core/di/service_locator_test.dart`, and replace the placeholder data
source with real I/O. Note that a scaffold passing its unit tests is not a routed
feature — it appears in the app only after the DI and route steps are applied, so
run `dart fix --apply`, `dart format .`, and `./scripts/fverify.sh` after wiring.

Features generated with the previous full layout keep working as-is; no
migration is required.

## Guardrails

- `test/architecture_test.dart` enforces the layering rules at test time (no cross-feature
  imports into internals, presentation never imports `data/`, no cubit-to-cubit fields,
  `core/` stays infrastructure-only outside the composition roots).
- `test/core/di/service_locator_test.dart` smoke-tests every DI registration.
- State idioms: union states for load-lifecycle screens (`features/home`), flat `copyWith`
  states for persistent interactive state (`features/counter`). See the `flutter-architecture`
  skill for the full rules.

## Removing Example Code

When starting a freshly generated app, remove the untouched Counter example
if you do not need it:

```bash
./remove_counter.sh
dart fix --apply
dart format .
./scripts/fverify.sh
```

The removal script deletes Counter source/tests and updates DI, routes, Home
navigation, and related tests. Review the diff; if you have customized the demo
or its wiring, remove those references manually instead of relying on its
template-specific text edits.
