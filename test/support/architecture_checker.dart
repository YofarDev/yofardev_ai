/// Analyzer-based architecture boundary checker for the FlutterForge template.
///
/// Enforces the layering, dependency-direction, DI and stored-state rules from
/// the flutter-architecture skill with the Dart analyzer (AST + resolved types)
/// instead of regexes. The checker is independent of the filesystem/test
/// runner:
///
/// - [ArchitectureChecker.checkSources] analyzes an in-memory fixture project
///   (sources keyed by app-relative `lib/...` paths). Fixtures get a package
///   configuration derived from the hosting app so `package:` imports of the
///   app and of its real dependencies (flutter, flutter_bloc, get_it, …)
///   resolve like they would in a generated application.
/// - [ArchitectureChecker.checkDirectory] analyzes a real application `lib/`
///   directory on disk with a single analysis context.
///
/// Results are structured: [CheckerResult.violations] carries rule id, source
/// path, line and explanation per finding; [CheckerResult.errors] carries
/// checker-level failures (syntax errors, unresolved URIs, failed analysis).
/// Callers must treat a non-empty error list as a failure (fail closed): an
/// error means the gate could not evaluate the code, never that it passed.
///
/// Scope limitation (by design): only statically visible dependencies are
/// checked. Dependencies hidden behind `dynamic`, runtime service resolution
/// or callbacks are not detected — those need flow tests and review.
///
/// ## Project adaptations (yofardev_ai)
///
/// This file is the FlutterForge template checker with three documented
/// divergences required by this app's AGENTS.md conventions (AGENTS.md
/// overrides the skill defaults):
///
/// 1. **Public barrels are whole-feature APIs.** The template holds feature
///    barrels to domain-only exports (`barrel-exposes-implementation`); here
///    a feature's `<feature>.dart` barrel legitimately re-exports its
///    presentation layer (cubits, widgets — that is how Home and the
///    composition roots consume features). Barrels are therefore not treated
///    as domain-like, the `barrel-exposes-implementation` rule is removed,
///    and domain-purity re-export chains STOP at a public barrel instead of
///    descending into it: the barrel is the feature's declared API surface.
/// 2. **The app logger is allowed in domain.** Domain services log through
///    `core/utils/logger.dart` by convention; the template bans it there.
/// 3. **`lib/core/design` replaces `lib/core/theme`** as the domain-forbidden
///    theme location (this app's design layer lives in `core/design/`).
library;

import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/session.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/diagnostic/diagnostic.dart';

/// Package name used for fixture projects.
///
/// Deliberately NOT the `my_flutter_app` template placeholder: generated apps
/// substitute that placeholder with their real package name, and a fixture
/// package named like the host app would collide with the host's entry in the
/// fixture package configuration (duplicate package names make the analyzer's
/// URI resolution undefined).
const String fixturePackageName = 'flutterforge_arch_fixture';

/// Files allowed to *resolve* from get_it — import `package:get_it` or
/// reference the app's `getIt` variable — by exact app-relative path.
///
/// `lib/main.dart` is deliberately NOT here: bootstrap may import
/// `service_locator.dart` and call the setup function (see
/// [serviceLocatorImportAllowlist]), but it must not resolve `getIt` or
/// register dependencies.
const List<String> locatorAllowlist = <String>[
  'lib/app.dart',
  'lib/core/di/service_locator.dart',
  'lib/core/router/app_router.dart',
];

/// Files allowed to *import* `service_locator.dart`, by exact app-relative
/// path. `lib/main.dart` is included so bootstrap can call the setup
/// function; everything else (features in particular) must receive
/// dependencies through constructors instead of reaching into the DI file.
const List<String> serviceLocatorImportAllowlist = <String>[
  'lib/app.dart',
  'lib/main.dart',
  'lib/core/di/service_locator.dart',
  'lib/core/router/app_router.dart',
];

/// The only file allowed to *register* dependencies.
const String serviceLocatorPath = 'lib/core/di/service_locator.dart';

/// App paths a domain file must never depend on. The design layer replaces
/// the template's `lib/core/theme` (project adaptation 3).
const List<String> domainForbiddenAppPrefixes = <String>[
  'lib/core/l10n',
  'lib/core/router',
  'lib/core/di',
  'lib/core/design',
];

/// A single enforced-rule violation.
final class ArchitectureViolation {
  ArchitectureViolation({
    required this.ruleId,
    required this.path,
    required this.line,
    required this.explanation,
  });

  /// Stable identifier of the violated rule, e.g. `inward-dependency`.
  final String ruleId;

  /// App-relative, slash-normalized path of the offending file (`lib/...`).
  final String path;

  /// One-based line of the offending construct.
  final int line;

  /// Human-readable explanation of the violation.
  final String explanation;

  @override
  String toString() => '$ruleId: $path:$line — $explanation';
}

/// A checker-level failure: the code could not be analyzed and the gate must
/// fail closed rather than pass silently.
final class CheckerError {
  CheckerError({required this.path, required this.message});

  /// App-relative path of the file the failure relates to.
  final String path;

  /// Actionable description of the failure.
  final String message;

  @override
  String toString() => 'checker-error: $path — $message';
}

/// Aggregated outcome of one checker run.
final class CheckerResult {
  CheckerResult({required this.violations, required this.errors});

  final List<ArchitectureViolation> violations;
  final List<CheckerError> errors;

