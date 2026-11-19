import 'dart:async';

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

/// Data-source seam: each call consumes the next scripted response.
class _Scripted{{FEATURE_PASCAL}}DataSource
    implements {{FEATURE_PASCAL}}RemoteDataSource {
  _Scripted{{FEATURE_PASCAL}}DataSource(this._responses);

  final List<Future<{{DATA_SOURCE_RETURN_TYPE}}> Function()> _responses;
  int calls = 0;

  @override
  Future<{{DATA_SOURCE_RETURN_TYPE}}> getData() => _responses[calls++]();
}

Future<{{DATA_SOURCE_RETURN_TYPE}}> _success() async => {{FLOW_TEST_DATA}};

Future<{{DATA_SOURCE_RETURN_TYPE}}> _timeout() async =>
    throw TimeoutException('flow test');

/// The {{FEATURE_SNAKE}} feature through its real wiring: the module's
/// registrations and route, the real repository (with the shared exception
/// mapper), cubit and screen. Only the data source is faked.
///
/// This is the feature's only generated test. Add repository, cubit or
/// screen tests when real mapping, rules or interaction logic lands — see
/// test/README.md for what each kind covers.
void main() {
  final AppLocalizations en = lookupAppLocalizations(const Locale('en'));

  Future<_Scripted{{FEATURE_PASCAL}}DataSource> pumpRoute(
    WidgetTester tester,
    List<Future<{{DATA_SOURCE_RETURN_TYPE}}> Function()> responses,
  ) async {
    final _Scripted{{FEATURE_PASCAL}}DataSource dataSource =
        _Scripted{{FEATURE_PASCAL}}DataSource(responses);
    final GetIt getIt = GetIt.asNewInstance();
    addTearDown(getIt.reset);
    register{{FEATURE_PASCAL}}Feature(getIt, remoteDataSource: dataSource);
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
    await tester.pump();
    return dataSource;
  }

  testWidgets('renders the loaded data', (WidgetTester tester) async {
    await pumpRoute(tester, <Future<{{DATA_SOURCE_RETURN_TYPE}}> Function()>[_success]);

    expect(find.text(en.{{L10N_DATA_KEY}}('Flow')), findsOneWidget);
  });

  testWidgets('a timeout shows the localized network failure', (
    WidgetTester tester,
  ) async {
    await pumpRoute(tester, <Future<{{DATA_SOURCE_RETURN_TYPE}}> Function()>[_timeout]);

    expect(find.text(en.failureNetwork), findsOneWidget);
    expect(find.text(en.{{L10N_DATA_KEY}}('Flow')), findsNothing);
  });

  testWidgets('retry after a failure loads the data', (
    WidgetTester tester,
  ) async {
    final _Scripted{{FEATURE_PASCAL}}DataSource dataSource = await pumpRoute(
      tester,
      <Future<{{DATA_SOURCE_RETURN_TYPE}}> Function()>[_timeout, _success],
    );
    expect(find.text(en.failureNetwork), findsOneWidget);

    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pump();

    expect(find.text(en.{{L10N_DATA_KEY}}('Flow')), findsOneWidget);
    expect(dataSource.calls, 2);
  });
}
