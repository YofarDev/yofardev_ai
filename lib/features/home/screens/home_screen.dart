import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../features/avatar/bloc/avatar_cubit.dart';
import '../../../features/avatar/bloc/avatar_state.dart';
import '../../../features/chat/bloc/chats_cubit.dart';
import '../../../logic/home/home_cubit.dart';
import '../../../logic/talking/talking_cubit.dart';
import '../../../res/app_colors.dart';
import '../../utils/platform_utils.dart';
import '../../chat/widgets/ai_text_input/ai_text_input.dart';
import '../../avatar/widgets/avatar_widgets.dart';
import '../../avatar/widgets/background_avatar.dart';
import '../../avatar/widgets/loading_avatar_widget.dart';
import '../../avatar/widgets/thinking_animation.dart';
import '../../demo/widgets/demo_controls_widget.dart';
import '../../../ui/widgets/home_buttons.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isTalkingWaitingSentences = false;
  final GlobalKey<DemoControlsState> _demoKey = GlobalKey();
  int _tapCount = 0;
  DateTime? _lastTapTime;

  void _handleTripleTap() {
    final DateTime now = DateTime.now();
    if (_lastTapTime != null &&
        now.difference(_lastTapTime!).inMilliseconds < 500) {
      _tapCount++;
    } else {
      _tapCount = 1;
    }
    _lastTapTime = now;

    if (_tapCount >= 3) {
      _tapCount = 0;
      _demoKey.currentState?.startDemo();
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      context.read<AvatarCubit>().setValuesBasedOnScreenWidth(
        screenWidth: MediaQuery.of(context).size.width > 800
            ? 800
            : MediaQuery.of(context).size.width,
      );
      final String
      sentencesStr = await DefaultAssetBundle.of(context).loadString(
        'assets/txt/waiting_sentences_${context.read<ChatsCubit>().state.currentLanguage}.txt',
      );
      final List<String> sentences = sentencesStr.split('\n');
      context.read<ChatsCubit>().prepareWaitingSentences(sentences);
    });
  }

  Future<void> _prepareWaitingTTS(String language) async {
    final String sentencesStr = await DefaultAssetBundle.of(
      context,
    ).loadString('assets/txt/waiting_sentences_$language.txt');
    final List<String> sentences = sentencesStr.split('\n');
    context.read<ChatsCubit>().prepareWaitingSentences(sentences);
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<HomeCubit>(
      create: (BuildContext context) => HomeCubit()..initialize(),
      child: BlocListener<AvatarCubit, AvatarState>(
        listenWhen: (AvatarState previous, AvatarState current) =>
            previous.statusAnimation != current.statusAnimation ||
            previous.status != current.status,
        listener: (BuildContext context, AvatarState state) async {
          if (state.statusAnimation == AvatarStatusAnimation.initial) return;
          context.read<HomeCubit>().startVolumeFade(
            state.statusAnimation != AvatarStatusAnimation.leaving,
          );
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
              context.read<HomeCubit>().startWaitingTtsLoop();
              _startWaitingTtsLoop();
            } else {
              context.read<HomeCubit>().stopWaitingTtsLoop();
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
                    context.read<HomeCubit>().playTts(
                      talkingState.answer.audioPath,
                      removeFile: true,
                      soundEffectsEnabled: context
                          .read<ChatsCubit>()
                          .state
                          .soundEffectsEnabled,
                      updateStatus: true,
                      onComplete: () {
                        context.read<TalkingCubit>().stopTalking(
                          soundEffectsEnabled: context
                              .read<ChatsCubit>()
                              .state
                              .soundEffectsEnabled,
                          removeFile: true,
                          updateStatus: true,
                        );
                      },
                    );
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
                            final Widget w = GestureDetector(
                              onTap: _handleTripleTap,
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
                                  DemoControls(key: _demoKey),
                                ],
                              ),
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
      ),
    );
  }

  Future<void> _startWaitingTtsLoop() async {
    context.read<ChatsCubit>().shuffleWaitingSentences();
    int i = 0;
    while (_isTalkingWaitingSentences && context.mounted) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      final List<Map<String, dynamic>> audioPaths = context
          .read<ChatsCubit>()
          .state
          .audioPathsWaitingSentences;
      if (audioPaths.isEmpty) break;

      final String audioPath = audioPaths[i]['audioPath'] as String;
      context.read<HomeCubit>().playTts(
        audioPath,
        removeFile: false,
        soundEffectsEnabled: false,
        updateStatus: false,
        onComplete: () {},
      );
      i++;
      if (i >= audioPaths.length) {
        i = 0;
      }
      await Future<void>.delayed(const Duration(seconds: 3));
    }
  }
}
