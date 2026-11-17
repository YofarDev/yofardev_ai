import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:nested/nested.dart';

import 'core/di/service_locator.dart';
import 'core/l10n/app_localization_delegates.dart';
import 'core/services/audio/interruption_service.dart';
import 'core/design/design.dart';
import 'core/router/app_router.dart';
import 'core/models/avatar_scene.dart';
import 'features/avatar/avatar.dart';
import 'features/chat/chat.dart';
import 'features/settings/settings.dart';
import 'features/talking/talking.dart';

/// App shell: owns app-scoped providers and the [MaterialApp.router].
class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: <SingleChildWidget>[
        // Truly global cubits - used throughout the app
        BlocProvider<SettingsCubit>(
          create: (BuildContext context) =>
              getIt<SettingsCubit>()..loadSettings(),
        ),
        // Feature cubits - shared across multiple screens
        BlocProvider<TalkingCubit>(
          create: (BuildContext context) => getIt<TalkingCubit>(),
        ),
        // Eager: it must be listening before the first sentence plays,
        // whether or not a caption reader is built yet.
        BlocProvider<CaptionCubit>(
          lazy: false,
          create: (BuildContext context) => getIt<CaptionCubit>()..init(),
        ),
        BlocProvider<ChatCubit>(
          create: (BuildContext context) => getIt<ChatCubit>()..init(),
        ),
        BlocProvider<ChatTtsCubit>(
          lazy: false,
          create: (BuildContext context) => getIt<ChatTtsCubit>(),
        ),
        BlocProvider<AvatarCubit>(
          create: (BuildContext context) => getIt<AvatarCubit>(),
        ),
        RepositoryProvider<InterruptionService>(
          create: (BuildContext context) => getIt<InterruptionService>(),
        ),
        // DemoCubit moved to HomeScreen scope
      ],
      child: AppView(routerConfig: AppRouter.router),
    );
  }
}

/// The [MaterialApp.router] under the app-scoped providers: rebuilt when the
/// language changes, and when the avatar's scene changes so the theme
/// cross-fades to that scene's accent. [routerConfig] is reused across those
/// rebuilds, so routed screens and their state are never re-created.
///
/// The `BlocSelector<AvatarCubit…>` reads the cubit at app start, so
/// AvatarCubit is created eagerly (`lazy:` on its provider has no effect).
class AppView extends StatelessWidget {
  const AppView({super.key, required this.routerConfig});

  final RouterConfig<Object> routerConfig;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsCubit, SettingsState>(
      buildWhen: (SettingsState previous, SettingsState current) {
        // Only rebuild when language changes, not on every settings change
        return previous.currentLanguage != current.currentLanguage;
      },
      builder: (BuildContext context, SettingsState settings) {
        return BlocSelector<AvatarCubit, AvatarState, AvatarScene>(
          selector: (AvatarState state) => state.scene,
          builder: (BuildContext context, AvatarScene scene) {
            return MaterialApp.router(
              title: 'Yofardev AI',
              debugShowCheckedModeBanner: false,
              locale: Locale(settings.currentLanguage),
              supportedLocales: const <Locale>[Locale('fr'), Locale('en')],
              // material_ui widgets read material_ui's localizations, so the
              // shared delegate list (not the gen-l10n flutter_localizations
              // one) is what makes non-English locales resolve.
              localizationsDelegates: appLocalizationsDelegates,
              theme: AppTheme.forScene(scene),
              themeMode: ThemeMode.dark,
              themeAnimationDuration: AppMotion.slow,
              themeAnimationCurve: AppMotion.standard,
              routerConfig: routerConfig,
            );
          },
        );
      },
    );
  }
}
