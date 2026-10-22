import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{PROJECT_NAME}}/core/l10n/generated/app_localizations.dart';
import 'package:{{PROJECT_NAME}}/core/models/failure.dart';
import 'package:{{PROJECT_NAME}}/features/{{FEATURE_SNAKE}}/domain/models/{{FEATURE_SNAKE}}.dart';
import 'package:{{PROJECT_NAME}}/features/{{FEATURE_SNAKE}}/presentation/bloc/{{FEATURE_SNAKE}}_cubit.dart';
import 'package:{{PROJECT_NAME}}/features/{{FEATURE_SNAKE}}/presentation/bloc/{{FEATURE_SNAKE}}_state.dart';
import 'package:{{PROJECT_NAME}}/features/{{FEATURE_SNAKE}}/presentation/screens/{{FEATURE_SNAKE}}_screen.dart';

/// Fake cubit so tests can push states without driving the real repository.
class Fake{{FEATURE_PASCAL}}Cubit extends Cubit<{{FEATURE_PASCAL}}State>
    implements {{FEATURE_PASCAL}}Cubit {
  Fake{{FEATURE_PASCAL}}Cubit() : super(const {{FEATURE_PASCAL}}State.initial());

  int loadCalls = 0;

  void pushState({{FEATURE_PASCAL}}State nextState) => emit(nextState);

  @override
  Future<void> loadData() async {
    loadCalls++;
  }
}

/// Widget tests for the generated screen: each state branch renders, the
/// failure category is localized (never a raw exception string), and the
/// refresh action reaches the cubit.
void main() {
  Widget buildTestableWidget(
    Widget child, {
    Locale locale = const Locale('en'),
  }) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: locale,
      home: child,
    );
  }

  testWidgets('shows a spinner in the initial and loading states', (
    WidgetTester tester,
  ) async {
    final Fake{{FEATURE_PASCAL}}Cubit cubit = Fake{{FEATURE_PASCAL}}Cubit();
    addTearDown(cubit.close);

    await tester.pumpWidget(
      buildTestableWidget(
        BlocProvider<{{FEATURE_PASCAL}}Cubit>.value(
          value: cubit,
          child: const {{FEATURE_PASCAL}}Screen(),
        ),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    cubit.pushState(const {{FEATURE_PASCAL}}State.loading());
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('renders the loaded data', (WidgetTester tester) async {
    final Fake{{FEATURE_PASCAL}}Cubit cubit = Fake{{FEATURE_PASCAL}}Cubit();
    addTearDown(cubit.close);

    await tester.pumpWidget(
      buildTestableWidget(
        BlocProvider<{{FEATURE_PASCAL}}Cubit>.value(
          value: cubit,
          child: const {{FEATURE_PASCAL}}Screen(),
        ),
      ),
    );

    cubit.pushState(
      const {{FEATURE_PASCAL}}State.loaded({{FEATURE_PASCAL}}(id: '1', name: 'Test')),
    );
    await tester.pump();

    // The data line is localized with a {name} placeholder (English below).
    expect(find.text('Data: Test'), findsOneWidget);
  });

  testWidgets('displays the localized failure and retries on failure', (
    WidgetTester tester,
  ) async {
    final Fake{{FEATURE_PASCAL}}Cubit cubit = Fake{{FEATURE_PASCAL}}Cubit();
    addTearDown(cubit.close);

    await tester.pumpWidget(
      buildTestableWidget(
        BlocProvider<{{FEATURE_PASCAL}}Cubit>.value(
          value: cubit,
          child: const {{FEATURE_PASCAL}}Screen(),
        ),
      ),
    );

    cubit.pushState(
      const {{FEATURE_PASCAL}}State.error(failure: Failure.networkError()),
    );
    await tester.pump();

    // The category is localized (English), not a raw exception string.
    expect(
      find.text('Network error. Please check your connection.'),
      findsOneWidget,
    );

    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pump();

    expect(cubit.loadCalls, 1);
  });
}
