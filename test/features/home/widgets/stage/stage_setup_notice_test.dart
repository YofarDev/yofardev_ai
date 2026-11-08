import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yofardev_ai/core/design/design.dart';
import 'package:yofardev_ai/core/l10n/generated/app_localizations.dart';
import 'package:yofardev_ai/core/router/route_constants.dart';
import 'package:yofardev_ai/core/services/llm/llm_service_interface.dart';
import 'package:yofardev_ai/features/home/widgets/stage/stage_setup_notice.dart';

class _MockLlmService extends Mock implements LlmServiceInterface {}

void main() {
  late _MockLlmService llm;
  late ValueNotifier<bool?> configured;

  setUp(() {
    llm = _MockLlmService();
    configured = ValueNotifier<bool?>(null);
    when(() => llm.configured).thenReturn(configured);
    // Loading the stored configs: none.
    when(() => llm.init()).thenAnswer((_) async => configured.value = false);
  });

  tearDown(() => configured.dispose());

  /// Home at `/`, the new-config form at [RouteConstants.newLlmConfig].
  Future<void> pump(
    WidgetTester tester,
    LlmServiceInterface? service, {
    bool reduceMotion = true,
  }) async {
    final GoRouter router = GoRouter(
      routes: <RouteBase>[
        GoRoute(
          path: RouteConstants.home,
          builder: (BuildContext context, GoRouterState state) => Material(
            child: MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(disableAnimations: reduceMotion),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: StageSetupNotice(llm: service),
              ),
            ),
          ),
        ),
        GoRoute(
          path: RouteConstants.newLlmConfig,
          builder: (BuildContext context, GoRouterState state) =>
              const Text('new config form'),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.dark,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('no service: nothing', (WidgetTester tester) async {
    await pump(tester, null);

    expect(find.text('Connect an AI to start chatting'), findsNothing);
  });

  testWidgets('loads the configs, then shows when there are none', (
    WidgetTester tester,
  ) async {
    await pump(tester, llm);

    verify(() => llm.init()).called(1);
    expect(find.text('Connect an AI to start chatting'), findsOneWidget);
    expect(find.textContaining('API key'), findsOneWidget);
  });

  testWidgets('never shows with a config, and hides once one is saved', (
    WidgetTester tester,
  ) async {
    configured.value = true;
    await pump(tester, llm);
    verifyNever(() => llm.init());
    expect(find.text('Connect an AI to start chatting'), findsNothing);

    configured.value = false;
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Connect an AI to start chatting'), findsOneWidget);

    configured.value = true;
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Connect an AI to start chatting'), findsNothing);
  });

  testWidgets('Set up opens the new-config form', (WidgetTester tester) async {
    await pump(tester, llm);

    await tester.tap(find.text('Set up'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('new config form'), findsOneWidget);
  });

  testWidgets('Later hides it for the session', (WidgetTester tester) async {
    await pump(tester, llm);

    await tester.tap(find.byTooltip('Later'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Connect an AI to start chatting'), findsNothing);
  });

  testWidgets('breathes without reduce motion', (WidgetTester tester) async {
    await pump(tester, llm, reduceMotion: false);
    expect(find.text('Connect an AI to start chatting'), findsOneWidget);
    expect(tester.binding.hasScheduledFrame, isTrue);
  });
}
