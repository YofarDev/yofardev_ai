import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/res/app_constants.dart';
import '../../avatar/avatar.dart';
import '../../chat/chat.dart';
import '../../talking/talking.dart';
import 'home_buttons.dart';

/// The main content stack for the home screen.
///
/// This widget encapsulates the layered UI structure including:
/// - Scene background and avatar (Rive when [AppConstants.useRiveAvatar],
///   PNG widgets otherwise)
/// - Thinking animation
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
          if (AppConstants.useRiveAvatar)
            _buildRiveStage(context)
          else
            ..._buildPngAvatarLayers(),
          if (!AppConstants.useRiveAvatar && talkingState is GeneratingState)
            const ThinkingAnimation(),
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

  /// The Rive scene with the avatar layered on top. The Rive `generating`
  /// phase carries its own thinking indication, so no Lottie overlay here.
  Widget _buildRiveStage(BuildContext context) {
    return BlocBuilder<AvatarCubit, AvatarState>(
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
            ),
          ],
        );
      },
    );
  }

  /// The v3 PNG layers, kept until the cut-over removes them.
  List<Widget> _buildPngAvatarLayers() {
    final bool showThinking = talkingState is GeneratingState;
    return <Widget>[
      const AnimatedBackgroundAvatar(),
      BlocBuilder<AvatarCubit, AvatarState>(
        builder: (BuildContext context, AvatarState avatarState) {
          final bool showAvatarLoading =
              chatsState.initializing ||
              avatarState.status == AvatarStatus.loading ||
              avatarState.status == AvatarStatus.initial;
          return showAvatarLoading
              ? const LoadingAvatarWidget()
              : const AvatarWidgets();
        },
      ),
      if (showThinking) const ThinkingAnimation(),
    ];
  }
}
