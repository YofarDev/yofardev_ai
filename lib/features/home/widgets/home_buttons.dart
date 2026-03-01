import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../avatar/bloc/avatar_cubit.dart';
import '../../chat/bloc/chats_cubit.dart';
import '../../chat/bloc/chats_state.dart';
import '../../talking/bloc/talking_cubit.dart';
import '../../chat/screens/chats_list_screen.dart';
import '../../settings/screens/settings_screen.dart';
import '../../../core/widgets/app_icon_button.dart';
import '../../../core/widgets/constrained_width.dart';
import '../../../core/widgets/function_calling_button.dart';

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
                        pageBuilder: (_, _, _) =>
                            const ConstrainedWidth(child: ChatsListPage()),
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
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: AppIconButton(
                    icon: Icons.settings_rounded,
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<dynamic>(
                          builder: (BuildContext context) =>
                              const ConstrainedWidth(child: SettingsPage()),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                const FunctionCallingButton(),
              ],
            ),
          ),
        );
      },
    );
  }
}