  /// True only when no violations were found AND the sources were fully
  /// analyzable. Always assert on this, not on `violations.isEmpty`.
  bool get isClean => violations.isEmpty && errors.isEmpty;
}

/// Analyzer-based architecture checker entry points.
abstract final class ArchitectureChecker {
  /// Analyzes an in-memory fixture app. [sources] maps app-relative paths
  /// (`lib/**.dart`) to file contents. The fixture gets a package
  /// configuration merging the hosting app's resolved packages (so flutter,
  /// flutter_bloc, get_it, fpdart, … resolve) with the fixture itself as
  /// [packageName].
  static Future<CheckerResult> checkSources(
    Map<String, String> sources, {
    String packageName = fixturePackageName,
  }) async {
    final _TempDirProject project = _TempDirProject(sources, packageName);
    return project.run();
  }

  /// Analyzes the real application rooted at [appRoot] (defaults to the
  /// current directory). Only `lib/` is checked, per the generated-file
  /// policy. One analysis context is created for the whole directory.
  static Future<CheckerResult> checkDirectory({String? appRoot}) async {
    final String root = _normalizePath(appRoot ?? Directory.current.path);
    final String libRoot = '$root/lib';
    final Directory libDir = Directory(libRoot);
    if (!libDir.existsSync()) {
      return CheckerResult(
        violations: const <ArchitectureViolation>[],
        errors: <CheckerError>[
          CheckerError(path: libRoot, message: 'lib/ directory not found'),
        ],
      );
    }

    final List<String> files = <String>[];
    for (final FileSystemEntity entity in libDir.listSync(recursive: true)) {
      if (entity is File && entity.path.endsWith('.dart')) {
        files.add(_normalizePath(entity.path));
      }
    }
    files.sort();

    final _AnalyzerRun run = _AnalyzerRun();
    await run.analyze(
      rootPath: libRoot,
      files: files,
      packageName: _packageNameFromPubspec(root),
    );
    return run.result;
  }
}

// ---------------------------------------------------------------------------
// Internal runner — one analysis context per project, shared rule engine
// ---------------------------------------------------------------------------

/// One analysis pass over a set of files sharing a single analysis context.
class _AnalyzerRun {
  final List<ArchitectureViolation> violations = <ArchitectureViolation>[];
  final List<CheckerError> errors = <CheckerError>[];
  final Map<String, ResolvedUnitResult> _resolved =
      <String, ResolvedUnitResult>{};

  /// Feature dependency graph: feature → (feature → first directive that
  /// created the edge). Populated from statically visible cross-feature
  /// imports/exports/parts, including every conditional branch.
  final Map<String, Map<String, _FeatureEdge>> _featureGraph =
      <String, Map<String, _FeatureEdge>>{};

  late final String rootPath;
  late final String packageName;
  late final AnalysisSession _session;

  CheckerResult get result =>
      CheckerResult(violations: violations, errors: errors);

  Future<void> analyze({
    required String rootPath,
    required List<String> files,
    required String packageName,
  }) async {
    this.rootPath = rootPath;
    this.packageName = packageName;

    final List<String> checkable = <String>[
      for (final String path in files)
        if (!_isGeneratedFile(path)) path,
    ];
    if (checkable.isEmpty) {
      errors.add(
        CheckerError(path: rootPath, message: 'No dart files found to check.'),
      );
      return;
    }

    final AnalysisContextCollection collection = AnalysisContextCollection(
      includedPaths: <String>[rootPath],
      sdkPath: _dartSdkPath(),
    );
    try {
      final AnalysisSession session = collection
          .contextFor(rootPath)
          .currentSession;
      _session = session;
      for (final String path in checkable) {
        final SomeResolvedUnitResult someResult = await session.getResolvedUnit(
          path,
        );
        if (someResult is! ResolvedUnitResult) {
          errors.add(
            CheckerError(
              path: _relative(path),
              message: 'Analysis returned no resolved unit for this file.',
            ),
          );
          continue;
        }
        _resolved[path] = someResult;

        // Fail closed on anything the analyzer could not resolve: syntax
        // errors and unresolved URIs would silently void the rules.
        for (final Diagnostic diagnostic in someResult.diagnostics) {
          if (diagnostic.severity != Severity.error) {
            continue;
          }
          errors.add(
            CheckerError(
              path: _relative(path),
              message:
                  '${diagnostic.diagnosticCode.lowerCaseName} at line '
                  '${_lineOf(someResult, diagnostic.offset)}: '
                  '${diagnostic.problemMessage.messageText(includeUrl: false)}',
            ),
          );
        }
      }

      // Rule evaluation runs even for files with errors (more findings is
      // better), but the caller must still fail on errors.
      // Traversal may resolve generated libraries on demand. Their own
      // declarations remain exempt; only the original handwritten set is run.
      for (final String path in List<String>.of(_resolved.keys)) {
        await _checkFile(path);
      }

      // Whole-graph rules run once every file has been seen.
      _detectFeatureCycles();
    } finally {
      await collection.dispose();
    }
  }

  void _recordFeatureEdge(
    String fromFeature,
    String toFeature,
    String importerPath,
    int line,
  ) {
    final Map<String, _FeatureEdge> outgoing = _featureGraph.putIfAbsent(
      fromFeature,
      () => <String, _FeatureEdge>{},
    );
    outgoing.putIfAbsent(
      toFeature,
      () => _FeatureEdge(path: importerPath, line: line),
    );
  }

