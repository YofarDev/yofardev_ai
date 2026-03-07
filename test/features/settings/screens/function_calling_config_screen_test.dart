import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mocktail/mocktail.dart';
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
        home: BlocProvider<SettingsCubit>.value(
          value: mockSettingsCubit,
          child: const FunctionCallingConfigScreen(),
        ),
      );
    }

    Widget createNavigableTestWidget() {
      return MaterialApp(
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

        expect(find.textContaining('Configure API keys'), findsOneWidget);
        expect(find.textContaining('Search the web'), findsOneWidget);
        expect(find.textContaining('Get current weather'), findsOneWidget);
        expect(
          find.textContaining('Get today\'s most popular'),
          findsOneWidget,
        );
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

        // Check for label text
        expect(find.text('API Key'), findsNWidgets(3));
        // Search Engine ID appears in both label and hint text
        expect(find.textContaining('Search Engine ID'), findsWidgets);
      });

      testWidgets('should render all toggle switches', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Should find 3 Switch widgets (one for each service)
        expect(find.byType(Switch), findsNWidgets(3));
        expect(find.text('Enable'), findsNWidgets(3));
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

        expect(find.text('Google Search'), findsOneWidget);
        expect(find.text('API Key'), findsWidgets);
        expect(find.textContaining('Search Engine ID'), findsWidgets);
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

        final Switch googleSwitch = tester.widget<Switch>(
          find.byType(Switch).first,
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

        await tester.tap(find.byType(Switch).first);
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

        // Find the first "API Key" labeled TextField (Google Search)
        final TextField apiKeyField = tester.widget<TextField>(
          find
              .ancestor(
                of: find.text('API Key'),
                matching: find.byType(TextField),
              )
              .first,
        );

        await tester.enterText(find.byWidget(apiKeyField), 'test-google-key');
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

        // Find the Engine ID TextField by its label
        final TextField engineIdField = tester.widget<TextField>(
          find
              .descendant(
                of: find.byType(FunctionCallingConfigScreen),
                matching: find.byType(TextField),
              )
              .at(1), // Second TextField is the Engine ID
        );

        await tester.enterText(find.byWidget(engineIdField), 'test-engine-id');
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

        expect(find.text('Weather'), findsOneWidget);
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

        final List<Switch> switches = tester
            .widgetList<Switch>(find.byType(Switch))
            .toList();

        // Second switch is Weather
        expect(switches[1].value, false);
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

        // Scroll to the Weather switch
        await tester.dragUntilVisible(
          find.text('Weather'),
          find.byType(SingleChildScrollView),
          const Offset(0, -50),
        );
        await tester.pumpAndSettle();

        // Find and tap the Weather switch (second one)
        final Finder weatherSwitch = find.byType(Switch).at(1);
        await tester.tap(weatherSwitch, warnIfMissed: false);
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

        // Find all API Key labeled TextFields and get the Weather one (second one)
        final List<TextField> apiKeyFields = tester
            .widgetList<TextField>(
              find.ancestor(
                of: find.text('API Key'),
                matching: find.byType(TextField),
              ),
            )
            .toList();

        // Second API Key field is Weather
        await tester.enterText(
          find.byWidget(apiKeyFields[1]),
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

        expect(find.text('News'), findsOneWidget);
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

        final List<Switch> switches = tester
            .widgetList<Switch>(find.byType(Switch))
            .toList();

        // Third switch is News
        expect(switches[2].value, false);
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

        // Scroll to the News section
        await tester.dragUntilVisible(
          find.text('News'),
          find.byType(SingleChildScrollView),
          const Offset(0, -50),
        );
        await tester.pumpAndSettle();

        // Find and tap the News switch (third one)
        final Finder newsSwitch = find.byType(Switch).at(2);
        await tester.tap(newsSwitch, warnIfMissed: false);
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

        // Find all TextFields
        final List<TextField> textFields = tester
            .widgetList<TextField>(find.byType(TextField))
            .toList();

        // Enter values - first is Google Search API Key, second is Engine ID
        await tester.enterText(find.byWidget(textFields[0]), 'google-api-key');
        await tester.enterText(find.byWidget(textFields[1]), 'engine-id-123');
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

        // Find all TextFields - third is Weather API Key
        final List<TextField> textFields = tester
            .widgetList<TextField>(find.byType(TextField))
            .toList();

        // Enter Weather key (third TextField)
        await tester.enterText(find.byWidget(textFields[2]), 'weather-api-key');
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

        final Switch firstSwitch = tester.widget<Switch>(
          find.byType(Switch).first,
        );
        expect(firstSwitch.value, false);
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
