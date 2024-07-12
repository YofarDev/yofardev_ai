import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:just_audio/just_audio.dart';

import '../../logic/avatar/avatar_cubit.dart';
import '../../logic/chat/chats_cubit.dart';
import '../../models/avatar.dart';
import '../../utils/extensions.dart';
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
            AppIconButton(
              icon: Icons.settings_rounded,
              onPressed: () async {
                final String chatId =
                    context.read<ChatsCubit>().state.currentChat.id;
                final AvatarConfig avatarConfig = AvatarConfig(
                  backgrounds: <AvatarBackgrounds>[
                    EnumUtils.getRandomValue(AvatarBackgrounds.values),
                  ],
                  top: <AvatarTop>[EnumUtils.getRandomValue(AvatarTop.values)],
                  bottom: <AvatarBottom>[
                    EnumUtils.getRandomValue(AvatarBottom.values),
                  ],
                  glasses: <AvatarGlasses>[
                    EnumUtils.getRandomValue(AvatarGlasses.values),
                  ],
                  specials: AvatarSpecials.values,
                );
                final AudioPlayer player = AudioPlayer();
                await player.setAsset('assets/sound_effects/frenchTheme.wav');
                player.play();
                context
                    .read<AvatarCubit>()
                    .onNewAvatarConfig(chatId, avatarConfig);
              },
            ),
          ],
        ),
      ),
    );
  }
}
