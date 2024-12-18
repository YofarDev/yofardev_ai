import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    } else {
      _setDefaultApiKey();
    }
    if (PlatformUtils.checkPlatform() == 'Android') {
      // to avoid a weird bug when first sound is played
      _initAudioPlayer();
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

  void _setDefaultApiKey() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if ((prefs.getString("google_api_key") ?? "").isNotEmpty) return;
    const String googleApiKey = 'API KEY HERE';
    if (googleApiKey.isNotEmpty) {
      prefs.setString('google_api_key', googleApiKey);
    }
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
            _startWaitingTtsLoop();
          }
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
                        Widget w = Stack(
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
