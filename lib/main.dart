import 'dart:async';
import 'dart:ui';

import 'package:alarm/alarm.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:nested/nested.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import 'core/di/service_locator.dart';
import 'core/router/app_router.dart';
import 'core/l10n/generated/app_localizations.dart';
import 'features/avatar/presentation/bloc/avatar_cubit.dart';
import 'features/chat/data/datasources/chat_local_datasource.dart';
import 'features/chat/presentation/bloc/chat_cubit.dart';
import 'features/chat/presentation/bloc/chat_state.dart';
import 'features/chat/presentation/bloc/chat_tts_cubit.dart';
import 'features/sound/data/datasources/tts_datasource.dart';
import 'features/talking/presentation/bloc/talking_cubit.dart';
import 'features/settings/presentation/bloc/settings_cubit.dart';
import 'core/res/app_theme.dart';
import 'core/utils/platform_utils.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setupServiceLocator();
  // Run chat data migration (previously in datasource constructor)
  await getIt<ChatLocalDatasource>().init();
  if (PlatformUtils.isDesktop()) {
    await windowManager.ensureInitialized();
    final Display primaryDisplay = await screenRetriever.getPrimaryDisplay();
    final double displayHeight = primaryDisplay.size.height * 0.8;
    final WindowOptions windowOptions = WindowOptions(
      size: Size(displayHeight * 9 / 16, displayHeight),
      title: "Yofardev AI",
      center: true,
      skipTaskbar: false,
    );
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }
  // Load saved language preference, falling back to device locale
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final String? savedLanguage = prefs.getString('language');
  final Locale deviceLocale = PlatformDispatcher.instance.locales.first;
  final String initialLanguage = savedLanguage ?? deviceLocale.languageCode;
  if (PlatformUtils.isMobile()) {
    await Alarm.init();
    SystemChrome.setPreferredOrientations(<DeviceOrientation>[
      DeviceOrientation.portraitUp,
    ]);
  }
  if (PlatformUtils.checkPlatform() != 'Web' &&
      PlatformUtils.checkPlatform() != 'MacOS') {
    unawaited(
      TtsDatasource.initSupertonic().catchError((Object error, StackTrace st) {
        // Startup should never be blocked by optional TTS warmup.
      }),
    );
  }
  runApp(MyApp(initialLanguage: initialLanguage));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.initialLanguage});

  final String initialLanguage;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: <SingleChildWidget>[
        // Truly global cubits - used throughout the app
        BlocProvider<SettingsCubit>(
          create: (BuildContext context) => getIt<SettingsCubit>(),
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
      child: BlocBuilder<ChatCubit, ChatState>(
        buildWhen: (ChatState previous, ChatState current) {
          // Only rebuild when language changes, not on every chat state change
          return previous.currentLanguage != current.currentLanguage;
        },
        builder: (BuildContext context, ChatState state) {
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