  /// Feature-cycle detection: features are graph nodes; statically visible
  /// cross-feature imports/exports/parts (including every conditional branch)
  /// are edges. A strongly connected component with more than one feature is
  /// a cycle — public-barrel access does not conceal it. Findings are
  /// deterministic (sorted nodes, smallest-first cycle) and deduplicated by
  /// edge, so repeated imports never produce duplicate diagnostics.
  void _detectFeatureCycles() {
    final List<String> nodes = _featureGraph.keys.toList()..sort();
    final Map<String, int> index = <String, int>{};
    final Map<String, int> low = <String, int>{};
    final List<String> stack = <String>[];
    final Set<String> onStack = <String>{};
    final List<List<String>> components = <List<String>>[];
    int counter = 0;

    void strongConnect(String node) {
      index[node] = counter;
      low[node] = counter;
      counter++;
      stack.add(node);
      onStack.add(node);
      final List<String> successors =
          (_featureGraph[node] ?? const <String, _FeatureEdge>{}).keys.toList()
            ..sort();
      for (final String successor in successors) {
        if (!index.containsKey(successor)) {
          strongConnect(successor);
          low[node] = low[node]! < low[successor]!
              ? low[node]!
              : low[successor]!;
        } else if (onStack.contains(successor)) {
          low[node] = low[node]! < index[successor]!
              ? low[node]!
              : index[successor]!;
        }
      }
      if (low[node] == index[node]) {
        final List<String> component = <String>[];
        while (true) {
          final String member = stack.removeLast();
          onStack.remove(member);
          component.add(member);
          if (member == node) {
            break;
          }
        }
        components.add(component);
      }
    }

    for (final String node in nodes) {
      if (!index.containsKey(node)) {
        strongConnect(node);
      }
    }

    for (final List<String> component in components) {
      if (component.length < 2) {
        continue; // single-feature components cannot be a cycle
      }
      component.sort();
      final List<String> cycle = _deterministicCycle(component);
      final _FeatureEdge? firstHop = _featureGraph[cycle.first]?[cycle[1]];
      violations.add(
        ArchitectureViolation(
          ruleId: 'feature-dependency-cycle',
          path: firstHop?.path ?? _relative(rootPath),
          line: firstHop?.line ?? 1,
          explanation:
              'features form a dependency cycle: ${cycle.join(' → ')} '
              '(strongly connected features: ${component.join(', ')}) — '
              'public-barrel access remains subject to acyclic feature '
              'dependencies',
        ),
      );
    }
  }

  /// A deterministic simple cycle through [component]: smallest-first DFS
  /// from the alphabetically first feature, always taking the smallest
  /// successor within the component. The component is strongly connected,
  /// so a cycle back to the start exists.
  List<String> _deterministicCycle(List<String> component) {
    final Set<String> members = component.toSet();
    final String start = component.first;
    final List<String> path = <String>[start];
    final Set<String> visited = <String>{start};

    bool walk(String node) {
      final List<String> successors =
          (_featureGraph[node] ?? const <String, _FeatureEdge>{}).keys.toList()
            ..sort();
      for (final String successor in successors) {
        if (successor == start && path.length >= 2) {
          path.add(start);
          return true;
        }
        if (members.contains(successor) && !visited.contains(successor)) {
          visited.add(successor);
          path.add(successor);
          if (walk(successor)) {
            return true;
          }
          path.removeLast();
          visited.remove(successor);
        }
      }
      return false;
    }

    if (!walk(start)) {
      path.add(start); // unreachable for a genuine SCC; keeps reporting valid
    }
    return path;
  }

  Future<void> _checkFile(String path) async {
    final ResolvedUnitResult result = _resolved[path]!;
    final _FileClassification importer = _classifyFile(_relative(path));

    // Directive checks: import/export/part (incl. conditional
    // configurations). `part`/`part of` are dependencies like any import —
    // the included file participates in this library's layer.
    for (final Directive directive in result.unit.directives) {
      if (directive is ImportDirective) {
        _checkDirective(importer, path, directive);
        if (importer.isDomainLike) {
          await _checkDomainImportChain(path, directive);
        }
      } else if (directive is ExportDirective) {
        _checkDirective(importer, path, directive);
        if (importer.isDomainLike) {
          await _checkDomainImportChain(path, directive);
        }
      } else if (directive is PartDirective) {
        _checkDirective(importer, path, directive);
      } else if (directive is PartOfDirective) {
        // Reverse direction: the library named by `part of` includes this
        // part file, so the layering rules are evaluated from the library's
        // side (e.g. a data file that is `part of` a domain library is a
        // domain→data dependency of that library).
        _checkPartOf(path, directive);
      }
    }

    // Usage checks via the resolved AST.
    result.unit.accept(_RuleVisitor(this, path, importer));
  }

  void _checkDirective(
    _FileClassification importer,
    String importerPath,
    UriBasedDirective directive,
  ) {
    final int line = _lineOf(_resolved[importerPath]!, directive.offset);
    for (final String uri in _directiveUris(directive)) {
      final String? targetPath = _resolveTarget(importerPath, uri);
      if (targetPath == null) {
        // External dependency — only `package:get_it` and, in domain, Flutter
        // UI libraries are restricted.
        if (uri.startsWith('package:get_it/') &&
            !locatorAllowlist.contains(importer.path)) {
          violations.add(
            ArchitectureViolation(
              ruleId: 'locator-access',
              path: importer.path,
              line: line,
              explanation:
                  'imports $uri — get_it is owned by $serviceLocatorPath; '
                  'features receive dependencies through constructors',
            ),
          );
        }
        if (importer.isDomainLike && _isFlutterUiImport(uri)) {
          violations.add(
            ArchitectureViolation(
              ruleId: 'domain-purity',
              path: importer.path,
              line: line,
              explanation:
                  'domain depends on Flutter UI library $uri — keep domain '
                  'free of UI (package:flutter/foundation.dart excepted)',
            ),
          );
        }
        continue;
      }
      _checkDependency(importer, line, uri, targetPath);
    }
  }

