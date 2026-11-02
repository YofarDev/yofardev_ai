import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'support/architecture_checker.dart';

/// Architecture gate for this app's `lib/` tree.
///
/// Two layers of enforcement:
///
/// 1. **The analyzer-based checker** (`test/support/architecture_checker.dart`,
///    the FlutterForge template checker with this project's documented
///    adaptations — see that file's header). It enforces, on resolved
///    imports/declarations (relative and `package:` syntax, conditional
///    branches, re-export chains included):
///    - inward dependencies (`presentation → domain ← data`);
///    - domain purity (no Flutter UI libraries, l10n, router, DI or the
///      design layer in domain — the app logger is allowed by convention);
///    - cross-feature access via a feature's public barrel only
///      (`lib/features/<name>/<name>.dart` — barrels are whole-feature APIs
///      here and may re-export presentation);
///    - acyclic feature dependencies (strongly connected features fail);
///    - `core/` imports no feature internals outside the composition roots;
///    - no stored Cubit/Bloc fields (nullable, aliased, generic and
///      inherited types included);
///    - `getIt` resolution limited to `app.dart`, `service_locator.dart` and
///      `app_router.dart` (`main.dart` may import the locator for bootstrap
///      only), registrations only in `service_locator.dart`.
///
///    A run with checker errors (syntax problems, unresolved imports) fails
///    the gate: the checker never passes code it could not analyze.
///    Rule-by-rule fixtures live in `test/architecture_checker_test.dart`
///    and `test/architecture_checker_boundaries_test.dart`.
///
/// 2. **This file's scan rules** for conventions the analyzer cannot see:
///    no `fpdart` (banned; errors use `Result<T>`), raw colors and fonts
///    only in `core/design/` (and `main.dart` for google_fonts), Rive types
///    only in the avatar presentation layer and `core/design/rive/`, and
///    the removed look-gate tokens stay removed.
///
/// When you add a rule to the flutter-architecture skill, add it to the
/// checker and give it fixtures in `architecture_checker_test.dart`.

/// Whether the file at [path] may import `package:rive/`: only the avatar
/// presentation layer and the UI-kit Rive widgets (`core/design/rive/`).
bool riveImportAllowed(String path) {
  final String normalised = path.replaceAll('\\', '/');
  return normalised.startsWith('lib/features/avatar/presentation/') ||
      normalised.startsWith('lib/core/design/rive/');
}

/// Whether [line] is a hard-coded Material color (`Colors.red`), the
/// `Colors.transparent` constant excepted.
bool hasHardCodedColor(String line) =>
    RegExp(r'(^|[^A-Za-z])Colors\.(?!transparent\b)').hasMatch(line);

/// Whether [content] reads the raw palette instead of the theme.
bool usesRawPalette(String content) =>
    content.contains('AppColors') || content.contains('AppPalette');

/// Whether [line] imports `package:google_fonts`.
bool importsGoogleFonts(String line) => line.contains('package:google_fonts');

/// Whether [line] is an import or export directive of `package:rive/`.
bool directiveUsesRive(String line) {
  final String trimmed = line.trim();
  return (trimmed.startsWith('import') || trimmed.startsWith('export')) &&
      trimmed.contains('package:rive/');
}

