import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../avatar/avatar.dart';
import '../../chat/chat.dart';
import '../../talking/talking.dart';
import 'home_buttons.dart';

/// The main content stack for the home screen.
///
/// This widget encapsulates the layered UI structure including:
/// - Rive scene background with the avatar on top
/// - AI text input
/// - Home buttons overlay
class HomeContentStack extends StatelessWidget {
  const HomeContentStack({
    super.key,
    required this.chatsState,
    required this.talkingState,
    required this.onTripleTap,
  });

  final ChatState chatsState;
  final TalkingState talkingState;
  final VoidCallback onTripleTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTripleTap,
      behavior: HitTestBehavior.translucent,
      child: Stack(
        fit: StackFit.expand,
        alignment: Alignment.topCenter,
        children: <Widget>[
          BlocBuilder<AvatarCubit, AvatarState>(
            builder: (BuildContext context, AvatarState avatarState) {
              return Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  RiveSceneView(
                    scene: avatarState.scene,
                    sceneEvent: avatarState.sceneEvent,
                    onPropTapped: (String propId) {
                      context.read<AvatarCubit>().onPropTapped(
                        avatarState.scene,
                        propId,
                      );
                    },
                  ),
                  RiveAvatarView(
                    avatarState: avatarState,
                    talkingState: talkingState,
                    onAvatarTapped: (String zone) {
                      context.read<AvatarCubit>().onAvatarTapped(zone);
                    },
                    onPresenceDone: (String presence) {
                      context.read<AvatarCubit>().onPresenceDone(presence);
                    },
                  ),
                ],
              );
            },
          ),
          if (!chatsState.initializing)
            Positioned(
              left: 8,
              right: 8,
              bottom: 16,
              child: AiTextInput(avatar: chatsState.currentChat.avatar),
            ),
          const FloatingStopButton(bottomPadding: 16),
          const HomeButtons(),
        ],
      ),
    );
  }
}
