import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/models/performance/performance.dart';
import '../../../../core/models/talking_phase.dart';

/// A rules-based camera: turns the avatar's situation into [CameraShot]
/// commands (moonshot M7 ruling 3). No AI, no Flutter widgets, no Rive.
///
/// Rules, highest priority first, evaluated on every input:
/// 1. reduce motion: `medium`, emitted once as a cut, then nothing more;
/// 2. a journey running: `wide`, eased 600 ms, held until it ends;
/// 3. a scene event: `wide`, eased 600 ms, held 2.5 s;
/// 4. a prop out: `propInsert`, eased 700 ms;
/// 5. speaking: the framing changes only in [onSentence], as a cut (see
///    there), and every sentence pushes in slowly (creep);
/// 6. composing, or the phase waiting / generating: `medium`, eased 1.2 s;
/// 7. otherwise, 2.5 s later: `wide`, eased 1.5 s.
///
/// Cuts only come from [onSentence] (and the one reduce-motion lock); every
/// other change eases. On the low quality tier ([setTier], M11 ruling 13)
/// there is no creep: a sentence cuts with none and a held sentence adds
/// none. A command equal to the current one is never emitted.
class CameraDirector {
  /// [now] is the injected clock (kept for symmetry with the other avatar
  /// services); the hold and idle delays run on timers, so tests drive them
  /// with `fakeAsync`.
  CameraDirector({required this.now});

  final DateTime Function() now;

  /// Eased pull-back to `wide` (journey, scene event).
  static const Duration pullBack = Duration(milliseconds: 600);

  /// Eased push to `propInsert`.
  static const Duration propPush = Duration(milliseconds: 700);

  /// Eased push to `medium` (composing, thinking).
  static const Duration thinkPush = Duration(milliseconds: 1200);

  /// Eased pull-back to `wide` when nothing is going on.
  static const Duration idlePullBack = Duration(milliseconds: 1500);

  /// How long a scene event holds the camera wide.
  static const Duration sceneHold = Duration(milliseconds: 2500);

  /// How long nothing must happen before the idle pull-back.
  static const Duration idleDelay = Duration(milliseconds: 2500);

  /// Extra zoom each sentence pushes in.
  static const double creepPerSentence = 0.04;

  /// The most creep allowed since the last cut.
  static const double maxCreep = 0.10;

  /// The time one sentence's creep takes.
  static const Duration creepDuration = Duration(seconds: 4);

  /// A cut that would change the zoom by less than this fraction holds.
  static const double minCutChange = 0.2;

  /// Intensity from which a sentence earns a close-up.
  static const double closeUpIntensity = 0.6;

  /// The nominal zoom of each shot, for the 20 % comparison.
  static double nominalZoom(Shot shot) {
    switch (shot) {
      case Shot.wide:
        return 1.0;
      case Shot.medium:
        return 1.5;
      case Shot.closeUp:
        return 2.2;
      case Shot.propInsert:
        return 2.0;
    }
  }

  final ValueNotifier<CameraShot> _shot = ValueNotifier<CameraShot>(
    CameraShot.initial,
  );

  bool _reduceMotion = false;
  QualityTier _tier = QualityTier.ultra;
  bool _journey = false;
  bool _sceneHold = false;
  AvatarProp _prop = AvatarProp.none;
  TalkingPhase _phase = TalkingPhase.idle;
  bool _composing = false;
  bool _speaking = false;

  int _sentences = 0;
  double _creep = 0;
  bool _framedBySentence = false;

  Timer? _sceneTimer;
  Timer? _idleTimer;
  bool _disposed = false;

  /// The current camera command.
  ValueListenable<CameraShot> get shot => _shot;

  void setReduceMotion(bool value) {
    _reduceMotion = value;
    _evaluate();
  }

  /// The quality tier in force: low drops the slow push-in.
  void setTier(QualityTier value) {
    _tier = value;
  }

  void setJourney(bool value) {
    _journey = value;
    _evaluate();
  }

  /// A scene cue (flare, meteor, ...): pull back and hold 2.5 s.
  void onSceneEvent() {
    _sceneHold = true;
    _sceneTimer?.cancel();
    _sceneTimer = Timer(sceneHold, () {
      _sceneTimer = null;
      _sceneHold = false;
      _evaluate();
    });
    _evaluate();
  }

  void setProp(AvatarProp value) {
    _prop = value;
    _evaluate();
  }

  void setPhase(TalkingPhase value) {
    _phase = value;
    _evaluate();
  }

  void setComposing(bool value) {
    _composing = value;
    _evaluate();
  }

