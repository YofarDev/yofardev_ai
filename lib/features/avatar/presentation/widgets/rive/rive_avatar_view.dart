import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:rive/rive.dart';

import '../../../../../core/utils/logger.dart';
import '../../../../talking/talking.dart';
import '../../../../../core/design/rive/rive_vm_binding.dart';
import '../../rive/avatar_rive_contract.dart';
import '../../bloc/avatar_state.dart';

/// Rive rendering of the avatar, driven entirely by [AvatarState] and
/// [TalkingState].
///
/// State → Rive: every look property (mood, hat, top, glasses, costume,
/// presence) is bound continuously; the talking feature feeds `mouth`
/// (MouthState) and `phase` (TalkingPhase). One-shot cues (gesture, and
/// presence changes handled as a settable enum) fire from seq diffs, so
/// repeating the same gesture still replays.
///
/// Rive → state: `avatar_tapped` events are forwarded to [onAvatarTapped].
///
/// Rive types never leave `lib/features/avatar/presentation/`.
class RiveAvatarView extends StatefulWidget {
  const RiveAvatarView({
    super.key,
    required this.avatarState,
    required this.talkingState,
    this.onAvatarTapped,
    this.onPresenceDone,
    this.onGestureDone,
  });

  final AvatarState avatarState;
  final TalkingState talkingState;
  final ValueChanged<String>? onAvatarTapped;

  /// Called with the presence value when the avatar finishes walking
  /// (`presence_done`).
  final ValueChanged<String>? onPresenceDone;

  /// Called when the upper-body gesture finishes (`gesture_done`).
  final VoidCallback? onGestureDone;

  @override
  State<RiveAvatarView> createState() => _RiveAvatarViewState();
}

class _RiveAvatarViewState extends State<RiveAvatarView>
    with WidgetsBindingObserver {
  File? _file;
  RiveWidgetController? _controller;
  RiveVmBinding? _binding;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Pause Rive while the app is in the background.
    final RiveWidgetController? controller = _controller;
    if (controller != null) {
      controller.active = state == AppLifecycleState.resumed;
    }
  }

  @override
  void didUpdateWidget(RiveAvatarView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final RiveVmBinding? binding = _binding;
    if (binding == null) {
      return;
    }
    // One-shot cues are detected by seq so a repeated gesture still fires.
    if (widget.avatarState.gestureEvent.seq !=
        oldWidget.avatarState.gestureEvent.seq) {
      binding.setEnum(
        AvatarRiveContract.propGestureId,
        AvatarRiveContract.gestureIdValues,
        widget.avatarState.gestureEvent.gesture.name,
      );
      binding.fireTrigger(AvatarRiveContract.propGestureTrigger);
    }
    _applyContinuousState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _teardown();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final File? file = await File.asset(
        AvatarRiveContract.avatarAssetPath,
        riveFactory: Factory.rive,
      );
      if (file == null) {
        if (mounted) {
          setState(() => _error = 'avatar.riv could not be decoded');
        }
        return;
      }
      final RiveWidgetController controller = RiveWidgetController(
        file,
        artboardSelector: ArtboardSelector.byName(
          AvatarRiveContract.avatarArtboard,
        ),
        stateMachineSelector: StateMachineSelector.byName(
          AvatarRiveContract.avatarStateMachine,
        ),
      );
      final RiveVmBinding binding = RiveVmBinding(controller);
      controller.stateMachine.addEventListener(_onRiveEvent);
      if (!mounted) {
        binding.dispose();
        controller.dispose();
        file.dispose();
        return;
      }
      setState(() {
        _file = file;
        _controller = controller;
        _binding = binding;
      });
      _applyContinuousState();
    } on Exception catch (e) {
      AppLogger.error(
        'RiveAvatarView failed to load avatar.riv',
        tag: 'RiveAvatarView',
        error: e,
      );
      if (mounted) {
        setState(() => _error = e.toString());
      }
    }
  }

  void _teardown() {
    final RiveWidgetController? controller = _controller;
    _binding?.dispose();
    controller?.stateMachine.removeEventListener(_onRiveEvent);
    controller?.dispose();
    _file?.dispose();
    _controller = null;
    _binding = null;
    _file = null;
  }

  /// Pushes every continuously-bound property from the current widget data.
  void _applyContinuousState() {
    final RiveVmBinding? binding = _binding;
    if (binding == null) {
      return;
    }
    final AvatarState avatarState = widget.avatarState;
    binding.setEnum(
      AvatarRiveContract.propMood,
      AvatarRiveContract.moodValues,
      avatarState.mood.name,
    );
    binding.setEnum(
      AvatarRiveContract.propPhase,
      AvatarRiveContract.phaseValues,
      widget.talkingState.phase.name,
    );
    binding.setNumber(
      AvatarRiveContract.propMouth,
      widget.talkingState.mouthState.index.toDouble(),
    );
    binding.setEnum(
      AvatarRiveContract.propHat,
      AvatarRiveContract.hatValues,
      avatarState.avatar.hat.name,
    );
    binding.setEnum(
      AvatarRiveContract.propTop,
      AvatarRiveContract.topValues,
      avatarState.avatar.top.name,
    );
    binding.setEnum(
      AvatarRiveContract.propGlasses,
      AvatarRiveContract.glassesValues,
      avatarState.avatar.glasses.name,
    );
    binding.setEnum(
      AvatarRiveContract.propCostume,
      AvatarRiveContract.costumeValues,
      avatarState.avatar.costume.name,
    );
    binding.setEnum(
      AvatarRiveContract.propPresence,
      AvatarRiveContract.presenceValues,
      avatarState.presence.name,
    );
  }

  void _onRiveEvent(Event event) {
    if (event.name == AvatarRiveContract.eventAvatarTapped) {
      final String? zone = event
          .stringProperty(AvatarRiveContract.avatarEventZoneProperty)
          ?.value;
      if (zone != null) {
        widget.onAvatarTapped?.call(zone);
      }
      return;
    }
    if (event.name == AvatarRiveContract.eventGestureDone) {
      widget.onGestureDone?.call();
      return;
    }
    if (event.name == AvatarRiveContract.eventPresenceDone) {
      final String? presence = event
          .stringProperty(AvatarRiveContract.avatarEventPresenceProperty)
          ?.value;
      if (presence != null) {
        widget.onPresenceDone?.call(presence);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final RiveWidgetController? controller = _controller;
    if (controller != null) {
      // The artboard's rig root sits on its bottom edge: contain scales the
      // whole artboard to fit, and bottom-center anchors the feet to the
      // screen bottom on viewports taller than the 800x1000 artboard aspect
      // (default center alignment would float the character mid-screen).
      return RiveWidget(
        controller: controller,
        fit: Fit.contain,
        alignment: Alignment.bottomCenter,
      );
    }
    if (_error != null && !kReleaseMode) {
      return ColoredBox(
        color: Theme.of(context).colorScheme.errorContainer,
        child: Center(
          child: Text('avatar.riv: $_error', textAlign: TextAlign.center),
        ),
      );
    }
    return const SizedBox.expand();
  }
}
