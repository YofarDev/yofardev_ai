import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

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

  test('core does not import features (composition roots excluded)', () {
    const List<String> allowed = <String>['lib/core/di/', 'lib/core/router/'];
    for (final File f in files) {
      if (!f.path.startsWith('lib/core/')) continue;
      if (allowed.any(f.path.startsWith)) continue;
      for (final String line in importsOf(f)) {
        expect(line.contains('features/'), isFalse, reason: '${f.path}: $line');
      }
    }
  });

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

  /// Resolves every relative import in [f] to a repo-relative path.
  List<String> relativeImportTargets(File f) => f
      .readAsLinesSync()
      .map((String l) => l.trim())
      .where((String l) => l.startsWith('import \''))
      .map((String l) => RegExp(r"import '([^']+)'").firstMatch(l)?.group(1))
      .whereType<String>()
      .where((String t) => t.startsWith('.'))
      .map((String t) => File.fromUri(Uri.file(f.path).resolve(t)).path)
      .toList();

  test('features import other features only via their public barrel', () {
    const List<String> barrels = <String>[
      'talking.dart',
      'chat.dart',
      'avatar.dart',
      'demo.dart',
      'settings.dart',
      'sound.dart',
    ];
    for (final File f in files) {
      final List<String> parts = f.path.split('/');
      if (parts.length < 3 || parts[1] != 'features') continue;
      final String ownFeature = parts[2];
      for (final String resolved in relativeImportTargets(f)) {
        final List<String> t = resolved.split('/');
        if (t.length > 3 && t[1] == 'features' && t[2] != ownFeature) {
          expect(
            barrels.contains(t.last),
            isTrue,
            reason: '${f.path} imports feature internals: $resolved',
          );
        }
      }
    }
  });

  test('no service resolves a cubit from getIt', () {
    // Services live both in core and in each feature's domain/services/.
    final List<String> serviceDirs = <String>[
      'lib/core/services/',
      ...Directory('lib/features').listSync().whereType<Directory>().map(
        (Directory d) => '${d.path}/domain/services/',
      ),
    ];
    for (final String dir in serviceDirs) {
      if (!Directory(dir).existsSync()) continue;
      for (final FileSystemEntity entity in Directory(
        dir,
      ).listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        for (final String line in entity.readAsLinesSync()) {
          expect(
            RegExp(r'getIt<\w*(Cubit|Bloc)>').hasMatch(line),
            isFalse,
            reason: '${entity.path}: $line',
          );
        }
      }
    }
  });

  test('feature domain imports neither data nor presentation', () {
    for (final File f in files) {
      final List<String> parts = f.path.split('/');
      if (parts.length < 4 || parts[1] != 'features' || parts[2] != 'domain') {
        continue;
      }
      for (final String target in relativeImportTargets(f)) {
        expect(
          RegExp(r'/features/[^/]+/(data|presentation)/').hasMatch(target),
          isFalse,
          reason: '${f.path}: domain imports layer internals: $target',
        );
      }
    }
  });

  test('layer rule detects a deliberate domain->data violation (fixture)', () {
    final File fixture = File(
      'test/fixtures/architecture/domain_leak_fixture.dart',
    );
    expect(fixture.existsSync(), isTrue);
    final List<String> targets = relativeImportTargets(fixture);
    expect(
      targets.any(
        (String t) =>
            RegExp(r'/features/[^/]+/(data|presentation)/').hasMatch(t),
      ),
      isTrue,
      reason: 'fixture must violate the rule the previous test enforces',
    );
  });

  test('getIt is resolved only in composition roots', () {
    const List<String> allowlist = <String>[
      'lib/core/di/service_locator.dart',
      'lib/app.dart',
      'lib/core/router/app_router.dart',
    ];
    for (final File f in files) {
      if (allowlist.contains(f.path)) continue;
      for (final String line in f.readAsLinesSync()) {
        expect(
          RegExp(r'\bgetIt[<(]').hasMatch(line),
          isFalse,
          reason:
              '${f.path}: resolves from getIt outside composition roots: $line',
        );
      }
    }
  });

  test('registrations appear only in service_locator.dart', () {
    for (final File f in files) {
      if (f.path == 'lib/core/di/service_locator.dart') continue;
      for (final String line in f.readAsLinesSync()) {
        expect(
          RegExp(
            r'getIt\.register(LazySingleton|Singleton|Factory)',
          ).hasMatch(line),
          isFalse,
          reason: '${f.path}: DI registration outside service_locator: $line',
        );
      }
    }
  });

  test('getIt rule detects a deliberate violation (fixture)', () {
    final String content = File(
      'test/fixtures/architecture/getit_violation_fixture.dart',
    ).readAsStringSync();
    expect(RegExp(r'\bgetIt[<(]').hasMatch(content), isTrue);
  });

  test('registrations rule detects a deliberate violation (fixture)', () {
    final String content = File(
      'test/fixtures/architecture/registration_violation_fixture.dart',
    ).readAsStringSync();
    expect(
      RegExp(
        r'getIt\.register(LazySingleton|Singleton|Factory)',
      ).hasMatch(content),
      isTrue,
    );
  });

  /// `lib/` files outside `lib/core/design/` (the only home of raw colors).
  List<File> filesOutsideDesign() =>
      files.where((File f) => !f.path.startsWith('lib/core/design/')).toList();

  test('AppColors and AppPalette are used only inside core/design', () {
    for (final File f in filesOutsideDesign()) {
      final String content = f.readAsStringSync();
      expect(
        content.contains('AppColors') || content.contains('AppPalette'),
        isFalse,
        reason:
            '${f.path}: read colors from the theme (context.colors / '
            'context.tokens), not from the raw palette',
      );
    }
  });

  test('no hard-coded Colors.* outside core/design (except transparent)', () {
    final RegExp hardCoded = RegExp(r'(^|[^A-Za-z])Colors\.(?!transparent\b)');
    for (final File f in filesOutsideDesign()) {
      for (final String line in f.readAsLinesSync()) {
        expect(
          hardCoded.hasMatch(line),
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
          line.contains('package:google_fonts'),
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
    expect(content.contains('AppColors'), isTrue);
    expect(
      RegExp(r'(^|[^A-Za-z])Colors\.(?!transparent\b)').hasMatch(content),
      isTrue,
    );
    expect(content.contains('package:google_fonts'), isTrue);
    // `Colors.transparent` alone must stay allowed.
    expect(
      RegExp(
        r'(^|[^A-Za-z])Colors\.(?!transparent\b)',
      ).hasMatch('color: Colors.transparent'),
      isFalse,
    );
  });
}
