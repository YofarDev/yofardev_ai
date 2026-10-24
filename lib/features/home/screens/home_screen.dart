import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/models/demo_script.dart';
import '../../../core/res/app_colors.dart';
import '../../../core/utils/logger.dart';
import '../../avatar/avatar.dart';
import '../../chat/chat.dart';
import '../../demo/demo.dart';
import '../widgets/home_content_stack.dart';
import '../../settings/settings.dart';

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
    AppLogger.debug(
      'Triple tap detected - count: $_tapCount',
      tag: 'HomeScreen',
    );
    final DateTime now = DateTime.now();
    if (_lastTapTime != null &&
        now.difference(_lastTapTime!).inMilliseconds < 500) {
      _tapCount++;
    } else {
      _tapCount = 1;
    }
    _lastTapTime = now;

    AppLogger.debug('Tap count after increment: $_tapCount', tag: 'HomeScreen');

    if (_tapCount >= 3) {
      AppLogger.info(
        'Triple tap threshold reached, starting demo',
        tag: 'HomeScreen',
      );
      _tapCount = 0;
      _startDemoMode();
    }
  }

  Future<void> _startDemoMode() async {
    final String chatId = context.read<ChatCubit>().state.currentChat.id;
    await context.read<DemoCubit>().startDemoMode(
      chatId: chatId,
      script: DemoScripts.beachDemo,
    );
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
      context.read<SettingsCubit>().state.currentLanguage,
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
    return BlocListener<DemoCubit, DemoState>(
      listener: (BuildContext context, DemoState state) {
        if (state.isActive) {
          AppLogger.info(
            'Demo activated - showing snackbar',
            tag: 'HomeScreen',
          );
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Demo mode activated'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: BlocBuilder<ChatCubit, ChatState>(
          builder: (BuildContext context, ChatState chatsState) {
            return HomeContentStack(
              chatsState: chatsState,
              onTripleTap: _handleTripleTap,
            );
          },
        ),
      ),
    );
  }
}
