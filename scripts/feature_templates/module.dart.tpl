import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/route_constants.dart';
import 'data/datasources/{{FEATURE_SNAKE}}_remote_datasource.dart';
import 'data/repositories/{{FEATURE_SNAKE}}_repository_impl.dart';
import 'domain/repositories/{{FEATURE_SNAKE}}_repository.dart';
{{MODULE_SERVICE_IMPORT}}import 'presentation/bloc/{{FEATURE_SNAKE}}_cubit.dart';
import 'presentation/screens/{{FEATURE_SNAKE}}_screen.dart';

/// Composition root of the {{FEATURE_SNAKE}} feature: its registrations and
/// routes. Only `service_locator.dart` and `app_router.dart` import this file.
void register{{FEATURE_PASCAL}}Feature(
  GetIt getIt, {
  I{{FEATURE_PASCAL}}RemoteDataSource? remoteDataSource,
}) {
  getIt.registerLazySingleton<I{{FEATURE_PASCAL}}RemoteDataSource>(
    () => remoteDataSource ?? {{FEATURE_PASCAL}}RemoteDataSource(),
  );
  getIt.registerLazySingleton<I{{FEATURE_PASCAL}}Repository>(
    () => {{FEATURE_PASCAL}}Repository(getIt<I{{FEATURE_PASCAL}}RemoteDataSource>()),
  );
{{MODULE_SERVICE_REGISTRATION}}  getIt.registerFactory<{{FEATURE_PASCAL}}Cubit>(
    () => {{FEATURE_PASCAL}}Cubit(getIt<{{CUBIT_DEP_TYPE}}>()),
  );
}

List<RouteBase> {{FEATURE_CAMEL}}Routes(GetIt getIt) => <RouteBase>[
  GoRoute(
    path: Routes.{{FEATURE_CAMEL}},
    name: '{{FEATURE_PASCAL}}',
    builder: (BuildContext context, GoRouterState state) =>
        BlocProvider<{{FEATURE_PASCAL}}Cubit>(
          create: (_) => getIt<{{FEATURE_PASCAL}}Cubit>()..loadData(),
          child: const {{FEATURE_PASCAL}}Screen(),
        ),
  ),
];
