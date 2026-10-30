import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../../../core/models/avatar_scene.dart';
import '../../../../core/models/performance/performance.dart';
import '../../../../core/models/talking_phase.dart';
import '../models/npc_intent.dart';

/// The NPC each scene has (contract v11): which one, and the prop that pokes
/// it.
enum NpcKind {
  cat('cat'),
  owl('owl'),
  crab('crab'),
  alien('ufo');

  const NpcKind(this.propId);

  /// The scene prop whose tap pokes it.
  final String propId;

  static NpcKind of(AvatarScene scene) => switch (scene) {
    AvatarScene.livingRoom => NpcKind.cat,
    AvatarScene.campfire => NpcKind.owl,
    AvatarScene.beach => NpcKind.crab,
    AvatarScene.deepSpace => NpcKind.alien,
  };
}

/// One move of `npcX`, eased in Dart (a jump under reduce motion: the NPC is
/// away meanwhile and appears at [to]).
class _Move {
  const _Move(this.from, this.to, this.start, this.length, {this.jump = false});

  final double from;
  final double to;
  final DateTime start;
  final Duration length;
  final bool jump;

  double progress(DateTime now) {
    final int total = length.inMicroseconds;
    if (total <= 0) {
      return 1;
    }
    return (now.difference(start).inMicroseconds / total).clamp(0.0, 1.0);
  }

  double xAt(DateTime now) {
    if (jump) {
      return to;
    }
    final double t = progress(now);
    // ease in-out (cubic), so a walk starts and stops softly
    final double eased = t < 0.5
        ? 4 * t * t * t
        : 1 - math.pow(-2 * t + 2, 3) / 2;
    return from + (to - from) * eased;
  }

  bool done(DateTime now) => progress(now) >= 1;
}

/// The behaviour trees of the scene NPCs (moonshot M8 ruling 9), one per
/// scene, pure: an injected clock and [math.Random], inputs through setters
/// (fed by `NpcFeed` and the Home stage), output [intent].
///
/// - **cat** (livingRoom, priority order): poked → react [reactLength], then
///   notice [pokeNoticeLength]; its name in a message ([catNames]) → notice
///   [mentionNoticeLength], then react; the avatar sad (valence ≤
///   [sadValence]) → walks to the rug (`npcX` → 1 over [catWalkLength]) and
///   sits by it (idle, look 0); woken (the avatar speaks with arousal ≥
///   [wakeArousal]) → idle; after [calmToSleep] of calm it walks to the warm
///   spot (lamp on: the rug, 1; lamp off: the cabinet, 0) and sleeps there
///   (rest); otherwise it rests where it is. While `catWalksBy` plays
///   ([catWalksByLength]) it never moves (the walking cat is the other cat).
/// - **owl** (campfire): poked → react; rain ≥ [owlRainHunch] → rest
///   (hunched); a question in the reply → idle swivel for [questionLength];
///   the avatar speaking → notice; otherwise rest (night quiet).
/// - **crab** (beach): poked → react, then scuttles away (`npcX` → 1 over
///   [crabScuttleLength]) and back after [crabAwayLength]; rain ≥
///   [crabRainHide] → rest (hidden); the avatar happy (valence ≥
///   [happyValence]) → idle (scuttle dance); otherwise rest.
/// - **alien** (deepSpace): poked → react (wave); "alien", "ufo", "ovni" in
///   a message ([alienNames]) → notice for [mentionNoticeLength]; rest while
///   the avatar thinks (waiting / generating); otherwise idle, drifting
///   (`move`, [driftLength]) to a random `npcX` every [driftMinGap] to
///   [driftMaxGap].
///
/// **Low tier** ([QualityTier.low]): nothing runs, the NPC holds
/// [NpcIntent.rest]. **Reduce motion**: no `move` (a position changes only
/// while the NPC is away, for [jumpLength]), no `react` (notice instead),
/// no drift.
///
/// "Toward the avatar" ([lookToAvatar]) depends on which side of the
/// centre-standing avatar the NPC is: every v10 spot is right of it (look
/// −[lookAmount]); the cat on the rug (`npcX` ≥ [catCrossesAt]) and the ufo
/// drifted left (`npcX` ≥ [alienCrossesAt]) look right (+). While it moves,
/// `npcLook` is its facing ([moveLook]): the cat and the ufo go left as
/// `npcX` grows, the crab right.
class NpcDirector {
  NpcDirector({
    required DateTime Function() now,
    math.Random? random,
    AvatarScene scene = AvatarScene.defaultScene,
  }) : _now = now,
       _random = random ?? math.Random(8),
       _scene = scene {
    _update();
  }

