import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/res/app_colors.dart';
import '../../avatar/presentation/bloc/avatar_cubit.dart';
import '../../avatar/presentation/bloc/avatar_state.dart';
import '../../chat/presentation/bloc/chats_cubit.dart';
import '../../chat/presentation/bloc/chats_state.dart';
import '../../chat/presentation/bloc/chat_tts_cubit.dart';
import '../../demo/presentation/bloc/demo_cubit.dart';
import '../../demo/domain/models/demo_script.dart';
import '../../talking/presentation/bloc/talking_cubit.dart';
import '../../talking/presentation/bloc/talking_state.dart';
import '../widgets/home_bloc_listeners.dart';
import '../widgets/home_content_stack.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _tapCount = 0;
  DateTime? _lastTapTime;
  double? _lastAppliedAvatarWidth;

  double _getTargetAvatarWidth(double width) => width > 800 ? 800 : width;

  void _updateAvatarScaleForCurrentWidth() {
    final double width = MediaQuery.of(context).size.width;
    if (width <= 0) return;
    final double targetWidth = _getTargetAvatarWidth(width);
    if (_lastAppliedAvatarWidth == targetWidth) return;
    _lastAppliedAvatarWidth = targetWidth;

    final AvatarCubit avatarCubit = context.read<AvatarCubit>();
    if (avatarCubit.state.status == AvatarStatus.initial) {
      avatarCubit.setValuesBasedOnScreenWidth(screenWidth: targetWidth);
    } else {
      avatarCubit.onScreenSizeChanged(targetWidth);
    }
  }

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
      context.read<DemoCubit>().startDemo(DemoScripts.beachDemo);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateAvatarScaleForCurrentWidth();
    });
    // Prepare waiting sentences loaded from cache
    context.read<ChatTtsCubit>().prepareWaitingSentences(
      context.read<ChatsCubit>().state.currentLanguage,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _updateAvatarScaleForCurrentWidth();
    });
  }

  @override
  void didChangeMetrics() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _updateAvatarScaleForCurrentWidth();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HomeBlocListeners(
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: BlocBuilder<ChatsCubit, ChatsState>(
          builder: (BuildContext context, ChatsState chatsState) {
            return BlocBuilder<TalkingCubit, TalkingState>(
              builder: (BuildContext context, TalkingState talkingState) {
                return HomeContentStack(
                  chatsState: chatsState,
                  talkingState: talkingState,
                  onTripleTap: _handleTripleTap,
                );
              },
            );
          },
        ),
      ),
    );
  }
}
