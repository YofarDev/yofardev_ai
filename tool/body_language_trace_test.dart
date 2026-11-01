// Persona body-language trace (moonshot M10 ruling 11): one scripted reply
// (fixed sentences, cues and timings, a fake clock) played through the real
// PerformanceDirector, FacePerformer, HeadMotionSolver and IdleLadder for
// each of the eight personas; it writes a markdown table to
// rive/review/m10/personas/trace.md (or PERSONA_OUT):
//
//   flutter test tool/body_language_trace_test.dart
//
// No LLM, no audio: the sentences carry synthetic speech timelines (one
// syllable per 200 ms, stresses and pitch peaks on a fixed pattern) and the
// playback events are sent in the order TtsPlaybackService sends them, the
// director fed as AvatarCueService feeds it. The face and the head are
// stepped at 60 fps as RiveAvatarView steps them (face first, the solver
// following the face, the head target from the director's gaze and prop);
// the idle that follows is stepped at 10 fps.
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/models/avatar_gesture.dart';
import 'package:yofardev_ai/core/models/chat.dart';
import 'package:yofardev_ai/core/models/performance/performance.dart';
import 'package:yofardev_ai/core/services/power/power_saver_source.dart';
import 'package:yofardev_ai/core/services/presence/composer_activity_service.dart';
import 'package:yofardev_ai/features/avatar/domain/models/face_frame.dart';
import 'package:yofardev_ai/features/avatar/domain/models/head_pose.dart';
import 'package:yofardev_ai/features/avatar/domain/models/performance_intent.dart';
import 'package:yofardev_ai/features/avatar/domain/services/face_performer.dart';
import 'package:yofardev_ai/features/avatar/domain/services/head_motion_solver.dart';
import 'package:yofardev_ai/features/avatar/domain/services/head_target_mapper.dart';
import 'package:yofardev_ai/features/avatar/domain/services/idle_ladder.dart';
import 'package:yofardev_ai/features/avatar/domain/services/performance_director.dart';
import 'package:yofardev_ai/features/talking/talking.dart';

const Duration _dt = Duration(microseconds: 16667);
const Duration _idleDt = Duration(milliseconds: 100);

/// How long a keyed gesture clip plays before `gesture_done`.
const Duration _gestureLength = Duration(milliseconds: 1200);

/// The breath before each sentence (ChatTtsCubit's pre-roll) and the gap
/// between two sentences.
const Duration _preroll = Duration(milliseconds: 350);
const Duration _gap = Duration(milliseconds: 250);

/// A nod is a dip of the face's pitch this far below the posture.
const double _nodDip = 0.05;

/// The idle after the reply is watched this long.
const Duration _idleWatch = Duration(minutes: 15);

class _Line {
  const _Line(this.text, this.seconds, {this.llmGesture});

  final String text;
  final double seconds;
  final AvatarGesture? llmGesture;
}

/// The scripted reply: a yes, a list, an emphatic beat, an LLM-cued line and
/// a closing question.
const List<_Line> _reply = <_Line>[
  _Line('Yes, that is a great question.', 2.0),
  _Line(
    'First set a goal, second plan the week, third track your progress.',
    3.6,
  ),
  _Line('Small wins add up fast!', 1.8),
  _Line('Remember to rest, too.', 2.0, llmGesture: AvatarGesture.wave),
  _Line('Plain steps every day will carry you.', 2.4),
  _Line('What will you try first?', 2.0),
];

/// What the user types before the reply (the listening lean).
const String _typed = 'How do I stay motivated?';

class _NoPowerSaver implements PowerSaverSource {
  @override
  Future<bool> get isOn async => false;

  @override
  Stream<bool> get changes => const Stream<bool>.empty();
}

