/// In-memory fixture app used by the architecture checker tests.
///
/// The base skeleton is a miniature but complete valid application (bootstrap,
/// composition, DI, router, two features with full layering) that the checker
/// must accept as-is. Individual tests override or add files to introduce one
/// violation at a time.
///
/// Fixtures are plain source strings — no live broken `.dart` files are ever
/// written into the analyzed source tree.
///
/// Project adaptation: the template's fixtures import `package:fpdart` as
/// their "approved pure Dart package" example; fpdart is banned in this app,
/// so the fixtures use `package:uuid` (a pure-Dart dependency) instead.
library;

/// The valid base fixture app: `lib/**.dart` path → source.
final Map<String, String> fixtureApp = <String, String>{
  // The forbidden localization import must resolve: negative policy fixtures
  // must fail because of the boundary rule rather than a missing-file error.
  'lib/core/l10n/generated/app_localizations.dart':
      'class AppLocalizations {}\n',
  'lib/main.dart': '''
import 'package:flutter/material.dart';

import 'app.dart';
import 'core/di/service_locator.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setupServiceLocator();
  runApp(const MyApp());
}
''',
  'lib/app.dart': '''
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/di/service_locator.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/alpha/presentation/bloc/alpha_cubit.dart';
import 'features/alpha/presentation/screens/alpha_screen.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AlphaCubit>(
      create: (_) => getIt<AlphaCubit>()..load(),
      child: MaterialApp.router(
        theme: AppTheme.lightTheme,
        routerConfig: AppRouter.router,
      ),
    );
  }
}
''',
  'lib/core/di/service_locator.dart': '''
import 'package:get_it/get_it.dart';

import '../../features/alpha/data/datasources/alpha_remote_datasource.dart';
import '../../features/alpha/data/repositories/alpha_repository_impl.dart';
import '../../features/alpha/domain/repositories/i_alpha_repository.dart';
import '../../features/alpha/domain/services/alpha_service.dart';
import '../../features/alpha/presentation/bloc/alpha_cubit.dart';

final GetIt getIt = GetIt.instance;

Future<void> setupServiceLocator() async {
  getIt.registerLazySingleton<IAlphaRemoteDataSource>(
    () => AlphaRemoteDataSource(),
  );
  getIt.registerLazySingleton<IAlphaRepository>(
    () => AlphaRepository(getIt<IAlphaRemoteDataSource>()),
  );
  getIt.registerLazySingleton<AlphaService>(
    () => AlphaService(getIt<IAlphaRepository>()),
  );
  getIt.registerFactory<AlphaCubit>(() => AlphaCubit(getIt<AlphaService>()));
}
''',
  'lib/core/router/app_router.dart': '''
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../di/service_locator.dart';
import '../../features/alpha/presentation/bloc/alpha_cubit.dart';
import '../../features/alpha/presentation/screens/alpha_screen.dart';

class AppRouter {
  AppRouter._();

  static final GoRouter router = GoRouter(
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (BuildContext context, GoRouterState state) {
          return BlocProvider<AlphaCubit>(
            create: (_) => getIt<AlphaCubit>(),
            child: const AlphaScreen(),
          );
        },
      ),
    ],
  );
}
''',
  'lib/core/theme/app_theme.dart': '''
import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme => ThemeData.light();
}
''',
  'lib/core/design/design.dart': '''
import 'package:flutter/material.dart';

class AppDesign {
  AppDesign._();

  static ThemeData get theme => ThemeData.light();
}
''',
  'lib/core/utils/logger.dart': '''
class AppLogger {
  void log(String message) {}
}
''',
  'lib/core/models/failure.dart': '''
class Failure {
  const Failure(this.message);
  final String message;
}
''',
  'lib/features/alpha/alpha.dart': '''
export 'domain/models/alpha_model.dart';
export 'domain/repositories/i_alpha_repository.dart';
''',
  'lib/features/alpha/domain/models/alpha_model.dart': '''
class AlphaModel {
  const AlphaModel(this.id);
  final String id;
}
''',
  'lib/features/alpha/domain/repositories/i_alpha_repository.dart': '''
import 'package:uuid/uuid.dart';

import '../../../../core/models/failure.dart';
import '../models/alpha_model.dart';

abstract interface class IAlphaRepository {
  Future<AlphaModel?> fetch();
}
''',
  'lib/features/alpha/domain/services/alpha_service.dart': '''
import 'package:uuid/uuid.dart';

import '../../../../core/models/failure.dart';
import '../models/alpha_model.dart';
import '../repositories/i_alpha_repository.dart';

class AlphaService {
  AlphaService(this._repository);

  final IAlphaRepository _repository;

  Future<AlphaModel?> get() => _repository.fetch();
}
''',
  'lib/features/alpha/data/datasources/alpha_remote_datasource.dart': '''
import 'package:flutter/foundation.dart';

abstract interface class IAlphaRemoteDataSource {
  Future<String> fetch();
}

class AlphaRemoteDataSource implements IAlphaRemoteDataSource {
  @override
  Future<String> fetch() async => 'alpha';
}
''',
  'lib/features/alpha/data/repositories/alpha_repository_impl.dart': '''
import 'package:uuid/uuid.dart';

import '../../../../core/models/failure.dart';
import '../../domain/models/alpha_model.dart';
import '../../domain/repositories/i_alpha_repository.dart';
import '../datasources/alpha_remote_datasource.dart';

class AlphaRepository implements IAlphaRepository {
  AlphaRepository(this._dataSource);

  final IAlphaRemoteDataSource _dataSource;

  @override
  Future<AlphaModel?> fetch() async {
    return AlphaModel(await _dataSource.fetch());
  }
}
''',
  'lib/features/alpha/presentation/bloc/alpha_state.dart': '''
sealed class AlphaState {
  const AlphaState();
}

class AlphaInitial extends AlphaState {
  const AlphaInitial();
}

class AlphaLoaded extends AlphaState {
  const AlphaLoaded(this.model);
  final String model;
}
''',
  'lib/features/alpha/presentation/bloc/alpha_cubit.dart': '''
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/services/alpha_service.dart';
import 'alpha_state.dart';

class AlphaCubit extends Cubit<AlphaState> {
  AlphaCubit(this._service) : super(const AlphaInitial());

  final AlphaService _service;

  Future<void> load() async {
    emit(const AlphaLoaded('done'));
  }
}
''',
  'lib/features/alpha/presentation/screens/alpha_screen.dart': '''
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/alpha_cubit.dart';
import '../bloc/alpha_state.dart';

class AlphaScreen extends StatelessWidget {
  const AlphaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocBuilder<AlphaCubit, AlphaState>(
        builder: (BuildContext context, AlphaState state) {
          return TextButton(
            onPressed: () => context.read<AlphaCubit>().load(),
            child: const Text('load'),
          );
        },
      ),
    );
  }
}
''',
  'lib/features/beta/beta.dart': '''
export 'domain/models/beta_model.dart';
export 'domain/contracts/beta_contract.dart';
''',
  'lib/features/beta/domain/models/beta_model.dart': '''
class BetaModel {
  const BetaModel(this.id);
  final String id;
}
''',
  'lib/features/beta/domain/contracts/beta_contract.dart': '''
abstract interface class BetaContract {
  String describe();
}
''',
  'lib/features/beta/data/beta_repository.dart': '''
import '../beta.dart';

class BetaRepository implements BetaContract {
  @override
  String describe() => 'beta';
}
''',
  'lib/features/beta/presentation/beta_screen.dart': '''
import 'package:flutter/material.dart';

class BetaScreen extends StatelessWidget {
  const BetaScreen({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
''',
};

/// Inserts [importLine] right after the last top-of-file import of [source],
/// keeping directives before declarations.
String withImport(String source, String importLine) {
  final List<String> lines = source.split('\n');
  int lastImport = -1;
  for (int i = 0; i < lines.length; i++) {
    if (lines[i].startsWith('import ')) {
      lastImport = i;
    }
  }
  lines.insert(lastImport + 1, importLine);
  return lines.join('\n');
}

/// Merges the valid [fixtureApp] skeleton with [overrides]/[additions].
Map<String, String> fixtureWith(Map<String, String> extra) => <String, String>{
  ...fixtureApp,
  ...extra,
};