  // — timings and thresholds (ruling 9) —
  // walk lengths from the scene art (M8 execution ruling 37): the cat
  // walks its whole path at about 0.13 npcX/s with no foot slide, the crab
  // scuttles at about 0.45/s
  static const Duration reactLength = Duration(milliseconds: 1600);
  static const Duration pokeNoticeLength = Duration(seconds: 4);
  static const Duration mentionNoticeLength = Duration(milliseconds: 1500);
  static const Duration catWalkLength = Duration(milliseconds: 7500);
  static const Duration calmToSleep = Duration(seconds: 20);
  static const Duration catWalksByLength = Duration(milliseconds: 10700);
  static const Duration questionLength = Duration(seconds: 3);
  static const Duration crabScuttleLength = Duration(milliseconds: 2200);
  static const Duration crabAwayLength = Duration(seconds: 8);
  static const Duration driftLength = Duration(seconds: 6);
  static const Duration driftMinGap = Duration(seconds: 8);
  static const Duration driftMaxGap = Duration(seconds: 14);
  static const Duration jumpLength = Duration(milliseconds: 400);

  /// How often a move is re-eased (the scene writes `npcX` on change).
  static const Duration frame = Duration(milliseconds: 33);

  static const double sadValence = -0.4;
  static const double happyValence = 0.4;
  static const double wakeArousal = 0.6;
  static const double owlRainHunch = 0.5;
  static const double crabRainHide = 0.2;
  static const double lookAmount = 0.7;
  static const double catCrossesAt = 0.9;
  static const double alienCrossesAt = 0.55;

  /// The facing written while moving (its sign is what the art reads).
  static const double moveLook = 0.5;

  /// Where [kind] at path position [x] looks to face the avatar.
  static double lookToAvatar(NpcKind kind, double x) {
    final bool leftOfAvatar = switch (kind) {
      NpcKind.cat => x >= catCrossesAt,
      NpcKind.alien => x >= alienCrossesAt,
      NpcKind.owl || NpcKind.crab => false,
    };
    return leftOfAvatar ? lookAmount : -lookAmount;
  }

  /// The facing of [kind] moving from [from] to [to].
  static double facing(NpcKind kind, double from, double to) {
    final bool growing = to > from;
    final bool goesLeft = kind == NpcKind.crab ? !growing : growing;
    return goesLeft ? -moveLook : moveLook;
  }

  static const Set<String> catNames = <String>{
    'cat',
    'cats',
    'kitty',
    'chat',
    'chats',
    'minou',
    'chaton',
    'chatons',
  };
  static const Set<String> alienNames = <String>{
    'alien',
    'aliens',
    'ufo',
    'ufos',
    'ovni',
    'ovnis',
  };

  final DateTime Function() _now;
  final math.Random _random;
  final ValueNotifier<NpcIntent> _intent = ValueNotifier<NpcIntent>(
    NpcIntent.rest,
  );

  // — inputs —
  AvatarScene _scene;
  QualityTier _tier = QualityTier.high;
  bool _reduceMotion = false;
  EmotionVector _emotion = const EmotionVector();
  bool _speaking = false;
  bool _thinking = false;
  double _rain = 0;
  bool _lampOn = true;

  // — the current scene's NPC —
  double _x = 0;
  _Move? _move;
  bool _moveTouched = false;
  DateTime? _pokedAt;
  DateTime? _mentionAt;
  DateTime? _questionAt;
  DateTime? _catWalksByUntil;
  bool _awake = false;
  DateTime? _activeAt;
  DateTime? _nextDriftAt;
  double? _driftTarget;

  Timer? _timer;
  bool _disposed = false;

  /// What the scene's NPC does now.
  ValueListenable<NpcIntent> get intent => _intent;

  /// The NPC of the scene on screen.
  NpcKind get kind => NpcKind.of(_scene);

