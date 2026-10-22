import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yofardev_ai/core/l10n/generated/app_localizations.dart';
import 'package:yofardev_ai/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:yofardev_ai/features/settings/presentation/bloc/settings_state.dart';
import 'package:yofardev_ai/features/settings/screens/function_calling_config_screen.dart';
import 'package:yofardev_ai/features/settings/widgets/function_calling_section.dart';

/// Mock class for SettingsCubit
class MockSettingsCubit extends Mock implements SettingsCubit {}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  group('FunctionCallingConfigScreen Widget Tests', () {
    late MockSettingsCubit mockSettingsCubit;

    setUp(() {
      mockSettingsCubit = MockSettingsCubit();

      // Setup default mock behaviors
      when(
        () => mockSettingsCubit.stream,
      ).thenAnswer((_) => const Stream<SettingsState>.empty());
      when(() => mockSettingsCubit.state).thenReturn(
        const SettingsState(
          googleSearchEnabled: true,
          openWeatherEnabled: true,
          newYorkTimesEnabled: true,
        ),
      );

      // Stub async methods
      when(
        () => mockSettingsCubit.updateGoogleSearchKey(any()),
      ).thenAnswer((_) async {});
      when(
        () => mockSettingsCubit.updateGoogleSearchEngineId(any()),
      ).thenAnswer((_) async {});
      when(
        () => mockSettingsCubit.updateOpenWeatherKey(any()),
      ).thenAnswer((_) async {});
      when(
        () => mockSettingsCubit.updateNewYorkTimesKey(any()),
      ).thenAnswer((_) async {});
      when(
        () => mockSettingsCubit.toggleGoogleSearch(any()),
      ).thenAnswer((_) async {});
      when(
        () => mockSettingsCubit.toggleOpenWeather(any()),
      ).thenAnswer((_) async {});
      when(
        () => mockSettingsCubit.toggleNewYorkTimes(any()),
      ).thenAnswer((_) async {});
    });

    Widget createTestWidget() {
      return MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider<SettingsCubit>.value(
          value: mockSettingsCubit,
          child: const FunctionCallingConfigScreen(),
        ),
      );
    }

    Widget createNavigableTestWidget() {
      return MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Navigator(
          onGenerateInitialRoutes: (_, _) => <Route<dynamic>>[
            MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text('HostScreen')),
            ),
            MaterialPageRoute<void>(
              builder: (_) => BlocProvider<SettingsCubit>.value(
                value: mockSettingsCubit,
                child: const FunctionCallingConfigScreen(),
              ),
            ),
          ],
        ),
      );
    }

    AppLocalizations localizationsFor(WidgetTester tester) {
      return AppLocalizations.of(
        tester.element(find.byType(FunctionCallingConfigScreen)),
      );
    }

    Finder sectionByTitle(String title) {
      return find.ancestor(
        of: find.text(title),
        matching: find.byType(FunctionCallingSection),
      );
    }

    Finder textFieldsInSection(String title) {
      return find.descendant(
        of: sectionByTitle(title),
        matching: find.byType(TextField),
      );
    }

    Finder switchInSection(String title) {
      return find.descendant(
        of: sectionByTitle(title),
        matching: find.byType(Switch),
      );
    }

    group('Screen Rendering', () {
      testWidgets('should render all three service sections', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(find.byType(FunctionCallingSection), findsNWidgets(3));
      });

      testWidgets('should render service descriptions', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        final AppLocalizations l10n = localizationsFor(tester);
        expect(
          find.text(l10n.settings_functionCalling_description),
          findsOneWidget,
        );
        expect(
          find.text(l10n.settings_googleSearch_description),
          findsOneWidget,
        );
        expect(find.text(l10n.settings_weather_description), findsOneWidget);
        expect(find.text(l10n.settings_news_description), findsOneWidget);
      });

      testWidgets('should render app bar with back button and save button', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(find.byType(IconButton), findsAtLeastNWidgets(2));
        expect(find.byIcon(Icons.arrow_back), findsOneWidget);
        expect(find.byIcon(Icons.save), findsOneWidget);
      });

      testWidgets('should render all text fields for API keys', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Should find 4 TextField widgets (Google Search has 2: API Key + Engine ID)
        expect(find.byType(TextField), findsNWidgets(4));

        final AppLocalizations l10n = localizationsFor(tester);
        // Check for label text
        expect(find.text(l10n.settings_apiKey), findsNWidgets(3));
        // Search Engine ID appears in both label and hint text
        expect(find.text(l10n.settings_engineId), findsOneWidget);
      });

      testWidgets('should render all toggle switches', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Should find 3 Switch widgets (one for each service)
        expect(find.byType(Switch), findsNWidgets(3));
        expect(
          find.text(localizationsFor(tester).settings_enable),
          findsNWidgets(3),
        );
      });

      testWidgets('should display service icons', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(find.text('🔍'), findsOneWidget); // Google Search
        expect(find.text('🌤️'), findsOneWidget); // Weather
        expect(find.text('📰'), findsOneWidget); // News
      });
    });

    group('Google Search Section', () {
      testWidgets('should render Google Search with key and engine ID fields', (
        WidgetTester tester,
      ) async {
        when(() => mockSettingsCubit.state).thenReturn(
          const SettingsState(
            googleSearchEnabled: true,
            openWeatherEnabled: true,
            newYorkTimesEnabled: true,
          ),
        );

        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        final AppLocalizations l10n = localizationsFor(tester);
        expect(find.text(l10n.settings_googleSearch), findsOneWidget);
        expect(find.text(l10n.settings_apiKey), findsWidgets);
        expect(find.text(l10n.settings_engineId), findsOneWidget);
      });

      testWidgets('should show Google Search toggle state correctly', (
        WidgetTester tester,
      ) async {
        when(() => mockSettingsCubit.state).thenReturn(
          const SettingsState(
            googleSearchEnabled: true,
            openWeatherEnabled: true,
            newYorkTimesEnabled: true,
          ),
        );

        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        final AppLocalizations l10n = localizationsFor(tester);
        final Switch googleSwitch = tester.widget<Switch>(
          switchInSection(l10n.settings_googleSearch),
        );
        expect(googleSwitch.value, true);
      });

      testWidgets('should toggle Google Search when switch is tapped', (
        WidgetTester tester,
      ) async {
        when(() => mockSettingsCubit.state).thenReturn(
          const SettingsState(
            googleSearchEnabled: true,
            openWeatherEnabled: true,
            newYorkTimesEnabled: true,
          ),
        );

        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        final AppLocalizations l10n = localizationsFor(tester);
        await tester.tap(switchInSection(l10n.settings_googleSearch));
        await tester.pumpAndSettle();

        verify(() => mockSettingsCubit.toggleGoogleSearch(false)).called(1);
      });

      testWidgets('should enter text in Google Search API key field', (
        WidgetTester tester,
      ) async {
        when(() => mockSettingsCubit.state).thenReturn(
          const SettingsState(
            googleSearchEnabled: true,
            openWeatherEnabled: true,
            newYorkTimesEnabled: true,
          ),
        );

        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        final AppLocalizations l10n = localizationsFor(tester);
        await tester.enterText(
          textFieldsInSection(l10n.settings_googleSearch).first,
          'test-google-key',
        );
        await tester.pump();

        expect(find.text('test-google-key'), findsOneWidget);
      });

      testWidgets('should enter text in Google Search Engine ID field', (
        WidgetTester tester,
      ) async {
        when(() => mockSettingsCubit.state).thenReturn(
          const SettingsState(
            googleSearchEnabled: true,
            openWeatherEnabled: true,
            newYorkTimesEnabled: true,
          ),
        );

        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        final AppLocalizations l10n = localizationsFor(tester);
        await tester.enterText(
          textFieldsInSection(l10n.settings_googleSearch).at(1),
          'test-engine-id',
        );
        await tester.pump();

        expect(find.text('test-engine-id'), findsOneWidget);
      });
    });

    group('Weather Section', () {
      testWidgets('should render Weather with API key field', (
        WidgetTester tester,
      ) async {
        when(() => mockSettingsCubit.state).thenReturn(
          const SettingsState(
            googleSearchEnabled: true,
            openWeatherEnabled: true,
            newYorkTimesEnabled: true,
          ),
        );

        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(
          find.text(localizationsFor(tester).settings_weather),
          findsOneWidget,
        );
      });

      testWidgets('should show Weather toggle state correctly', (
        WidgetTester tester,
      ) async {
        when(() => mockSettingsCubit.state).thenReturn(
          const SettingsState(
            googleSearchEnabled: true,
            openWeatherEnabled: false,
            newYorkTimesEnabled: true,
          ),
        );

        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        final AppLocalizations l10n = localizationsFor(tester);
        final Switch weatherSwitch = tester.widget<Switch>(
          switchInSection(l10n.settings_weather),
        );
        expect(weatherSwitch.value, false);
      });

      testWidgets('should toggle Weather when switch is tapped', (
        WidgetTester tester,
      ) async {
        when(() => mockSettingsCubit.state).thenReturn(
          const SettingsState(
            googleSearchEnabled: true,
            openWeatherEnabled: true,
            newYorkTimesEnabled: true,
          ),
        );

        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        final AppLocalizations l10n = localizationsFor(tester);
        // Scroll to the Weather switch
        await tester.dragUntilVisible(
          find.text(l10n.settings_weather),
          find.byType(SingleChildScrollView),
          const Offset(0, -50),
        );
        await tester.pumpAndSettle();

        await tester.tap(
          switchInSection(l10n.settings_weather),
          warnIfMissed: false,
        );
        await tester.pumpAndSettle();

        verify(() => mockSettingsCubit.toggleOpenWeather(false)).called(1);
      });

      testWidgets('should enter text in Weather API key field', (
        WidgetTester tester,
      ) async {
        when(() => mockSettingsCubit.state).thenReturn(
          const SettingsState(
            googleSearchEnabled: true,
            openWeatherEnabled: true,
            newYorkTimesEnabled: true,
          ),
        );

        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        final AppLocalizations l10n = localizationsFor(tester);
        await tester.enterText(
          textFieldsInSection(l10n.settings_weather).first,
          'test-weather-key',
        );
        await tester.pump();

        expect(find.text('test-weather-key'), findsOneWidget);
      });
    });

    group('News Section', () {
      testWidgets('should render News with API key field', (
        WidgetTester tester,
      ) async {
        when(() => mockSettingsCubit.state).thenReturn(
          const SettingsState(
            googleSearchEnabled: true,
            openWeatherEnabled: true,
            newYorkTimesEnabled: true,
          ),
        );

        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(
          find.text(localizationsFor(tester).settings_news),
          findsOneWidget,
        );
      });

      testWidgets('should show News toggle state correctly', (
        WidgetTester tester,
      ) async {
        when(() => mockSettingsCubit.state).thenReturn(
          const SettingsState(
            googleSearchEnabled: true,
            openWeatherEnabled: true,
            newYorkTimesEnabled: false,
          ),
        );

        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        final AppLocalizations l10n = localizationsFor(tester);
        final Switch newsSwitch = tester.widget<Switch>(
          switchInSection(l10n.settings_news),
        );
        expect(newsSwitch.value, false);
      });

      testWidgets('should toggle News when switch is tapped', (
        WidgetTester tester,
      ) async {
        when(() => mockSettingsCubit.state).thenReturn(
          const SettingsState(
            googleSearchEnabled: true,
            openWeatherEnabled: true,
            newYorkTimesEnabled: true,
          ),
        );

        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        final AppLocalizations l10n = localizationsFor(tester);
        // Scroll to the News section
        await tester.dragUntilVisible(
          find.text(l10n.settings_news),
          find.byType(SingleChildScrollView),
          const Offset(0, -50),
        );
        await tester.pumpAndSettle();

        await tester.tap(
          switchInSection(l10n.settings_news),
          warnIfMissed: false,
        );
        await tester.pumpAndSettle();

        verify(() => mockSettingsCubit.toggleNewYorkTimes(false)).called(1);
      });
    });

    group('Save Functionality', () {
      testWidgets('should save all Google Search fields when save is pressed', (
        WidgetTester tester,
      ) async {
        when(() => mockSettingsCubit.state).thenReturn(
          const SettingsState(
            googleSearchEnabled: true,
            openWeatherEnabled: true,
            newYorkTimesEnabled: true,
          ),
        );

        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        final AppLocalizations l10n = localizationsFor(tester);
        await tester.enterText(
          textFieldsInSection(l10n.settings_googleSearch).first,
          'google-api-key',
        );
        await tester.enterText(
          textFieldsInSection(l10n.settings_googleSearch).at(1),
          'engine-id-123',
        );
        await tester.pump();

        // Tap save button
        await tester.tap(find.byIcon(Icons.save));
        await tester.pumpAndSettle();

        verify(
          () => mockSettingsCubit.updateGoogleSearchKey('google-api-key'),
        ).called(1);
        verify(
          () => mockSettingsCubit.updateGoogleSearchEngineId('engine-id-123'),
        ).called(1);
      });

      testWidgets('should save Weather field when save is pressed', (
        WidgetTester tester,
      ) async {
        when(() => mockSettingsCubit.state).thenReturn(
          const SettingsState(
            googleSearchEnabled: true,
            openWeatherEnabled: true,
            newYorkTimesEnabled: true,
          ),
        );

        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        final AppLocalizations l10n = localizationsFor(tester);
        await tester.enterText(
          textFieldsInSection(l10n.settings_weather).first,
          'weather-api-key',
        );
        await tester.pump();

        // Tap save button
        await tester.tap(find.byIcon(Icons.save));
        await tester.pumpAndSettle();

        verify(
          () => mockSettingsCubit.updateOpenWeatherKey('weather-api-key'),
        ).called(1);
      });

      testWidgets('should show success message when save completes', (
        WidgetTester tester,
      ) async {
        when(() => mockSettingsCubit.state).thenReturn(
          const SettingsState(
            googleSearchEnabled: true,
            openWeatherEnabled: true,
            newYorkTimesEnabled: true,
          ),
        );

        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Tap save button
        await tester.tap(find.byIcon(Icons.save));
        // Pump multiple times to allow the SnackBar to appear before navigation
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Look for SnackBar
        expect(find.byType(SnackBar), findsOneWidget);
      });

      testWidgets('should navigate back after save', (
        WidgetTester tester,
      ) async {
        when(() => mockSettingsCubit.state).thenReturn(
          const SettingsState(
            googleSearchEnabled: true,
            openWeatherEnabled: true,
            newYorkTimesEnabled: true,
          ),
        );

        await tester.pumpWidget(createNavigableTestWidget());
        await tester.pumpAndSettle();

        // Tap save button
        await tester.tap(find.byIcon(Icons.save));
        await tester.pumpAndSettle();

        expect(find.text('HostScreen'), findsOneWidget);
      });

      testWidgets('should not save empty fields', (WidgetTester tester) async {
        when(() => mockSettingsCubit.state).thenReturn(
          const SettingsState(
            googleSearchEnabled: true,
            openWeatherEnabled: true,
            newYorkTimesEnabled: true,
          ),
        );

        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Tap save button without entering any text
        await tester.tap(find.byIcon(Icons.save));
        await tester.pumpAndSettle();

        verifyNever(() => mockSettingsCubit.updateGoogleSearchKey(any()));
        verifyNever(() => mockSettingsCubit.updateGoogleSearchEngineId(any()));
        verifyNever(() => mockSettingsCubit.updateOpenWeatherKey(any()));
        verifyNever(() => mockSettingsCubit.updateNewYorkTimesKey(any()));
      });
    });

    group('State Updates', () {
      testWidgets('should display correct initial state from SettingsCubit', (
        WidgetTester tester,
      ) async {
        // Test with all services disabled
        when(() => mockSettingsCubit.state).thenReturn(
          const SettingsState(
            googleSearchEnabled: false,
            openWeatherEnabled: false,
            newYorkTimesEnabled: false,
          ),
        );

        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        final Iterable<Switch> switches = tester.widgetList<Switch>(
          find.byType(Switch),
        );
        expect(
          switches.every((Switch toggle) => toggle.value == false),
          isTrue,
        );
      });
    });

    group('User Interactions', () {
      testWidgets('should be scrollable when content overflows', (
        WidgetTester tester,
      ) async {
        when(() => mockSettingsCubit.state).thenReturn(
          const SettingsState(
            googleSearchEnabled: true,
            openWeatherEnabled: true,
            newYorkTimesEnabled: true,
          ),
        );

        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(find.byType(SingleChildScrollView), findsOneWidget);
      });

      testWidgets('should navigate back when back button is pressed', (
        WidgetTester tester,
      ) async {
        when(() => mockSettingsCubit.state).thenReturn(
          const SettingsState(
            googleSearchEnabled: true,
            openWeatherEnabled: true,
            newYorkTimesEnabled: true,
          ),
        );

        await tester.pumpWidget(createNavigableTestWidget());
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.arrow_back));
        await tester.pumpAndSettle();

        expect(find.text('HostScreen'), findsOneWidget);
      });
    });

    group('Text Field Properties', () {
      testWidgets('should have obscure text enabled for API key fields', (
        WidgetTester tester,
      ) async {
        when(() => mockSettingsCubit.state).thenReturn(
          const SettingsState(
            googleSearchEnabled: true,
            openWeatherEnabled: true,
            newYorkTimesEnabled: true,
          ),
        );

        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        final List<TextField> textFields = tester
            .widgetList<TextField>(find.byType(TextField))
            .toList();

        for (final TextField field in textFields) {
          expect(field.obscureText, true);
        }
      });

      testWidgets('should have proper hint texts', (WidgetTester tester) async {
        when(() => mockSettingsCubit.state).thenReturn(
          const SettingsState(
            googleSearchEnabled: true,
            openWeatherEnabled: true,
            newYorkTimesEnabled: true,
          ),
        );

        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Check for hint texts (use findsWidgets where text appears in multiple places)
        expect(find.textContaining('Google Search API key'), findsOneWidget);
        expect(find.textContaining('Search Engine ID'), findsWidgets);
        expect(find.textContaining('OpenWeather API key'), findsOneWidget);
        expect(find.textContaining('New York Times API key'), findsOneWidget);
      });
    });

    group('Card Layout', () {
      testWidgets('should render each section in a Card', (
        WidgetTester tester,
      ) async {
        when(() => mockSettingsCubit.state).thenReturn(
          const SettingsState(
            googleSearchEnabled: true,
            openWeatherEnabled: true,
            newYorkTimesEnabled: true,
          ),
        );

        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(find.byType(Card), findsNWidgets(3));
      });
    });
  });
}
