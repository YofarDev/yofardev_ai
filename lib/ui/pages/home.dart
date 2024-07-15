import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:just_audio/just_audio.dart';

import '../../logic/avatar/avatar_cubit.dart';
import '../../logic/avatar/avatar_state.dart';
import '../../logic/chat/chats_cubit.dart';
import '../../logic/talking/talking_cubit.dart';
import '../../models/avatar.dart';
import '../../res/app_colors.dart';
import '../../res/app_constants.dart';
import '../../utils/platform_utils.dart';
import '../../utils/volume_fader.dart';
import '../widgets/ai_text_input.dart';
import '../widgets/avatar/avatar_widgets.dart';
import '../widgets/avatar/background_avatar.dart';
import '../widgets/avatar/thinking_animation.dart';
import '../widgets/home_buttons.dart';
import '../widgets/world_borders.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  late ProgressiveVolumeControl _volumeControl;

  @override
  void initState() {
    super.initState();
    if (checkPlatform() != 'Web') {
      _initVolumeControl();
    }
    if (checkPlatform() == 'Android') {
      // to avoid a weird bug when first sound is played
      _initAudioPlayer();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateAvatarValuesBasedOnScreenWidth();
    });
  }

  void _initAudioPlayer() async {
    final AudioPlayer player = AudioPlayer();
    await player.setAsset('assets/sound_effects/_silence.mp3');
    player.play();
  }

  void _updateAvatarValuesBasedOnScreenWidth() async {
    context.read<AvatarCubit>().setValuesBasedOnScreenWidth(
          screenWidth: MediaQuery.of(context).size.width > AppConstants.maxWidth
              ? AppConstants.maxWidth
              : MediaQuery.of(context).size.width,
        );
  }

  void _initVolumeControl() async {
    _volumeControl = ProgressiveVolumeControl();
  }

  @override
  Widget build(BuildContext context) {
    _updateAvatarValuesBasedOnScreenWidth();
    return BlocListener<AvatarCubit, AvatarState>(
      listenWhen: (AvatarState previous, AvatarState current) =>
          previous.statusAnimation != current.statusAnimation ||
          previous.status != current.status,
      listener: (BuildContext context, AvatarState state) {
        if (state.statusAnimation == AvatarStatusAnimation.initial) return;
        _volumeControl.startVolumeFade(
          state.statusAnimation != AvatarStatusAnimation.leaving,
        );
      },
      child: BlocListener<ChatsCubit, ChatsState>(
        listenWhen: (ChatsState previous, ChatsState current) =>
            previous.currentChat != current.currentChat,
        listener: (BuildContext context, ChatsState state) {
          context.read<AvatarCubit>().loadAvatar(state.currentChat.id);
        },
        child: BlocListener<TalkingCubit, TalkingState>(
          listenWhen: (TalkingState previous, TalkingState current) =>
              previous.answer.annotations != current.answer.annotations,
          listener: (BuildContext context, TalkingState state) {
            if (state.answer.annotations.isNotEmpty) {
              final AvatarConfig avatarConfig = context
                  .read<AvatarCubit>()
                  .setAvatarConfigFromNewAnswer(state.answer.annotations);
              context
                  .read<AvatarCubit>()
                  .onNewAvatarConfig(state.answer.chatId, avatarConfig);
            }
          },
          child: BlocBuilder<AvatarCubit, AvatarState>(
            builder: (BuildContext context, AvatarState avatarState) {
              return BlocBuilder<TalkingCubit, TalkingState>(
                builder: (BuildContext context, TalkingState state) {
                  final bool isLoading = state.status == TalkingStatus.loading;
                  Widget w = Stack(
                    fit: StackFit.expand,
                    alignment: Alignment.topCenter,
                    children: <Widget>[
                      const BackgroundAvatar(),
                      const AvatarWidgets(),
                      if (isLoading) const ThinkingAnimation(),
                      const Positioned(
                        left: 8,
                        right: 8,
                        bottom: 16,
                        child: AiTextInput(),
                      ),
                      const HomeButtons(),
                    ],
                  );
                  w = Stack(
                    children: <Widget>[
                      Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: AppConstants.maxWidth,
                          ),
                          child: w,
                        ),
                      ),
                      if (MediaQuery.of(context).size.width >
                          AppConstants.maxWidth)
                        const WorldBorders(),
                    ],
                  );
                  return Scaffold(
                    backgroundColor: AppColors.background,
                    body: w,
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
