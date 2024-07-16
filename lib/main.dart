import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:nested/nested.dart';

import 'l10n/app_localization_delegate.dart';
import 'l10n/localization_manager.dart';
import 'logic/avatar/avatar_cubit.dart';
import 'logic/chat/chats_cubit.dart';
import 'logic/talking/talking_cubit.dart';
import 'ui/pages/home.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final Locale deviceLocale = PlatformDispatcher.instance.locales.first;
  await LocalizationManager().initialize(deviceLocale.languageCode);
  SystemChrome.setPreferredOrientations(
    <DeviceOrientation>[DeviceOrientation.portraitUp],
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: <SingleChildWidget>[
        BlocProvider<TalkingCubit>(
          create: (BuildContext context) => TalkingCubit(),
        ),
        BlocProvider<ChatsCubit>(
          create: (BuildContext context) => ChatsCubit()..init(),
        ),
        BlocProvider<AvatarCubit>(
          create: (BuildContext context) => AvatarCubit(),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
          supportedLocales: const <Locale>[
          Locale('fr'),
          Locale('en'),
        ],
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          AppLocalizationsDelegate(), 
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
        ),
        home: const Home(),
         
      ),
    );
  }
}