  /// The scene on screen: a new scene's NPC starts over at rest on its spot.
  void setScene(AvatarScene scene) {
    if (scene == _scene) {
      return;
    }
    _scene = scene;
    _resetNpc();
    _update();
  }

  void setTier(QualityTier tier) {
    if (tier == _tier) {
      return;
    }
    _tier = tier;
    if (tier == QualityTier.low) {
      _resetNpc();
    }
    _update();
  }

  void setReduceMotion(bool value) {
    if (value == _reduceMotion) {
      return;
    }
    _reduceMotion = value;
    _update();
  }

  /// The director's emotion (valence and arousal).
  void setEmotion(EmotionVector emotion) {
    if (emotion == _emotion) {
      return;
    }
    _emotion = emotion;
    _update();
  }

  /// The avatar is speaking a reply.
  void setSpeaking(bool value) {
    if (value == _speaking) {
      return;
    }
    _speaking = value;
    _update();
  }

  /// The talking phase: waiting and generating are the avatar thinking.
  void setPhase(TalkingPhase phase) {
    final bool thinking =
        phase == TalkingPhase.waiting || phase == TalkingPhase.generating;
    if (thinking == _thinking) {
      return;
    }
    _thinking = thinking;
    _update();
  }

  /// The world's steady rain, 0..1.
  void setRain(double value) {
    final double rain = value.isNaN ? 0 : value.clamp(0.0, 1.0);
    if (rain == _rain) {
      return;
    }
    _rain = rain;
    _update();
  }

  /// A message the user sent.
  void onUserText(String text) => _onText(text, reply: false);

  /// A reply sentence the avatar starts speaking.
  void onReplySentence(String text) => _onText(text, reply: true);

  /// A scene prop was tapped: its NPC's poke.
  void poke(String propId) {
    if (propId != kind.propId) {
      return;
    }
    _pokedAt = _now();
    _update();
  }

  /// A scene event played (the lamp, the walking cat).
  void onSceneEvent(SceneEvent event) {
    switch (event) {
      case SceneEvent.lightsOff:
        _lampOn = false;
      case SceneEvent.lightsOn:
        _lampOn = true;
      case SceneEvent.catWalksBy:
        if (_scene == AvatarScene.livingRoom) {
          _catWalksByUntil = _now().add(catWalksByLength);
        }
      default:
        return;
    }
    _update();
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    _intent.dispose();
  }

  // — internals —

  void _onText(String text, {required bool reply}) {
    final DateTime now = _now();
    bool changed = false;
    final Set<String> names = switch (kind) {
      NpcKind.cat => catNames,
      NpcKind.alien => alienNames,
      NpcKind.owl || NpcKind.crab => const <String>{},
    };
    if (names.isNotEmpty && _words(text).any(names.contains)) {
      _mentionAt = now;
      changed = true;
    }
    if (reply && kind == NpcKind.owl && text.trim().endsWith('?')) {
      _questionAt = now;
      changed = true;
    }
    if (changed) {
      _update();
    }
  }

  /// The lower-case words of [text] (letters, accents and apostrophes).
  static Iterable<String> _words(String text) => text
      .toLowerCase()
      .split(RegExp(r"[^a-zà-ÿœæ'’]+"))
      .where((String w) => w.isNotEmpty);

  void _resetNpc() {
    _x = 0;
    _move = null;
    _pokedAt = null;
    _mentionAt = null;
    _questionAt = null;
    _catWalksByUntil = null;
    _awake = false;
    _activeAt = null;
    _nextDriftAt = null;
    _driftTarget = null;
    _lampOn = true;
  }

  void _update() {
    if (_disposed) {
      return;
    }
    final DateTime now = _now();
    final NpcIntent next = _evaluate(now);
    if (next != _intent.value) {
      _intent.value = next;
    }
    _schedule(now);
  }