  /// Evaluates every per-dependency rule for one resolved `import`/`export`/
  /// `part`/`part of` relationship from [importer] to [targetPath].
  void _checkDependency(
    _FileClassification importer,
    int line,
    String uri,
    String targetPath,
  ) {
    final _FileClassification target = _classifyFile(_relative(targetPath));

    // Rule: locator access — importing the DI composition root is reserved
    // for the composition roots and bootstrap. This catches relative- and
    // package-syntax imports of `service_locator.dart` from features and
    // other files, independent of how the file's symbols are then used.
    if (_relative(targetPath) == serviceLocatorPath &&
        !serviceLocatorImportAllowlist.contains(importer.path)) {
      violations.add(
        ArchitectureViolation(
          ruleId: 'locator-access',
          path: importer.path,
          line: line,
          explanation:
              'imports $serviceLocatorPath — the service locator is only '
              'imported by ${serviceLocatorImportAllowlist.join(', ')}; '
              'features receive dependencies through constructors',
        ),
      );
    }

    // Rule: inward dependencies (domain files; barrels are whole-feature
    // APIs here — project adaptation 1).
    if (importer.isDomainLike &&
        (target.layer == _Layer.data || target.layer == _Layer.presentation)) {
      violations.add(
        ArchitectureViolation(
          ruleId: 'inward-dependency',
          path: importer.path,
          line: line,
          explanation:
              'domain imports ${target.layer.name} file ${_relative(targetPath)}',
        ),
      );
    }
    if (importer.layer == _Layer.data && target.layer == _Layer.presentation) {
      violations.add(
        ArchitectureViolation(
          ruleId: 'inward-dependency',
          path: importer.path,
          line: line,
          explanation:
              'data imports presentation file ${_relative(targetPath)}',
        ),
      );
    }
    if (importer.layer == _Layer.presentation && target.layer == _Layer.data) {
      violations.add(
        ArchitectureViolation(
          ruleId: 'inward-dependency',
          path: importer.path,
          line: line,
          explanation:
              'presentation imports data file ${_relative(targetPath)}',
        ),
      );
    }

    // Rule: domain purity (domain files).
    if (importer.isDomainLike &&
        _isDomainForbiddenAppPath(_relative(targetPath))) {
      violations.add(
        ArchitectureViolation(
          ruleId: 'domain-purity',
          path: importer.path,
          line: line,
          explanation:
              'domain depends on ${_relative(targetPath)} — l10n, router, DI '
              'and the design layer are not domain dependencies',
        ),
      );
    }

    // Rule: cross-feature access.
    if (importer.feature != null && target.feature != null) {
      if (importer.feature != target.feature) {
        _recordFeatureEdge(
          importer.feature!,
          target.feature!,
          importer.path,
          line,
        );
        final String publicBarrel =
            'lib/features/${target.feature}/${target.feature}.dart';
        if (_relative(targetPath) != publicBarrel) {
          violations.add(
            ArchitectureViolation(
              ruleId: 'cross-feature-internals',
              path: importer.path,
              line: line,
              explanation:
                  'cross-feature import of ${_relative(targetPath)} — only '
                  'the public barrel $publicBarrel may be imported',
            ),
          );
        }
      }
    }

    // Rule: infrastructure (core and root-level non-composition files).
    if (importer.isCoreLike &&
        target.feature != null &&
        !locatorAllowlist.contains(importer.path)) {
      violations.add(
        ArchitectureViolation(
          ruleId: 'core-imports-feature',
          path: importer.path,
          line: line,
          explanation:
              'core imports feature internals ${_relative(targetPath)} '
              'outside the designated composition roots',
        ),
      );
    }
  }

