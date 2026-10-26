import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/design/theme/app_theme.dart';
import 'package:yofardev_ai/core/l10n/generated/app_localizations.dart';
import 'package:yofardev_ai/features/demo/demo.dart';
import 'package:yofardev_ai/features/demo/domain/services/demo_controller.dart';
import 'package:yofardev_ai/features/home/widgets/demo_activated_listener.dart';

class MockDemoCubit extends MockCubit<DemoState> implements DemoCubit {}

Future<void> _pump(
  WidgetTester tester,
  MockDemoCubit cubit,
  Locale locale,
) async {
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

void main() {
  late MockDemoCubit cubit;

  setUp(() {
    cubit = MockDemoCubit();
  });

  testWidgets('shows the French snackbar when the demo becomes active', (
    WidgetTester tester,
  ) async {
    whenListen(
      cubit,
      Stream<DemoState>.fromIterable(<DemoState>[
        const DemoState(status: DemoStatus.active),
      ]),
      initialState: const DemoState(),
    );
    await _pump(tester, cubit, const Locale('fr'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Mode démo activé'), findsOneWidget);
  });

  testWidgets('shows the English snackbar when the demo becomes active', (
    WidgetTester tester,
  ) async {
    whenListen(
      cubit,
      Stream<DemoState>.fromIterable(<DemoState>[
        const DemoState(status: DemoStatus.active),
      ]),
      initialState: const DemoState(),
    );
    await _pump(tester, cubit, const Locale('en'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Demo mode activated'), findsOneWidget);
  });

  testWidgets('shows nothing while the demo is idle', (
    WidgetTester tester,
  ) async {
    whenListen(
      cubit,
      const Stream<DemoState>.empty(),
      initialState: const DemoState(),
    );
    await _pump(tester, cubit, const Locale('fr'));
    await tester.pump();

    expect(find.byType(SnackBar), findsNothing);
  });
}
