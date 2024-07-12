import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:just_audio/just_audio.dart';

import '../../logic/avatar/avatar_cubit.dart';
import '../../logic/avatar/avatar_state.dart';
import '../../logic/chat/chats_cubit.dart';
import '../../logic/talking/talking_cubit.dart';
import '../../models/avatar.dart';
import '../../res/app_constants.dart';
import '../../utils/volume_fader.dart';
import '../widgets/ai_text_input.dart';
import '../widgets/avatar/avatar_widgets.dart';
import '../widgets/avatar/background_avatar.dart';
import '../widgets/avatar/thinking_animation.dart';
import '../widgets/home_buttons.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initAvatar();
      _initAudioPlayer();
      _initVolumeControl();
    });
  }

  // to avoid a weird bug when first sound is played
  void _initAudioPlayer() async {
    final AudioPlayer player = AudioPlayer();
    await player.setAsset('assets/sound_effects/_silence.mp3');
    player.play();
  }

  void _initAvatar() async {
    context.read<AvatarCubit>().initBaseValues(
          originalWidth: AppConstants().avatarWidth,
          originalHeight: AppConstants().avatarHeight,
          screenWidth: MediaQuery.of(context).size.width,
        );
  }

  void _initVolumeControl() async {
    _volumeControl = ProgressiveVolumeControl(
      fadeDuration: Duration(seconds: AppConstants().movingAvatarDuration),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AvatarCubit, AvatarState>(
      listenWhen: (AvatarState previous, AvatarState current) =>
          previous.statusAnimation != current.statusAnimation,
      listener: (BuildContext context, AvatarState state) {
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
                  return Scaffold(
                    backgroundColor: Colors.blue,
                    body: Stack(
                      fit: StackFit.expand,
                      alignment: Alignment.topCenter,
                      children: <Widget>[
                        const BackgroundAvatar(),
                        const AvatarWidgets(),
                        if (isLoading) const ThinkingAnimation(),
                        const Positioned(
                          left: 16,
                          right: 16,
                          bottom: 16,
                          child: AiTextInput(),
                        ),
                        const HomeButtons(),
                      ],
                    ),
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
