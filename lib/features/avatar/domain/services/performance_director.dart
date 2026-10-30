import 'dart:async';
import 'dart:math' as math;

import '../../../../core/models/avatar_gesture.dart';
import '../../../../core/models/avatar_mood.dart';
import '../../../../core/models/performance/performance.dart';
import '../../../../core/services/presence/composer_activity_service.dart';
import '../../../../core/utils/logger.dart';
import '../models/performance_intent.dart';
import 'auto_acting_rules.dart';

/// Where a gesture request came from.
enum GestureSource { llm, auto }

class _QueuedGesture {
  const _QueuedGesture(this.gesture, this.source);

  final AvatarGesture gesture;
  final GestureSource source;
}

/// Central gesture arbiter and intent snapshot holder (v1).
///
/// At most one gesture plays at a time. Requests that arrive while one is
/// playing are queued, at most 2 deep; when the queue is full the oldest
/// `auto` request is dropped first. `onGestureDone()` (or a 4 s safety
/// timeout) plays the next request once the cooldown since the last start
/// has elapsed. An LLM gesture always outranks an auto gesture.
///
/// Presence (M4): the director also turns the composer's typing reports, the
/// running tool and the idle ladder's stage into intent fields.
/// - **Gaze**: speaking → user; a running tool → away; composing → the
///   caret; idle stage 1 → seeded glances (away 0.25–0.45 for 1.2 s every
///   6–10 s); else user.
/// - **Prop**: the tablet while a lookup tool runs, the newspaper while the
///   news tool runs ([newsTools]); kept [tabletHoldOver] after the tool ends,
///   so back-to-back tools never put it away in between, but only for a tool
///   that takes the same prop: a different prop always goes through `none`
///   first (one intent with no prop, then the new one; never both), and
///   while the idle ladder has it out (stage 2: 8 s once a minute, stage 3:
///   held); never while speaking. Gestures requested while a prop is out are
///   dropped, except that an LLM gesture is activity: it clears the idle
///   tablet and the hold-over, and plays.
/// - **Put-away**: a gesture that could start while the prop is on its way
///   out (the intent's prop went to `none` less than [propPutAway] ago, e.g.
///   the first auto gesture of a reply after a lookup tool) waits for the
///   put-away to finish, as it waits for the cooldown: the Rive layer would
///   otherwise snap the gesture's arm up when the put-away ends. The
///   director cannot see that end (M4 ruling 23), so it times it.
/// - **Lean** 0.6 while the user types (0 when speaking), a backchannel
///   nod when typing resumes after a 600 ms pause or a word ends (at most
///   one per 2.5 s) and a reaction on a typed `?` / `!` (at most one per
///   1.2 s).
/// - **Tablet weather** (M8 ruling 14): a reading from [tabletWeather]
///   that arrives while the tablet is out for [weatherTool] shows on its
///   card (`tabletWeather` + `tabletTemp`) until the tablet is put away or
///   another tool takes over; a fresh weather lookup starts blank.
/// Speech, a tool starting, composer reports and taps are all activity: the
/// idle stage goes back to 0 at once and [activity] tells the ladder.
class PerformanceDirector {
  PerformanceDirector({
    required DateTime Function() now,
    this.gestureCooldown = const Duration(milliseconds: 1500),
    int seed = 11,
    Stream<TabletWeatherReading>? tabletWeather,
  }) : _now = now,
       _rng = math.Random(seed) {
    _tabletWeatherSubscription = tabletWeather?.listen(_onWeatherReading);
  }

  final DateTime Function() _now;
  final Duration gestureCooldown;
  final math.Random _rng;

  /// The tools that look something up: the avatar pulls out the tablet.
  static const Set<String> lookupTools = <String>{
    'searchGoogle',
    'getTextContentFromWebsite',
    'getCurrentWeather',
    'getMostPopularNewsOfTheDay',
  };

  /// Lean target while the user types.
  static const double composingLean = 0.6;

  /// Typing that resumes after this long a pause earns a backchannel nod.
  static const Duration nodPause = Duration(milliseconds: 600);

  /// Fewest time between two backchannel nods.
  static const Duration nodGap = Duration(milliseconds: 2500);

  /// Fewest time between two punctuation reactions.
  static const Duration reactionGap = Duration(milliseconds: 1200);

  /// The lookup whose reading shows on the tablet's weather card.
  static const String weatherTool = 'getCurrentWeather';

  /// The lookup tools that read the newspaper instead of the tablet.
  static const Set<String> newsTools = <String>{'getMostPopularNewsOfTheDay'};

