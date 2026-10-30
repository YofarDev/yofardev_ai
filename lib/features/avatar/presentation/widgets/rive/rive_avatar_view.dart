import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:rive/rive.dart';

import '../../../../../core/design/tokens/scene_lights.dart';
import '../../../../../core/models/avatar_mood.dart';
import '../../../../../core/models/performance/performance.dart';
import '../../../../../core/utils/logger.dart';
import '../../../../talking/talking.dart';
import '../../../../../core/design/rive/rive_vm_binding.dart';
import '../../../domain/models/face_frame.dart';
import '../../../domain/models/head_pose.dart';
import '../../../domain/services/face_performer.dart';
import '../../../domain/services/head_motion_solver.dart';
import '../../rive/avatar_face_writer.dart';
import '../../rive/avatar_light_writer.dart';
import '../../rive/avatar_rive_contract.dart';
import '../../bloc/avatar_state.dart';
import '../stage_camera.dart';

/// Rive rendering of the avatar, driven entirely by [AvatarState] and
/// [TalkingState].
///
/// State → Rive: every look property (mood, hat, top, glasses, costume,
/// presence) is bound continuously; the talking feature feeds `mouth`
/// (MouthState) and `phase` (TalkingPhase). One-shot cues (gesture, and
/// presence changes handled as a settable enum) fire from seq diffs, so
/// repeating the same gesture still replays.
///
/// Head turn: a [Ticker] steps a [HeadMotionSolver] toward
/// [AvatarState.headTarget] each frame and writes `yaw`, `pitch`,
/// `hairLagYaw`, `hairLagPitch`, `eyeLeadYaw` and `eyeLeadPitch` when one changes by more than
/// 0.001. The ticker idles once the head has settled and drift is off (reduce
/// motion); `MediaQuery.disableAnimationsOf` drives the solver's reduce-motion
/// mode.
///
/// Face (contract v6): a [FacePerformer], stepped by the same ticker, writes
/// the 14 `au*` numbers, their 14 per-side `au<Name>L` / `au<Name>R`
/// offsets, `lipTuck`, `tongueUp`, `roll`, `breath`, `autoBlink` and the
/// `blink` trigger, and adds its nod to `pitch`; `mouth` stays 0. Without a
/// performer (lab, tests) the view writes the current mood's AU preset and
/// side offsets and keeps driving `mouth` from [TalkingState]. A non-null
/// [faceOverride] (the UI lab) is written instead of either, with `mouth` 0.
///
/// Light and prop (contract v7): the scene's static `LightRig`
/// (`SceneLights.of(avatarState.scene)`) is written to `AvatarVM` through an
/// [AvatarLightWriter] on load and when the scene changes, never per frame;
/// `prop` follows [AvatarState.prop]; `lean` rides in the face frame. The
/// avatar relights as soon as the scene state changes, slightly before the
/// new scene file finishes loading (accepted).
///
/// Rive → state: `avatar_tapped` events are forwarded to [onAvatarTapped].
///
/// Rive types never leave `lib/features/avatar/presentation/`.
class RiveAvatarView extends StatefulWidget {
  const RiveAvatarView({
    super.key,
    required this.avatarState,
    required this.talkingState,
    this.headSolver,
    this.facePerformer,
    this.faceOverride,
    this.onAvatarTapped,
    this.onPresenceDone,
    this.onGestureDone,
  });

  final AvatarState avatarState;
  final TalkingState talkingState;

  /// Solver stepping the head turn; a default one is created when omitted
  /// (tests inject their own).
  final HeadMotionSolver? headSolver;

  /// Drives the face and speech; null writes static mood presets instead.
  final FacePerformer? facePerformer;

  /// A face written instead of the performer's frame (or the static mood
  /// face) while non-null: the UI lab's hand-set pose. Its `blinkSerial`
  /// counts from 0 when the override starts; every change of it fires
  /// `blink`. Back to null, the live face resumes without a blink.
  final FaceFrame? faceOverride;
  final ValueChanged<String>? onAvatarTapped;

  /// Called with the presence value when the avatar finishes walking
  /// (`presence_done`).
  final ValueChanged<String>? onPresenceDone;

  /// Called when the upper-body gesture finishes (`gesture_done`).
  final VoidCallback? onGestureDone;

