import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../avatar/bloc/avatar_cubit.dart';
import '../../chat/bloc/chats_cubit.dart';
import '../../chat/bloc/chats_state.dart';
import '../../talking/bloc/talking_cubit.dart';
import '../../../core/widgets/app_icon_button.dart';
import '../../../core/widgets/function_calling_button.dart';
import '../../../core/router/route_constants.dart';

class HomeButtons extends StatelessWidget {
  const HomeButtons({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<ChatsCubit, ChatsState>(
      listener: (BuildContext context, ChatsState state) {
        if (state.chatCreated) {
          // Handle cross-feature coordination when chat is created
          context.read<AvatarCubit>().loadAvatar(state.currentChat.id);
          context.read<TalkingCubit>().init();
        }
      },
      child: BlocBuilder<ChatsCubit, ChatsState>(
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
                      context.go(RouteConstants.chats);
                    },
                  ),
                  const SizedBox(height: 8),
                  AppIconButton(
                    icon: Icons.add_outlined,
                    onPressed: () {
                      context.read<ChatsCubit>().createNewChat();
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: AppIconButton(
                      icon: Icons.settings_rounded,
                      onPressed: () {
                        context.go(RouteConstants.settings);
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  FunctionCallingButton(
                    isEnabled: state.functionCallingEnabled,
                    onToggle: () =>
                        context.read<ChatsCubit>().toggleFunctionCalling(),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
