import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yofardev_ai/app.dart';
import 'package:yofardev_ai/core/di/service_locator.dart';
import 'package:yofardev_ai/core/models/avatar_config.dart';
import 'package:yofardev_ai/core/models/avatar_scene.dart';
import 'package:yofardev_ai/core/models/demo_script.dart';
import 'package:yofardev_ai/core/models/llm_config.dart';
import 'package:yofardev_ai/core/services/llm/fake_llm_service.dart';
import 'package:yofardev_ai/core/services/world/world_state_service.dart';
import 'package:yofardev_ai/features/avatar/avatar.dart';
import 'package:yofardev_ai/features/avatar/domain/services/head_target_mapper.dart';
import 'package:yofardev_ai/features/chat/chat.dart';
import 'package:yofardev_ai/features/home/widgets/home_content_stack.dart';
import 'package:yofardev_ai/features/talking/talking.dart';

import 'support/canned_weather_tool.dart';
import 'support/frame_grabber.dart';
import 'support/say_tts_synthesizer.dart';

/// Wow #1 and Wow #2 played by the real app (moonshot M6 Task 6, rulings
/// 1–7). macOS only; NOT part of `flutter test` or `scripts/fverify.sh`:
///
///     flutter test integration_test/wow_capture_test.dart -d macos \
///       --dart-define=WOW=wow1            # or wow2
///     flutter test ... --dart-define=WOW=wow1 --dart-define=CAPTURE=false
///
/// The real `App` boots on an in-memory store (one dummy LLM config, English)
/// with no network: the debug `FakeLlmService` plays a scripted reply (wow2:
/// a `getCurrentWeather` tool round, then the answer), a canned weather tool
/// answers after 2.5 s, and macOS `say` stands in for on-device TTS. The user
/// line is typed into the real composer and sent; everything else is the
/// app's own pipeline. The render view is grabbed every 66 ms (raw RGBA) and
/// the app state sampled with it; `rive/tools/wow_capture.py` assembles the
/// GIF, the MP4 (with the WAVs) and the gates. CAPTURE=false grabs nothing
/// and records `FrameTiming` instead.
///
/// Output: `~/Library/Caches/fr.yofardev.yofardevAi/wow/<wow>[_timing]/`,
/// printed as `WOW_DIR <path>`.
const String _wow = String.fromEnvironment('WOW', defaultValue: 'wow1');
const bool _capture = bool.fromEnvironment('CAPTURE', defaultValue: true);

class _Script {
  const _Script({
    required this.scene,
    required this.rain,
    required this.user,
    required this.responses,
  });

  final AvatarScene scene;
  final double rain;
  final String user;
  final List<FakeLlmResponse> responses;
}

String _answer(String text, String mood) =>
    jsonEncode(<String, String>{'text': text, 'mood': mood});

final Map<String, _Script> _scripts = <String, _Script>{
  // Campfire at night, raining (world sync is M7–M9: the harness sets it).
  'wow1': _Script(
    scene: AvatarScene.campfire,
    rain: 1,
    user: 'Can you tell me a story by the fire?',
    responses: <FakeLlmResponse>[
      FakeLlmResponse(
        jsonBody: _answer(
          'Picture a big bright moon above the pines. '
              'Maybe the rain will pass by morning. '
              'Do you hear the logs hissing?',
          'happy',
        ),
      ),
    ],
  ),
  // "What's the weather in Tokyo?": a tool round, then the answer.
  'wow2': _Script(
    scene: AvatarScene.livingRoom,
    rain: 0,
    user: "What's the weather in Tokyo?",
    responses: <FakeLlmResponse>[
      const FakeLlmResponse(
        jsonBody: '',
        toolCalls: <FakeToolCall>[
          FakeToolCall(
            name: 'getCurrentWeather',
            arguments: <String, dynamic>{'location': 'Tokyo'},
          ),
        ],
      ),
      FakeLlmResponse(
        jsonBody: _answer(
          "[g:nod] It's eighteen degrees in Tokyo, with light rain "
              'and a soft breeze. Bring an umbrella!',
          'happy',
        ),
      ),
    ],
  ),
};

/// Refuses every connection and counts the attempts (ruling 2). Creating a
/// client is fine (the app makes one at startup); opening a socket is not.
class _NoNetwork extends HttpOverrides {
  int attempts = 0;
  final List<String> urls = <String>[];

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..connectionFactory = (Uri url, String? proxyHost, int? proxyPort) {
        attempts++;
        urls.add(url.toString());
        return Future<ConnectionTask<Socket>>.error(
          SocketException('network disabled by the wow capture: $url'),
        );
      };
  }
}