  /// Domain purity through re-export chains: a domain file that imports a
  /// local library which — transitively, through ANY conditional export
  /// branch — re-exports a forbidden dependency violates domain-purity, even
  /// when a `show` clause narrows the symbols. The reported explanation
  /// carries the full chain, e.g.
  /// `domain/model.dart → core/shared.dart → package:flutter/material.dart`.
  ///
  /// Scoped by design to app-local re-export chains ending in KNOWN
  /// forbidden targets (Flutter UI libraries and forbidden app files);
  /// third-party package internals are not audited exhaustively.
  ///
  /// Project adaptation 1: the chain STOPS at a public feature barrel
  /// (`lib/features/<f>/<f>.dart`) without reporting — the barrel is the
  /// feature's whole-feature public API here, so what it re-exports is the
  /// owning feature's concern, not the importer's.
  Future<void> _checkDomainImportChain(
    String importerPath,
    UriBasedDirective directive,
  ) async {
    final int line = _lineOf(_resolved[importerPath]!, directive.offset);
    final List<List<String>> toVisit = <List<String>>[];
    for (final String uri in _directiveUris(directive)) {
      final String? target = _resolveTarget(importerPath, uri);
      if (target != null) {
        toVisit.add(<String>[target]);
      }
    }
    final Set<String> visited = <String>{};
    while (toVisit.isNotEmpty) {
      final List<String> chain = toVisit.removeLast();
      final String current = chain.last;
      if (!visited.add(current)) {
        continue; // cyclic pure exports terminate here
      }
      if (_classifyFile(_relative(current)).isPublicBarrel) {
        continue; // public barrel = API boundary (project adaptation 1)
      }
      final ResolvedUnitResult? unitResult = await _unitForTraversal(current);
      if (unitResult == null) {
        continue; // _unitForTraversal records resolution errors (fail closed).
      }
      for (final Directive nested in unitResult.unit.directives) {
        if (nested is! ExportDirective && nested is! PartDirective) {
          continue;
        }
        for (final String uri in _directiveUris(nested as UriBasedDirective)) {
          final String? next = _resolveTarget(current, uri);
          if (next != null) {
            final _FileClassification target = _classifyFile(_relative(next));
            if (_isDomainForbiddenAppPath(target.path) ||
                target.layer == _Layer.data ||
                target.layer == _Layer.presentation) {
              _reportChainViolation(importerPath, line, <String>[
                ...chain.map(_relative),
                _relative(next),
              ]);
            } else {
              toVisit.add(<String>[...chain, next]);
            }
          } else if (_isFlutterUiImport(uri)) {
            _reportChainViolation(importerPath, line, <String>[
              ...chain.map(_relative),
              uri,
            ]);
          }
        }
      }
    }
  }

  /// Generated files are exempt from standalone declaration rules, but cannot
  /// conceal a dependency reached from a handwritten domain/public barrel.
  /// Resolve reached units (including unselected conditional branches) on
  /// demand and cache them for the rest of this analysis pass.
  Future<ResolvedUnitResult?> _unitForTraversal(String path) async {
    final ResolvedUnitResult? cached = _resolved[path];
    if (cached != null) {
      return cached;
    }
    final SomeResolvedUnitResult result = await _session.getResolvedUnit(path);
    if (result is! ResolvedUnitResult) {
      errors.add(
        CheckerError(
          path: _relative(path),
          message:
              'Could not resolve a library reached through an export chain.',
        ),
      );
      return null;
    }
    _resolved[path] = result;
    for (final Diagnostic diagnostic in result.diagnostics) {
      if (diagnostic.severity == Severity.error) {
        errors.add(
          CheckerError(
            path: _relative(path),
            message:
                '${diagnostic.diagnosticCode.lowerCaseName} at line '
                '${_lineOf(result, diagnostic.offset)}: '
                '${diagnostic.problemMessage.messageText(includeUrl: false)}',
          ),
        );
      }
    }
    return result;
  }

  void _reportChainViolation(
    String importerPath,
    int line,
    List<String> chain,
  ) {
    violations.add(
      ArchitectureViolation(
        ruleId: 'domain-purity',
        path: _relative(importerPath),
        line: line,
        explanation:
            'domain depends on ${chain.last} through a re-export chain '
            '(${chain.join(' → ')}) — importing a barrel that re-exports a '
            'forbidden dependency is forbidden, even behind a show clause',
      ),
    );
  }

  /// `part of` with a file URI: the named library includes this part file, so
  /// the layering rules are evaluated with the LIBRARY as the importer and
  /// the PART FILE as the target (e.g. a data-layer part of a domain library
  /// is a domain→data dependency of that library, reported even when the
  /// library's own `part` directive was never seen — generated libraries,
  /// excluded files).
  void _checkPartOf(String partPath, PartOfDirective directive) {
    final String? uri = directive.uri?.stringValue;
    // `part of some.library.name;` carries no file URI to resolve.
    if (uri == null) {
      return;
    }
    final String? libraryPath = _resolveTarget(partPath, uri);
    if (libraryPath == null) {
      return;
    }
    final _FileClassification library = _classifyFile(_relative(libraryPath));
    final int line = _lineOf(_resolved[partPath]!, directive.offset);
    _checkDependency(library, line, uri, partPath);
  }

  /// The base URI of [directive] plus the URI of every conditional
  /// configuration branch — each branch is a real dependency on some platform.
  List<String> _directiveUris(UriBasedDirective directive) => <String>[
    if (directive.uri.stringValue != null) directive.uri.stringValue!,
    for (final Configuration configuration
        in directive is NamespaceDirective
            ? directive.configurations
            : const <Configuration>[])
      if (configuration.uri.stringValue != null) configuration.uri.stringValue!,
  ];

  // -- helpers --------------------------------------------------------------

  /// App-relative path (`lib/...`) — violations and errors always report
  /// paths as they appear in the app, not as analyzed-directory paths.
  String _relative(String absolutePath) {
    final String normalized = _normalizePath(absolutePath);
    final String root = _normalizePath(rootPath);
    final String relative = normalized.startsWith('$root/')
        ? normalized.substring(root.length + 1)
        : normalized;
    return root.endsWith('/lib') ? 'lib/$relative' : relative;
  }

  int _lineOf(ResolvedUnitResult result, int offset) =>
      result.lineInfo.getLocation(offset).lineNumber;