  /// The avatar starts or stops speaking a reply. Starting a reply resets the
  /// sentence count; stopping changes nothing at once.
  void setSpeaking(bool value) {
    if (value && !_speaking) {
      _sentences = 0;
    }
    _speaking = value;
    _evaluate();
  }

  /// A sentence of the reply starts, with the director's emotion [intensity]
  /// (0..1). The one place the camera cuts.
  ///
  /// The first sentence of a reply frames `medium`; a question, an intensity
  /// of at least 0.6 or every third sentence frames `closeUp`; any other
  /// `medium`. A cut that would change the zoom by under 20 % holds instead
  /// and only adds creep. Higher rules (reduce motion, journey, scene event,
  /// prop) still win: the sentence is counted but frames nothing.
  void onSentence(String text, {required double intensity}) {
    if (_disposed) {
      return;
    }
    _sentences++;
    if (_reduceMotion || _journey || _sceneHold || _prop != AvatarProp.none) {
      return;
    }
    _idleTimer?.cancel();
    _idleTimer = null;

    final bool question = text.trimRight().endsWith('?');
    final bool closeUp =
        _sentences > 1 &&
        (question || intensity >= closeUpIntensity || _sentences % 3 == 0);
    final Shot target = closeUp ? Shot.closeUp : Shot.medium;

    final CameraShot current = _shot.value;
    final double from = nominalZoom(current.shot);
    final double change = (nominalZoom(target) - from).abs() / from;
    // A shot that no sentence framed (a prop insert left behind, ...) is
    // replaced by a cut whenever the kind differs.
    final bool hold =
        change < minCutChange && (_framedBySentence || current.shot == target);

    final bool creeps = _tier.allowsCameraCreep;
    if (hold) {
      if (!creeps) {
        return;
      }
      final double creep = (_creep + creepPerSentence).clamp(0.0, maxCreep);
      if (creep <= current.creep) {
        _creep = creep;
        return;
      }
      _creep = creep;
      _emit(
        CameraShot(
          shot: current.shot,
          move: CameraMove.ease,
          creep: creep,
          creepDuration: creepDuration,
          serial: current.serial + 1,
        ),
      );
      return;
    }

    _creep = creeps ? creepPerSentence : 0;
    _framedBySentence = true;
    _emit(
      CameraShot(
        shot: target,
        move: CameraMove.cut,
        creep: _creep,
        creepDuration: creeps ? creepDuration : Duration.zero,
        serial: current.serial + 1,
      ),
    );
  }

  void _evaluate() {
    if (_disposed) {
      return;
    }
    if (_reduceMotion) {
      _cancelIdle();
      if (_shot.value.shot != Shot.medium) {
        _framedBySentence = false;
        _creep = 0;
        _emit(_next(Shot.medium, CameraMove.cut, Duration.zero));
      }
      return;
    }
    if (_journey || _sceneHold) {
      _ease(Shot.wide, pullBack);
    } else if (_prop != AvatarProp.none) {
      _ease(Shot.propInsert, propPush);
    } else if (_speaking) {
      _cancelIdle();
    } else if (_composing ||
        _phase == TalkingPhase.waiting ||
        _phase == TalkingPhase.generating) {
      _ease(Shot.medium, thinkPush);
    } else if (_idleTimer == null && _shot.value.shot != Shot.wide) {
      _idleTimer = Timer(idleDelay, () {
        _idleTimer = null;
        if (_isIdle) {
          _ease(Shot.wide, idlePullBack);
        }
      });
    }
  }

  bool get _isIdle =>
      !_reduceMotion &&
      !_journey &&
      !_sceneHold &&
      _prop == AvatarProp.none &&
      !_speaking &&
      !_composing &&
      _phase != TalkingPhase.waiting &&
      _phase != TalkingPhase.generating;

  void _ease(Shot target, Duration duration) {
    _cancelIdle();
    if (_shot.value.shot == target) {
      return;
    }
    _creep = 0;
    _framedBySentence = false;
    _emit(_next(target, CameraMove.ease, duration));
  }

  CameraShot _next(Shot target, CameraMove move, Duration duration) =>
      CameraShot(
        shot: target,
        move: move,
        duration: duration,
        serial: _shot.value.serial + 1,
      );

  void _cancelIdle() {
    _idleTimer?.cancel();
    _idleTimer = null;
  }

  void _emit(CameraShot value) {
    _shot.value = value;
  }

  /// Cancels the timers and closes [shot].
  void dispose() {
    _disposed = true;
    _sceneTimer?.cancel();
    _sceneTimer = null;
    _cancelIdle();
    _shot.dispose();
  }
}
