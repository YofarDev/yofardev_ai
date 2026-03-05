import 'dart:ui';

import 'package:alarm/alarm.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:nested/nested.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

import 'core/di/service_locator.dart';
import 'core/router/app_router.dart';
import 'features/avatar/bloc/avatar_cubit.dart';
import 'features/chat/bloc/chats_cubit.dart';
import 'features/chat/bloc/chat_list_cubit.dart';
import 'features/chat/bloc/chat_message_cubit.dart';
import 'features/demo/bloc/demo_cubit.dart';
import 'features/sound/data/datasources/tts_datasource.dart';
import 'l10n/app_localization_delegate.dart';
import 'l10n/localization_manager.dart';
import 'features/talking/bloc/talking_cubit.dart';
import 'features/home/bloc/home_cubit.dart';
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
  final Locale deviceLocale = PlatformDispatcher.instance.locales.first;
  await LocalizationManager().initialize(deviceLocale.languageCode);
  if (PlatformUtils.checkPlatform() != 'Web' &&
      PlatformUtils.checkPlatform() != 'MacOS') {
    await Alarm.init();
    SystemChrome.setPreferredOrientations(<DeviceOrientation>[
      DeviceOrientation.portraitUp,
    ]);
  }
  if (PlatformUtils.checkPlatform() != 'Web') {
    await dotenv.load();
    await TtsDatasource.initSupertonic();
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

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
        BlocProvider<AvatarCubit>(
          create: (BuildContext context) => AvatarCubit(),
        ),
        BlocProvider<DemoCubit>(
          create: (BuildContext context) => getIt<DemoCubit>(),
        ),
        BlocProvider<HomeCubit>(
          create: (BuildContext context) => HomeCubit()..initialize(),
        ),
      ],
      child: MaterialApp.router(
        title: 'Yofardev AI',
        debugShowCheckedModeBanner: false,
        supportedLocales: const <Locale>[Locale('fr'), Locale('en')],
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          AppLocalizationsDelegate(),
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