  /// Resolves an import/export/part URI to an app file path (absolute), or
  /// `null` when it is external. Handles relative URIs (including `../`,
  /// `./`, redundant separators) and same-package `package:` URIs; both are
  /// segment-normalized (`.`, `..` and empty segments collapsed) BEFORE any
  /// layer classification, so `package:p/features/x/domain/../data/a.dart`
  /// cannot masquerade as a domain path. Returns `null` for `dart:` and
  /// third-party packages.
  String? _resolveTarget(String importerAbsPath, String uri) {
    if (uri.isEmpty || uri.startsWith('dart:')) {
      return null;
    }
    String resolved;
    if (uri.startsWith('package:')) {
      final int slash = uri.indexOf('/');
      if (slash < 0) {
        return null;
      }
      final String pkg = uri.substring('package:'.length, slash);
      if (pkg != packageName) {
        return null;
      }
      resolved =
          '$rootPath/${_normalizeSegments(uri.substring(slash + 1).split('/'))}';
    } else {
      final List<String> dir = _normalizePath(importerAbsPath).split('/')
        ..removeLast();
      resolved = _normalizeSegments(<String>[...dir, ...uri.split('/')]);
    }
    resolved = _normalizePath(resolved);
    final String root = _normalizePath(rootPath);
    return resolved.startsWith('$root/') ? resolved : null;
  }
}

/// AST visitor enforcing usage rules (locator access, registration ownership,
/// stored cubit/bloc fields).
class _RuleVisitor extends RecursiveAstVisitor<void> {
  _RuleVisitor(this._run, this._path, this._importer);

  final _AnalyzerRun _run;
  final String _path;
  final _FileClassification _importer;

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    final Element? element = node.element;
    if (element != null && !locatorAllowlist.contains(_importer.path)) {
      final bool isGetItReference =
          _isGetItElement(element) || _isDiFileVariableElement(element);
      if (isGetItReference) {
        _run.violations.add(
          ArchitectureViolation(
            ruleId: 'locator-access',
            path: _importer.path,
            line: _line(node),
            explanation:
                "references the service locator ('${node.token.lexeme}') — "
                'resolution is limited to ${locatorAllowlist.join(', ')}; '
                'feature classes use constructor injection',
          ),
        );
      }
    }
    super.visitSimpleIdentifier(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final Identifier methodName = node.methodName;
    final Element? element = methodName.element;
    if (element != null &&
        (element.name?.startsWith('register') ?? false) &&
        _isGetItElement(element) &&
        _importer.path != serviceLocatorPath) {
      _run.violations.add(
        ArchitectureViolation(
          ruleId: 'registration-outside-di',
          path: _importer.path,
          line: _line(node),
          explanation:
              "registers a dependency ('${methodName.name}') outside "
              '$serviceLocatorPath — registration is owned by the service '
              'locator only',
        ),
      );
    }
    super.visitMethodInvocation(node);
  }

  @override
  void visitFieldDeclaration(FieldDeclaration node) {
    _checkStoredCubit(node.fields);
    super.visitFieldDeclaration(node);
  }

  @override
  void visitTopLevelVariableDeclaration(TopLevelVariableDeclaration node) {
    _checkStoredCubit(node.variables);
    super.visitTopLevelVariableDeclaration(node);
  }

  void _checkStoredCubit(VariableDeclarationList fields) {
    for (final VariableDeclaration variable in fields.variables) {
      final PropertyInducingElement? element =
          variable.declaredFragment?.element as PropertyInducingElement?;
      final DartType? type = element?.type;
      if (type == null) {
        continue;
      }
      if (_isCubitType(type, <DartType>{})) {
        _run.violations.add(
          ArchitectureViolation(
            ruleId: 'stored-cubit',
            path: _importer.path,
            line: _line(variable),
            explanation:
                "stores a Cubit/Bloc-typed dependency "
                "('${variable.name.lexeme}' of type "
                '${type.getDisplayString()}) — cubits must not depend on other '
                'cubits or be stored by services; extract a domain service',
          ),
        );
      }
    }
  }

  /// True when [type] is, contains (as a type argument — containers,
  /// generics, futures), or derives from (inherited cubit subclasses) a
  /// `Cubit`/`Bloc` from package:flutter_bloc. Type aliases are already
  /// resolved into their aliased type; nullability is irrelevant.
  bool _isCubitType(DartType type, Set<DartType> visited) {
    if (!visited.add(type)) {
      return false;
    }
    if (type is InterfaceType) {
      final InterfaceElement element = type.element;
      if (_isFlutterBlocCubitElement(element)) {
        return true;
      }
      for (final InterfaceType supertype in type.allSupertypes) {
        if (_isFlutterBlocCubitElement(supertype.element)) {
          return true;
        }
      }
    }
    if (type is ParameterizedType) {
      for (final DartType argument in type.typeArguments) {
        if (_isCubitType(argument, visited)) {
          return true;
        }
      }
    }
    return false;
  }

  bool _isFlutterBlocCubitElement(InterfaceElement element) {
    if (element.name != 'Cubit' && element.name != 'Bloc') {
      return false;
    }
    // Cubit/Bloc live in package:bloc and are re-exported by flutter_bloc.
    return element.library.identifier.startsWith('package:bloc/') ||
        element.library.identifier.startsWith('package:flutter_bloc/');
  }

  bool _isGetItElement(Element element) {
    final LibraryElement? library = element.library;
    if (library == null) {
      return false;
    }
    return library.identifier.startsWith('package:get_it/');
  }

