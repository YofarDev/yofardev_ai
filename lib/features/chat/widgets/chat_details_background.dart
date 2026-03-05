import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/models/avatar_config.dart';
import '../../../../core/res/app_colors.dart';
import '../bloc/chats_cubit.dart';
import '../bloc/chats_state.dart';

class ChatDetailsBackground extends StatelessWidget {
  const ChatDetailsBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChatsCubit, ChatsState>(
      builder: (BuildContext context, ChatsState state) {
        return Stack(
          children: <Widget>[
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[AppColors.background, AppColors.surface],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Opacity(
                opacity: 0.15,
                child: Image.asset(
                  state.openedChat.avatar.background.getPath(),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      AppColors.surface.withValues(alpha: 0.6),
                      AppColors.surface.withValues(alpha: 0.3),
                      AppColors.surface.withValues(alpha: 0.6),
                    ],
                    stops: const <double>[0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
