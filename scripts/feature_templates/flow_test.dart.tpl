import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:{{PROJECT_NAME}}/core/l10n/app_localization_delegates.dart';
import 'package:{{PROJECT_NAME}}/core/l10n/generated/app_localizations.dart';
import 'package:{{PROJECT_NAME}}/core/router/route_constants.dart';
import 'package:{{PROJECT_NAME}}/features/{{FEATURE_SNAKE}}/data/datasources/{{FEATURE_SNAKE}}_remote_datasource.dart';
import 'package:{{PROJECT_NAME}}/features/{{FEATURE_SNAKE}}/{{FEATURE_SNAKE}}_module.dart';
import '{{FLOW_TEST_DATA_IMPORT}}';

class _Fake{{FEATURE_PASCAL}}DataSource implements {{FEATURE_PASCAL}}RemoteDataSource {
  @override
  Future<{{DATA_SOURCE_RETURN_TYPE}}> getData() async => {{FLOW_TEST_DATA}};
}

/// Real wiring over a fake data source: the module's registrations, its
/// route, cubit, repository and screen, with no network.
void main() {
  testWidgets('the {{FEATURE_SNAKE}} route loads and renders its data', (
    WidgetTester tester,
  ) async {
    final GetIt getIt = GetIt.asNewInstance();
    addTearDown(getIt.reset);
    register{{FEATURE_PASCAL}}Feature(getIt, remoteDataSource: _Fake{{FEATURE_PASCAL}}DataSource());
    final GoRouter router = GoRouter(
      initialLocation: RouteConstants.{{FEATURE_CAMEL}},
      routes: {{FEATURE_CAMEL}}Routes(getIt),
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        locale: const Locale('en'),
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(lookupAppLocalizations(const Locale('en')).{{L10N_DATA_KEY}}('Flow')),
      findsOneWidget,
    );
  });
}