  /// The prop a tool takes: the newspaper for [newsTools], the tablet for
  /// the other [lookupTools], none otherwise.
  static AvatarProp propForTool(String tool) {
    if (!lookupTools.contains(tool)) {
      return AvatarProp.none;
    }
    return newsTools.contains(tool) ? AvatarProp.newspaper : AvatarProp.tablet;
  }

  /// The prop stays out this long after a lookup tool ends, so a second
  /// tool taking the same prop right away keeps it.
  static const Duration tabletHoldOver = Duration(milliseconds: 400);

  /// How long the prop takes to go away once the intent's prop is `none`.
  /// Mirrors the Rive `prop_tablet_away` clip (417 ms; the newspaper reuses
  /// its timing), rounded up. A gesture waits this long after the prop clears.
  static const Duration propPutAway = Duration(milliseconds: 420);

  /// Stage 2: the tablet is out this long, once per [tabletPeriod].
  static const Duration tabletHold = Duration(seconds: 8);
  static const Duration tabletPeriod = Duration(seconds: 60);

  /// Stage 1 glances: how long, and the range between two of them.
  static const Duration glanceHold = Duration(milliseconds: 1200);
  static const int _glanceMinMs = 6000;
  static const int _glanceSpanMs = 4000;

  static const Duration _safetyTimeout = Duration(seconds: 4);
  static const int _maxQueueDepth = 2;

  // Derived from the mood once (setMood), not on every intent snapshot.
  EmotionVector _emotion = emotionForMood(AvatarMood.neutral);
  ActionUnits _face = actionUnitsForMood(AvatarMood.neutral);
  bool _speaking = false;
  String? _activeTool;
  AvatarProp _heldOver = AvatarProp.none;
  Timer? _holdOverTimer;

  // — presence —
  ComposerActivity _composer = ComposerActivity.idle;
  int _idleStage = 0;
  bool _idleTablet = false;
  double? _glance;
  Timer? _glanceTimer;
  Timer? _tabletTimer;
  DateTime? _lastTypedAt;
  DateTime? _lastNodAt;
  DateTime? _lastReactionAt;
  int _nodSerial = 0;
  PresenceReaction? _reaction;
  int _reactionSerial = 0;
  PerformanceIntent? _lastIntent;
  DateTime? _propClearedAt;
  bool _disposed = false;

  // — tablet weather —
  StreamSubscription<TabletWeatherReading>? _tabletWeatherSubscription;
  bool _weatherLookup = false;
  TabletWeatherReading? _weatherReading;

  AvatarGesture? _playing;
  int _serial = 0;
  DateTime? _lastStartAt;
  final List<_QueuedGesture> _queue = <_QueuedGesture>[];
  Timer? _safetyTimer;
  Timer? _cooldownTimer;

  final StreamController<PerformanceIntent> _controller =
      StreamController<PerformanceIntent>.broadcast();
  final StreamController<void> _activityController =
      StreamController<void>.broadcast();

  /// Fires on every sign of the user's (or the avatar's own) presence:
  /// composer reports, taps, speech and tool starts. The idle ladder resets
  /// on it.
  Stream<void> get activity => _activityController.stream;

  /// Emits every intent snapshot change.
  Stream<PerformanceIntent> get intents => _controller.stream;

  /// Latest intent snapshot.
  PerformanceIntent get current => _buildIntent();

  /// Arms the director's mood (emotion + face presets follow it).
  void setMood(AvatarMood? mood) {
    final AvatarMood resolved = mood ?? AvatarMood.neutral;
    _emotion = emotionForMood(resolved);
    _face = actionUnitsForMood(resolved);
    _emit();
  }

  void setSpeaking(bool speaking) {
    _speaking = speaking;
    if (speaking) {
      _endHoldOver();
      _noteActivity();
    }
    _emit();
  }

  void setActiveTool(String? toolName) {
    final String? previous = _activeTool;
    _activeTool = toolName;
    if (toolName != null && toolName != previous) {
      // Each lookup starts with a blank card; only a weather lookup fills it.
      _weatherLookup = toolName == weatherTool;
      _weatherReading = null;
    }
    if (toolName != null) {
      // The tool's own prop takes over from a held-over one: the same prop
      // stays out, a different one goes through none first (_add).
      _endHoldOver();
      _noteActivity();
    } else if (previous != null &&
        lookupTools.contains(previous) &&
        !_speaking) {
      // The prop outlasts the tool a moment: the next one may follow.
      _heldOver = propForTool(previous);
      _holdOverTimer?.cancel();
      _holdOverTimer = Timer(tabletHoldOver, () {
        _holdOverTimer = null;
        _heldOver = AvatarProp.none;
        _emit();
      });
    }
    _emit();
  }

