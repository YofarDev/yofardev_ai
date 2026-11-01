import 'dart:isolate';

import 'package:archive/archive_io.dart';

/// Unpacks a downloaded model archive into a folder.
abstract class ModelArchiveExtractor {
  Future<void> extractTarBz2({
    required String archivePath,
    required String destinationDir,
  });
}

/// Streaming bz2 → tar → files with `package:archive`, off the UI isolate.
/// Pure Dart: slow on low-end phones (tens of seconds), but bounded memory.
class ArchivePackageExtractor implements ModelArchiveExtractor {
  const ArchivePackageExtractor();

  @override
  Future<void> extractTarBz2({
    required String archivePath,
    required String destinationDir,
  }) => Isolate.run<void>(
    () => extractFileToDisk(archivePath, destinationDir, verify: true),
  );
}
