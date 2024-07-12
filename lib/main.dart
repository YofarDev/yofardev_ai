import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:nested/nested.dart';

import 'logic/avatar/avatar_cubit.dart';
import 'logic/chat/chats_cubit.dart';
import 'logic/talking/talking_cubit.dart';
import 'ui/screens/home.dart';

void main() {
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
          create: (BuildContext context) => ChatsCubit()..getCurrentChat(),
        ),
        BlocProvider<AvatarCubit>(
          create: (BuildContext context) => AvatarCubit(),
        ),
      ],
      child: MaterialApp(
        supportedLocales: const <Locale>[Locale('fr')],
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
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
