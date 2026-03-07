import 'package:flutter/material.dart';

import '../../avatar/widgets/avatar_widgets.dart';
import '../../avatar/widgets/background_avatar.dart';
import '../../avatar/widgets/loading_avatar_widget.dart';
import '../../avatar/widgets/thinking_animation.dart';
import '../../chat/presentation/bloc/chats_state.dart';
import '../../chat/widgets/ai_text_input/ai_text_input.dart';
import '../../talking/presentation/bloc/talking_state.dart';
import 'home_buttons.dart';

/// The main content stack for the home screen.
///
/// This widget encapsulates the layered UI structure including:
/// - Background avatar
/// - Main avatar widgets or loading state
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

  final ChatsState chatsState;
  final TalkingState talkingState;
  final VoidCallback onTripleTap;

  @override
  Widget build(BuildContext context) {
    final bool isLoading = talkingState.status == TalkingStatus.loading;
    return GestureDetector(
      onTap: onTripleTap,
      behavior: HitTestBehavior.translucent,
      child: Stack(
        fit: StackFit.expand,
        alignment: Alignment.topCenter,
        children: <Widget>[
          const BackgroundAvatar(),
          if (!chatsState.initializing)
            const AvatarWidgets()
          else
            const LoadingAvatarWidget(),
          if (isLoading) const ThinkingAnimation(),
          if (!chatsState.initializing)
            const Positioned(
              left: 8,
              right: 8,
              bottom: 16,
              child: AiTextInput(),
            ),
          const HomeButtons(),
        ],
      ),
    );
  }
}