  /// True when [element] resolves to a top-level variable or property declared
  /// in the app's own DI composition root (`service_locator.dart`) — i.e. the
  /// app's `getIt`, however it is named. Functions (the bootstrap setup) are
  /// deliberately excluded so `main.dart` may call setup. This catches
  /// references that resolve through the app's library instead of
  /// `package:get_it`, which a plain get_it-library check would miss.
  bool _isDiFileVariableElement(Element element) {
    final PropertyInducingElement variable;
    if (element is PropertyAccessorElement) {
      variable = element.variable;
    } else if (element is PropertyInducingElement) {
      variable = element;
    } else {
      return false;
    }
    // Top-level variables/getters always know their library (non-nullable
    // override of Element.library).
    final LibraryElement library = variable.library;
    final String identifier = library.identifier;
    if (identifier.startsWith('package:')) {
      return identifier ==
          'package:${_run.packageName}/core/di/service_locator.dart';
    }
    return _normalizePath(
      identifier,
    ).endsWith('/lib/core/di/service_locator.dart');
  }

  int _line(AstNode node) => _run._lineOf(_run._resolved[_path]!, node.offset);
}

// ---------------------------------------------------------------------------
// Classification helpers
// ---------------------------------------------------------------------------

enum _Layer { none, data, domain, presentation }

/// The first directive observed to create a feature→feature edge; used to
/// report cycles at the source directive that participates in them.
final class _FeatureEdge {
  const _FeatureEdge({required this.path, required this.line});

  final String path;
  final int line;
}

/// Classification of one app file by its normalized app-relative path.
final class _FileClassification {
  const _FileClassification({
    required this.path,
    required this.layer,
    required this.feature,
    required this.isPublicBarrel,
    required this.isCoreLike,
  });

  /// App-relative normalized path (`lib/...`).
  final String path;
  final _Layer layer;

  /// Feature name when the file lives under `lib/features/<feature>/`.
  final String? feature;
  final bool isPublicBarrel;

  /// True for `lib/core/**` and root-level `lib/*.dart` infrastructure files
  /// (excluding `lib/app.dart`, `lib/main.dart` and the DI composition root).
  final bool isCoreLike;

  /// Domain files share the purity rules. Public feature barrels do NOT
  /// (project adaptation 1: they are whole-feature APIs here).
  bool get isDomainLike => layer == _Layer.domain;
}

/// Classifies [appRelativePath] (must be normalized, app-relative).
_FileClassification _classifyFile(String appRelativePath) {
  final String path = _normalizePath(appRelativePath);
  String? feature;
  _Layer layer = _Layer.none;
  bool isBarrel = false;

  final RegExpMatch? featureMatch = RegExp(
    r'^lib/features/([^/]+)/(.*)$',
  ).firstMatch(path);
  if (featureMatch != null) {
    feature = featureMatch.group(1);
    final String rest = featureMatch.group(2)!;
    if (rest == '$feature.dart') {
      isBarrel = true;
    } else if (rest.startsWith('data/')) {
      layer = _Layer.data;
    } else if (rest.startsWith('domain/')) {
      layer = _Layer.domain;
    } else if (rest.startsWith('presentation/')) {
      layer = _Layer.presentation;
    }
  }

  final bool isCoreLike =
      (path.startsWith('lib/core/') ||
          RegExp(r'^lib/[^/]+\.dart$').hasMatch(path)) &&
      path != 'lib/app.dart' &&
      path != 'lib/main.dart' &&
      path != serviceLocatorPath;

  return _FileClassification(
    path: path,
    layer: layer,
    feature: feature,
    isPublicBarrel: isBarrel,
    isCoreLike: isCoreLike,
  );
}

/// Generated-file policy: machine-owned declarations are exempt from standalone
/// rules. Re-export chains reached from handwritten domain files or public
/// barrels still traverse generated libraries and fail on resolution errors.
bool _isGeneratedFile(String path) {
  final String normalized = _normalizePath(path);
  return normalized.endsWith('.g.dart') ||
      normalized.endsWith('.freezed.dart') ||
      normalized.contains('/l10n/generated/');
}

/// Whether [uri] is a Flutter UI library forbidden in domain.
bool _isFlutterUiImport(String uri) {
  if (uri == 'package:flutter/foundation.dart') {
    return false;
  }
  return uri.startsWith('package:flutter/') ||
      uri.startsWith('package:flutter_localizations/');
}

/// Whether [appPath] is an app-owned file domain must not depend on.
/// The app logger is deliberately absent (project adaptation 2).
bool _isDomainForbiddenAppPath(String appPath) {
  for (final String prefix in domainForbiddenAppPrefixes) {
    if (appPath == prefix || appPath.startsWith('$prefix/')) {
      return true;
    }
  }
  return false;
}

String _normalizePath(String path) {
  String normalized = path.replaceAll(Platform.pathSeparator, '/');
  while (normalized.contains('//')) {
    normalized = normalized.replaceAll('//', '/');
  }
  return normalized;
}

String _normalizeSegments(List<String> parts) {
  final bool isAbsolute = parts.isNotEmpty && parts.first.isEmpty;
  final List<String> stack = <String>[];
  for (final String part in parts) {
    if (part == '.' || part.isEmpty) {
      continue;
    }
    if (part == '..') {
      if (stack.isNotEmpty) {
        stack.removeLast();
      }
    } else {
      stack.add(part);
    }
  }
  final String joined = stack.join('/');
  return isAbsolute ? '/$joined' : joined;
}