  /// The composer's latest report: lean, caret gaze, and (while the user
  /// types and nothing else has the floor) the backchannel nod and the
  /// punctuation reaction. Allocates nothing beyond the intent it emits.
  void setComposer(ComposerActivity activity) {
    final bool composingBefore = _composing;
    final double caretBefore = _composer.caretFraction;
    final int stageBefore = _idleStage;
    final int nodsBefore = _nodSerial;
    final int reactionsBefore = _reactionSerial;
    _composer = activity;
    _noteActivity();
    // Caret moves and touches (not edited) are presence, never a nod.
    if (activity.typing &&
        activity.edited &&
        !_speaking &&
        _activeTool == null) {
      _typed(activity.lastChar);
    }
    // A keystroke that changes nothing the intent shows (same caret, no nod,
    // no reaction) builds no snapshot at all.
    if (_composing == composingBefore &&
        _idleStage == stageBefore &&
        _nodSerial == nodsBefore &&
        _reactionSerial == reactionsBefore &&
        (!_composing || activity.caretFraction == caretBefore)) {
      return;
    }
    _emitIfChanged();
  }

  /// The idle ladder's stage (0 active, 1 glances, 2 tablet now and then,
  /// 3 tablet held).
  void setIdleStage(int stage) {
    final int next = stage.clamp(0, 3);
    if (next == _idleStage) {
      return;
    }
    _applyIdleStage(next);
    _emit();
  }

  /// The user did something (a tap): the idle stage goes back to 0 and
  /// [activity] fires.
  void onUserActivity() {
    _noteActivity();
    _emit();
  }

  /// Requests a gesture: plays immediately when idle and past the cooldown,
  /// otherwise joins the queue (dropping the oldest auto request when full).
  void requestGesture(
    AvatarGesture gesture, {
    GestureSource source = GestureSource.llm,
  }) {
    if (source == GestureSource.llm) {
      // The LLM acting is presence: the idle tablet (and a tool's hold-over)
      // go away so the gesture can play. A tool still running keeps the
      // tablet, and the gesture is dropped below.
      final bool tabletWasIdleOut = _prop != AvatarProp.none;
      _endHoldOver();
      _noteActivity();
      if (tabletWasIdleOut && _prop == AvatarProp.none) {
        _emit();
      }
    }
    if (_prop != AvatarProp.none) {
      AppLogger.debug(
        'PerformanceDirector: prop out, dropped ${gesture.name}',
        tag: 'PerformanceDirector',
      );
      return;
    }
    if (_playing == null && _gestureWait == Duration.zero) {
      _start(gesture);
      return;
    }
    if (_queue.length >= _maxQueueDepth) {
      final int dropIndex = _queue.indexWhere(
        (_QueuedGesture q) => q.source == GestureSource.auto,
      );
      // An auto request never evicts an LLM one: with no auto queued, the
      // incoming auto request is the one dropped.
      if (dropIndex == -1 && source == GestureSource.auto) {
        AppLogger.debug(
          'PerformanceDirector: queue full of LLM gestures, dropped auto '
          '${gesture.name}',
          tag: 'PerformanceDirector',
        );
        return;
      }
      final _QueuedGesture dropped = _queue.removeAt(
        dropIndex == -1 ? 0 : dropIndex,
      );
      AppLogger.debug(
        'PerformanceDirector: queue full, dropped $dropped',
        tag: 'PerformanceDirector',
      );
    }
    _queue.add(_QueuedGesture(gesture, source));
    _armCooldownTimer();
  }

  /// The playing gesture finished: clears it and plays the next queued
  /// request once the cooldown has elapsed.
  void onGestureDone() {
    _safetyTimer?.cancel();
    _safetyTimer = null;
    if (_playing == null) {
      return;
    }
    _playing = null;
    _emit();
    _playNext();
  }

  /// Auto-acting entry point: derives gestures from the sentence and
  /// requests them as `auto`.
  void onSentence(String text) {
    for (final AvatarGesture gesture in gesturesFor(text)) {
      requestGesture(gesture, source: GestureSource.auto);
    }
  }

  /// Closes the intents stream and cancels all timers.
  Future<void> dispose() async {
    _disposed = true;
    _safetyTimer?.cancel();
    _cooldownTimer?.cancel();
    _glanceTimer?.cancel();
    _tabletTimer?.cancel();
    _holdOverTimer?.cancel();
    await _tabletWeatherSubscription?.cancel();
    await _controller.close();
    await _activityController.close();
  }