  NpcIntent _evaluate(DateTime now) {
    if (_tier == QualityTier.low) {
      _timer?.cancel();
      return NpcIntent.rest;
    }
    final _Move? move = _move;
    if (move != null && move.done(now)) {
      _x = move.to;
      _move = null;
    }
    _moveTouched = false;
    final NpcIntent intent = switch (kind) {
      NpcKind.cat => _cat(now),
      NpcKind.owl => _owl(now),
      NpcKind.crab => _crab(now),
      NpcKind.alien => _alien(now),
    };
    if (!_moveTouched && _move != null) {
      // Another branch took over: the walk stops where it is.
      _x = _move!.xAt(now);
      _move = null;
    }
    return intent;
  }

  double _xNow(DateTime now) => _move?.xAt(now) ?? _x;

  bool _within(DateTime? since, DateTime now, Duration length) =>
      since != null && now.difference(since) < length;

  /// A reaction: `react`, or `notice` under reduce motion (no loop).
  NpcIntent _react(DateTime now, {double look = 0}) => NpcIntent(
    npc: _reduceMotion ? NpcState.notice : NpcState.react,
    npcX: _xNow(now),
    npcLook: _reduceMotion ? _toAvatar(now) : look,
  );

  double _toAvatar(DateTime now) => lookToAvatar(kind, _xNow(now));

  NpcIntent _at(NpcState state, DateTime now, {double look = 0}) =>
      NpcIntent(npc: state, npcX: _xNow(now), npcLook: look);

  /// Goes to [target] over [length] (a jump while away under reduce
  /// motion), then shows [arrived] there.
  NpcIntent _goTo(
    double target,
    Duration length,
    DateTime now, {
    required NpcState arrived,
  }) {
    final _Move? move = _move;
    if (move == null && (_x - target).abs() < 1e-6) {
      return NpcIntent(npc: arrived, npcX: target);
    }
    _moveTouched = true;
    if (move == null || move.to != target) {
      final double from = _xNow(now);
      _move = _reduceMotion
          ? _Move(from, target, now, jumpLength, jump: true)
          : _Move(from, target, now, length);
    }
    final _Move active = _move!;
    if (active.jump) {
      return NpcIntent(npc: NpcState.away, npcX: target);
    }
    return NpcIntent(
      npc: NpcState.move,
      npcX: active.xAt(now),
      npcLook: facing(kind, active.from, active.to),
    );
  }

  void _wake(DateTime now) {
    _awake = true;
    _activeAt = now;
  }

  NpcIntent _cat(DateTime now) {
    if (_pokedAt != null) {
      if (_within(_pokedAt, now, reactLength)) {
        _wake(now);
        return _react(now);
      }
      if (_within(_pokedAt, now, reactLength + pokeNoticeLength)) {
        _wake(now);
        return _at(NpcState.notice, now, look: _toAvatar(now));
      }
      _pokedAt = null;
    }
    if (_mentionAt != null) {
      if (_within(_mentionAt, now, mentionNoticeLength)) {
        _wake(now);
        return _at(NpcState.notice, now, look: _toAvatar(now));
      }
      if (_within(_mentionAt, now, mentionNoticeLength + reactLength)) {
        _wake(now);
        return _react(now, look: _toAvatar(now));
      }
      _mentionAt = null;
    }
    final DateTime? walkEnd = _catWalksByUntil;
    final bool walkingCat = walkEnd != null && now.isBefore(walkEnd);
    if (!walkingCat) {
      _catWalksByUntil = null;
    }
    if (_emotion.valence <= sadValence) {
      _wake(now);
      if (walkingCat) {
        return _at(NpcState.idle, now);
      }
      return _goTo(1, catWalkLength, now, arrived: NpcState.idle);
    }
    if (_speaking && _emotion.arousal >= wakeArousal) {
      _wake(now);
    }
    if (!_awake) {
      return _at(NpcState.rest, now);
    }
    if (_within(_activeAt, now, calmToSleep) || walkingCat) {
      return _at(NpcState.idle, now);
    }
    final double warmSpot = _lampOn ? 1 : 0;
    final NpcIntent intent = _goTo(
      warmSpot,
      catWalkLength,
      now,
      arrived: NpcState.rest,
    );
    if (intent.npc == NpcState.rest) {
      _awake = false;
    }
    return intent;
  }

