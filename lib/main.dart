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
import 'features/chat/presentation/bloc/chats_cubit.dart';
import 'features/chat/presentation/bloc/chat_list_cubit.dart';
import 'features/chat/presentation/bloc/chat_message_cubit.dart';
import 'features/chat/presentation/bloc/chat_title_cubit.dart';
import 'features/chat/presentation/bloc/chat_tts_cubit.dart';
import 'features/demo/presentation/bloc/demo_cubit.dart';
import 'features/sound/data/datasources/tts_datasource.dart';
import 'features/talking/presentation/bloc/talking_cubit.dart';
import 'features/home/presentation/bloc/home_cubit.dart';
import 'features/settings/presentation/bloc/settings_cubit.dart';
import 'core/res/app_theme.dart';
import 'core/utils/platform_utils.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setupServiceLocator();
  if (!PlatformUtils.isMobile()) {
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
  if (PlatformUtils.checkPlatform() != 'Web') {
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
        BlocProvider<TalkingCubit>(
          create: (BuildContext context) => getIt<TalkingCubit>(),
        ),
        BlocProvider<ChatsCubit>(
          create: (BuildContext context) => getIt<ChatsCubit>()..init(),
        ),
        BlocProvider<ChatListCubit>(
          create: (BuildContext context) => getIt<ChatListCubit>()..init(),
        ),
        BlocProvider<ChatMessageCubit>(
          create: (BuildContext context) => getIt<ChatMessageCubit>(),
        ),
        BlocProvider<ChatTitleCubit>(
          create: (BuildContext context) => getIt<ChatTitleCubit>(),
        ),
        BlocProvider<ChatTtsCubit>(
          lazy: false,
          create: (BuildContext context) => getIt<ChatTtsCubit>(),
        ),
        BlocProvider<AvatarCubit>(
          create: (BuildContext context) => getIt<AvatarCubit>(),
        ),
        BlocProvider<DemoCubit>(
          create: (BuildContext context) => getIt<DemoCubit>(),
        ),
        BlocProvider<SettingsCubit>(
          create: (BuildContext context) => getIt<SettingsCubit>(),
        ),
        BlocProvider<HomeCubit>(
          create: (BuildContext context) => getIt<HomeCubit>()..initialize(),
        ),
      ],
      child: MaterialApp.router(
        title: 'Yofardev AI',
        debugShowCheckedModeBanner: false,
        locale: Locale(initialLanguage),
        supportedLocales: const <Locale>[Locale('fr'), Locale('en')],
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: AppTheme.lightTheme,
        routerConfig: AppRouter.router,
      ),
    );
  }
}
