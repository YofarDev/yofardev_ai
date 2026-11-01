// Face and speech traces for the art critic (moonshot M2/M3), driven by the
// real speech analyzer and FacePerformer at 60 fps. It runs under
// `flutter test` (the performer reaches Flutter through the talking barrel);
// arguments come from the environment and the JSON goes to FACE_OUT:
//
//   FACE_TRACE=presets FACE_OUT=out.json flutter test tool/face_speech_trace_test.dart
//   FACE_TRACE=speech FACE_WAV=x.wav FACE_TEXT="..." [FACE_MOOD=happy] \
//     [FACE_LANG=fr] FACE_OUT=out.json flutter test tool/face_speech_trace_test.dart
//
// FACE_TEXT is the sentence the WAV says: the analyzer aligns its phonemes
// (text-informed, in FACE_LANG: `en` by default, `fr`, or a locale tag) to
// the audio, falling back to the audio classifier when they do not match.
// The `say` fixtures (commands in test/fixtures/speech/README.md) are ready
// inputs, e.g.:
//
//   FACE_TRACE=speech FACE_WAV=test/fixtures/speech/fine_view.wav \
//     FACE_TEXT="A fine view of five vines." FACE_OUT=out.json \
//     flutter test tool/face_speech_trace_test.dart
//   FACE_TRACE=speech FACE_WAV=test/fixtures/speech/bonjour.wav \
//     FACE_TEXT="Bonjour, comment allez-vous ?" FACE_LANG=fr \
//     FACE_OUT=out.json flutter test tool/face_speech_trace_test.dart
//
// speech: 0.5 s of the mood alone, the sentence (playback position = time
// since its start), then 1 s after it ends: the timeline and one face frame
// per 1/60 s. As in the app, the sentence is announced
// `ChatTtsCubit.defaultSpeechPreroll` before its audio (with its first
// sounding viseme: the analysis is ready by then), and the performer runs
// with its idle life on. The JSON records the WAV's path (`wav`, from the
// repo root when inside it) and the pre-roll (`preroll`, ms). presets: the settled face of every mood, and every viseme's
// mouth through the speech merge at a neutral mood. Every face frame carries
// the 14 AUs (`au`), the contract v6 per-side offsets (`left` and `right`,
// the viewer's) and the scalars (FaceFrame.toJson); speech frames also carry
// the head solver's pose (`head`: yaw, pitch, hairLagYaw, hairLagPitch,
// eyeLeadYaw, eyeLeadPitch), stepped after the face as the avatar view does.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/models/avatar_mood.dart';
import 'package:yofardev_ai/core/models/performance/performance.dart';
import 'package:yofardev_ai/core/services/audio/speech_analyzer.dart';
import 'package:yofardev_ai/core/services/audio/wav_pcm.dart';
import 'package:yofardev_ai/features/avatar/domain/models/face_frame.dart';
import 'package:yofardev_ai/features/avatar/domain/models/head_pose.dart';
import 'package:yofardev_ai/features/avatar/domain/services/head_motion_solver.dart';
import 'package:yofardev_ai/features/avatar/domain/models/performance_intent.dart';
import 'package:yofardev_ai/features/avatar/domain/services/face_performer.dart';
import 'package:yofardev_ai/features/chat/presentation/bloc/chat_tts_cubit.dart';
import 'package:yofardev_ai/features/talking/talking.dart';

const int _fps = 60;
const Duration _dt = Duration(microseconds: 16667);

class _Harness {
  _Harness() {
    performer = FacePerformer(
      intents: intents.stream,
      playback: playback.stream,
      speechPosition: () => position,
    );
  }

  final StreamController<PerformanceIntent> intents =
      StreamController<PerformanceIntent>.broadcast(sync: true);
  final StreamController<PlaybackEvent> playback =
      StreamController<PlaybackEvent>.broadcast(sync: true);
  Duration? position;
  late final FacePerformer performer;

  void mood(AvatarMood m) => intents.add(
    PerformanceIntent(emotion: emotionForMood(m), face: actionUnitsForMood(m)),
  );

  FaceFrame run(int frames) {
    FaceFrame f = performer.frame;
    for (int i = 0; i < frames; i++) {
      f = performer.step(_dt);
    }
    return f;
  }
}

void main() {
  final Map<String, String> env = Platform.environment;
  final String? mode = env['FACE_TRACE'];
  final String? out = env['FACE_OUT'];
  test(
    'face trace (FACE_TRACE=$mode)',
    () async {
      final Object json = mode == 'presets'
          ? _presets()
          : await _speech(
              env['FACE_WAV']!,
              env['FACE_TEXT']!,
              AvatarMood.values.byName(env['FACE_MOOD'] ?? 'neutral'),
              env['FACE_LANG'] ?? 'en',
            );
      File(out!).writeAsStringSync(jsonEncode(json));
    },
    skip: mode == null || out == null
        ? 'set FACE_TRACE (presets|speech) and FACE_OUT'
        : false,
  );
}

