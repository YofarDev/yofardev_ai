import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nested/nested.dart';

import '../../../core/design/design.dart';
import '../../../core/models/demo_script.dart';
import '../../../core/services/speech/speech_input_service.dart';
import '../../../core/utils/logger.dart';
import '../../avatar/avatar.dart';
import '../../chat/chat.dart';
import '../../demo/demo.dart';
import '../../settings/settings.dart';
import '../../talking/talking.dart';
import '../widgets/demo_activated_listener.dart';
import '../widgets/home_content_stack.dart';

/// Home: the Stage ([HomeContentStack]) full screen. The keyboard does not
/// resize it: the Stage lifts its own bottom chrome above the keyboard.
///
/// [speech] comes from the route (Home never reads the service locator).
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.speech});

  final SpeechInputService speech;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _tapCount = 0;
  DateTime? _lastTapTime;
  double? _lastAppliedAvatarWidth;

  double _getTargetAvatarWidth(double width) => width > 800 ? 800 : width;

  void _updateAvatarScaleForCurrentWidth() {
    final double width = MediaQuery.sizeOf(context).width;
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

  /// Debug builds: three taps on the stage within 500 ms each play the demo.
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

  /// A new chat loads its avatar and resets the talking state.
  void _onChatCreated(BuildContext context, ChatState state) {
    context.read<AvatarCubit>().loadAvatar(state.currentChat.id);
    context.read<TalkingCubit>().init();
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

  /// Built once (and again only for a new [HomeScreen.speech]): the same
  /// instance on every build, so a theme cross-fade or a keyboard frame that
  /// rebuilds Home stops here instead of rebuilding the Stage.
  late Widget _stage = _buildStage();

  Widget _buildStage() {
    final Widget stage = HomeContentStack(
      speech: widget.speech,
      onStartDemo: _startDemoMode,
    );
    if (!kDebugMode) {
      return stage;
    }
    return GestureDetector(
      onTap: _handleTripleTap,
      behavior: HitTestBehavior.translucent,
      child: stage,
    );
  }

  @override
  void didUpdateWidget(HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.speech != oldWidget.speech) {
      _stage = _buildStage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: <SingleChildWidget>[
        const DemoActivatedListener(),
        BlocListener<ChatCubit, ChatState>(
          listenWhen: (ChatState previous, ChatState current) =>
              !previous.chatCreated && current.chatCreated,
          listener: _onChatCreated,
        ),
      ],
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: context.tokens.background,
        body: _stage,
      ),
    );
  }
}
