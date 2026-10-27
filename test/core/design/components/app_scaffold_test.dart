import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:yofardev_ai/core/design/components/components.dart';
import 'package:yofardev_ai/core/design/design.dart';
import 'package:yofardev_ai/core/l10n/generated/app_localizations.dart';

import 'look_test_theme.dart';

void main() {
  Widget app(GoRouter router) {
    return MaterialApp.router(
      theme: AppTheme.dark,
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    );
  }

  group('AppScaffold cel', () {
    testWidgets('paints a flat background instead of a gradient', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: celTestTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const AppScaffold(title: 'Cel', body: SizedBox()),
        ),
      );
      final DecoratedBox box = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byType(AppScaffold),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      final BoxDecoration decoration = box.decoration as BoxDecoration;
      final AppTokens tokens = Theme.of(
        tester.element(find.byType(AppScaffold)),
      ).extension<AppTokens>()!;
      expect(decoration.gradient, isNull);
      expect(decoration.color, tokens.background);
    });
  });

  group('AppScaffold', () {
    testWidgets('shows the title and actions, back pops to the first route', (
      WidgetTester tester,
    ) async {
      final GoRouter router = GoRouter(
        routes: <RouteBase>[
          GoRoute(
            path: '/',
            builder: (BuildContext c, GoRouterState s) =>
                const Scaffold(body: Text('first')),
          ),
          GoRoute(
            path: '/second',
            builder: (BuildContext c, GoRouterState s) => AppScaffold(
              title: 'Second page',
              actions: const <Widget>[Icon(Icons.star, key: Key('action'))],
              body: const Text('second body'),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(app(router));
      unawaited(router.push('/second'));
      await tester.pumpAndSettle();

      expect(find.text('Second page'), findsOneWidget);
      expect(find.text('second body'), findsOneWidget);
      expect(find.byKey(const Key('action')), findsOneWidget);
      expect(find.byTooltip('Back'), findsOneWidget);

      await tester.tap(find.byType(AppIconButton));
      await tester.pumpAndSettle();

      expect(find.text('first'), findsOneWidget);
      expect(find.text('Second page'), findsNothing);
    });

    testWidgets('does not throw when there is nothing to pop', (
      WidgetTester tester,
    ) async {
      final GoRouter router = GoRouter(
        routes: <RouteBase>[
          GoRoute(
            path: '/',
            builder: (BuildContext c, GoRouterState s) =>
                AppScaffold(title: 'Root', body: const Text('body')),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(app(router));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(AppIconButton));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Root'), findsOneWidget);
    });

    testWidgets('survives RTL and 1.5x text with a long title', (
      WidgetTester tester,
    ) async {
      final GoRouter router = GoRouter(
        routes: <RouteBase>[
          GoRoute(
            path: '/',
            builder: (BuildContext c, GoRouterState s) => MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: AppScaffold(
                  title: 'A very long title that cannot possibly fit',
                  actions: const <Widget>[Icon(Icons.star)],
                  body: const SizedBox.expand(),
                ),
              ),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(app(router));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      // RTL: the back button is on the right, the title to its left.
      expect(
        tester.getCenter(find.byType(AppIconButton)).dx,
        greaterThan(tester.getCenter(find.byType(Text)).dx),
      );
    });
  });
}