void main() {
  final List<File> files = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((File f) => f.path.endsWith('.dart'))
      .toList();

  List<String> importsOf(File f) => f
      .readAsLinesSync()
      .where((String l) => l.trimLeft().startsWith('import'))
      .map((String l) => l.trim())
      .toList();

  test('lib/ respects the architecture boundaries', () async {
    final CheckerResult result = await ArchitectureChecker.checkDirectory();
    expect(
      result.errors,
      isEmpty,
      reason:
          'The architecture checker could not analyze the following files; '
          'the gate fails closed until these are fixed:\n'
          '${result.errors.join('\n')}',
    );
    expect(
      result.violations,
      isEmpty,
      reason:
          'Architecture boundary violations:\n'
          '${result.violations.join('\n')}',
    );
  }, timeout: const Timeout(Duration(minutes: 10)));

  test('no fpdart anywhere', () {
    for (final File f in files) {
      for (final String line in importsOf(f)) {
        expect(
          line.contains('package:fpdart'),
          isFalse,
          reason: '${f.path}: $line',
        );
      }
    }
  });

  /// `lib/` files outside `lib/core/design/` (the only home of raw colors).
  List<File> filesOutsideDesign() =>
      files.where((File f) => !f.path.startsWith('lib/core/design/')).toList();

  test('AppColors and AppPalette are used only inside core/design', () {
    for (final File f in filesOutsideDesign()) {
      final String content = f.readAsStringSync();
      expect(
        usesRawPalette(content),
        isFalse,
        reason:
            '${f.path}: read colors from the theme (context.colors / '
            'context.tokens), not from the raw palette',
      );
    }
  });

  test('no hard-coded Colors.* outside core/design (except transparent)', () {
    for (final File f in filesOutsideDesign()) {
      for (final String line in f.readAsLinesSync()) {
        expect(
          hasHardCodedColor(line),
          isFalse,
          reason: '${f.path}: hard-coded Material color: $line',
        );
      }
    }
  });

  test('google_fonts is imported only by core/design and main.dart', () {
    for (final File f in filesOutsideDesign()) {
      if (f.path == 'lib/main.dart') continue;
      for (final String line in importsOf(f)) {
        expect(
          importsGoogleFonts(line),
          isFalse,
          reason: '${f.path}: fonts belong to the theme: $line',
        );
      }
    }
  });

  test('color rules detect deliberate violations (fixture)', () {
    final String content = File(
      'test/fixtures/architecture/hardcoded_color_fixture.dart',
    ).readAsStringSync();
    expect(usesRawPalette(content), isTrue);
    expect(content.split('\n').any(hasHardCodedColor), isTrue);
    expect(content.split('\n').any(importsGoogleFonts), isTrue);
    // `Colors.transparent` alone must stay allowed.
    expect(hasHardCodedColor('color: Colors.transparent'), isFalse);
  });

  test(
    'riveImportAllowed accepts only avatar presentation and design/rive',
    () {
      expect(
        riveImportAllowed('lib/features/avatar/presentation/x.dart'),
        isTrue,
      );
      expect(riveImportAllowed('lib/core/design/rive/x.dart'), isTrue);
      expect(riveImportAllowed('lib/features/chat/x.dart'), isFalse);
      expect(riveImportAllowed('lib/core/design/x.dart'), isFalse);
      // Windows-style separators are normalised.
      expect(riveImportAllowed(r'lib\core\design\rive\x.dart'), isTrue);
      expect(riveImportAllowed(r'lib\core\design\x.dart'), isFalse);
      // Look-alike prefixes are not allowed.
      expect(riveImportAllowed('lib/core/design/rive_extra/x.dart'), isFalse);
      expect(
        riveImportAllowed('lib/features/avatar/presentation_old/x.dart'),
        isFalse,
      );
    },
  );

  test('directiveUsesRive catches imports and exports of package:rive', () {
    expect(directiveUsesRive("import 'package:rive/rive.dart';"), isTrue);
    expect(directiveUsesRive("export 'package:rive/rive.dart';"), isTrue);
    expect(
      directiveUsesRive("  export 'package:rive/rive.dart' show X;"),
      isTrue,
    );
    expect(
      directiveUsesRive("import 'package:flutter/material.dart';"),
      isFalse,
    );
    expect(directiveUsesRive('// see package:rive/rive.dart docs'), isFalse);
  });

  test(
    'package:rive is imported or exported only where riveImportAllowed permits',
    () {
      for (final File f in files) {
        for (final String line in f.readAsLinesSync()) {
          if (!directiveUsesRive(line)) continue;
          expect(
            riveImportAllowed(f.path),
            isTrue,
            reason:
                '${f.path}: Rive types belong in lib/features/avatar/'
                'presentation/ or lib/core/design/rive/: $line',
          );
        }
      }
    },
  );

  group('removed look-gate code stays removed', () {
    final List<File> dartFiles = <String>['lib', 'test']
        .expand(
          (String d) =>
              Directory(d).listSync(recursive: true).whereType<File>(),
        )
        .where(
          (File f) =>
              f.path.endsWith('.dart') &&
              f.path != 'test/architecture_test.dart',
        )
        .toList();

    const List<String> banned = <String>[
      'AppSurfaceStyle',
      'celFill',
      'LabFontFetching',
      'makeLookTestable',
      'UiLooks.neon',
      'UiLooks.cel',
    ];

    for (final String token in banned) {
      test('no $token under lib/ and test/', () {
        for (final File f in dartFiles) {
          expect(
            f.readAsStringSync().contains(token),
            isFalse,
            reason: '${f.path} still mentions $token',
          );
        }
      });
    }

    test('no Outfit or PlusJakartaSans under lib/', () {
      for (final File f in files) {
        final String content = f.readAsStringSync();
        expect(
          content.contains('Outfit') || content.contains('PlusJakartaSans'),
          isFalse,
          reason: '${f.path} still references a removed font',
        );
      }
    });
  });
}