/// A deterministic speech timeline for [line]: one syllable per 200 ms (a
/// 150 ms vowel, a 50 ms gap), a stress every other syllable (strengths
/// cycling 0.9 / 0.5 / 0.7 / 0.35) and a pitch peak every fourth; a question
/// ends on a rising peak.
SpeechTimeline _timelineFor(_Line line) {
  final Duration total = Duration(microseconds: (line.seconds * 1e6).round());
  const Duration syllable = Duration(milliseconds: 200);
  final int n = total.inMicroseconds ~/ syllable.inMicroseconds;
  final bool question = line.text.trim().endsWith('?');
  const List<double> strengths = <double>[0.9, 0.5, 0.7, 0.35];
  final List<VisemeSpan> visemes = <VisemeSpan>[];
  final List<ProsodyMark> marks = <ProsodyMark>[];
  const List<Viseme> vowels = <Viseme>[Viseme.aa, Viseme.e, Viseme.oh];
  for (int i = 0; i < n; i++) {
    final Duration start = syllable * i;
    visemes.add(
      VisemeSpan(
        viseme: vowels[i % vowels.length],
        start: start,
        end: start + const Duration(milliseconds: 150),
      ),
    );
    visemes.add(
      VisemeSpan(
        viseme: Viseme.sil,
        start: start + const Duration(milliseconds: 150),
        end: start + syllable,
      ),
    );
    if (i.isEven) {
      marks.add(
        ProsodyMark(
          kind: ProsodyMarkKind.stress,
          at: start + const Duration(milliseconds: 40),
          strength: strengths[(i ~/ 2) % strengths.length],
        ),
      );
    }
    if (i % 4 == 1 && !(question && i >= n - 3)) {
      marks.add(
        ProsodyMark(
          kind: ProsodyMarkKind.pitchPeak,
          at: start + const Duration(milliseconds: 60),
          strength: 0.8,
          slope: 0.5,
        ),
      );
    }
  }
  if (question) {
    marks.add(
      ProsodyMark(
        kind: ProsodyMarkKind.pitchPeak,
        at: syllable * (n - 1) + const Duration(milliseconds: 60),
        slope: 0.8,
      ),
    );
  }
  marks.sort((ProsodyMark a, ProsodyMark b) => a.at.compareTo(b.at));
  return SpeechTimeline(
    visemes: visemes,
    marks: marks,
    duration: total,
    isQuestion: question,
  );
}

class _Stats {
  final List<AvatarGesture> gestures = <AvatarGesture>[];
  final List<String> gestureSources = <String>[];
  double leanSum = 0;
  double leanMax = -double.infinity;
  double pitchSum = 0;
  double pitchMin = double.infinity;
  double pitchMax = -double.infinity;
  double rollSum = 0;
  double rollMin = double.infinity;
  double rollMax = -double.infinity;
  int frames = 0;
  int nods = 0;

  /// The deepest point of each dip, and of the dip under way (null: none).
  final List<double> dipDepths = <double>[];
  double? _dip;

  /// One frame of the face's pitch relative to the posture: a dip starts
  /// below −[_nodDip] and ends back above it.
  void nod(double pitch) {
    final double? dip = _dip;
    if (dip == null) {
      if (pitch <= -_nodDip) {
        nods++;
        _dip = pitch;
      }
    } else if (pitch > -_nodDip) {
      dipDepths.add(-dip);
      _dip = null;
    } else {
      _dip = math.min(dip, pitch);
    }
  }

  double get meanDip => dipDepths.isEmpty
      ? 0
      : dipDepths.reduce((double a, double b) => a + b) / dipDepths.length;
  final Map<int, double> idleOnsets = <int, double>{};
  final Map<int, AvatarProp> idleProps = <int, AvatarProp>{};

  void add(FaceFrame face, HeadPose pose) {
    final double pitch = (pose.pitch + face.nodPitch).clamp(-1.0, 1.0);
    leanSum += face.lean;
    leanMax = math.max(leanMax, face.lean);
    pitchSum += pitch;
    pitchMin = math.min(pitchMin, pitch);
    pitchMax = math.max(pitchMax, pitch);
    rollSum += face.roll;
    rollMin = math.min(rollMin, face.roll);
    rollMax = math.max(rollMax, face.roll);
    frames++;
  }
}

