import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nested/nested.dart';
import 'package:yofardev_ai/app.dart';
import 'package:yofardev_ai/core/design/design.dart';
import 'package:yofardev_ai/core/models/avatar_config.dart';
import 'package:yofardev_ai/core/models/avatar_mood.dart';
import 'package:yofardev_ai/core/models/avatar_scene.dart';
import 'package:yofardev_ai/features/avatar/avatar.dart';
import 'package:yofardev_ai/features/settings/settings.dart';

class _MockSettingsCubit extends MockCubit<SettingsState>
    implements SettingsCubit {}

class _MockAvatarCubit extends MockCubit<AvatarState> implements AvatarCubit {}

/// Routed content that never reads the theme: counts its states and builds so
/// the test can prove a scene change does not rebuild or re-create it.
class _RoutedProbe extends StatefulWidget {
  const _RoutedProbe();

  static int inits = 0;
  static int builds = 0;

  @override
  State<_RoutedProbe> createState() => _RoutedProbeState();
}

class _RoutedProbeState extends State<_RoutedProbe> {
  @override
  void initState() {
    super.initState();
    _RoutedProbe.inits++;
  }

  @override
  Widget build(BuildContext context) {
    _RoutedProbe.builds++;
    return const SizedBox(width: 10, height: 10);
  }
}

/// Reads the ambient theme (so only it depends on the theme).
class _ThemeReader extends StatelessWidget {
  const _ThemeReader();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(color: context.colors.primary);
  }
}

class _Page extends StatelessWidget {
  const _Page();

  @override
  Widget build(BuildContext context) {
    return const Column(children: <Widget>[_RoutedProbe(), _ThemeReader()]);
  }
}

void main() {
  const AvatarState initial = AvatarState(
    avatar: Avatar(),
    avatarConfig: AvatarConfig(),
  );

  late _MockSettingsCubit settings;
  late _MockAvatarCubit avatar;
  late StreamController<AvatarState> avatarStates;
  late GoRouter router;

  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    _RoutedProbe.inits = 0;
    _RoutedProbe.builds = 0;
    settings = _MockSettingsCubit();
    whenListen(
      settings,
      const Stream<SettingsState>.empty(),
      initialState: const SettingsState(currentLanguage: 'en'),
    );
    avatarStates = StreamController<AvatarState>();
    avatar = _MockAvatarCubit();
    whenListen(avatar, avatarStates.stream, initialState: initial);
    router = GoRouter(
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (BuildContext context, GoRouterState state) => const _Page(),
        ),
      ],
    );
  });

  tearDown(() async {
    router.dispose();
    await avatarStates.close();
  });

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: <SingleChildWidget>[
          BlocProvider<SettingsCubit>.value(value: settings),
          BlocProvider<AvatarCubit>.value(value: avatar),
        ],
        child: AppView(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Emits [state] from the avatar cubit and pumps the frame that rebuilds
  /// its listeners (the stream delivers on a later microtask than the add).
  Future<void> emit(WidgetTester tester, AvatarState state) async {
    avatarStates.add(state);
    await tester.pump();
    await tester.pump();
  }

  Color primary(WidgetTester tester) =>
      Theme.of(tester.element(find.byType(_ThemeReader))).colorScheme.primary;

  MaterialApp app(WidgetTester tester) =>
      tester.widget<MaterialApp>(find.byType(MaterialApp));

  testWidgets('starts on the current scene theme with the shared router', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    expect(app(tester).theme, same(AppTheme.forScene(AvatarScene.livingRoom)));
    expect(app(tester).routerConfig, same(router));
    expect(app(tester).themeAnimationDuration, AppMotion.slow);
    expect(app(tester).themeAnimationCurve, AppMotion.standard);
    expect(primary(tester), const Color(0xFFF4B860));
  });

  testWidgets(
    'a scene change cross-fades the accent without rebuilding routed content',
    (WidgetTester tester) async {
      await pumpApp(tester);
      final int buildsBefore = _RoutedProbe.builds;
      expect(_RoutedProbe.inits, 1);

      await emit(tester, initial.copyWith(scene: AvatarScene.beach));
      expect(app(tester).theme, same(AppTheme.forScene(AvatarScene.beach)));
      expect(app(tester).routerConfig, same(router));

      await tester.pump(AppMotion.slow ~/ 2);
      final Color mid = primary(tester);
      expect(mid, isNot(const Color(0xFFF4B860)));
      expect(mid, isNot(const Color(0xFFFF9478)));

      await tester.pumpAndSettle();
      expect(primary(tester), const Color(0xFFFF9478));
      expect(_RoutedProbe.inits, 1);
      expect(_RoutedProbe.builds, buildsBefore);
    },
  );

  testWidgets('avatar changes other than the scene keep the MaterialApp', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);
    final MaterialApp before = app(tester);

    await emit(tester, initial.copyWith(mood: AvatarMood.happy));
    await tester.pumpAndSettle();

    expect(avatar.state.mood, AvatarMood.happy);
    expect(app(tester), same(before));
  });
}