Future<Map<String, Object>> _speech(
  String wav,
  String text,
  AvatarMood mood,
  String language,
) async {
  final Uint8List bytes = await File(wav).readAsBytes();
  final SpeechTimeline timeline = const SpeechAnalyzer().analyze(
    WavPcm.decode(bytes),
    text: text,
    language: language,
  );

  final _Harness h = _Harness()..mood(mood);
  const Duration preroll = ChatTtsCubit.defaultSpeechPreroll;
  final int prerollFrames = (preroll.inMicroseconds / _dt.inMicroseconds)
      .round();
  Viseme? onset;
  for (final VisemeSpan s in timeline.visemes) {
    if (s.viseme != Viseme.sil) {
      onset = s.viseme;
      break;
    }
  }
  // the head solver as the avatar view runs it (facing the user: idle drift
  // and micro-saccades on top of the face)
  final HeadMotionSolver head = HeadMotionSolver()..setTarget(0, 0);
  final List<Map<String, Object>> frames = <Map<String, Object>>[];
  const int lead = _fps ~/ 2;
  assert(prerollFrames <= lead, 'the pre-roll must fit the lead-in');
  final int speech = (timeline.duration.inMicroseconds / 16667).ceil();
  final int total = lead + speech + _fps;
  for (int i = 0; i < total; i++) {
    if (i == lead - prerollFrames) {
      // the cubit announces each sentence its pre-roll before playing it
      h.playback.add(SpeechPrerollEvent(preroll, onset: onset));
    }
    if (i == lead) {
      h.position = Duration.zero;
      h.playback.add(const SpeakingStartedEvent());
      h.playback.add(SpeechTimelineEvent(timeline));
    }
    if (i == lead + speech) {
      // as in the app: the animation completes, then the cubit stops the
      // sentence (a natural stop, not an interruption)
      h.playback.add(const AnimationCompletedEvent());
      h.playback.add(const SpeakingStoppedEvent());
      h.position = null;
    }
    if (i > lead && i < lead + speech) {
      h.position = _dt * (i - lead);
    }
    final FaceFrame f = h.performer.step(_dt);
    // as in the avatar view: the face's nods and roll drive the hair
    // follow-through and its gaze cues the eyes, then the solver steps
    head.followFace(f);
    final HeadPose pose = head.step(_dt);
    frames.add(<String, Object>{
      'head': pose.toJson(),
      't': i / _fps,
      'speech': i >= lead && i < lead + speech ? (i - lead) / _fps : -1,
      ...f.toJson(),
    });
  }
  await h.performer.dispose();
  return <String, Object>{
    'fps': _fps,
    'lead': lead / _fps,
    'wav': _repoRelative(wav),
    'preroll': preroll.inMilliseconds,
    'text': text,
    'language': language,
    'mood': mood.name,
    'timeline': <String, Object>{
      'duration': timeline.duration.inMilliseconds,
      'leadingSilence': timeline.leadingSilence.inMilliseconds,
      'isQuestion': timeline.isQuestion,
      'visemes': <Map<String, Object>>[
        for (final VisemeSpan s in timeline.visemes)
          <String, Object>{
            'v': s.viseme.name,
            'start': s.start.inMilliseconds,
            'end': s.end.inMilliseconds,
            'weight': s.weight,
          },
      ],
      'marks': <Map<String, Object>>[
        for (final ProsodyMark m in timeline.marks)
          <String, Object>{
            'kind': m.kind.name,
            'at': m.at.inMilliseconds,
            'length': m.length.inMilliseconds,
            'strength': m.strength,
            if (m.slope != null) 'slope': m.slope!,
          },
      ],
    },
    'frames': frames,
  };
}

/// [path] from the repo root (the working directory of `flutter test`) when
/// it lies inside it, else absolute.
String _repoRelative(String path) {
  final String abs = File(path).absolute.path;
  final String root = '${Directory.current.absolute.path}/';
  return abs.startsWith(root) ? abs.substring(root.length) : abs;
}

Map<String, Object> _presets() {
  final Map<String, Object> moods = <String, Object>{};
  for (final AvatarMood m in AvatarMood.values) {
    final _Harness h = _Harness()..mood(m);
    moods[m.name] = h.run(_fps * 2).toJson();
  }
  final Map<String, Object> visemes = <String, Object>{};
  for (final Viseme v in Viseme.values) {
    final _Harness h = _Harness()..mood(AvatarMood.neutral);
    h.position = Duration.zero;
    h.playback.add(const SpeakingStartedEvent());
    h.playback.add(
      SpeechTimelineEvent(
        SpeechTimeline(
          visemes: <VisemeSpan>[
            VisemeSpan(
              viseme: v,
              start: Duration.zero,
              end: const Duration(seconds: 2),
            ),
          ],
          duration: const Duration(seconds: 2),
        ),
      ),
    );
    FaceFrame f = h.performer.frame;
    for (int i = 1; i <= _fps; i++) {
      h.position = _dt * i;
      f = h.performer.step(_dt);
    }
    visemes[v.name] = f.toJson();
  }
  return <String, Object>{'moods': moods, 'visemes': visemes};
}
