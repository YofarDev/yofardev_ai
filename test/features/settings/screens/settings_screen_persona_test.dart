import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:yofardev_ai/core/design/theme/app_theme.dart';
import 'package:yofardev_ai/core/l10n/generated/app_localizations.dart';
import 'package:yofardev_ai/core/models/chat.dart';
import 'package:yofardev_ai/core/models/llm_config.dart';
import 'package:yofardev_ai/core/services/llm/llm_service_interface.dart';
import 'package:yofardev_ai/core/services/settings_local_datasource.dart';
import 'package:yofardev_ai/features/settings/data/repositories/settings_repository_impl.dart';
import 'package:yofardev_ai/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:yofardev_ai/features/settings/screens/settings_screen.dart';

class _MockLlmService extends Mock implements LlmServiceInterface {}

/// Real datasource, but the base prompt stays out of rootBundle: loading
/// bundle assets in a second testWidgets of the same isolate never completes.
class _TestDatasource extends SettingsLocalDatasource {
  @override
  Future<String> getBaseSystemPrompt(String languageCode) async =>
      'Base prompt. Persona: \$PERSONA';
}

/// Drives the real SettingsPage the way the running app does: the
/// SettingsCubit lives above the router ([app.dart]) and has already loaded
/// the stored settings before the page is opened.
void main() {
  setUpAll(() {
    registerFallbackValue(ChatPersona.normal);
  });

  /// Bounded settle: fails fast with a stack instead of stalling 10 minutes.
  Future<void> settle(WidgetTester tester) => tester.pumpAndSettle(
    const Duration(milliseconds: 100),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 20),
  );

  Future<void> pumpSettings(
    WidgetTester tester, {
    Map<String, Object> prefs = const <String, Object>{},
  }) async {
    SharedPreferences.setMockInitialValues(prefs);
    final _MockLlmService llm = _MockLlmService();
    when(() => llm.init()).thenAnswer((_) async {});
    when(() => llm.getAllConfigs()).thenReturn(const <LlmConfig>[]);
    when(() => llm.getCurrentConfig()).thenReturn(null);

    final SettingsCubit cubit = SettingsCubit(
      settingsRepository: SettingsRepositoryImpl(datasource: _TestDatasource()),
      llmService: llm,
    );
    // The app-root load (app.dart): by the time the user opens the page,
    // the cubit state already holds the stored settings.
    await cubit.loadSettings();

    final GoRouter router = GoRouter(
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (BuildContext context, GoRouterState state) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => context.push('/settings'),
                child: const Text('open settings'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/settings',
          builder: (BuildContext context, GoRouterState state) =>
              const SettingsPage(),
        ),
      ],
    );

    await tester.pumpWidget(
      BlocProvider<SettingsCubit>.value(
        value: cubit,
        child: MaterialApp.router(
          theme: AppTheme.dark,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await settle(tester);
    await tester.tap(find.text('open settings'));
    await settle(tester);
  }

  Future<String> storedPersona() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('persona') ?? '';
  }

  Future<void> selectPersona(WidgetTester tester, String label) async {
    await tester.tap(find.byType(DropdownButton<ChatPersona>));
    await settle(tester);
    await tester.tap(find.text(label).last);
    await settle(tester);
  }

  /// Like [pumpSettings], but the page opens before the app-root cubit has
  /// finished loading: the stored persona arrives after initState seeded
  /// the defaults.
  Future<void> pumpSettingsBeforeLoadCompletes(
    WidgetTester tester, {
    Map<String, Object> prefs = const <String, Object>{},
  }) async {
    SharedPreferences.setMockInitialValues(prefs);
    final _MockLlmService llm = _MockLlmService();
    when(() => llm.init()).thenAnswer((_) async {});
    when(() => llm.getAllConfigs()).thenReturn(const <LlmConfig>[]);
    when(() => llm.getCurrentConfig()).thenReturn(null);

    final SettingsCubit cubit = SettingsCubit(
      settingsRepository: SettingsRepositoryImpl(datasource: _TestDatasource()),
      llmService: llm,
    );
    final GoRouter router = GoRouter(
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (BuildContext context, GoRouterState state) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => context.push('/settings'),
                child: const Text('open settings'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/settings',
          builder: (BuildContext context, GoRouterState state) =>
              const SettingsPage(),
        ),
      ],
    );

    await tester.pumpWidget(
      BlocProvider<SettingsCubit>.value(
        value: cubit,
        child: MaterialApp.router(
          theme: AppTheme.dark,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await settle(tester);
    await tester.tap(find.text('open settings'));
    await settle(tester);
  }

  group('SettingsPage persona', () {
    testWidgets('shows the stored persona when reopened', (
      WidgetTester tester,
    ) async {
      await pumpSettings(
        tester,
        prefs: <String, Object>{'persona': 'doomer', 'username': 'Yoann'},
      );

      final DropdownButton<ChatPersona> dropdown = tester
          .widget<DropdownButton<ChatPersona>>(
            find.byType(DropdownButton<ChatPersona>),
          );
      expect(dropdown.value, ChatPersona.doomer);
    });

    testWidgets('a late load still seeds the dropdown', (
      WidgetTester tester,
    ) async {
      await pumpSettingsBeforeLoadCompletes(
        tester,
        prefs: <String, Object>{'persona': 'doomer', 'username': 'Yoann'},
      );

      final DropdownButton<ChatPersona> dropdown = tester
          .widget<DropdownButton<ChatPersona>>(
            find.byType(DropdownButton<ChatPersona>),
          );
      expect(dropdown.value, ChatPersona.doomer);
    });

    testWidgets('saving untouched settings keeps the stored persona', (
      WidgetTester tester,
    ) async {
      await pumpSettings(
        tester,
        prefs: <String, Object>{'persona': 'doomer', 'username': 'Yoann'},
      );

      await tester.tap(find.byIcon(Icons.save));
      await settle(tester);

      expect(await storedPersona(), 'doomer');
    });

    testWidgets('selecting a persona and saving persists it', (
      WidgetTester tester,
    ) async {
      await pumpSettings(
        tester,
        prefs: <String, Object>{'persona': 'normal', 'username': 'Yoann'},
      );

      await selectPersona(tester, 'Coach');
      await tester.tap(find.byIcon(Icons.save));
      await settle(tester);

      expect(await storedPersona(), 'coach');
    });

    testWidgets('selecting a persona alongside a username edit persists it', (
      WidgetTester tester,
    ) async {
      await pumpSettings(
        tester,
        prefs: <String, Object>{'persona': 'normal', 'username': 'Yoann'},
      );

      await tester.enterText(find.byType(TextFormField).first, 'Alice');
      await selectPersona(tester, 'Coach');
      await tester.tap(find.byIcon(Icons.save));
      await settle(tester);

      expect(await storedPersona(), 'coach');
    });
  });
}
