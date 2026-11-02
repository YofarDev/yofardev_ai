/// Shared expectation helpers for the architecture checker test files.
///
/// Both `architecture_checker_test.dart` and
/// `architecture_checker_boundaries_test.dart` use these. The two test FILES
/// are separate on purpose: the analyzer retains per-process state across
/// fixture runs, and separate isolates keep every file's checks independent.
library;

import 'package:flutter_test/flutter_test.dart';

import 'architecture_checker.dart';
import 'fixture_app.dart';

/// Domain-service fixture importing get_it with an aliased/direct resolution.
String getItFixture(String importLine, String resolution) {
  final String withImportLine = withImport(
    fixtureApp['lib/features/alpha/domain/services/alpha_service.dart']!,
    importLine,
  );
  return '$withImportLine\n$resolution\n';
}

/// Adds [importLine] to the domain service fixture and expects a
/// `domain-purity` violation.
Future<void> expectDomainForbidden(String importLine) async {
  final CheckerResult result = await ArchitectureChecker.checkSources(
    fixtureWith(<String, String>{
      'lib/features/alpha/domain/services/alpha_service.dart': withImport(
        fixtureApp['lib/features/alpha/domain/services/alpha_service.dart']!,
        importLine,
      ),
    }),
  );
  expect(result.errors, isEmpty, reason: 'negative fixture must be analyzable');
  expect(
    result.violations.map(
      (ArchitectureViolation violation) => violation.ruleId,
    ),
    contains('domain-purity'),
    reason:
        '$importLine should violate domain-purity, got: ${result.violations}',
  );
}

/// [sources] must produce no violations and no checker errors (fail closed).
Future<void> expectClean(
  Map<String, String> sources,
  String description,
) async {
  final CheckerResult result = await ArchitectureChecker.checkSources(sources);
  expect(
    result.isClean,
    isTrue,
    reason:
        '$description should pass, but got: '
        '${result.violations} ${result.errors}',
  );
}

/// [sources] must produce at least one [ruleId] violation.
Future<void> expectViolation(
  Map<String, String> sources,
  String ruleId,
  String description,
) async {
  final CheckerResult result = await ArchitectureChecker.checkSources(sources);
  expect(result.errors, isEmpty, reason: 'negative fixture must be analyzable');
  expect(
    result.violations.map(
      (ArchitectureViolation violation) => violation.ruleId,
    ),
    contains(ruleId),
    reason: '$description should violate $ruleId, got: ${result.violations}',
  );
}
