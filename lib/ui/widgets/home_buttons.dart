import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../logic/avatar/avatar_cubit.dart';
import '../../logic/chat/chats_cubit.dart';
import '../screens/chat/chats_list_page.dart';
import 'app_icon_button.dart';

class HomeButtons extends StatelessWidget {
  const HomeButtons({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 8,
      top: 8,
      child: SafeArea(
        child: Column(
          children: <Widget>[
            AppIconButton(
              icon: Icons.chat_bubble_outline_rounded,
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<dynamic>(
                    builder: (BuildContext context) => const ChatsListPage(),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            AppIconButton(
              icon: Icons.add_outlined,
              onPressed: () {
                context
                    .read<ChatsCubit>()
                    .createNewChat(context.read<AvatarCubit>());
              },
            ),
            const SizedBox(height: 8),
            // AppIconButton(
            //   icon: Icons.settings_rounded,
            //   onPressed: () {
            //     context.read<AvatarCubit>().changeOutOfScreenStatus();
            //   },
            // ),
          ],
        ),
      ),
    );
  }
}
