import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../logic/avatar/avatar_cubit.dart';
import '../../logic/chat/chats_cubit.dart';
import '../../logic/talking/talking_cubit.dart';
import '../pages/chat/chats_list_page.dart';
import '../pages/settings/settings_page.dart';
import 'app_icon_button.dart';

class HomeButtons extends StatelessWidget {
  const HomeButtons({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChatsCubit, ChatsState>(
      builder: (BuildContext context, ChatsState state) {
        return Positioned(
          right: 8,
          top: 8,
          child: SafeArea(
            child: Column(
              children: <Widget>[
                GestureDetector(
                  onTap: () {
                    context.read<ChatsCubit>().setCurrentLanguage(
                          state.currentLanguage == 'fr' ? 'en' : 'fr',
                        );
                  },
                  child: Text(
                    state.currentLanguage == 'fr' ? '🇫🇷' : '🇬🇧',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
                const SizedBox(height: 8),
                AppIconButton(
                  icon: Icons.chat_bubble_outline_rounded,
                  onPressed: () {
                    Navigator.of(context).push(
                      PageRouteBuilder<dynamic>(
                        pageBuilder: (_, __, ___) => const ChatsListPage(),
                        transitionDuration: Duration.zero,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                AppIconButton(
                  icon: Icons.add_outlined,
                  onPressed: () {
                    context.read<ChatsCubit>().createNewChat(
                          context.read<AvatarCubit>(),
                          context.read<TalkingCubit>(),
                        );
                  },
                ),
                const SizedBox(height: 8),
                AppIconButton(
                  icon: Icons.settings_rounded,
                  onPressed: () {
                    Navigator.of(context).push(
                      PageRouteBuilder<dynamic>(
                        pageBuilder: (_, __, ___) => const SettingsPage(),
                        transitionDuration: Duration.zero,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }
}
