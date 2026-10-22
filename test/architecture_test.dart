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
      for (final String line in f.readAsLinesSync()) {
        final RegExpMatch? m = RegExp(r"import '([^']+)'").firstMatch(line);
        if (m == null) continue;
        final String target = m.group(1)!;
        if (!target.startsWith('.')) continue;
        final String resolved = File.fromUri(
          Uri.file(f.path).resolve(target),
        ).path;
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
}
