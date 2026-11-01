import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nested/nested.dart';

import '../../../core/design/design.dart';
import '../../../core/models/demo_script.dart';
import '../../../core/services/motion/parallax_source.dart';
import '../../../core/services/quality/quality_tier_service.dart';
import '../../../core/services/world/world_state_service.dart';
import '../../../core/services/app_lifecycle_service.dart';
import '../../../core/services/presence/composer_activity_service.dart';
import '../../../core/services/speech/speech_input_service.dart';
import '../../../core/utils/logger.dart';
import '../../avatar/avatar.dart';
import '../../chat/chat.dart';
import '../../demo/demo.dart';
import '../../settings/settings.dart';
import '../../talking/talking.dart';
import '../widgets/demo_activated_listener.dart';
import '../widgets/home_content_stack.dart';
import '../../../core/services/audio/ambient_bed_service.dart';
import '../../../core/services/audio/foley_service.dart';
import '../../sound/sound.dart';

/// Home: the Stage ([HomeContentStack]) full screen. The keyboard does not
/// resize it: the Stage lifts its own bottom chrome above the keyboard.
///
/// [speech], [composerActivity], [parallax], [world], [facePerformer],
/// [camera], [npc], [foley], [beds], [lifecycle] and [quality] come from the
/// route (Home never reads the service locator).
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.speech,
    this.composerActivity,
    this.parallax,
    this.world,
    this.facePerformer,
    this.camera,
    this.npc,
    this.foley,
    this.beds,
    this.lifecycle,
    this.quality,
    this.voiceEngine,
  });

  final SpeechInputService speech;

  /// Hears the composer's typing (null: nobody listens).
  final ComposerActivityService? composerActivity;

  /// The scene's parallax offset and the pointer's sink (null: centred).
  final ParallaxSource? parallax;

  /// The world the scene shows, its rain (null: dry).
  final WorldStateService? world;

  /// Drives the avatar's face and speech (null: static mood faces).
  final FacePerformer? facePerformer;

  /// Frames the stage (null: no camera, the whole stage always).
  final CameraDirector? camera;

  /// The scene NPC's behaviour (null: it rests).
  final NpcDirector? npc;

  /// Foley and haptics from the avatar's events and the taps (null: silent).
  final FoleyService? foley;

  /// The Kokoro voice's install, for the first-run notice (null: none).
  final TtsEngineStatusService? voiceEngine;

  /// The ambient beds, following the scene (null: silent).
  final AmbientBedService? beds;

  /// Carries a scene pick from the More menu to the chat (null: the menu has
  /// no scene picker).
  final AppLifecycleService? lifecycle;

  /// The quality tier in force, told when the stage shows and is active
  /// (null: ultra, no benchmark from here).
  final QualityTierService? quality;

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

  /// Coming back to the app is presence: the idle ladder starts over (the
  /// avatar would otherwise greet the user with the tablet out).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      widget.composerActivity?.touch();
    }
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
      composerActivity: widget.composerActivity,
      parallax: widget.parallax,
      world: widget.world,
      facePerformer: widget.facePerformer,
      camera: widget.camera,
      npc: widget.npc,
      foley: widget.foley,
      beds: widget.beds,
      lifecycle: widget.lifecycle,
      quality: widget.quality,
      voiceEngine: widget.voiceEngine,
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
    if (widget.speech != oldWidget.speech ||
        widget.composerActivity != oldWidget.composerActivity ||
        widget.parallax != oldWidget.parallax ||
        widget.world != oldWidget.world ||
        widget.facePerformer != oldWidget.facePerformer ||
        widget.camera != oldWidget.camera ||
        widget.npc != oldWidget.npc ||
        widget.foley != oldWidget.foley ||
        widget.beds != oldWidget.beds ||
        widget.lifecycle != oldWidget.lifecycle ||
        widget.quality != oldWidget.quality ||
        widget.voiceEngine != oldWidget.voiceEngine) {
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
