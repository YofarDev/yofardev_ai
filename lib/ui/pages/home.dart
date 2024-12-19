import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:just_audio/just_audio.dart';

import '../../logic/avatar/avatar_cubit.dart';
import '../../logic/avatar/avatar_state.dart';
import '../../logic/chat/chats_cubit.dart';
import '../../logic/talking/talking_cubit.dart';
import '../../res/app_colors.dart';
import '../../res/app_constants.dart';
import '../../utils/app_utils.dart';
import '../../utils/platform_utils.dart';
import '../../utils/volume_fader.dart';
import '../widgets/ai_text_input.dart';
import '../widgets/avatar/avatar_widgets.dart';
import '../widgets/avatar/background_avatar.dart';
import '../widgets/avatar/loading_avatar_widget.dart';
import '../widgets/avatar/thinking_animation.dart';
import '../widgets/home_buttons.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  late ProgressiveVolumeControl _volumeControl;
  late AudioPlayer _player;
  bool _isTalkingWaitingSentences = false;

  @override
  void initState() {
    super.initState();
    if (PlatformUtils.checkPlatform() != 'Web') {
      _initVolumeControl();
      _initAudioPlayer(); // to avoid a weird bug when first sound is played
    }
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _updateAvatarValuesBasedOnScreenWidth();
      final String sentencesStr =
          await DefaultAssetBundle.of(context).loadString(
        'assets/txt/waiting_sentences_${context.read<ChatsCubit>().state.currentLanguage}.txt',
      );
      final List<String> sentences = sentencesStr.split('\n');
      context.read<ChatsCubit>().prepareWaitingSentences(sentences);
    });
  }

  void _initAudioPlayer() async {
    _player = AudioPlayer();
    await _player
        .setAsset(AppUtils.fixAssetsPath('assets/sound_effects/_silence.mp3'));
    _player.play();
  }

  void _updateAvatarValuesBasedOnScreenWidth() async {
    context.read<AvatarCubit>().setValuesBasedOnScreenWidth(
          screenWidth: MediaQuery.of(context).size.width > AppConstants.maxWidth
              ? AppConstants.maxWidth
              : MediaQuery.of(context).size.width,
        );
  }

  void _initVolumeControl() async {
    if (PlatformUtils.checkPlatform() == 'Web') return;
    _volumeControl = ProgressiveVolumeControl();
  }

  Future<void> _prepareWaitingTTS(String language) async {
    final String sentencesStr = await DefaultAssetBundle.of(context).loadString(
      'assets/txt/waiting_sentences_$language.txt',
    );
    final List<String> sentences = sentencesStr.split('\n');
    context.read<ChatsCubit>().prepareWaitingSentences(sentences);
  }

  @override
  void dispose() {
    super.dispose();
    _player.dispose();
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
        if (PlatformUtils.checkPlatform() != 'Web') {
          _volumeControl.startVolumeFade(
            state.statusAnimation != AvatarStatusAnimation.leaving,
          );
        }
      },
      child: BlocListener<TalkingCubit, TalkingState>(
        listenWhen: (TalkingState previous, TalkingState current) =>
            previous.status != current.status,
        listener: (BuildContext context, TalkingState state) {
          _isTalkingWaitingSentences = state.status == TalkingStatus.loading;
          if (_isTalkingWaitingSentences) {
            if (PlatformUtils.checkPlatform() == 'Web') {
              return;
            }
            _startWaitingTtsLoop();
          }
        },
        child: BlocListener<ChatsCubit, ChatsState>(
          listenWhen: (ChatsState previous, ChatsState current) =>
              previous.currentLanguage != current.currentLanguage,
          listener: (BuildContext context, ChatsState state) {
            _prepareWaitingTTS(state.currentLanguage);
          },
          child: BlocListener<ChatsCubit, ChatsState>(
            listenWhen: (ChatsState previous, ChatsState current) =>
                previous.currentChat.id != current.currentChat.id,
            listener: (BuildContext context, ChatsState state) {
              context.read<AvatarCubit>().loadAvatar(state.currentChat.id);
            },
            child: BlocListener<TalkingCubit, TalkingState>(
              listenWhen: (TalkingState previous, TalkingState current) =>
                  previous.answer != current.answer,
              listener: (BuildContext context, TalkingState talkingState) {
                context.read<AvatarCubit>().onNewAvatarConfig(
                      talkingState.answer.chatId,
                      talkingState.answer.avatarConfig,
                    );

                if (talkingState.status == TalkingStatus.success) {
                  _playTts(talkingState.answer.audioPath);
                }
              },
              child: BlocBuilder<ChatsCubit, ChatsState>(
                builder: (BuildContext context, ChatsState chatsState) {
                  return BlocBuilder<AvatarCubit, AvatarState>(
                    builder: (BuildContext context, AvatarState avatarState) {
                      return BlocBuilder<TalkingCubit, TalkingState>(
                        builder: (BuildContext context, TalkingState state) {
                          final bool isLoading =
                              state.status == TalkingStatus.loading;
                          final Widget w = Stack(
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
                          );

                          return Scaffold(
                            backgroundColor: AppColors.background,
                            body: w,
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _startWaitingTtsLoop() async {
    await _player.stop();
    context.read<ChatsCubit>().shuffleWaitingSentences();
    int i = 0;
    while (_isTalkingWaitingSentences) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (_player.playing) continue;
      final String audioPath = context
          .read<ChatsCubit>()
          .state
          .audioPathsWaitingSentences[i]['audioPath'] as String;
      await _playTts(
        audioPath,
        removeFile: false,
        soundEffectsEnabled: false,
        updateStatus: false,
      );
      i++;
      if (i >=
          context.read<ChatsCubit>().state.audioPathsWaitingSentences.length) {
        i = 0;
      }
      await Future<void>.delayed(const Duration(seconds: 3));
    }
  }

  Future<void> _playTts(
    String audioPath, {
    bool removeFile = true,
    bool? soundEffectsEnabled,
    bool updateStatus = true,
  }) async {
    await _player.stop();
    await _player.setFilePath(audioPath, initialPosition: Duration.zero);
    await _player.play().then((_) async {
      await _player.stop();
      context.read<TalkingCubit>().stopTalking(
            soundEffectsEnabled: soundEffectsEnabled ??
                context.read<ChatsCubit>().state.soundEffectsEnabled,
            removeFile: removeFile,
            updateStatus: updateStatus,
          );
    });
  }
}
