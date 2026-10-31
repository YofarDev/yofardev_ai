import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../../../core/models/avatar_scene.dart';
import '../../../../core/models/performance/performance.dart';
import '../../../../core/models/talking_phase.dart';
import '../models/npc_intent.dart';
import 'gull_flock.dart';

/// The NPC each scene has (contract v11): which one, and the prop that pokes
/// it.
enum NpcKind {
  cat('cat'),
  owl('owl'),
  crab('crab'),
  alien('ufo'),
  fish('fish'),
  pigeon('pigeon'),
  dog('dog'),
  squirrel('squirrel'),
  ladybug('ladybug'),
  mouse('mouse');

  const NpcKind(this.propId);

  /// The scene prop whose tap pokes it.
  final String propId;

  static NpcKind of(AvatarScene scene) => switch (scene) {
    AvatarScene.livingRoom => NpcKind.cat,
    AvatarScene.campfire => NpcKind.owl,
    AvatarScene.beach => NpcKind.crab,
    AvatarScene.deepSpace => NpcKind.alien,
    AvatarScene.cafe => NpcKind.fish,
    AvatarScene.rooftop => NpcKind.pigeon,
    AvatarScene.mountainHut => NpcKind.dog,
    AvatarScene.forestCabin => NpcKind.squirrel,
    AvatarScene.trainCompartment => NpcKind.ladybug,
    AvatarScene.library => NpcKind.mouse,
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

/// The behaviour trees of the scene NPCs (moonshot M8 ruling 9, M9 ruling 11,
/// M11 ruling 7),
/// one per scene, pure: an injected clock and [math.Random], inputs through
/// setters (fed by `NpcFeed` and the Home stage), output [intent].
///
/// - **cat** (livingRoom, priority order): poked → react [reactLength], then
///   notice [pokeNoticeLength]; its name in a message ([catNames]) → notice
///   [mentionNoticeLength], then react; the avatar sad (valence ≤
///   [sadValence]) → walks to the rug (`npcX` → 1 over [catWalkLength]) and
///   sits by it (idle, look 0); woken (the avatar speaks with arousal ≥
///   [wakeArousal]) → idle; after [calmToSleep] of calm it walks to the warm
///   spot (lamp on: the rug, 1; lamp off: the cabinet, 0) and sleeps there
///   (rest); otherwise it rests where it is. While `catWalksBy` plays
///   ([catWalksByLength]) it never starts to move (the walking cat is the other
///   cat); one caught mid-walk goes `away` until the walking cat has passed
///   (its walk runs on unseen) and reappears at its target.
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
/// - **fish** (cafe): poked → react [fishReactLength], then notice
///   [fishNoticeLength]; the avatar speaking → notice; otherwise idle, with
///   a swim ([fishSwimLength]) to a random `npcX` every [fishSwimMinGap] to
///   [fishSwimMaxGap].
/// - **pigeon** (rooftop): poked, or `fireworks` → react
///   [pigeonReactLength], then walks away (`npcX` → 1 over
///   [pigeonWalkLength]) and back after [pigeonAwayLength]; rain ≥
///   [pigeonRainRest] → rest; otherwise idle, with a walk to a random `npcX`
///   every [pigeonWalkMinGap] to [pigeonWalkMaxGap].
/// - **dog** (mountainHut, like the cat): poked → react [reactLength], then
///   notice [pokeNoticeLength]; its name ([dogNames]) → notice
///   [mentionNoticeLength], then react; the avatar sad (valence ≤
///   [sadValence]) → trots to the avatar (`npcX` → 1 over [dogTrotLength])
///   and sits (idle); woken (speech with arousal ≥ [wakeArousal]) → idle;
///   after [calmToSleep] of calm it trots back to the rug (0) and rests;
///   otherwise it sleeps by the stove.
/// - **squirrel** (forestCabin): poked → react [squirrelReactLength], then
///   scampers to the maple's trunk (`npcX` → 1 at [squirrelRunRate]) and back
///   after [squirrelAwayLength]; a `gust` → react [squirrelReactLength]; rain
///   ≥ [squirrelRainShelter] → to the trunk (1) and rest, back to the rail
///   once it is dry; otherwise idle, with a dash to a random `npcX` every
///   [squirrelDashMinGap] to [squirrelDashMaxGap].
/// - **ladybug** (trainCompartment): poked → react [ladybugReactLength], then
///   idle; a `tunnel` → rest for [tunnelLength] (the event's length);
///   otherwise idle, with a walk to a random `npcX` every [ladybugWalkMinGap]
///   to [ladybugWalkMaxGap].
/// - **mouse** (library): asleep (rest) by the bottom shelf; poked → react
///   [mouseReactLength], then runs to its shelf (0) and rests; `lightning` →
///   react [mouseReactLength], then the same; its name ([mouseNames]) →
///   notice [mentionNoticeLength]; the avatar speaking with arousal ≥
///   [wakeArousal] → notice; each wakes it. Awake, it idles with a scurry to a
///   random `npcX` every [mouseScurryMinGap] to [mouseScurryMaxGap] (the only
///   use of its move cycle; M11 interpretation); after [calmToSleep] of calm
///   it scurries back to the shelf and sleeps.
///
/// - **gulls** (beach only, the second slot, [gullIntent]; see [GullFlock]):
///   away, they land after [GullFlock.calmToLand] of calm; a `seagulls` or
///   `bigWave` event, a poke of the [gullPropId] prop, the crab's react (its
///   poke), the avatar speaking with arousal ≥ [GullFlock.excitedArousal] or
///   rain ≥ [GullFlock.rainAway] → react, then fly off to away.
///
/// **Low tier** ([QualityTier.low]): nothing runs, the NPC holds
/// [NpcIntent.rest] and the gulls stay away. **Reduce motion**: no `move` (a position changes only
/// while the NPC is away, for [jumpLength]), no `react` (notice instead),
/// no drift.
///
/// "Toward the avatar" ([lookToAvatar]) depends on which side of the
/// centre-standing avatar the NPC is: every v10 spot is right of it (look
/// −[lookAmount]); the cat on the rug (`npcX` ≥ [catCrossesAt]) and the ufo
/// drifted left (`npcX` ≥ [alienCrossesAt]) look right (+). While it moves,
/// `npcLook` is its facing ([moveLook]): the cat, the dog and the ufo go left
/// as `npcX` grows, the crab and the pigeon right. The squirrel sits on the
/// rail right of the avatar and climbs the maple left of it
/// ([squirrelCrossesAt]); it runs left as `npcX` grows. The ladybug's sill is
/// left of the avatar (look +), the mouse's shelf and chair right of it (look
/// −); both go right as `npcX` grows. The fish faces right while
/// `npcLook` ≥ 0 and left while < 0 in every state, so it swims with a small
/// ±[fishMoveLook] and keeps its last facing sign when idle.
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

  // M9 ruling 11, rates measured from the built art (rive/tools/scene_npc.py):
  // the fish swims its ~28 px bowl at 0.5 npcX/s, the pigeon walks at
  // 0.354 npcX/s (whole path ~2.8 s) and the dog trots at 1.042 npcX/s (whole
  // path ~0.96 s), all without foot slide. Partial moves take distance / rate.
  static const Duration fishReactLength = Duration(milliseconds: 1200);
  static const Duration fishNoticeLength = Duration(seconds: 3);
  static const double fishSwimRate = 0.5;

  /// The shortest swim, whatever the distance.
  static const Duration fishSwimMinLength = Duration(seconds: 1);

  /// The whole bowl, 0 → 1.
  static final Duration fishSwimLength = travelTime(1, fishSwimRate);
  static const Duration fishSwimMinGap = Duration(seconds: 10);
  static const Duration fishSwimMaxGap = Duration(seconds: 16);
  static const Duration pigeonReactLength = Duration(milliseconds: 800);
  static const double pigeonWalkRate = 0.354;

  /// The whole path, 0 → 1 (~2.8 s).
  static final Duration pigeonWalkLength = travelTime(1, pigeonWalkRate);
  static const Duration pigeonAwayLength = Duration(seconds: 10);
  static const Duration pigeonWalkMinGap = Duration(seconds: 12);
  static const Duration pigeonWalkMaxGap = Duration(seconds: 20);
  static const double dogTrotRate = 1.042;

  /// The whole path, 0 → 1 (~0.87 s).
  static final Duration dogTrotLength = travelTime(1, dogTrotRate);

  // M11 ruling 7. The squirrel's and the ladybug's rates are measured from
  // the built art (`scene_forest_cabin.squirrel_run_speed()` 0.1767 npcX/s,
  // `scene_train.ladybug_walk_speed()` 0.1735 npcX/s: no foot slide); the
  // mouse's is an estimate until `scene_library` gives a stride (re-measure
  // as M9 did for the fish, pigeon and dog).
  static const Duration squirrelReactLength = Duration(milliseconds: 800);
  static const double squirrelRunRate = 0.177;

  /// The whole path, rail to branch (~5.6 s).
  static final Duration squirrelRunLength = travelTime(1, squirrelRunRate);
  static const Duration squirrelAwayLength = Duration(seconds: 8);
  static const Duration squirrelDashMinGap = Duration(seconds: 12);
  static const Duration squirrelDashMaxGap = Duration(seconds: 20);
  static const double squirrelRainShelter = 0.5;
  static const double squirrelCrossesAt = 0.5;
  static const Duration ladybugReactLength = Duration(milliseconds: 600);
  static const double ladybugWalkRate = 0.173;

  /// The whole sill, 0 → 1 (~5.8 s).
  static final Duration ladybugWalkLength = travelTime(1, ladybugWalkRate);
  static const Duration ladybugWalkMinGap = Duration(seconds: 10);
  static const Duration ladybugWalkMaxGap = Duration(seconds: 16);

  /// The train's `tunnel` event (180 frames at 60 fps).
  static const Duration tunnelLength = Duration(seconds: 3);
  static const Duration mouseReactLength = Duration(milliseconds: 600);
  static const double mouseScurryRate = 0.6;

  /// The whole path, shelf to chair (~1.7 s).
  static final Duration mouseScurryLength = travelTime(1, mouseScurryRate);
  static const Duration mouseScurryMinGap = Duration(seconds: 10);
  static const Duration mouseScurryMaxGap = Duration(seconds: 16);

  /// How often a move is re-eased (the scene writes `npcX` on change).
  static const Duration frame = Duration(milliseconds: 33);

  static const double sadValence = -0.4;
  static const double happyValence = 0.4;
  static const double wakeArousal = 0.6;
  static const double owlRainHunch = 0.5;
  static const double crabRainHide = 0.2;
  static const double pigeonRainRest = 0.5;
  static const double lookAmount = 0.7;
  static const double catCrossesAt = 0.9;
  static const double alienCrossesAt = 0.55;
  static const double dogCrossesAt = 0.9;

  /// The facing written while moving (its sign is what the art reads).
  static const double moveLook = 0.5;

  /// The fish's facing while swimming: only the sign counts (right while
  /// `npcLook` ≥ 0, left while < 0), so it stays small.
  static const double fishMoveLook = 0.01;

  /// How long covering [distance] of `npcX` takes at [rate] npcX/s.
  static Duration travelTime(double distance, double rate) => Duration(
    microseconds: (distance.abs() / rate * Duration.microsecondsPerSecond)
        .round(),
  );

  /// The beach prop whose tap pokes the gulls (the crab has its own).
  static const String gullPropId = 'seagull';

  /// Where [kind] at path position [x] looks to face the avatar.
  static double lookToAvatar(NpcKind kind, double x) {
    final bool leftOfAvatar = switch (kind) {
      NpcKind.cat => x >= catCrossesAt,
      NpcKind.alien => x >= alienCrossesAt,
      NpcKind.dog => x >= dogCrossesAt,
      NpcKind.squirrel => x >= squirrelCrossesAt,
      NpcKind.ladybug => true,
      NpcKind.owl ||
      NpcKind.crab ||
      NpcKind.fish ||
      NpcKind.pigeon ||
      NpcKind.mouse => false,
    };
    return leftOfAvatar ? lookAmount : -lookAmount;
  }

  /// The facing of [kind] moving from [from] to [to].
  static double facing(NpcKind kind, double from, double to) {
    final bool growing = to > from;
    if (kind == NpcKind.fish) {
      // faces right while npcLook >= 0 (the art), so a swim to a higher
      // npcX is +, to a lower one -
      return growing ? fishMoveLook : -fishMoveLook;
    }
    final bool goesRight =
        kind == NpcKind.crab ||
        kind == NpcKind.pigeon ||
        kind == NpcKind.ladybug ||
        kind == NpcKind.mouse;
    final bool goesLeft = goesRight ? !growing : growing;
    return goesLeft ? -moveLook : moveLook;
  }

  static const Set<String> catNames = <String>{
    'cat',
    'cats',
    'kitty',
    'minou',
    'chaton',
    'chatons',
  };

  /// French "chat" is also an English word ("let's chat", "new chat"): it
  /// names the cat only right after a French determiner
  /// ([catFrenchDeterminers]).
  static const Set<String> catFrenchNames = <String>{'chat', 'chats'};
  static const Set<String> catFrenchDeterminers = <String>{
    'le',
    'ton',
    'mon',
    'un',
    'ce',
    'les',
    'tes',
    'mes',
    'des',
  };
  static const Set<String> dogNames = <String>{
    'dog',
    'dogs',
    'doggy',
    'puppy',
    'puppies',
    'chien',
    'chiens',
    'toutou',
    'toutous',
    'chiot',
    'chiots',
  };
  static const Set<String> mouseNames = <String>{'mouse', 'mice', 'souris'};
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
  final ValueNotifier<NpcIntent> _gullIntent = ValueNotifier<NpcIntent>(
    NpcIntent.away,
  );
  final GullFlock _gulls = GullFlock();

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
  DateTime? _gustAt;
  DateTime? _tunnelAt;
  DateTime? _lightningAt;

  /// The cat NPC was mid-walk when `catWalksBy` started: it is `away` (its
  /// walk runs on unseen and it reappears at its target) until the walking
  /// cat has passed, so the two never show together.
  bool _hiddenByWalker = false;
  bool _awake = false;
  DateTime? _activeAt;
  DateTime? _nextDriftAt;
  double? _driftTarget;

  /// The pigeon (or the squirrel) walked away after a poke, or the squirrel
  /// sheltered from the rain, and is on its way back.
  bool _returningHome = false;

  /// The fish's last facing (see [_fish]); it starts facing right.
  bool _fishFacesLeft = false;

  Timer? _timer;
  bool _disposed = false;

  /// What the scene's NPC does now.
  ValueListenable<NpcIntent> get intent => _intent;

  /// What the beach's gulls do now (the second slot, `npc2*`): away on every
  /// other scene.
  ValueListenable<NpcIntent> get gullIntent => _gullIntent;

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
    if (_scene == AvatarScene.beach) {
      // the gulls' own prop, and the crab's react startles them too
      if (propId == gullPropId || propId == NpcKind.crab.propId) {
        _gulls.startle(_now());
        if (propId == gullPropId) {
          _update();
          return;
        }
      }
    }
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
      case SceneEvent.fireworks:
        // the bang startles the pigeon like a poke
        if (kind != NpcKind.pigeon) {
          return;
        }
        _pokedAt = _now();
      case SceneEvent.gust:
        if (kind != NpcKind.squirrel) {
          return;
        }
        _gustAt = _now();
      case SceneEvent.tunnel:
        if (kind != NpcKind.ladybug) {
          return;
        }
        _tunnelAt = _now();
      case SceneEvent.lightning:
        if (kind != NpcKind.mouse) {
          return;
        }
        _lightningAt = _now();
      case SceneEvent.seagulls || SceneEvent.bigWave:
        // a passing flock or a big wave sends the sitting gulls off
        if (_scene != AvatarScene.beach) {
          return;
        }
        _gulls.startle(_now());
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
    _gullIntent.dispose();
  }