  // — internals —

  Duration get _cooldownRemaining {
    final DateTime? last = _lastStartAt;
    if (last == null) {
      return Duration.zero;
    }
    final Duration elapsed = _now().difference(last);
    return elapsed >= gestureCooldown
        ? Duration.zero
        : gestureCooldown - elapsed;
  }

  Duration get _putAwayRemaining {
    final DateTime? cleared = _propClearedAt;
    if (cleared == null) {
      return Duration.zero;
    }
    final Duration elapsed = _now().difference(cleared);
    return elapsed >= propPutAway ? Duration.zero : propPutAway - elapsed;
  }

  /// How long until a gesture may start: the later of the cooldown and the
  /// prop's put-away.
  Duration get _gestureWait {
    final Duration cooldown = _cooldownRemaining;
    final Duration putAway = _putAwayRemaining;
    return cooldown > putAway ? cooldown : putAway;
  }

  void _start(AvatarGesture gesture) {
    _safetyTimer?.cancel();
    _playing = gesture;
    _serial++;
    _lastStartAt = _now();
    _safetyTimer = Timer(_safetyTimeout, onGestureDone);
    _emit();
    AppLogger.debug(
      'PerformanceDirector: gesture ${gesture.name} started (serial $_serial)',
      tag: 'PerformanceDirector',
    );
  }

  void _playNext() {
    if (_playing != null || _queue.isEmpty) {
      return;
    }
    if (_prop != AvatarProp.none) {
      AppLogger.debug(
        'PerformanceDirector: prop out, dropped ${_queue.length} queued '
        'gesture(s)',
        tag: 'PerformanceDirector',
      );
      _queue.clear();
      return;
    }
    if (_gestureWait > Duration.zero) {
      _armCooldownTimer();
      return;
    }
    // LLM gestures outrank auto gestures: pick the first LLM request,
    // otherwise the oldest request.
    final int index = _queue.indexWhere(
      (_QueuedGesture q) => q.source == GestureSource.llm,
    );
    final _QueuedGesture next = _queue.removeAt(index == -1 ? 0 : index);
    _start(next.gesture);
  }

  void _armCooldownTimer() {
    if (_cooldownTimer != null || _queue.isEmpty) {
      return;
    }
    final Duration remaining = _gestureWait;
    _cooldownTimer = Timer(
      remaining <= Duration.zero ? const Duration(milliseconds: 1) : remaining,
      () {
        _cooldownTimer = null;
        _playNext();
      },
    );
  }

  /// The prop held right now: never while speaking; the tablet for a lookup
  /// tool, the hands free for any other tool, else what the idle ladder says.
  AvatarProp get _prop {
    if (_speaking) {
      return AvatarProp.none;
    }
    final String? tool = _activeTool;
    if (tool != null) {
      return propForTool(tool);
    }
    if (_heldOver != AvatarProp.none) {
      return _heldOver;
    }
    return _idleTablet ? AvatarProp.tablet : AvatarProp.none;
  }

  /// A weather lookup's answer: shown while that lookup's tablet is out.
  void _onWeatherReading(TabletWeatherReading reading) {
    if (!_weatherLookup) {
      return;
    }
    _weatherReading = reading;
    _emit();
  }

  /// The card for the current prop: the reading while the tablet is out for
  /// the weather lookup, else the generic card.
  ({TabletWeather glyph, int temp}) _tabletCard(AvatarProp prop) {
    final TabletWeatherReading? reading = _weatherReading;
    if (prop != AvatarProp.tablet || !_weatherLookup || reading == null) {
      return (glyph: TabletWeather.none, temp: 0);
    }
    return (glyph: reading.glyph, temp: reading.roundedTemp);
  }

  void _endHoldOver() {
    _holdOverTimer?.cancel();
    _holdOverTimer = null;
    _heldOver = AvatarProp.none;
  }

  bool get _composing => _composer.typing && !_speaking;