  /// The settled face of [mood] (its AU preset and side offsets), written
  /// when there is no performer.
  @visibleForTesting
  static FaceFrame staticFace(AvatarMood mood) {
    final ({ActionUnitSides left, ActionUnitSides right}) sides = sidesForMood(
      mood,
    );
    return FaceFrame(
      au: actionUnitsForMood(mood),
      left: sides.left,
      right: sides.right,
    );
  }

  @override
  State<RiveAvatarView> createState() => _RiveAvatarViewState();
}

class _RiveAvatarViewState extends State<RiveAvatarView>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  /// Smallest change worth writing to the view model.
  static const double _writeEpsilon = 0.001;

  late final HeadMotionSolver _solver = widget.headSolver ?? HeadMotionSolver();
  late final Ticker _ticker = createTicker(_onTick);
  Duration _lastElapsed = Duration.zero;
  double? _writtenYaw;
  double? _writtenPitch;
  double? _writtenHairYaw;
  double? _writtenHairPitch;
  double? _writtenEyeLead;
  double? _writtenEyeLeadPitch;
  FaceFrame _face = FaceFrame.rest;
  AvatarFaceWriter? _faceWriter;
  AvatarLightWriter? _lightWriter;
  File? _file;
  RiveWidgetController? _controller;
  RiveVmBinding? _binding;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _solver.setTarget(
      widget.avatarState.headTarget.yaw,
      widget.avatarState.headTarget.pitch,
      reading: widget.avatarState.headTarget.reading,
    );
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _solver.reduceMotion = MediaQuery.disableAnimationsOf(context);
    widget.facePerformer?.reduceMotion = _solver.reduceMotion;
    _ensureTicking();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Pause Rive (and the head ticker that feeds it) while the app is in the
    // background.
    final bool resumed = state == AppLifecycleState.resumed;
    _ticker.muted = !resumed;
    final RiveWidgetController? controller = _controller;
    if (controller != null) {
      controller.active = resumed;
    }
  }

  @override
  void didUpdateWidget(RiveAvatarView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.avatarState.headTarget != oldWidget.avatarState.headTarget) {
      _solver.setTarget(
        widget.avatarState.headTarget.yaw,
        widget.avatarState.headTarget.pitch,
        reading: widget.avatarState.headTarget.reading,
      );
      _ensureTicking();
    }
    if (widget.facePerformer != null) {
      // speech or a mood change may have woken the performer
      _ensureTicking();
    }
    final FaceFrame? override = widget.faceOverride;
    if ((override == null) != (oldWidget.faceOverride == null)) {
      // Override and live face count blinks apart: switching never blinks,
      // except an override that starts with blinks already asked for.
      _faceWriter?.adoptBlinkSerial(
        override == null ? _liveFace().blinkSerial : 0,
      );
    }
    final RiveVmBinding? binding = _binding;
    if (binding == null) {
      return;
    }
    if (widget.avatarState.scene != oldWidget.avatarState.scene) {
      _lightWriter?.write(SceneLights.of(widget.avatarState.scene));
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
    _ticker.dispose();
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
      // A fresh binding has none of the head numbers yet.
      _writtenYaw = _writtenPitch = _writtenHairYaw = null;
      _writtenHairPitch = _writtenEyeLead = _writtenEyeLeadPitch = null;
      _faceWriter = AvatarFaceWriter(_BindingSink(binding));
      _lightWriter = AvatarLightWriter(_BindingSink(binding))
        ..write(SceneLights.of(widget.avatarState.scene));
      _writeFace(widget.faceOverride ?? _liveFace(), force: true);
      _writeHeadPose(_solver.pose);
      _ensureTicking();
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

  /// Starts the frame ticker unless it runs already. Nothing ticks before
  /// the view model is bound: there is nothing to write to yet.
  void _ensureTicking() {
    if (_binding != null && !_ticker.isActive) {
      _lastElapsed = Duration.zero;
      _ticker.start();
    }
  }

  void _onTick(Duration elapsed) {
    final Duration dt = elapsed - _lastElapsed;
    _lastElapsed = elapsed;
    final FacePerformer? performer = widget.facePerformer;
    if (performer != null) {
      // The performer keeps running under an override, so Reset resumes it
      // where it would be.
      final FaceFrame live = performer.step(dt);
      _writeFace(widget.faceOverride ?? live);
    }
    // The face's nods and roll drive the hair's follow-through, its gaze
    // cues the eyes: the solver steps after the face.
    _solver.followFace(_face);
    final HeadPose pose = _solver.step(dt);
    _writeHeadPose(pose);
    if (!_solver.driftEnabled &&
        _solver.isSettled &&
        (performer == null || performer.isSettled)) {
      // At rest: make sure the final values landed, then stop ticking. The
      // settled performer's frame is exactly on target; writing it in full
      // keeps a last sub-epsilon step from being skipped.
      _writeHeadPose(pose, force: true);
      if (performer != null) {
        _writeFace(widget.faceOverride ?? performer.frame, force: true);
      }
      _ticker.stop();
    }
  }

  /// Writes the six rig numbers that moved by more than [_writeEpsilon]
  /// since they were last written ([force]: all of them).
  void _writeHeadPose(HeadPose pose, {bool force = false}) {
    final RiveVmBinding? binding = _binding;
    if (binding == null) {
      return;
    }
    double? write(String name, double value, double? last) {
      if (!force && last != null && (value - last).abs() <= _writeEpsilon) {
        return last;
      }
      binding.setNumber(name, value);
      return value;
    }

    _writtenYaw = write(AvatarRiveContract.propYaw, pose.yaw, _writtenYaw);
    _writtenPitch = write(
      AvatarRiveContract.propPitch,
      (pose.pitch + _face.nodPitch).clamp(
        AvatarRiveContract.pitchMin,
        AvatarRiveContract.pitchMax,
      ),
      _writtenPitch,
    );
    _writtenHairYaw = write(
      AvatarRiveContract.propHairLagYaw,
      pose.hairLagYaw,
      _writtenHairYaw,
    );
    _writtenHairPitch = write(
      AvatarRiveContract.propHairLagPitch,
      pose.hairLagPitch,
      _writtenHairPitch,
    );
    _writtenEyeLead = write(
      AvatarRiveContract.propEyeLeadYaw,
      pose.eyeLeadYaw,
      _writtenEyeLead,
    );
    _writtenEyeLeadPitch = write(
      AvatarRiveContract.propEyeLeadPitch,
      pose.eyeLeadPitch,
      _writtenEyeLeadPitch,
    );
  }

  /// The face of the current mood, for a view without a performer.
  FaceFrame _staticFace() => RiveAvatarView.staticFace(widget.avatarState.mood);

  /// The face without an override: the performer's current frame, or the
  /// static mood face.
  FaceFrame _liveFace() => widget.facePerformer?.frame ?? _staticFace();

  /// Writes [face] through the face writer (it skips unchanged numbers and
  /// fires `blink` once per new blink serial).
  void _writeFace(FaceFrame face, {bool force = false}) {
    _face = face;
    _faceWriter?.write(face, force: force);
  }

  void _teardown() {
    final RiveWidgetController? controller = _controller;
    _binding?.dispose();
    controller?.stateMachine.removeEventListener(_onRiveEvent);
    controller?.dispose();
    _file?.dispose();
    _controller = null;
    _binding = null;
    _faceWriter = null;
    _lightWriter = null;
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
    // With a performer (or an override) the mouth AUs carry speech; `mouth`
    // (the legacy jaw alias) must stay 0 so the two never add up.
    final FaceFrame? override = widget.faceOverride;
    binding.setNumber(
      AvatarRiveContract.propMouth,
      widget.facePerformer == null && override == null
          ? widget.talkingState.mouthState.index.toDouble()
          : 0,
    );
    if (override != null) {
      _writeFace(override);
    } else if (widget.facePerformer == null) {
      _writeFace(_staticFace());
    }
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
      AvatarRiveContract.propProp,
      AvatarRiveContract.propValues,
      avatarState.prop.name,
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
        // The camera's texture scale: changes once per shot, not per frame.
        renderResolution: RenderResolution.layout(
          scale: StageRenderScale.of(context),
        ),
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

/// [AvatarFaceWriter]'s sink over the Rive view-model binding.
class _BindingSink implements AvatarVmSink {
  const _BindingSink(this._binding);

  final RiveVmBinding _binding;

  @override
  void setNumber(String name, double value) => _binding.setNumber(name, value);

  @override
  void setBool(String name, bool value) => _binding.setBool(name, value);

  @override
  void setColor(String name, int argb) => _binding.setColor(name, Color(argb));

  @override
  void fireTrigger(String name) => _binding.fireTrigger(name);
}