void main() {
  final IntegrationTestWidgetsFlutterBinding binding =
      IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('wow capture: $_wow', (WidgetTester tester) async {
    final _Script script = _scripts[_wow]!;
    final _NoNetwork network = _NoNetwork();
    HttpOverrides.global = network;
    // A failing step still restores the process (the explicit cleanup below
    // runs on success; both are idempotent).
    addTearDown(() {
      HttpOverrides.global = null;
      FakeLlmService().deactivate();
    });

    final Directory root = Directory(
      '${(await getTemporaryDirectory()).path}/wow/'
      '$_wow${_capture ? '' : '_timing'}',
    );
    if (root.existsSync()) {
      root.deleteSync(recursive: true);
    }
    final Directory frameDir = Directory('${root.path}/frames')
      ..createSync(recursive: true);
    final Directory audioDir = Directory('${root.path}/audio')
      ..createSync(recursive: true);

    // In-memory store: the owner's chats, configs and keys are never touched.
    const LlmConfig config = LlmConfig(
      id: 'wow',
      label: 'Wow capture (scripted)',
      baseUrl: 'http://127.0.0.1:9',
      apiKey: 'none',
      model: 'scripted',
    );
    SharedPreferences.setMockInitialValues(<String, Object>{
      'llm_configs': jsonEncode(<Map<String, dynamic>>[config.toJson()]),
      'current_llm_config_id': config.id,
      'language': 'en',
    });

    final SayTtsSynthesizer tts = SayTtsSynthesizer(audioDir);
    await setupServiceLocator(
      ttsSynthesizer: tts,
      tools: <CannedWeatherTool>[CannedWeatherTool()],
    );
    await bootstrapApp();
    await tester.pumpWidget(const App());
    await _settle(tester, const Duration(seconds: 6));

    final BuildContext home = tester.element(find.byType(HomeContentStack));
    final ChatCubit chat = home.read<ChatCubit>();
    final AvatarCubit avatar = home.read<AvatarCubit>();
    final TalkingCubit talking = home.read<TalkingCubit>();
    final PerformanceDirector director = getIt<PerformanceDirector>();
    final FacePerformer performer = getIt<FacePerformer>();
    final WorldStateService world = getIt<WorldStateService>();

    if (!chat.state.functionCallingEnabled) {
      chat.toggleFunctionCalling();
    }
    avatar.onNewAvatarConfig(
      chat.state.currentChat.id,
      AvatarConfig(background: script.scene),
    );
    world.setRain(script.rain);
    await _settle(tester, const Duration(seconds: 4));
    expect(avatar.state.scene, script.scene);

    FakeLlmService().activate(script.responses, title: 'Wow');

    // ---- recording
    final Stopwatch clock = Stopwatch()..start();
    final List<Map<String, Object?>> samples = <Map<String, Object?>>[];
    final List<Map<String, Object?>> events = <Map<String, Object?>>[];
    bool speaking = false;
    bool spoke = false;
    int lastStop = 0;
    final StreamSubscription<PlaybackEvent> playback =
        getIt<TtsPlaybackService>().events.listen((PlaybackEvent e) {
          final int ms = clock.elapsedMilliseconds;
          switch (e) {
            case SpeakingStartedEvent():
              speaking = true;
              spoke = true;
              events.add(<String, Object?>{'ms': ms, 'type': 'start'});
            case SpeakingStoppedEvent(:final bool interrupted):
              speaking = false;
              lastStop = ms;
              events.add(<String, Object?>{
                'ms': ms,
                'type': 'stop',
                'interrupted': interrupted,
              });
            case SpeechPrerollEvent(:final Duration lead):
              events.add(<String, Object?>{
                'ms': ms,
                'type': 'preroll',
                'lead': lead.inMilliseconds,
              });
            case CaptionEvent(:final String text):
              events.add(<String, Object?>{
                'ms': ms,
                'type': 'caption',
                'text': text,
              });
            default:
              break;
          }
        });
    void sample() {
      final PerformanceIntent intent = director.current;
      final HeadTarget head = headTargetFor(
        intent.gaze,
        activeTool: intent.activeTool,
        prop: intent.prop,
      );
      final FaceFrame face = performer.frame;
      samples.add(<String, Object?>{
        'ms': clock.elapsedMilliseconds,
        'phase': talking.state.phase.name,
        'tool': chat.state.activeTool,
        'prop': intent.prop.name,
        'lean': intent.lean,
        'yaw': head.yaw,
        'speaking': intent.speaking,
        'jaw': face.au.jawDrop,
        'press': face.au.lipPress,
        'browInner': face.au.browInnerUp,
        'browOuter': face.au.browOuterUp,
        'breath': face.breath,
        'tuck': face.lipTuck,
        'scene': avatar.state.scene.name,
        'rain': world.rain.value,
      });
    }

    final Timer sampler = Timer.periodic(
      const Duration(milliseconds: 33),
      (_) => sample(),
    );
    addTearDown(sampler.cancel);
    final RenderView view = tester.binding.renderViews.first;
    final FrameGrabber grabber = FrameGrabber(view, frameDir);
    final List<FrameTiming> timings = <FrameTiming>[];
    void onTimings(List<FrameTiming> t) => timings.addAll(t);
    addTearDown(grabber.stop);
    addTearDown(playback.cancel);
    if (_capture) {
      grabber.start(clock);
    } else {
      SchedulerBinding.instance.addTimingsCallback(onTimings);
    }

    // establishing shot, then the user types (composer activity → lean)
    await _settle(tester, const Duration(seconds: 2));
    final Finder field = find.byType(TextField);
    events.add(<String, Object?>{
      'ms': clock.elapsedMilliseconds,
      'type': 'typing',
    });
    for (int i = 1; i <= script.user.length; i++) {
      await tester.enterText(field, script.user.substring(0, i));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 90));
    }
    await _settle(tester, const Duration(milliseconds: 500));
    events.add(<String, Object?>{
      'ms': clock.elapsedMilliseconds,
      'type': 'send',
    });
    await tester.testTextInput.receiveAction(TextInputAction.send);

    // until the reply has been spoken and the face has settled
    final int deadline = clock.elapsedMilliseconds + 45000;
    while (clock.elapsedMilliseconds < deadline) {
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      final bool consumed = FakeLlmService().remainingResponses == 0;
      if (consumed &&
          spoke &&
          !speaking &&
          clock.elapsedMilliseconds - lastStop > 1800) {
        break;
      }
    }
    sampler.cancel();
    await grabber.stop();
    if (_capture && script.rain > 0) {
      // the front layer's proof: the same pose wet, then dry
      await grabber.grabOnce('wet');
      world.setRain(0);
      await _settle(tester, const Duration(milliseconds: 1200));
      await grabber.grabOnce('dry');
    }
    if (!_capture) {
      SchedulerBinding.instance.removeTimingsCallback(onTimings);
    }
    await playback.cancel();
    FakeLlmService().deactivate();
    HttpOverrides.global = null;

    final Map<String, Object?> timeline = <String, Object?>{
      'wow': _wow,
      'capture': _capture,
      'scene': script.scene.name,
      'rain': script.rain,
      'user': script.user,
      'reply': script.responses
          .where((FakeLlmResponse r) => r.toolCalls.isEmpty)
          .map((FakeLlmResponse r) => jsonDecode(r.jsonBody)['text'])
          .join(' '),
      'size': <double>[grabber.size?.width ?? 0, grabber.size?.height ?? 0],
      'frames': <Map<String, int>>[
        for (final ({int index, int ms}) f in grabber.frames)
          <String, int>{'i': f.index, 'ms': f.ms},
      ],
      'samples': samples,
      'events': events,
      'audio': <Map<String, String>>[
        for (final ({String text, String file}) a in tts.spoken)
          <String, String>{'text': a.text, 'file': a.file},
      ],
      'network_attempts': network.attempts,
      'network_stacks': network.urls,
      'frame_timings': <Map<String, double>>[
        for (final FrameTiming t in timings)
          <String, double>{
            'build': t.buildDuration.inMicroseconds / 1000,
            'raster': t.rasterDuration.inMicroseconds / 1000,
          },
      ],
    };
    File(
      '${root.path}/timeline.json',
    ).writeAsStringSync(const JsonEncoder.withIndent(' ').convert(timeline));
    // ignore: avoid_print
    print('WOW_DIR ${root.path}');

    expect(spoke, isTrue, reason: 'the reply was never spoken');
    expect(network.attempts, 0, reason: network.urls.join('\n'));
  }, timeout: const Timeout(Duration(minutes: 3)));
}

/// Lets real time pass with the engine producing frames.
Future<void> _settle(WidgetTester tester, Duration time) async {
  await tester.pump();
  await Future<void>.delayed(time);
  await tester.pump();
}