  PerformanceIntent _buildIntent() {
    final GazeTarget gaze;
    if (_speaking) {
      gaze = const GazeTarget.user();
    } else if (_activeTool != null) {
      gaze = const GazeTarget.away(0.6);
    } else if (_composing) {
      gaze = GazeTarget.caret(_composer.caretFraction.clamp(0.0, 1.0));
    } else if (_glance != null) {
      gaze = GazeTarget.away(_glance!);
    } else {
      gaze = const GazeTarget.user();
    }
    final AvatarProp prop = _prop;
    final ({TabletWeather glyph, int temp}) card = _tabletCard(prop);
    return PerformanceIntent(
      emotion: _emotion,
      face: _face,
      gaze: gaze,
      speaking: _speaking,
      pendingGesture: _playing,
      gestureSerial: _serial,
      activeTool: _activeTool,
      prop: prop,
      lean: _composing ? composingLean : 0,
      nodSerial: _nodSerial,
      reaction: _reaction,
      reactionSerial: _reactionSerial,
      idleStage: _idleStage,
      tabletWeather: card.glyph,
      tabletTemp: card.temp,
    );
  }

  // — presence internals —

  /// A sign of presence: the idle ladder starts over, here and in its own
  /// clock (through [activity]).
  void _noteActivity() {
    if (_idleStage != 0) {
      _applyIdleStage(0);
    }
    if (!_activityController.isClosed) {
      _activityController.add(null);
    }
  }

  /// Handles one typed key: the backchannel nod and the punctuation
  /// reaction, each rate-limited.
  void _typed(String? char) {
    final DateTime now = _now();
    final DateTime? last = _lastTypedAt;
    final bool resumed = last == null || now.difference(last) >= nodPause;
    _lastTypedAt = now;
    final bool wordEnd = char != null && char.trim().isEmpty && char != '';
    if ((resumed || wordEnd) && _elapsed(_lastNodAt, now, nodGap)) {
      _nodSerial++;
      _lastNodAt = now;
    }
    final PresenceReaction? reaction = switch (char) {
      '?' => PresenceReaction.question,
      '!' => PresenceReaction.exclaim,
      _ => null,
    };
    if (reaction != null && _elapsed(_lastReactionAt, now, reactionGap)) {
      _reaction = reaction;
      _reactionSerial++;
      _lastReactionAt = now;
    }
  }

  bool _elapsed(DateTime? since, DateTime now, Duration gap) =>
      since == null || now.difference(since) >= gap;

  void _applyIdleStage(int stage) {
    _idleStage = stage;
    _glanceTimer?.cancel();
    _glanceTimer = null;
    _tabletTimer?.cancel();
    _tabletTimer = null;
    _glance = null;
    _idleTablet = false;
    if (_disposed) {
      return;
    }
    switch (stage) {
      case 1:
        _scheduleGlance();
      case 2:
        _setTablet(true);
      case 3:
        _idleTablet = true;
    }
  }

  void _scheduleGlance() {
    _glanceTimer = Timer(
      Duration(milliseconds: _glanceMinMs + _rng.nextInt(_glanceSpanMs + 1)),
      () {
        final double sign = _rng.nextBool() ? 1 : -1;
        _glance = sign * (0.25 + 0.2 * _rng.nextDouble());
        _emit();
        _glanceTimer = Timer(glanceHold, () {
          _glance = null;
          _emit();
          _scheduleGlance();
        });
      },
    );
  }

  /// Stage 2: the tablet out for [tabletHold], away for the rest of the
  /// [tabletPeriod], and round again.
  void _setTablet(bool out) {
    _idleTablet = out;
    _tabletTimer = Timer(out ? tabletHold : tabletPeriod - tabletHold, () {
      _setTablet(!out);
      _emit();
    });
  }

  void _emit() {
    if (!_controller.isClosed) {
      _add(_buildIntent());
    }
  }

  /// Adds [intent]; a prop changing straight to another prop is preceded by
  /// the same intent with no prop, so the two never show together.
  void _add(PerformanceIntent intent) {
    final AvatarProp before = _lastIntent?.prop ?? AvatarProp.none;
    if (before != AvatarProp.none &&
        intent.prop != AvatarProp.none &&
        intent.prop != before) {
      _controller.add(intent.copyWith(prop: AvatarProp.none));
    }
    if (before != AvatarProp.none && intent.prop == AvatarProp.none) {
      _propClearedAt = _now();
    }
    if (intent.prop == AvatarProp.none) {
      // Put away: the weather lookup's card goes with it.
      _weatherLookup = false;
      _weatherReading = null;
    }
    _lastIntent = intent;
    _controller.add(intent);
  }

  /// Emits only when the snapshot differs from the last one (a stream of
  /// identical composer reports adds nothing).
  void _emitIfChanged() {
    if (_controller.isClosed) {
      return;
    }
    final PerformanceIntent intent = _buildIntent();
    if (intent == _lastIntent) {
      return;
    }
    _add(intent);
  }
}
