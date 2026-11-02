/// Every test analyzes a fresh in-memory fixture project with the Dart
/// analyzer (2–9 s each in isolation); under the full-suite load of
/// concurrent test isolates a single fixture can exceed the 30 s default,
/// so the whole file gets a generous timeout.
@Timeout(Duration(minutes: 2))
library;

import 'package:flutter_test/flutter_test.dart';

import 'support/architecture_checker.dart';
import 'support/checker_expectations.dart';
import 'support/fixture_app.dart';

void main() {
  Future<void> expectClean(
    Map<String, String> sources,
    String description,
  ) async {
    final CheckerResult result = await ArchitectureChecker.checkSources(
      sources,
    );
    expect(
      result.isClean,
      isTrue,
      reason:
          '$description should pass, but got: '
          '${result.violations} ${result.errors}',
    );
  }

  Future<void> expectViolation(
    Map<String, String> sources,
    String ruleId,
    String description,
  ) async {
    final CheckerResult result = await ArchitectureChecker.checkSources(
      sources,
    );
    expect(
      result.violations.map(
        (ArchitectureViolation violation) => violation.ruleId,
      ),
      contains(ruleId),
      reason: '$description should violate $ruleId, got: ${result.violations}',
    );
  }

  group('base fixture', () {
    test(
      'valid DI, router, app composition and main bootstrap are accepted',
      () async {
        await expectClean(fixtureApp, 'the valid base fixture app');
      },
    );
  });

  group('inward dependencies', () {
    test('own domain importing own data — relative syntax', () async {
      await expectViolation(
        fixtureWith(<String, String>{
          'lib/features/alpha/domain/services/alpha_service.dart': '''
import 'package:uuid/uuid.dart';

import '../../../../core/models/failure.dart';
import '../models/alpha_model.dart';
import '../repositories/i_alpha_repository.dart';
import '../../../alpha/data/datasources/alpha_remote_datasource.dart';

class AlphaService {
  AlphaService(this._repository);
  final IAlphaRepository _repository;
}
''',
        }),
        'inward-dependency',
        'domain importing data via relative import',
      );
    });

    test('own domain importing own data — package syntax', () async {
      await expectViolation(
        fixtureWith(<String, String>{
          'lib/features/alpha/domain/services/alpha_service.dart': withImport(
            fixtureApp['lib/features/alpha/domain/services/alpha_service.dart']!,
            "import 'package:flutterforge_arch_fixture/features/alpha/data/models/alpha_dto.dart';",
          ),
          'lib/features/alpha/data/models/alpha_dto.dart': '''
class AlphaDto {
  const AlphaDto(this.id);
  final String id;
}
''',
        }),
        'inward-dependency',
        'domain importing data via package: import',
      );
    });

    test('presentation importing own data', () async {
      await expectViolation(
        fixtureWith(<String, String>{
          'lib/features/alpha/presentation/screens/alpha_screen.dart': withImport(
            fixtureApp['lib/features/alpha/presentation/screens/alpha_screen.dart']!,
            "import '../../data/datasources/alpha_remote_datasource.dart';",
          ),
        }),
        'inward-dependency',
        'presentation importing data',
      );
    });

    test('data importing own presentation', () async {
      await expectViolation(
        fixtureWith(<String, String>{
          'lib/features/alpha/data/repositories/alpha_repository_impl.dart':
              withImport(
                fixtureApp['lib/features/alpha/data/repositories/alpha_repository_impl.dart']!,
                "import '../../presentation/bloc/alpha_cubit.dart';",
              ),
        }),
        'inward-dependency',
        'data importing presentation',
      );
    });
  });

  group('domain purity', () {
    test('domain importing flutter/material is rejected', () async {
      await expectViolation(
        fixtureWith(<String, String>{
          'lib/features/alpha/domain/models/alpha_model.dart': '''
import 'package:flutter/material.dart';

class AlphaModel {
  const AlphaModel(this.id);
  final String id;
  Color get color => Colors.blue;
}
''',
        }),
        'domain-purity',
        'domain importing flutter/material',
      );
    });

    test('domain importing generated localizations is rejected', () async {
      await expectDomainForbidden(
        "import '../../../../core/l10n/generated/app_localizations.dart';",
      );
    });

    test('domain importing the router is rejected', () async {
      await expectDomainForbidden(
        "import '../../../../core/router/app_router.dart';",
      );
    });

    test('domain importing the DI composition root is rejected', () async {
      await expectDomainForbidden(
        "import '../../../../core/di/service_locator.dart';",
      );
    });

    test('domain importing the design layer is rejected', () async {
      await expectDomainForbidden(
        "import '../../../../core/design/design.dart';",
      );
    });

    test(
      'domain importing the app logger is accepted (project adaptation 2)',
      () async {
        await expectClean(
          fixtureWith(<String, String>{
            'lib/features/alpha/domain/services/alpha_service.dart': withImport(
              fixtureApp['lib/features/alpha/domain/services/alpha_service.dart']!,
              "import '../../../../core/utils/logger.dart';",
            ),
          }),
          'domain services log through the app logger by convention',
        );
      },
    );

    test(
      'domain may depend on pure shared models and approved Dart packages',
      () async {
        await expectClean(fixtureApp, 'domain importing core/models and uuid');
      },
    );
  });

  group('cross-feature access', () {
    test('allowed: importing another feature public domain contract via its '
        'barrel', () async {
      final CheckerResult result = await ArchitectureChecker.checkSources(
        fixtureWith(<String, String>{
          'lib/features/alpha/domain/services/alpha_service.dart': '''
import 'package:flutterforge_arch_fixture/features/beta/beta.dart';
import '../repositories/i_alpha_repository.dart';

class AlphaService implements BetaContract {
  AlphaService(this._repository);
  final IAlphaRepository _repository;

  @override
  String describe() => 'alpha';
}
''',
          'lib/features/beta/beta.dart': '''
export 'domain/models/beta_model.dart';
export 'domain/contracts/beta_contract.dart';
''',
        }),
      );
      expect(
        result.violations
            .where(
              (ArchitectureViolation violation) =>
                  violation.ruleId == 'cross-feature-internals',
            )
            .toList(),
        isEmpty,
        reason: 'importing the public barrel is allowed: ${result.violations}',
      );
      expect(result.errors, isEmpty, reason: 'fixture must be analyzable');
    });

    test('allowed: importing a whole-feature barrel that also re-exports '
        'presentation (project adaptation 1)', () async {
      // This app's feature barrels expose their presentation layer too
      // (cubits, widgets) — that is how Home consumes features. A domain
      // file importing such a barrel for its DOMAIN symbols must stay
      // clean; the chain stops at the barrel boundary.
      final CheckerResult result = await ArchitectureChecker.checkSources(
        fixtureWith(<String, String>{
          'lib/features/beta/beta.dart': '''
export 'domain/models/beta_model.dart';
export 'domain/contracts/beta_contract.dart';
export 'presentation/beta_screen.dart';
''',
          'lib/features/alpha/domain/services/alpha_service.dart': '''
import 'package:flutterforge_arch_fixture/features/beta/beta.dart'
    show BetaContract;

import '../repositories/i_alpha_repository.dart';

class AlphaService implements BetaContract {
  AlphaService(this._repository);
  final IAlphaRepository _repository;

  @override
  String describe() => 'alpha';
}
''',
        }),
      );
      expect(
        result.isClean,
        isTrue,
        reason:
            'the barrel is the feature API; the chain must stop there: '
            '${result.violations} ${result.errors}',
      );
    });

    test('rejected: direct import of another feature domain internals', () async {
      await expectViolation(
        fixtureWith(<String, String>{
          'lib/features/alpha/domain/services/alpha_service.dart': withImport(
            fixtureApp['lib/features/alpha/domain/services/alpha_service.dart']!,
            "import '../../../beta/domain/models/beta_model.dart';",
          ),
        }),
        'cross-feature-internals',
        'direct domain-internal cross-feature import',
      );
    });

    test('rejected: cross-feature data and presentation imports', () async {
      await expectViolation(
        fixtureWith(<String, String>{
          'lib/features/alpha/domain/services/alpha_service.dart': withImport(
            fixtureApp['lib/features/alpha/domain/services/alpha_service.dart']!,
            "import 'package:flutterforge_arch_fixture/features/beta/data/beta_repository.dart';",
          ),
        }),
        'cross-feature-internals',
        'cross-feature data import',
      );
      await expectViolation(
        fixtureWith(<String, String>{
          'lib/features/alpha/presentation/screens/alpha_screen.dart': withImport(
            fixtureApp['lib/features/alpha/presentation/screens/alpha_screen.dart']!,
            "import 'package:flutterforge_arch_fixture/features/beta/presentation/beta_screen.dart';",
          ),
        }),
        'cross-feature-internals',
        'cross-feature presentation import',
      );
    });

    test('accepted: barrel exposing its own feature data layer '
        '(project adaptation 1)', () async {
      await expectClean(
        fixtureWith(<String, String>{
          'lib/features/beta/beta.dart': '''
export 'domain/models/beta_model.dart';
export 'domain/contracts/beta_contract.dart';
export 'data/beta_repository.dart';
''',
        }),
        'whole-feature barrels may re-export any layer of their feature',
      );
    });

    test('accepted: barrel re-exporting a neutral gateway that exposes data '
        '(project adaptation 1)', () async {
      // The template policed what a barrel reaches transitively
      // (`barrel-exposes-implementation`); here the barrel is the API
      // boundary, so its transitive exports are the feature's own concern.
      // The gateway is a layer-neutral file at the feature root (not a
      // domain file — a domain file directly exporting data stays an
      // inward-dependency violation).
      await expectClean(
        fixtureWith(<String, String>{
          'lib/features/beta/beta.dart': '''
export 'domain/models/beta_model.dart';
export 'domain/contracts/beta_contract.dart';
export 'gateway.dart';
''',
          'lib/features/beta/gateway.dart': '''
export 'data/beta_repository.dart';
''',
        }),
        'the public barrel is the API boundary, not its transitive exports',
      );
    });

    test('accepted: barrel conditionally exporting a data implementation '
        '(project adaptation 1)', () async {
      await expectClean(
        fixtureWith(<String, String>{
          'lib/features/beta/beta.dart': '''
export 'domain/models/beta_model.dart';
export 'domain/contracts/beta_contract.dart'
    if (dart.library.io) 'data/beta_repository.dart';
''',
        }),
        'conditional export branch of an own-feature file via the barrel',
      );
    });

    test('accepted: public barrel importing its own data implementation '
        '(project adaptation 1)', () async {
      await expectClean(
        fixtureWith(<String, String>{
          'lib/features/beta/beta.dart': '''
import 'data/beta_repository.dart';

export 'domain/models/beta_model.dart';
export 'domain/contracts/beta_contract.dart';
''',
        }),
        'barrels are not held to domain purity here',
      );
    });

    test(
      'accepted: public contract importing its own domain contract',
      () async {
        await expectClean(
          fixtureWith(<String, String>{
            'lib/features/beta/beta.dart': '''
import 'domain/contracts/beta_contract.dart';

export 'domain/models/beta_model.dart';
export 'domain/contracts/beta_contract.dart';
''',
          }),
          'public barrel importing a domain file',
        );
      },
    );
  });

  group('part and part-of relationships', () {
    test('rejected: domain library including a data file through part', () async {
      await expectViolation(
        fixtureWith(<String, String>{
          'lib/features/alpha/domain/services/alpha_service.dart': withImport(
            fixtureApp['lib/features/alpha/domain/services/alpha_service.dart']!,
            "part '../../data/leak_part.dart';",
          ),
          'lib/features/alpha/data/leak_part.dart': '''
part of '../domain/services/alpha_service.dart';

class LeakedData {
  const LeakedData();
}
''',
        }),
        'inward-dependency',
        'domain library with a data part file',
      );
    });

    test('rejected: data file that is part of a domain library (part-of side '
        'alone, library excluded as generated)', () async {
      // Isolates the part-of mechanism: the library is a `.g.dart` file,
      // excluded from checking by the generated-file policy, so its own
      // `part` directive is never evaluated — only the part file's
      // `part of` can expose the domain→data dependency.
      await expectViolation(
        fixtureWith(<String, String>{
          'lib/features/alpha/domain/services/alpha_service.g.dart': '''
part '../../data/leak_part.dart';
''',
          'lib/features/alpha/data/leak_part.dart': '''
part of '../domain/services/alpha_service.g.dart';

class LeakedData {
  const LeakedData();
}
''',
        }),
        'inward-dependency',
        'part-of dependency reported from the library side alone',
      );
    });

    test('accepted: domain library with a same-layer domain part', () async {
      await expectClean(
        fixtureWith(<String, String>{
          'lib/features/alpha/domain/services/alpha_service.dart': withImport(
            fixtureApp['lib/features/alpha/domain/services/alpha_service.dart']!,
            "part 'alpha_service_helpers.dart';",
          ),
          'lib/features/alpha/domain/services/alpha_service_helpers.dart': '''
part of 'alpha_service.dart';

class AlphaServiceHelper {
  const AlphaServiceHelper();
}
''',
        }),
        'same-layer part inclusion',
      );
    });
  });

  group('stored state controllers', () {
    Future<void> expectStoredCubit(String fieldDeclaration, String why) async {
      await expectViolation(
        fixtureWith(<String, String>{
          'lib/features/alpha/presentation/bloc/beta_mirror_cubit.dart':
              '''
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:uuid/uuid.dart';

import '../../../../core/models/failure.dart';
import '../../domain/models/alpha_model.dart';
import '../../domain/repositories/i_alpha_repository.dart';
import '../../domain/services/alpha_service.dart';
import 'alpha_cubit.dart';

class MirrorCubit extends Cubit<AlphaState2> {
  MirrorCubit(this._service) : super(const AlphaInitial2());

  final AlphaService _service;
  $fieldDeclaration
}

typedef AlphaCubitRef = AlphaCubit;

AlphaCubit placeholder() => AlphaCubit(AlphaService(PlaceholderRepository()));

class PlaceholderRepository implements IAlphaRepository {
  @override
  Future<AlphaModel?> fetch() async => null;
}

AlphaCubit placeholder2() => placeholder();

class AlphaState2 {}

class AlphaInitial2 extends AlphaState2 {
  const AlphaInitial2();
}
''',
        }),
        'stored-cubit',
        why,
      );
    }

    test('nullable stored cubit is rejected', () async {
      await expectStoredCubit('AlphaCubit? _other;', 'nullable cubit field');
    });

    test('late final stored cubit is rejected', () async {
      await expectStoredCubit(
        'late final AlphaCubit _other;',
        'late final cubit field',
      );
    });

    test('mutable (non-final) stored cubit is rejected', () async {
      await expectStoredCubit(
        'AlphaCubit _other = placeholder();',
        'mutable cubit field',
      );
    });

    test('aliased stored cubit is rejected', () async {
      await expectStoredCubit(
        'AlphaCubitRef _other = placeholder2();',
        'aliased cubit field',
      );
    });

    test('generic/container stored cubit is rejected', () async {
      await expectStoredCubit(
        'List<AlphaCubit> _others = <AlphaCubit>[];',
        'container cubit field',
      );
    });

    test('unusually named Cubit subclass stored is rejected', () async {
      await expectViolation(
        fixtureWith(<String, String>{
          'lib/features/alpha/presentation/bloc/weird_cubit.dart': '''
import 'package:flutter_bloc/flutter_bloc.dart';

class WeirdController extends Cubit<int> {
  WeirdController() : super(0);
}
''',
          'lib/features/alpha/presentation/bloc/beta_mirror_cubit.dart': '''
import 'package:flutter_bloc/flutter_bloc.dart';

import 'weird_cubit.dart';

class Holder {
  WeirdController stored = WeirdController();
}
''',
        }),
        'stored-cubit',
        'unusually named cubit subclass stored as field',
      );
    });

    test('cubit inheriting another stored/inherited type chain is rejected '
        '(inherited cubit type)', () async {
      await expectViolation(
        fixtureWith(<String, String>{
          'lib/features/alpha/presentation/bloc/weird_cubit.dart': '''
import 'package:flutter_bloc/flutter_bloc.dart';

class WeirdController extends Cubit<int> {
  WeirdController() : super(0);
}

class DerivedController extends WeirdController {
  DerivedController() : super();
}
''',
          'lib/features/alpha/presentation/bloc/beta_mirror_cubit.dart': '''
import 'weird_cubit.dart';

class Holder {
  DerivedController stored = DerivedController();
}
''',
        }),
        'stored-cubit',
        'field typed as a subclass of a Cubit subclass (inherited type)',
      );
    });

    test('allowed: local context.read inside a widget callback', () async {
      await expectClean(fixtureApp, 'context.read inside onPressed callback');
    });

    test('allowed: non-cubit fields', () async {
      await expectClean(
        fixtureWith(<String, String>{
          'lib/features/alpha/presentation/bloc/beta_mirror_cubit.dart': '''
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/services/alpha_service.dart';

class AlphaState3 {
  const AlphaState3();
}

class MirrorCubit extends Cubit<AlphaState3> {
  MirrorCubit(this._service) : super(const AlphaState3());

  final AlphaService _service;
  final List<String> items = <String>[];
}
''',
        }),
        'service field is not a cubit field',
      );
    });
  });

  group('locator access', () {
    test('rejected: feature-level direct getIt resolution', () async {
      await expectViolation(
        fixtureWith(<String, String>{
          'lib/features/alpha/domain/services/alpha_service.dart': getItFixture(
            "import 'package:get_it/get_it.dart';",
            'final AlphaService self = getIt<AlphaService>();',
          ),
        }),
        'locator-access',
        'feature-level getIt resolution',
      );
    });

    test('rejected: aliased GetIt.instance resolution in a feature', () async {
      await expectViolation(
        fixtureWith(<String, String>{
          'lib/features/alpha/domain/services/alpha_service.dart': getItFixture(
            "import 'package:get_it/get_it.dart' as sl;",
            'final AlphaService self = sl.GetIt.instance<AlphaService>();',
          ),
        }),
        'locator-access',
        'aliased GetIt.instance resolution',
      );
    });

    test('rejected: presentation resolving getIt via relative DI import '
        '(no package:get_it import)', () async {
      await expectViolation(
        fixtureWith(<String, String>{
          'lib/features/alpha/presentation/screens/alpha_screen.dart': '''
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/service_locator.dart';
import '../bloc/alpha_cubit.dart';
import '../bloc/alpha_state.dart';

class AlphaScreen extends StatelessWidget {
  const AlphaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AlphaCubit>(
      create: (_) => getIt<AlphaCubit>(),
      child: Scaffold(
        body: BlocBuilder<AlphaCubit, AlphaState>(
          builder: (BuildContext context, AlphaState state) =>
              const Text('alpha'),
        ),
      ),
    );
  }
}
''',
        }),
        'locator-access',
        'presentation resolving getIt through the relative DI import',
      );
    });

    test('rejected: domain resolving getIt via relative DI import '
        '(no package:get_it import)', () async {
      await expectViolation(
        fixtureWith(<String, String>{
          'lib/features/alpha/domain/services/alpha_service.dart': '''
import '../../../../core/di/service_locator.dart';
import '../models/alpha_model.dart';
import '../repositories/i_alpha_repository.dart';

class AlphaService {
  AlphaService(this._repository);

  final IAlphaRepository _repository;

  AlphaModel? grab() => getIt<AlphaModel>();
}
''',
        }),
        'locator-access',
        'domain resolving getIt through the relative DI import',
      );
    });

    test(
      'accepted: main.dart imports the DI file for bootstrap setup only',
      () async {
        await expectClean(
          fixtureApp,
          'main.dart importing service_locator.dart and calling '
          'setupServiceLocator() without touching getIt',
        );
      },
    );

    test('rejected: registration outside service_locator.dart', () async {
      final String routerWithDataSource = withImport(
        fixtureApp['lib/core/router/app_router.dart']!,
        "import '../../features/alpha/data/datasources/alpha_remote_datasource.dart';",
      );
      await expectViolation(
        fixtureWith(<String, String>{
          'lib/core/router/app_router.dart':
              '$routerWithDataSource\n'
              'void sneaky() => getIt.registerFactory<AlphaCubit>(\n'
              '    () => AlphaCubit(AlphaService(AlphaRepository(AlphaRemoteDataSource()))));\n',
        }),
        'registration-outside-di',
        'registration in app_router',
      );
    });

    test('accepted: constructor injection in features', () async {
      await expectClean(fixtureApp, 'constructor injection');
    });
  });

  group('composition and bootstrap', () {
    test('accepted: app.dart composing app-scoped providers with '
        'presentation imports', () async {
      await expectClean(
        fixtureApp,
        'app.dart composition with presentation imports',
      );
    });

    test('accepted: main bootstrap calling setup + runApp', () async {
      await expectClean(fixtureApp, 'main bootstrap');
    });

    test('rejected: main.dart registering dependencies', () async {
      await expectViolation(
        fixtureWith(<String, String>{
          'lib/main.dart': '''
import 'package:flutter/material.dart';

import 'app.dart';
import 'core/di/service_locator.dart';
import 'features/alpha/presentation/bloc/alpha_cubit.dart';
import 'features/alpha/domain/services/alpha_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  getIt.registerFactory<AlphaCubit>(() => AlphaCubit(AlphaService(getIt(null))));
  await setupServiceLocator();
  runApp(const MyApp());
}
''',
        }),
        'registration-outside-di',
        'registration in main.dart',
      );
    });

    test('rejected: core importing feature internals outside composition '
        'roots', () async {
      await expectViolation(
        fixtureWith(<String, String>{
          'lib/core/services/example_service.dart': '''
import '../../features/alpha/presentation/bloc/alpha_cubit.dart';

class ExampleService {
  ExampleService();
}
''',
        }),
        'core-imports-feature',
        'core importing presentation',
      );
    });
  });

  group('syntax and resolution handling', () {
    test('conditional imports are inspected on every branch', () async {
      await expectViolation(
        fixtureWith(<String, String>{
          'lib/features/alpha/domain/services/alpha_service.dart': '''
import 'package:uuid/uuid.dart';

import '../../../../core/models/failure.dart';
import '../models/alpha_model.dart';
import '../repositories/i_alpha_repository.dart'
    if (dart.library.io) '../../../alpha/data/datasources/alpha_remote_datasource.dart';

class AlphaService {
  AlphaService(this._repository);
  final IAlphaRepository _repository;
}
''',
        }),
        'inward-dependency',
        'conditional import data branch',
      );
    });

    test('multiline import syntax is inspected', () async {
      await expectViolation(
        fixtureWith(<String, String>{
          'lib/features/alpha/presentation/screens/alpha_screen.dart': '''
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import
    '../../data/datasources/alpha_remote_datasource.dart';
import '../bloc/alpha_cubit.dart';
import '../bloc/alpha_state.dart';

class AlphaScreen extends StatelessWidget {
  const AlphaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AlphaCubit, AlphaState>(
      builder: (BuildContext context, AlphaState state) => const Text('x'),
    );
  }
}
''',
        }),
        'inward-dependency',
        'multiline import',
      );
    });

    test('path normalization: ../ chains and ./ segments resolve to the same '
        'file identity', () async {
      await expectViolation(
        fixtureWith(<String, String>{
          'lib/features/alpha/domain/services/alpha_service.dart': withImport(
            fixtureApp['lib/features/alpha/domain/services/alpha_service.dart']!,
            "import './../.././../alpha/data/datasources/./alpha_remote_datasource.dart';",
          ),
        }),
        'inward-dependency',
        'normalized path resolves to data file',
      );
    });

    test('path normalization: package import whose ../ segments collapse into '
        'the data layer', () async {
      await expectViolation(
        fixtureWith(<String, String>{
          'lib/features/alpha/domain/services/alpha_service.dart': withImport(
            fixtureApp['lib/features/alpha/domain/services/alpha_service.dart']!,
            "import 'package:flutterforge_arch_fixture/features/alpha/domain/../data/datasources/alpha_remote_datasource.dart';",
          ),
        }),
        'inward-dependency',
        'package import with .. collapsing into a data file',
      );
    });

    test(
      'malformed fixture (syntax error) fails loudly, not silently',
      () async {
        final CheckerResult result = await ArchitectureChecker.checkSources(
          fixtureWith(<String, String>{
            'lib/features/alpha/domain/models/broken.dart': 'class Broken {',
          }),
        );
        expect(result.errors, isNotEmpty, reason: 'syntax error must surface');
        expect(result.isClean, isFalse);
      },
    );

    test(
      'unresolved import fails loudly with an actionable checker error',
      () async {
        final CheckerResult result = await ArchitectureChecker.checkSources(
          fixtureWith(<String, String>{
            'lib/features/alpha/domain/services/alpha_service.dart': withImport(
              fixtureApp['lib/features/alpha/domain/services/alpha_service.dart']!,
              "import '../repositories/does_not_exist.dart';",
            ),
          }),
        );
        expect(
          result.errors,
          isNotEmpty,
          reason: 'unresolved URI must surface',
        );
        expect(
          result.errors.any(
            (CheckerError error) =>
                error.message.contains('does_not_exist.dart'),
          ),
          isTrue,
          reason: 'error should name the unresolved file: ${result.errors}',
        );
      },
    );

    test('unresolved package import fails loudly', () async {
      final CheckerResult result = await ArchitectureChecker.checkSources(
        fixtureWith(<String, String>{
          'lib/features/alpha/domain/services/alpha_service.dart': withImport(
            fixtureApp['lib/features/alpha/domain/services/alpha_service.dart']!,
            "import 'package:not_a_real_package/nope.dart';",
          ),
        }),
      );
      expect(result.errors, isNotEmpty);
    });
  });

  group('generated-file policy', () {
    test('generated implementation files are excluded from checking', () async {
      await expectClean(
        fixtureWith(<String, String>{
          'lib/features/alpha/presentation/bloc/alpha_cubit.freezed.dart': '''
// Generated garbage that would violate every rule if checked.
import 'dart:html';
import '../../data/datasources/alpha_remote_datasource.dart';
class FreezedJunk {
  AlphaCubit? _cubit;
}
''',
          'lib/core/l10n/generated/app_localizations.dart': '''
import 'package:flutter/material.dart';
import '../../features/alpha/data/datasources/alpha_remote_datasource.dart';
class AppLocalizations {}
''',
        }),
        'generated files excluded by policy',
      );
    });
  });
}