_Stats _trace(ChatPersona persona) {
  final BodyLanguageProfile profile = BodyLanguageProfile.of(persona);
  final _Stats stats = _Stats();
  fakeAsync((FakeAsync async) {
    DateTime now = DateTime(2026, 10, 31, 20);
    Duration? position;
    final PerformanceDirector director = PerformanceDirector(now: () => now);
    final StreamController<PlaybackEvent> playback =
        StreamController<PlaybackEvent>.broadcast(sync: true);
    final FacePerformer face = FacePerformer(
      intents: director.intents,
      playback: playback.stream,
      speechPosition: () => position,
    );
    final HeadMotionSolver solver = HeadMotionSolver();
    final IdleLadder ladder = IdleLadder(
      now: () => now,
      power: _NoPowerSaver(),
      reduceMotion: () => false,
    );
    // as AvatarCueService bridges them
    DateTime lastActivity = now;
    director.activity.listen((_) {
      lastActivity = now;
      ladder.onActivity();
    });
    ladder.stages.listen(director.setIdleStage);
    int lastSerial = 0;
    director.intents.listen((PerformanceIntent intent) {
      if (intent.pendingGesture != null && intent.gestureSerial > lastSerial) {
        lastSerial = intent.gestureSerial;
        stats.gestures.add(intent.pendingGesture!);
        Timer(_gestureLength, director.onGestureDone);
      }
    });
    bool watchingIdle = false;
    int lastStage = 0;
    unawaited(ladder.start());
    async.flushMicrotasks();

    // the chat's persona, as AvatarCueService applies it
    director.setProfile(profile);
    ladder.thresholdScale = profile.idle.ladderScale;

    void frame(Duration dt, {bool record = true}) {
      now = now.add(dt);
      async.elapse(dt);
      final PerformanceIntent intent = director.current;
      final HeadTarget target = headTargetFor(
        intent.gaze,
        activeTool: intent.activeTool,
        prop: intent.prop,
      );
      solver.setTarget(target.yaw, target.pitch, reading: target.reading);
      final FaceFrame f = face.step(dt);
      solver.followFace(f);
      final HeadPose pose = solver.step(dt);
      if (record) {
        stats.nod(f.nodPitch - profile.posture.pitch);
        stats.add(f, pose);
      }
      if (watchingIdle && director.current.idleStage != lastStage) {
        lastStage = director.current.idleStage;
        stats.idleOnsets[lastStage] =
            now.difference(lastActivity).inMilliseconds / 1000;
        stats.idleProps[lastStage] = director.current.prop;
      }
    }

    void run(Duration length, {Duration dt = _dt, bool record = true}) {
      final int n = length.inMicroseconds ~/ dt.inMicroseconds;
      for (int i = 0; i < n; i++) {
        frame(dt, record: record);
      }
    }

    // settle into the persona's rest pose first (not recorded)
    run(const Duration(seconds: 1), record: false);

    // the user types (the listening lean, caret gaze, backchannel nods)
    for (int i = 0; i < _typed.length; i++) {
      director.setComposer(
        ComposerActivity(
          typing: true,
          caretFraction: (i + 1) / _typed.length,
          lastChar: _typed[i],
        ),
      );
      run(const Duration(milliseconds: 150));
    }
    director.setComposer(ComposerActivity.idle);
    run(const Duration(milliseconds: 800));

    // the reply
    for (final _Line line in _reply) {
      final SpeechTimeline timeline = _timelineFor(line);
      playback.add(SpeechPrerollEvent(_preroll, onset: Viseme.aa));
      run(_preroll);
      position = Duration.zero;
      playback.add(const SpeakingStartedEvent());
      director.setSpeaking(true);
      playback.add(SpeechTimelineEvent(timeline));
      final AvatarGesture? cue = line.llmGesture;
      if (cue != null) {
        director.requestGesture(cue);
      }
      director.onSentence(line.text, autoActing: cue == null);
      final int n = timeline.duration.inMicroseconds ~/ _dt.inMicroseconds;
      for (int i = 0; i < n; i++) {
        position = _dt * (i + 1);
        frame(_dt);
      }
      playback.add(const AnimationCompletedEvent());
      playback.add(const SpeakingStoppedEvent());
      position = null;
      director.setSpeaking(false);
      run(_gap);
    }
    // the reply's tail (the last nod, the full stop)
    run(const Duration(seconds: 2));

    // the idle that follows
    watchingIdle = true;
    run(_idleWatch, dt: _idleDt, record: false);

    unawaited(face.dispose());
    unawaited(director.dispose());
    unawaited(ladder.dispose());
    unawaited(playback.close());
    async.flushMicrotasks();
  });
  return stats;
}

String _f(double v) => v.toStringAsFixed(3);

