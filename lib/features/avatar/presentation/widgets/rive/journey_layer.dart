import 'dart:async';

import 'package:flutter/foundation.dart'
    show ValueListenable, visibleForTesting;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:rive/rive.dart';

import '../../../../../core/design/rive/rive_vm_binding.dart';
import '../../../../../core/design/tokens/scene_lights.dart';
import '../../../../../core/models/avatar_scene.dart';
import '../../../../../core/models/performance/light_rig.dart';
import '../../../../../core/utils/logger.dart';
import '../../../domain/models/journey.dart';
import '../../rive/avatar_face_writer.dart';
import '../../rive/avatar_rive_contract.dart';
import '../../rive/journey_choreography.dart';
import '../../rive/journey_passage.dart';
import 'avatar_passage_box.dart';
import '../stage_camera.dart';

/// The avatar and a scene journey's threshold (contract v15, the storybook;
/// M7 rulings 5–9 with the v15 staging; v17: the avatar goes in): [avatar]
/// at a fixed index (never remounted), drawn through its [AvatarPassage]
/// while a journey runs ([JourneyPassage]: into the portal's core, the
/// path's tunnel, the rocket's hatch, folded into the book's gutter), and the
/// `Journey` artboard drawn with the avatar's fit (contain, bottom-centre):
/// under the avatar for the path, portal and rocket (the avatar walks in
/// front of them and into them), over it for the book (its page block hides
/// the folded avatar right of the spine).
///
/// The threshold file loads when a [journey] starts and is disposed when it
/// ends. A ticker turns the journey's beat and the time spent in it into the
/// `JourneyVM` numbers ([JourneyChoreography]) and idles once the beat's
/// moves are done. The light colours follow the scene the avatar is in at
/// [daylight]; the vignette's own light (`vignetteKey` / `vignetteAmbient`)
/// follows the scene NOT on screen, in its rig, for every threshold (v16: the
/// portal's core, the path's far end, the rocket's porthole); the book also
/// writes its vignette number (`dest<Scene>`).
///
/// [jacket] (v11 `JourneyVM.jacket`, book only) comes from the cubit's
/// state, and is written as soon as the widget updates, not on the next
/// tick: it flips in the same frame as the avatar's `jacket`.
class JourneyLayer extends StatefulWidget {
  const JourneyLayer({
    super.key,
    required this.avatar,
    required this.journey,
    this.daylight,
    this.jacket = 0,
    this.vmSink,
  });

  final Widget avatar;
  final JourneyState? journey;
  final ValueListenable<double>? daylight;

  /// The jacket on the book's ribbon, 0..1 (`AvatarState.journeyJacket`).
  final double jacket;

  /// A fake binding the numbers are written through instead of the Rive
  /// view model (tests: no `journey.riv` needed).
  @visibleForTesting
  final AvatarVmSink? vmSink;

  /// The ribbon's jacket written for [journey]: [jacket] on the book, 0 on
  /// the other thresholds (they have no ribbon).
  @visibleForTesting
  static double journeyJacketOf(JourneyState journey, double jacket) =>
      journey.hasJacket ? jacket.clamp(0.0, 1.0) : 0;

  @override
  State<JourneyLayer> createState() => _JourneyLayerState();
}