/// The Dart SDK of the running toolchain (`.../bin/cache/dart-sdk` inside
/// Flutter). Passed explicitly because the analyzer's SDK auto-detection can
/// pick the wrong directory when running under `flutter test`.
String? _dartSdkPath() {
  final String executable = _normalizePath(Platform.resolvedExecutable);

  // Plain Dart VM: resolvedExecutable ends with <sdk>/bin/dart or <sdk>/bin/dart.exe.
  final String binDirectory = File(executable).parent.path;
  final String vmCandidate = _normalizePath('$binDirectory/..');
  if (Directory('$vmCandidate/lib/_internal').existsSync()) {
    return vmCandidate;
  }

  // Flutter tooling (flutter_tester etc.): locate the SDK's dart-sdk directory
  // relative to the marker `<flutter>/bin/cache/artifacts/...`.
  final int cacheMarker = executable.indexOf('/bin/cache/artifacts/');
  if (cacheMarker > 0) {
    final String flutterRoot = executable.substring(0, cacheMarker);
    final String sdkCandidate = '$flutterRoot/bin/cache/dart-sdk';
    if (Directory('$sdkCandidate/lib/_internal').existsSync()) {
      return sdkCandidate;
    }
  }

  final String? flutterRootEnvironment = Platform.environment['FLUTTER_ROOT'];
  if (flutterRootEnvironment != null) {
    final String sdkCandidate = '$flutterRootEnvironment/bin/cache/dart-sdk';
    if (Directory('$sdkCandidate/lib/_internal').existsSync()) {
      return sdkCandidate;
    }
  }
  return null;
}

String _packageNameFromPubspec(String appRoot) {
  final File pubspec = File('$appRoot/pubspec.yaml');
  if (!pubspec.existsSync()) {
    return fixturePackageName;
  }
  final RegExpMatch? match = RegExp(
    r'^name:\s*(\S+)',
    multiLine: true,
  ).firstMatch(pubspec.readAsStringSync());
  return match?.group(1) ?? fixturePackageName;
}

// ---------------------------------------------------------------------------
// Temp-dir fixture project
// ---------------------------------------------------------------------------

/// Fixture project materialized in a disposable system-temp directory.
///
/// Sources stay strings (never live `.dart` files inside the analyzed app
/// tree); the temporary directory is written for the analyzer — which reads
/// the real SDK and pub cache on disk — and deleted after the run. The
/// analyzer's overlay-based in-memory workspace proved nondeterministic on
/// freshly generated apps; a real directory is not.
class _TempDirProject {
  _TempDirProject(this.sources, this.packageName);

  final Map<String, String> sources;
  final String packageName;

  Future<CheckerResult> run() async {
    final Directory root = await Directory.systemTemp.createTemp(
      'flutterforge_arch_fixture-',
    );
    try {
      final List<String> files = <String>[];
      for (final String key in sources.keys) {
        final String normalized = _normalizePath(key);
        if (!normalized.startsWith('lib/') || !normalized.endsWith('.dart')) {
          throw ArgumentError(
            'Fixture sources must be app-relative lib/**.dart paths, got: $key',
          );
        }
        final File file = File('${root.path}/$normalized');
        file.createSync(recursive: true);
        file.writeAsStringSync(sources[key]!);
        if (!_isGeneratedFile(normalized)) {
          files.add(file.path);
        }
      }

      File(
        '${root.path}/pubspec.yaml',
      ).writeAsStringSync('name: $packageName\nenvironment:\n  sdk: ^3.5.0\n');
      final Directory dartTool = Directory('${root.path}/.dart_tool');
      dartTool.createSync(recursive: true);
      File('${dartTool.path}/package_config.json').writeAsStringSync(
        jsonEncode(<String, Object?>{
          'configVersion': 2,
          'packages': <Object?>[
            ..._hostPackages(packageName),
            <String, Object?>{
              'name': packageName,
              'rootUri': root.absolute.uri.toString(),
              'packageUri': 'lib/',
              'languageVersion': '3.5',
            },
          ],
        }),
      );

      files.sort();
      final _AnalyzerRun run = _AnalyzerRun();
      await run.analyze(
        rootPath: '${root.path}/lib',
        files: files,
        packageName: packageName,
      );
      return run.result;
    } finally {
      try {
        root.deleteSync(recursive: true);
      } on FileSystemException {
        // Best effort: a leftover temp fixture directory is harmless.
      }
    }
  }

  /// Packages of the hosting app, as absolute `file:` URIs, so fixture imports
  /// of flutter / flutter_bloc / get_it / fpdart / … resolve to the same
  /// versions the generated app actually uses.
  /// Host packages, excluding any entry named like the fixture package.
  List<Map<String, Object?>> _hostPackages(String fixtureName) {
    final File config = File('.dart_tool/package_config.json');
    if (!config.existsSync()) {
      throw StateError(
        'Cannot locate .dart_tool/package_config.json of the hosting app — '
        'run the checker inside the generated app (flutter test).',
      );
    }
    final Object? decoded =
        (jsonDecode(config.readAsStringSync())
            as Map<String, Object?>)['packages'];
    final Uri base = config.absolute.parent.uri;
    final List<Object?> raw = decoded as List<Object?>;
    return <Map<String, Object?>>[
      for (final Object? entry in raw) ...<Map<String, Object?>>[
        () {
          final Map<String, Object?> package = entry! as Map<String, Object?>;
          if (package['name'] == fixtureName) {
            return const <String, Object?>{};
          }
          return <String, Object?>{
            ...package,
            'rootUri': base.resolve(package['rootUri']! as String).toString(),
          };
        }(),
      ],
    ];
  }
}
