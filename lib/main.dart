import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nested/nested.dart';

import 'logic/avatar/avatar_cubit.dart';
import 'logic/history/history_cubit.dart';
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
        BlocProvider<HistoryCubit>(
          create: (BuildContext context) => HistoryCubit(),
        ),
        BlocProvider<AvatarCubit>(
          create: (BuildContext context) => AvatarCubit()..getBgImage(),
        ),
      ],
      child: MaterialApp(
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
        ),
        home: const Home(),
      ),
    );
  }
}