class _JourneyLayerState extends State<JourneyLayer>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_onTick);
  final ValueNotifier<PaintedPassage> _passage = ValueNotifier<PaintedPassage>(
    PaintedPassage.none,
  );
  Duration _beatStart = Duration.zero;
  Duration _now = Duration.zero;
  bool _restartBeat = true;
  int? _serial;
  bool _reduceMotion = false;
  File? _file;
  RiveWidgetController? _controller;
  RiveVmBinding? _binding;
  AvatarVmSink? _bindingSink;
  bool _loading = false;
  final Map<String, double> _written = <String, double>{};
  LightRig? _writtenLight;
  LightRig? _writtenVignetteLight;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
  }

  @override
  void didUpdateWidget(JourneyLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.journey != oldWidget.journey) {
      _sync();
    }
    if (widget.jacket != oldWidget.jacket) {
      // The handoff: this frame, with the avatar's own jacket.
      _write();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _passage.dispose();
    _unload();
    super.dispose();
  }

  void _sync() {
    final JourneyState? journey = widget.journey;
    // A reduced journey (a cross-fade cut) has no threshold to load.
    if (journey == null || journey.reduced) {
      _ticker.stop();
      _serial = null;
      _passage.value = PaintedPassage.none;
      if (_file != null) {
        // The next frame no longer draws the overlay.
        _unload();
      }
      return;
    }
    if (journey.serial != _serial) {
      _serial = journey.serial;
      _restartBeat = true;
    }
    _apply(
      JourneyChoreography.at(journey, Duration.zero, reduceMotion: true),
      journey,
    );
    if (_file == null && !_loading) {
      unawaited(_load());
    }
    if (!_ticker.isActive) {
      _ticker.start();
      _now = Duration.zero;
    }
  }

  /// The avatar's passage, its tint resolved: the portal's glow in the far
  /// scene's key light (the vignette's rig), the path's silhouette in the
  /// scene's ambient, darkened.
  void _apply(JourneyFrame frame, JourneyState journey) {
    final AvatarPassage passage = frame.passage;
    final double daylight = widget.daylight?.value ?? 0;
    final int? tint = switch (passage.tint) {
      PassageTint.none => null,
      PassageTint.glow => SceneLights.at(
        _otherScene(journey),
        daylight,
      ).keyColor,
      PassageTint.silhouette => _darken(
        SceneLights.at(journey.sceneNow, daylight).ambientColor,
        0.55,
      ),
    };
    _passage.value = PaintedPassage(passage, tint);
  }

  /// The scene NOT on screen: the destination before the cut, the origin
  /// from it.
  static AvatarScene _otherScene(JourneyState journey) =>
      journey.phase.index >= JourneyPhase.cut.index ? journey.from : journey.to;

  static int _darken(int argb, double k) {
    int channel(int shift) => (((argb >> shift) & 0xFF) * k).round();
    return (argb & 0xFF000000) |
        (channel(16) << 16) |
        (channel(8) << 8) |
        channel(0);
  }

  Future<void> _load() async {
    _loading = true;
    try {
      final File? file = await File.asset(
        AvatarRiveContract.journeyAssetPath,
        riveFactory: Factory.rive,
      );
      if (file == null) {
        AppLogger.warning(
          'JourneyLayer: journey.riv could not be decoded',
          tag: 'JourneyLayer',
        );
        return;
      }
      if (!mounted || widget.journey == null) {
        file.dispose();
        return;
      }
      final RiveWidgetController controller = RiveWidgetController(
        file,
        artboardSelector: ArtboardSelector.byName(
          AvatarRiveContract.journeyArtboard,
        ),
        stateMachineSelector: StateMachineSelector.byName(
          AvatarRiveContract.journeyStateMachine,
        ),
      );
      final RiveVmBinding binding = RiveVmBinding(controller);
      setState(() {
        _file = file;
        _controller = controller;
        _binding = binding;
        _bindingSink = _BindingSink(binding);
        _written.clear();
        _writtenLight = null;
        _writtenVignetteLight = null;
      });
      _write(force: true);
    } on Exception catch (e) {
      AppLogger.error(
        'JourneyLayer failed to load journey.riv',
        tag: 'JourneyLayer',
        error: e,
      );
    } finally {
      _loading = false;
    }
  }

  /// Drops the file; no rebuild here: callers are `dispose` and `_sync`
  /// (from `initState` / `didUpdateWidget`, whose build follows).
  void _unload() {
    final RiveWidgetController? controller = _controller;
    final File? file = _file;
    final RiveVmBinding? binding = _binding;
    _binding = null;
    _bindingSink = null;
    _controller = null;
    _file = null;
    _written.clear();
    _writtenLight = null;
    _writtenVignetteLight = null;
    binding?.dispose();
    controller?.dispose();
    file?.dispose();
  }

  void _onTick(Duration elapsed) {
    _now = elapsed;
    if (_restartBeat) {
      _beatStart = elapsed;
      _restartBeat = false;
    }
    _write();
    final JourneyState? journey = widget.journey;
    if (journey == null) {
      _ticker.stop();
      return;
    }
    // Idle once the beat's moves are done (the walks are the avatar's).
    if (_binding != null &&
        elapsed - _beatStart > JourneyChoreography.settleOf(journey)) {
      _ticker.stop();
      _restartBeat = true;
      _now = Duration.zero;
    }
  }

  void _write({bool force = false}) {
    final JourneyState? journey = widget.journey;
    final JourneyFrame frame = JourneyChoreography.at(
      journey,
      _now - _beatStart,
      reduceMotion: _reduceMotion,
    );
    if (journey == null) {
      return;
    }
    _apply(frame, journey);
    final AvatarVmSink? sink = widget.vmSink ?? _bindingSink;
    if (sink == null) {
      return;
    }
    void number(String name, double value) {
      final double? last = _written[name];
      if (!force && last != null && (last - value).abs() <= 0.001) {
        return;
      }
      _written[name] = value;
      sink.setNumber(name, value);
    }

    for (final JourneyFamily family in JourneyFamily.values) {
      number(_familyProp(family), family == frame.family ? frame.show : 0);
    }
    number(AvatarRiveContract.journeyPropOpen, frame.open);
    number(AvatarRiveContract.journeyPropUnfold, frame.unfold);
    for (final AvatarScene scene in AvatarScene.values) {
      number(
        AvatarRiveContract.journeyDestProp(scene),
        frame.destination == scene ? frame.show : 0,
      );
    }
    number(AvatarRiveContract.journeyPropLift, frame.lift);
    number(
      AvatarRiveContract.journeyPropJacket,
      JourneyLayer.journeyJacketOf(journey, widget.jacket),
    );
    final LightRig rig = SceneLights.at(
      journey.sceneNow,
      widget.daylight?.value ?? 0,
    );
    if (force || rig != _writtenLight) {
      _writtenLight = rig;
      sink.setColor(AvatarRiveContract.journeyPropLightKey, rig.keyColor);
      sink.setColor(
        AvatarRiveContract.journeyPropLightAmbient,
        rig.ambientColor,
      );
    }
    // The vignette's light is the OTHER scene's rig (v15): the destination
    // before the cut, the origin from it. v16: every threshold looks onto it
    // (the portal's core, the path's far end, the rocket's porthole), so it
    // is written for every family; only the book has a vignette number.
    final AvatarScene other = _otherScene(journey);
    final LightRig vignette = SceneLights.at(
      other,
      widget.daylight?.value ?? 0,
    );
    if (force || vignette != _writtenVignetteLight) {
      _writtenVignetteLight = vignette;
      sink.setColor(
        AvatarRiveContract.journeyPropVignetteKey,
        vignette.keyColor,
      );
      sink.setColor(
        AvatarRiveContract.journeyPropVignetteAmbient,
        vignette.ambientColor,
      );
    }
  }

  static String _familyProp(JourneyFamily family) => switch (family) {
    JourneyFamily.book => AvatarRiveContract.journeyPropBook,
    JourneyFamily.path => AvatarRiveContract.journeyPropPath,
    JourneyFamily.portal => AvatarRiveContract.journeyPropPortal,
    JourneyFamily.rocket => AvatarRiveContract.journeyPropRocket,
  };

  @override
  Widget build(BuildContext context) {
    final RiveWidgetController? controller = _controller;
    final JourneyState? journey = widget.journey;
    final Widget? threshold = controller != null && journey != null
        ? IgnorePointer(
            child: RiveWidget(
              controller: controller,
              fit: Fit.contain,
              alignment: Alignment.bottomCenter,
              renderResolution: RenderResolution.layout(
                scale: StageRenderScale.of(context),
              ),
            ),
          )
        : null;
    final bool over = journey?.family == JourneyFamily.book;
    // Fixed slots: the avatar stays at index 1 whichever side the threshold
    // is drawn on.
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        if (threshold != null && !over) threshold else const SizedBox.shrink(),
        AvatarPassageBox(passage: _passage, child: widget.avatar),
        if (threshold != null && over) threshold else const SizedBox.shrink(),
      ],
    );
  }
}

/// [AvatarVmSink] over the journey's Rive view-model binding.
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