String _onset(_Stats s, int stage) {
  final double? at = s.idleOnsets[stage];
  return at == null ? '—' : at.toStringAsFixed(0);
}

void main() {
  test('persona body-language trace', () {
    final String out =
        Platform.environment['PERSONA_OUT'] ??
        'rive/review/m10/personas/trace.md';
    final StringBuffer md = StringBuffer()
      ..writeln('# Persona body-language trace (M10 ruling 11)')
      ..writeln()
      ..writeln(
        'Generated by `flutter test tool/body_language_trace_test.dart`: one '
        'scripted reply through the real director, face performer, head '
        'solver and idle ladder per persona (fake clock, no LLM, no audio).',
      )
      ..writeln()
      ..writeln(
        'Script: the user types "$_typed" (150 ms per key), then the reply '
        '(350 ms pre-roll, 250 ms between sentences; each keyed gesture '
        'plays ${_gestureLength.inMilliseconds} ms):',
      )
      ..writeln();
    for (int i = 0; i < _reply.length; i++) {
      final _Line l = _reply[i];
      md.writeln(
        '${i + 1}. "${l.text}" (${l.seconds} s'
        '${l.llmGesture == null ? '' : ', LLM cue `${l.llmGesture!.name}`'})',
      );
    }
    md
      ..writeln()
      ..writeln(
        'Lean, pitch and roll are the written `AvatarVM` values over the '
        'typing and the reply (pitch = head solver + the face\'s nod, as the '
        'avatar view writes it). Nods: dips of the face pitch ≥ '
        '$_nodDip below the posture (stress nods, backchannel nods, the '
        'full-stop drop). Idle: the onset of stages 1 / 2 / 3, in seconds '
        'after the last activity, and the prop out at stage 3.',
      )
      ..writeln()
      ..writeln(
        '| persona | rate | gestures played | lean mean / max | '
        'pitch mean / min / max | roll mean / min / max | nods (mean depth) | '
        'idle 1 / 2 / 3 (s) | idle prop |',
      )
      ..writeln('|---|---|---|---|---|---|---|---|---|');
    for (final ChatPersona persona in ChatPersona.values) {
      final BodyLanguageProfile p = BodyLanguageProfile.of(persona);
      final _Stats s = _trace(persona);
      final int n = s.frames;
      md.writeln(
        '| ${persona.name} | ${p.gestureRate} | '
        '${s.gestures.isEmpty ? '—' : s.gestures.map((AvatarGesture g) => g.name).join(', ')} | '
        '${_f(s.leanSum / n)} / ${_f(s.leanMax)} | '
        '${_f(s.pitchSum / n)} / ${_f(s.pitchMin)} / ${_f(s.pitchMax)} | '
        '${_f(s.rollSum / n)} / ${_f(s.rollMin)} / ${_f(s.rollMax)} | '
        '${s.nods} (${_f(s.meanDip)}) | '
        '${_onset(s, 1)} / ${_onset(s, 2)} / ${_onset(s, 3)} | '
        '${s.idleProps[3]?.name ?? '—'} |',
      );
    }
    md
      ..writeln()
      ..writeln('Profiles (`BodyLanguageProfile.of`):')
      ..writeln()
      ..writeln(
        '| persona | rate | bias | posture lean / pitch / roll | motion | '
        'ladder × | glance × | idle prop |',
      )
      ..writeln('|---|---|---|---|---|---|---|---|');
    for (final ChatPersona persona in ChatPersona.values) {
      final BodyLanguageProfile p = BodyLanguageProfile.of(persona);
      final String bias = p.gestureBias.isEmpty
          ? '—'
          : p.gestureBias
                .map(
                  (GestureSwap s) =>
                      '${s.from?.name ?? 'beat'} → '
                      '${s.to.map((AvatarGesture g) => g.name).join('/')}',
                )
                .join('; ');
      md.writeln(
        '| ${persona.name} | ${p.gestureRate} | $bias | '
        '${p.posture.lean} / ${p.posture.pitch} / ${p.posture.roll} | '
        '${p.motionScale} | ${p.idle.ladderScale} | '
        '${p.idle.glancePeriodScale} | ${p.idle.prop.name} |',
      );
    }
    final File file = File(out);
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(md.toString());
  }, timeout: const Timeout(Duration(minutes: 5)));
}
