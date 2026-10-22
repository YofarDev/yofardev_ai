import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nested/nested.dart';

import 'core/di/service_locator.dart';
import 'core/l10n/generated/app_localizations.dart';
import 'core/res/app_theme.dart';
import 'core/router/app_router.dart';
import 'features/avatar/presentation/bloc/avatar_cubit.dart';
import 'features/chat/chat.dart';
import 'features/settings/settings.dart';
import 'features/talking/talking.dart';

/// App shell: owns app-scoped providers and the [MaterialApp.router].
class App extends StatelessWidget {
  const App({super.key, required this.initialLanguage});

  final String initialLanguage;

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
        // DemoCubit and HomeCubit moved to HomeScreen scope
      ],
      child: BlocBuilder<SettingsCubit, SettingsState>(
        buildWhen: (SettingsState previous, SettingsState current) {
          // Only rebuild when language changes, not on every settings change
          return previous.currentLanguage != current.currentLanguage;
        },
        builder: (BuildContext context, SettingsState state) {
          return MaterialApp.router(
            title: 'Yofardev AI',
            debugShowCheckedModeBanner: false,
            locale: Locale(state.currentLanguage),
            supportedLocales: const <Locale>[Locale('fr'), Locale('en')],
            localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            theme: AppTheme.lightTheme,
            routerConfig: AppRouter.router,
          );
        },
      ),
    );
  }
}