  NpcIntent _owl(DateTime now) {
    if (_within(_pokedAt, now, reactLength)) {
      return _react(now, look: _toAvatar(now));
    }
    _pokedAt = null;
    if (_rain >= owlRainHunch) {
      return _at(NpcState.rest, now);
    }
    if (_within(_questionAt, now, questionLength)) {
      return _at(NpcState.idle, now);
    }
    _questionAt = null;
    if (_speaking) {
      return _at(NpcState.notice, now, look: _toAvatar(now));
    }
    return _at(NpcState.rest, now);
  }

  NpcIntent _crab(DateTime now) {
    if (_pokedAt != null) {
      if (_within(_pokedAt, now, reactLength)) {
        return _react(now);
      }
      if (_within(
        _pokedAt,
        now,
        reactLength + crabScuttleLength + crabAwayLength,
      )) {
        return _goTo(1, crabScuttleLength, now, arrived: NpcState.idle);
      }
      _pokedAt = null;
    }
    if (_move != null || _x > 1e-6) {
      // back to its spot first, whatever else
      return _goTo(0, crabScuttleLength, now, arrived: NpcState.rest);
    }
    if (_rain >= crabRainHide) {
      return _at(NpcState.rest, now);
    }
    if (_emotion.valence >= happyValence) {
      return _at(NpcState.idle, now);
    }
    return _at(NpcState.rest, now);
  }

  NpcIntent _alien(DateTime now) {
    if (_within(_pokedAt, now, reactLength)) {
      return _react(now, look: _toAvatar(now));
    }
    _pokedAt = null;
    if (_within(_mentionAt, now, mentionNoticeLength)) {
      return _at(NpcState.notice, now, look: _toAvatar(now));
    }
    _mentionAt = null;
    if (_thinking) {
      return _at(NpcState.rest, now);
    }
    if (_reduceMotion) {
      return _at(NpcState.idle, now);
    }
    final double? target = _driftTarget;
    if (target != null && (_move != null && _move!.to == target)) {
      return _goTo(target, driftLength, now, arrived: NpcState.idle);
    }
    _driftTarget = null;
    final DateTime next = _nextDriftAt ??= now.add(_driftGap());
    if (!now.isBefore(next)) {
      final double to = _random.nextDouble();
      _driftTarget = to;
      _nextDriftAt = now.add(driftLength).add(_driftGap());
      return _goTo(to, driftLength, now, arrived: NpcState.idle);
    }
    return _at(NpcState.idle, now);
  }

  Duration _driftGap() {
    final int span = driftMaxGap.inMilliseconds - driftMinGap.inMilliseconds;
    return driftMinGap + Duration(milliseconds: _random.nextInt(span + 1));
  }

  /// Re-evaluates at the next moment the tree can change: every [frame]
  /// while a move runs, else the earliest pending deadline.
  void _schedule(DateTime now) {
    _timer?.cancel();
    _timer = null;
    if (_tier == QualityTier.low) {
      return;
    }
    final _Move? move = _move;
    if (move != null) {
      // every frame while it walks (only its end for a jump), and exactly
      // at the end, so it lands on time
      final Duration left =
          move.start.add(move.length).difference(now) +
          const Duration(milliseconds: 1);
      _timer = Timer(move.jump || left < frame ? left : frame, _update);
      return;
    }
    DateTime? earliest;
    void consider(DateTime? at) {
      if (at == null || !at.isAfter(now)) {
        return;
      }
      if (earliest == null || at.isBefore(earliest!)) {
        earliest = at;
      }
    }

    final DateTime? poked = _pokedAt;
    if (poked != null) {
      consider(poked.add(reactLength));
      consider(poked.add(reactLength + pokeNoticeLength));
      consider(poked.add(reactLength + crabScuttleLength + crabAwayLength));
    }
    final DateTime? mention = _mentionAt;
    if (mention != null) {
      consider(mention.add(mentionNoticeLength));
      consider(mention.add(mentionNoticeLength + reactLength));
    }
    consider(_questionAt?.add(questionLength));
    consider(_catWalksByUntil);
    if (_awake) {
      consider(_activeAt?.add(calmToSleep));
    }
    if (kind == NpcKind.alien) {
      consider(_nextDriftAt);
    }
    final DateTime? at = earliest;
    if (at != null) {
      _timer = Timer(
        at.difference(now) + const Duration(milliseconds: 1),
        _update,
      );
    }
  }
}
