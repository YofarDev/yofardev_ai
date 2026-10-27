import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yofardev_ai/core/design/rive/ui_kit_file.dart';
import 'package:yofardev_ai/core/router/route_constants.dart';
import 'package:yofardev_ai/features/home/widgets/stage/stage_top_bar.dart';
import 'package:yofardev_ai/features/settings/settings.dart';
import 'package:yofardev_ai/features/talking/talking.dart';

import '../../../../helpers/rive_test_assets.dart';
import '../../stage_harness.dart';

void main() {
  late StageHarness h;
  late GoRouter router;
  late int demos;

  setUp(() {
    serveFakeRiveAssets();
    UiKitFile.resetForTest();
    h = StageHarness();
    demos = 0;
    router = GoRouter(
      routes: <RouteBase>[
        GoRoute(
          path: RouteConstants.home,
          builder: (BuildContext context, GoRouterState state) => Scaffold(
            body: SafeArea(child: StageTopBar(onStartDemo: () => demos++)),
          ),
        ),
        GoRoute(
          path: RouteConstants.chats,
          builder: (BuildContext context, GoRouterState state) =>
              const Text('chats page'),
        ),
        GoRoute(
          path: RouteConstants.settings,
          builder: (BuildContext context, GoRouterState state) =>
              const Text('settings page'),
        ),
      ],
    );
  });

  tearDown(() => router.dispose());

  Future<void> pumpBar(WidgetTester tester, {Locale? locale}) async {
    await tester.pumpWidget(
      h.routerApp(router, locale: locale ?? const Locale('en')),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(find.bySemanticsLabel('Menu'));
    await tester.pumpAndSettle();
  }

  testWidgets('History opens the chats list', (WidgetTester tester) async {
    await pumpBar(tester);
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    expect(find.text('chats page'), findsOneWidget);
  });

  testWidgets('the chips are localized', (WidgetTester tester) async {
    await pumpBar(tester, locale: const Locale('fr'));
    expect(find.text('Historique'), findsOneWidget);
  });

  testWidgets('the chips keep 48 dp hit targets', (WidgetTester tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await pumpBar(tester);
    expect(tester.getSize(find.bySemanticsLabel('History')).height, 48);
    expect(tester.getSize(find.bySemanticsLabel('Menu')), const Size(48, 48));
    handle.dispose();
  });

  testWidgets('History sits at the start, More at the end', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await pumpBar(tester);
    final double width = tester.getSize(find.byType(StageTopBar)).width;
    expect(tester.getTopLeft(find.bySemanticsLabel('History')).dx, 0);
    expect(tester.getTopRight(find.bySemanticsLabel('Menu')).dx, width);
    handle.dispose();
  });

  testWidgets('More → New chat creates a chat and closes the menu', (
    WidgetTester tester,
  ) async {
    await pumpBar(tester);
    await openMenu(tester);
    await tester.tap(find.text('New chat'));
    await tester.pumpAndSettle();
    verify(() => h.chatCubit.createNewChat()).called(1);
    expect(find.text('New chat'), findsNothing);
  });

  testWidgets('More → language offers the other language', (
    WidgetTester tester,
  ) async {
    await pumpBar(tester);
    await openMenu(tester);
    await tester.tap(find.text('Français'));
    await tester.pumpAndSettle();
    verify(() => h.settingsCubit.setCurrentLanguage('fr')).called(1);

    h.settings.emit(const SettingsState(currentLanguage: 'fr'));
    await tester.idle();
    await openMenu(tester);
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    verify(() => h.settingsCubit.setCurrentLanguage('en')).called(1);
  });

  testWidgets('More → captions shows the action the tap does', (
    WidgetTester tester,
  ) async {
    await pumpBar(tester);
    await openMenu(tester);
    await tester.tap(find.text('Hide captions'));
    await tester.pumpAndSettle();
    verify(() => h.captionCubit.toggle()).called(1);

    h.caption.emit(const CaptionState(enabled: false));
    await tester.idle();
    await openMenu(tester);
    expect(find.text('Show captions'), findsOneWidget);
  });

  testWidgets('More → Settings opens the settings', (
    WidgetTester tester,
  ) async {
    await pumpBar(tester);
    await openMenu(tester);
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('settings page'), findsOneWidget);
  });

  testWidgets('More → demo plays the demo', (WidgetTester tester) async {
    await pumpBar(tester);
    await openMenu(tester);
    await tester.tap(find.text('Play the demo'));
    await tester.pumpAndSettle();
    expect(demos, 1);
  });
}
