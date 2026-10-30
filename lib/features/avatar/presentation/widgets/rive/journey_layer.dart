import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:rive/rive.dart';

import '../../../../../core/design/rive/rive_vm_binding.dart';
import '../../../../../core/design/tokens/scene_lights.dart';
import '../../../../../core/models/performance/light_rig.dart';
import '../../../../../core/utils/logger.dart';
import '../../../domain/models/journey.dart';
import '../../rive/avatar_rive_contract.dart';
import '../../rive/journey_choreography.dart';
import '../stage_camera.dart';

/// The avatar with a scene journey's threshold over it (contract v10, M7
/// rulings 5–9): [avatar] at a fixed index (never remounted), clipped right
/// of the threshold while a journey runs, and the `Journey` artboard drawn
/// above it with the avatar's fit (contain, bottom-centre).
///
/// The threshold file loads when a [journey] starts and is disposed when it
/// ends. A ticker turns the journey's beat and the time spent in it into the
/// `JourneyVM` numbers ([JourneyChoreography]) and idles once the beat's
/// moves are done. The light colours follow the scene the avatar is in at
/// [daylight].
class JourneyLayer extends StatefulWidget {
  const JourneyLayer({
    super.key,
    required this.avatar,
    required this.journey,
    this.daylight,
  });

  final Widget avatar;
  final JourneyState? journey;
  final ValueListenable<double>? daylight;

  @override
  State<JourneyLayer> createState() => _JourneyLayerState();
}

class _JourneyLayerState extends State<JourneyLayer>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_onTick);
  final ValueNotifier<bool> _clip = ValueNotifier<bool>(false);
  Duration _beatStart = Duration.zero;
  Duration _now = Duration.zero;
  bool _restartBeat = true;
  int? _serial;
  bool _reduceMotion = false;
  File? _file;
  RiveWidgetController? _controller;
  RiveVmBinding? _binding;
  bool _loading = false;
  final Map<String, double> _written = <String, double>{};
  LightRig? _writtenLight;

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
  }

  @override
  void dispose() {
    _ticker.dispose();
    _clip.dispose();
    _unload();
    super.dispose();
  }

  void _sync() {
    final JourneyState? journey = widget.journey;
    if (journey == null) {
      _ticker.stop();
      _serial = null;
      _clip.value = false;
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
      JourneyChoreography.at(journey, Duration.zero, reduceMotion: true).clip,
    );
    if (_file == null && !_loading) {
      unawaited(_load());
    }
    if (!_ticker.isActive) {
      _ticker.start();
      _now = Duration.zero;
    }
  }

  void _apply(bool clip) => _clip.value = clip;

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
      setState(() {
        _file = file;
        _controller = controller;
        _binding = RiveVmBinding(controller);
        _written.clear();
        _writtenLight = null;
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
    _controller = null;
    _file = null;
    _written.clear();
    _writtenLight = null;
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
    _apply(frame.clip);
    final RiveVmBinding? binding = _binding;
    if (binding == null || journey == null) {
      return;
    }
    void number(String name, double value) {
      final double? last = _written[name];
      if (!force && last != null && (last - value).abs() <= 0.001) {
        return;
      }
      _written[name] = value;
      binding.setNumber(name, value);
    }

    for (final JourneyFamily family in JourneyFamily.values) {
      number(_familyProp(family), family == frame.family ? frame.show : 0);
    }
    number(AvatarRiveContract.journeyPropOpen, frame.open);
    number(AvatarRiveContract.journeyPropLift, frame.lift);
    final LightRig rig = SceneLights.at(
      journey.sceneNow,
      widget.daylight?.value ?? 0,
    );
    if (force || rig != _writtenLight) {
      _writtenLight = rig;
      binding.setColor(
        AvatarRiveContract.journeyPropLightKey,
        Color(rig.keyColor),
      );
      binding.setColor(
        AvatarRiveContract.journeyPropLightAmbient,
        Color(rig.ambientColor),
      );
    }
  }

  static String _familyProp(JourneyFamily family) => switch (family) {
    JourneyFamily.door => AvatarRiveContract.journeyPropDoor,
    JourneyFamily.path => AvatarRiveContract.journeyPropPath,
    JourneyFamily.portal => AvatarRiveContract.journeyPropPortal,
    JourneyFamily.rocket => AvatarRiveContract.journeyPropRocket,
  };

  @override
  Widget build(BuildContext context) {
    final RiveWidgetController? controller = _controller;
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        ClipRect(clipper: ThresholdClipper(_clip), child: widget.avatar),
        if (controller != null && widget.journey != null)
          IgnorePointer(
            child: RiveWidget(
              controller: controller,
              fit: Fit.contain,
              alignment: Alignment.bottomCenter,
              renderResolution: RenderResolution.layout(
                scale: StageRenderScale.of(context),
              ),
            ),
          ),
      ],
    );
  }
}

/// Clips the avatar right of the journey threshold (artboard x
/// [AvatarRiveContract.journeyThresholdX]) while [active] is true, mapped with
/// the avatar's contain / bottom-centre fit; otherwise clips nothing.
class ThresholdClipper extends CustomClipper<Rect> {
  ThresholdClipper(this.active) : super(reclip: active);

  final ValueListenable<bool> active;

  /// The threshold's x in a [size] box (the avatar's fit).
  static double thresholdX(Size size) {
    final double scale = math.min(
      size.width / AvatarRiveContract.journeyArtboardWidth,
      size.height / AvatarRiveContract.journeyArtboardHeight,
    );
    final double left =
        (size.width - AvatarRiveContract.journeyArtboardWidth * scale) / 2;
    return left + AvatarRiveContract.journeyThresholdX * scale;
  }

  @override
  Rect getClip(Size size) {
    final Rect everything = Rect.fromLTRB(
      -size.width,
      -size.height,
      size.width * 2,
      size.height * 2,
    );
    if (!active.value) {
      return everything;
    }
    return Rect.fromLTRB(
      everything.left,
      everything.top,
      thresholdX(size),
      everything.bottom,
    );
  }

  @override
  bool shouldReclip(ThresholdClipper oldClipper) => oldClipper.active != active;
}
