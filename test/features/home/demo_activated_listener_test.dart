import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/design/components/components.dart';
import 'package:yofardev_ai/core/design/theme/app_theme.dart';
import 'package:yofardev_ai/core/l10n/generated/app_localizations.dart';
import 'package:yofardev_ai/features/demo/demo.dart';
import 'package:yofardev_ai/features/demo/domain/services/demo_controller.dart';
import 'package:yofardev_ai/features/home/widgets/demo_activated_listener.dart';

class MockDemoCubit extends MockCubit<DemoState> implements DemoCubit {}

const DemoState _idle = DemoState();

DemoState _active(int countdown) =>
    DemoState(status: DemoStatus.active, countdownValue: countdown);

void main() {
  late MockDemoCubit cubit;
  late StreamController<DemoState> states;

  setUp(() {
    cubit = MockDemoCubit();
    states = StreamController<DemoState>();
    whenListen(cubit, states.stream, initialState: _idle);
  });

  tearDown(() => states.close());

  Future<void> pump(WidgetTester tester, Locale locale) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        locale: locale,
        localizationsDelegates: const <LocalizationsDelegate<Object>>[
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider<DemoCubit>.value(
          value: cubit,
          child: const DemoActivatedListener(
            child: Scaffold(body: SizedBox.expand()),
          ),
        ),
      ),
    );
  }

  Future<void> emit(WidgetTester tester, DemoState state) async {
    states.add(state);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  /// Lets the toast leave and its timer run out.
  Future<void> drain(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  }

  Element? toast() {
    final Iterable<Element> found = find.byType(AppToast).evaluate();
    return found.isEmpty ? null : found.single;
  }

  testWidgets('shows the French toast when the demo becomes active', (
    WidgetTester tester,
  ) async {
    await pump(tester, const Locale('fr'));
    await emit(tester, _active(3));
    expect(find.text('Mode démo activé'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    await drain(tester);
  });

  testWidgets('shows the English toast when the demo becomes active', (
    WidgetTester tester,
  ) async {
    await pump(tester, const Locale('en'));
    await emit(tester, _active(3));
    expect(find.text('Demo mode activated'), findsOneWidget);
    await drain(tester);
  });

  testWidgets('shows once per activation, not on every active state', (
    WidgetTester tester,
  ) async {
    await pump(tester, const Locale('en'));
    await emit(tester, _active(3));
    final Element? first = toast();
    expect(first, isNotNull);

    await emit(tester, _active(2));
    await emit(tester, _active(1));
    expect(identical(toast(), first), isTrue, reason: 'no second toast');
    await drain(tester);
    expect(toast(), isNull);

    // A later activation shows it again.
    await emit(tester, _idle);
    await emit(tester, _active(3));
    expect(toast(), isNotNull);
    await drain(tester);
  });

  testWidgets('shows nothing while the demo is idle', (
    WidgetTester tester,
  ) async {
    await pump(tester, const Locale('fr'));
    await emit(tester, _idle);
    expect(find.byType(AppToast), findsNothing);
  });
}