  // — internals —

  void _onText(String text, {required bool reply}) {
    final DateTime now = _now();
    bool changed = false;
    final Set<String> names = switch (kind) {
      NpcKind.cat => catNames,
      NpcKind.alien => alienNames,
      NpcKind.dog => dogNames,
      NpcKind.mouse => mouseNames,
      NpcKind.owl ||
      NpcKind.crab ||
      NpcKind.fish ||
      NpcKind.pigeon ||
      NpcKind.squirrel ||
      NpcKind.ladybug => const <String>{},
    };
    if (names.isNotEmpty && _mentions(text, names)) {
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

  /// Whether [text] has a word of [names] (for the cat, also French "chat"
  /// after a determiner).
  bool _mentions(String text, Set<String> names) {
    final List<String> words = _words(text).toList();
    for (int i = 0; i < words.length; i++) {
      final String word = words[i];
      if (names.contains(word)) {
        return true;
      }
      if (kind == NpcKind.cat &&
          i > 0 &&
          catFrenchNames.contains(word) &&
          catFrenchDeterminers.contains(words[i - 1])) {
        return true;
      }
    }
    return false;
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
    _gustAt = null;
    _tunnelAt = null;
    _lightningAt = null;
    _hiddenByWalker = false;
    _awake = false;
    _activeAt = null;
    _nextDriftAt = null;
    _driftTarget = null;
    _returningHome = false;
    _fishFacesLeft = false;
    _lampOn = true;
    _gulls.reset();
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
    final NpcIntent gulls = _evaluateGulls(now);
    if (gulls != _gullIntent.value) {
      _gullIntent.value = gulls;
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
      NpcKind.fish => _fish(now),
      NpcKind.pigeon => _pigeon(now),
      NpcKind.dog => _dog(now),
      NpcKind.squirrel => _squirrel(now),
      NpcKind.ladybug => _ladybug(now),
      NpcKind.mouse => _mouse(now),
    };
    if (!_moveTouched && _move != null) {
      // Another branch took over: the walk stops where it is.
      _x = _move!.xAt(now);
      _move = null;
    }
    return intent;
  }

  NpcIntent _evaluateGulls(DateTime now) => _gulls.evaluate(
    now,
    active: _tier != QualityTier.low && _scene == AvatarScene.beach,
    rain: _rain,
    reduceMotion: _reduceMotion,
    excited: _speaking && _emotion.arousal >= GullFlock.excitedArousal,
  );

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

  /// Like [_goTo], over distance / [rate] (at least [minLength]).
  NpcIntent _goAt(
    double target,
    double rate,
    DateTime now, {
    required NpcState arrived,
    Duration minLength = Duration.zero,
  }) {
    final Duration length = travelTime(target - _xNow(now), rate);
    return _goTo(
      target,
      length < minLength ? minLength : length,
      now,
      arrived: arrived,
    );
  }

  void _wake(DateTime now) {
    _awake = true;
    _activeAt = now;
  }

  /// The pet branches the cat and the dog share (they outrank everything):
  /// a poke (react, then notice) and its name (notice, then react); both wake
  /// it. Null when neither is under way.
  NpcIntent? _petAttention(DateTime now) {
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
    return null;
  }

  NpcIntent _cat(DateTime now) {
    final NpcIntent? attention = _petAttention(now);
    if (attention != null) {
      return attention;
    }
    final DateTime? walkEnd = _catWalksByUntil;
    final bool walkingCat = walkEnd != null && now.isBefore(walkEnd);
    if (!walkingCat) {
      _catWalksByUntil = null;
      _hiddenByWalker = false;
    } else if (_move != null) {
      _hiddenByWalker = true;
    }
    if (_hiddenByWalker) {
      // Keep the walk running unseen (it is not stopped by the branch rule).
      _moveTouched = true;
      return NpcIntent(npc: NpcState.away, npcX: _move?.to ?? _x);
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
    return _wander(
      now,
      length: driftLength,
      minGap: driftMinGap,
      maxGap: driftMaxGap,
    );
  }

  /// Idle, with a move to a random `npcX` every [minGap] to [maxGap]: of
  /// [length], or distance / [rate] (at least [minLength]); none under reduce
  /// motion.
  NpcIntent _wander(
    DateTime now, {
    Duration? length,
    double? rate,
    Duration minLength = Duration.zero,
    required Duration minGap,
    required Duration maxGap,
  }) {
    if (_reduceMotion) {
      return _at(NpcState.idle, now);
    }
    final double? target = _driftTarget;
    if (target != null && (_move != null && _move!.to == target)) {
      return _goTo(target, _move!.length, now, arrived: NpcState.idle);
    }
    _driftTarget = null;
    final DateTime next = _nextDriftAt ??= now.add(_gap(minGap, maxGap));
    if (!now.isBefore(next)) {
      final double to = _random.nextDouble();
      Duration span = length ?? travelTime(to - _xNow(now), rate!);
      if (span < minLength) {
        span = minLength;
      }
      _driftTarget = to;
      _nextDriftAt = now.add(span).add(_gap(minGap, maxGap));
      return _goTo(to, span, now, arrived: NpcState.idle);
    }
    return _at(NpcState.idle, now);
  }

  Duration _gap(Duration min, Duration max) {
    final int span = max.inMilliseconds - min.inMilliseconds;
    return min + Duration(milliseconds: _random.nextInt(span + 1));
  }

  /// The fish faces right while `npcLook` >= 0 and left while < 0, in every
  /// state: whatever it shows keeps the last facing sign.
  NpcIntent _fish(DateTime now) {
    final NpcIntent raw = _fishRaw(now);
    if (raw.npcLook < 0) {
      _fishFacesLeft = true;
    } else if (raw.npcLook > 0) {
      _fishFacesLeft = false;
    } else if (_fishFacesLeft) {
      return NpcIntent(npc: raw.npc, npcX: raw.npcX, npcLook: -fishMoveLook);
    }
    return raw;
  }

  NpcIntent _fishRaw(DateTime now) {
    if (_pokedAt != null) {
      if (_within(_pokedAt, now, fishReactLength)) {
        return _react(now, look: _toAvatar(now));
      }
      if (_within(_pokedAt, now, fishReactLength + fishNoticeLength)) {
        return _at(NpcState.notice, now, look: _toAvatar(now));
      }
      _pokedAt = null;
    }
    if (_speaking) {
      return _at(NpcState.notice, now, look: _toAvatar(now));
    }
    return _wander(
      now,
      rate: fishSwimRate,
      minLength: fishSwimMinLength,
      minGap: fishSwimMinGap,
      maxGap: fishSwimMaxGap,
    );
  }

  NpcIntent _pigeon(DateTime now) {
    if (_pokedAt != null) {
      if (_within(_pokedAt, now, pigeonReactLength)) {
        return _react(now, look: _toAvatar(now));
      }
      if (_within(
        _pokedAt,
        now,
        pigeonReactLength + pigeonWalkLength + pigeonAwayLength,
      )) {
        return _goAt(1, pigeonWalkRate, now, arrived: NpcState.idle);
      }
      _pokedAt = null;
      _returningHome = true;
      _driftTarget = null;
    }
    if (_rain >= pigeonRainRest) {
      return _at(NpcState.rest, now);
    }
    if (_returningHome) {
      if (_move == null && _x.abs() < 1e-6) {
        _returningHome = false;
        _nextDriftAt = null;
      } else {
        return _goAt(0, pigeonWalkRate, now, arrived: NpcState.idle);
      }
    }
    return _wander(
      now,
      rate: pigeonWalkRate,
      minGap: pigeonWalkMinGap,
      maxGap: pigeonWalkMaxGap,
    );
  }

  NpcIntent _dog(DateTime now) {
    final NpcIntent? attention = _petAttention(now);
    if (attention != null) {
      return attention;
    }
    if (_emotion.valence <= sadValence) {
      _wake(now);
      return _goAt(1, dogTrotRate, now, arrived: NpcState.idle);
    }
    if (_speaking && _emotion.arousal >= wakeArousal) {
      _wake(now);
    }
    if (!_awake) {
      return _at(NpcState.rest, now);
    }
    if (_within(_activeAt, now, calmToSleep)) {
      return _at(NpcState.idle, now);
    }
    final NpcIntent intent = _goAt(0, dogTrotRate, now, arrived: NpcState.rest);
    if (intent.npc == NpcState.rest) {
      _awake = false;
    }
    return intent;
  }

  NpcIntent _squirrel(DateTime now) {
    if (_pokedAt != null) {
      if (_within(_pokedAt, now, squirrelReactLength)) {
        return _react(now, look: _toAvatar(now));
      }
      if (_within(
        _pokedAt,
        now,
        squirrelReactLength + squirrelRunLength + squirrelAwayLength,
      )) {
        return _goAt(1, squirrelRunRate, now, arrived: NpcState.idle);
      }
      _pokedAt = null;
      _returningHome = true;
      _driftTarget = null;
    }
    if (_within(_gustAt, now, squirrelReactLength)) {
      return _react(now, look: _toAvatar(now));
    }
    _gustAt = null;
    if (_rain >= squirrelRainShelter) {
      _returningHome = true;
      _driftTarget = null;
      return _goAt(1, squirrelRunRate, now, arrived: NpcState.rest);
    }
    if (_returningHome) {
      if (_move == null && _x.abs() < 1e-6) {
        _returningHome = false;
        _nextDriftAt = null;
      } else {
        return _goAt(0, squirrelRunRate, now, arrived: NpcState.idle);
      }
    }
    return _wander(
      now,
      rate: squirrelRunRate,
      minGap: squirrelDashMinGap,
      maxGap: squirrelDashMaxGap,
    );
  }

  NpcIntent _ladybug(DateTime now) {
    if (_within(_pokedAt, now, ladybugReactLength)) {
      return _react(now, look: _toAvatar(now));
    }
    _pokedAt = null;
    if (_within(_tunnelAt, now, tunnelLength)) {
      return _at(NpcState.rest, now);
    }
    _tunnelAt = null;
    return _wander(
      now,
      rate: ladybugWalkRate,
      minGap: ladybugWalkMinGap,
      maxGap: ladybugWalkMaxGap,
    );
  }

  /// The mouse goes back to sleep: by its shelf (0), wherever it was.
  void _mouseSleeps() {
    _awake = false;
    _activeAt = null;
    _nextDriftAt = null;
    _driftTarget = null;
  }

  NpcIntent _mouse(DateTime now) {
    if (_pokedAt != null) {
      if (_within(_pokedAt, now, mouseReactLength)) {
        return _react(now, look: _toAvatar(now));
      }
      _pokedAt = null;
      _mouseSleeps();
    }
    if (_lightningAt != null) {
      if (_within(_lightningAt, now, mouseReactLength)) {
        return _react(now, look: _toAvatar(now));
      }
      _lightningAt = null;
      _mouseSleeps();
    }
    if (_mentionAt != null) {
      if (_within(_mentionAt, now, mentionNoticeLength)) {
        _wake(now);
        return _at(NpcState.notice, now, look: _toAvatar(now));
      }
      _mentionAt = null;
    }
    if (_speaking && _emotion.arousal >= wakeArousal) {
      _wake(now);
      return _at(NpcState.notice, now, look: _toAvatar(now));
    }
    if (_awake && _within(_activeAt, now, calmToSleep)) {
      return _wander(
        now,
        rate: mouseScurryRate,
        minGap: mouseScurryMinGap,
        maxGap: mouseScurryMaxGap,
      );
    }
    if (_awake) {
      _mouseSleeps();
    }
    return _goAt(0, mouseScurryRate, now, arrived: NpcState.rest);
  }

  /// Re-evaluates at the next moment the tree can change: every [frame]
  /// while a move or a gull flight runs, else the earliest pending deadline.
  void _schedule(DateTime now) {
    _timer?.cancel();
    _timer = null;
    if (_tier == QualityTier.low) {
      return;
    }
    Duration? delay;
    void sooner(Duration candidate) {
      if (delay == null || candidate < delay!) {
        delay = candidate;
      }
    }

    final _Move? move = _move;
    if (move != null) {
      // every frame while it walks (only its end for a jump), and exactly
      // at the end, so it lands on time
      final Duration left =
          move.start.add(move.length).difference(now) +
          const Duration(milliseconds: 1);
      sooner(move.jump || left < frame ? left : frame);
    }
    final DateTime? gullChange = _gulls.nextChange;
    if (_gulls.animating && gullChange != null) {
      final Duration left =
          gullChange.difference(now) + const Duration(milliseconds: 1);
      sooner(left < frame ? left : frame);
    }
    if (delay != null) {
      _timer = Timer(delay!, _update);
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

    consider(gullChange);
    final DateTime? poked = _pokedAt;
    if (poked != null) {
      consider(poked.add(reactLength));
      consider(poked.add(reactLength + pokeNoticeLength));
      consider(poked.add(reactLength + crabScuttleLength + crabAwayLength));
      consider(poked.add(fishReactLength));
      consider(poked.add(fishReactLength + fishNoticeLength));
      consider(poked.add(pigeonReactLength));
      consider(
        poked.add(pigeonReactLength + pigeonWalkLength + pigeonAwayLength),
      );
      consider(poked.add(squirrelReactLength));
      consider(
        poked.add(squirrelReactLength + squirrelRunLength + squirrelAwayLength),
      );
      consider(poked.add(ladybugReactLength));
      consider(poked.add(mouseReactLength));
    }
    consider(_gustAt?.add(squirrelReactLength));
    consider(_tunnelAt?.add(tunnelLength));
    consider(_lightningAt?.add(mouseReactLength));
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
    if (kind == NpcKind.alien ||
        kind == NpcKind.fish ||
        kind == NpcKind.pigeon ||
        kind == NpcKind.squirrel ||
        kind == NpcKind.ladybug ||
        kind == NpcKind.mouse) {
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
