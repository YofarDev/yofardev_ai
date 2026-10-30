import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
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
import 'package:yofardev_ai/core/models/performance/shot.dart';
import 'package:yofardev_ai/core/models/seasonal_wardrobe.dart';
import 'package:yofardev_ai/core/models/weather_report.dart';
import 'package:yofardev_ai/core/services/audio/foley_service.dart';
import 'package:yofardev_ai/core/services/llm/fake_llm_service.dart';
import 'package:yofardev_ai/core/services/world/tablet_weather_source.dart';
import 'package:yofardev_ai/core/services/world/world_state_service.dart';
import 'package:yofardev_ai/features/avatar/avatar.dart';
import 'package:yofardev_ai/features/avatar/domain/models/scene_drag.dart';
import 'package:yofardev_ai/features/avatar/domain/services/head_target_mapper.dart';
import 'package:yofardev_ai/features/avatar/presentation/rive/prop_drag_controller.dart';
import 'package:yofardev_ai/features/avatar/presentation/widgets/rive/scene_drag_surface.dart';
import 'package:yofardev_ai/features/chat/chat.dart';
import 'package:yofardev_ai/features/home/widgets/home_content_stack.dart';
import 'package:yofardev_ai/features/talking/talking.dart';

import 'support/canned_weather_tool.dart';
import 'support/frame_grabber.dart';
import 'support/say_tts_synthesizer.dart';

/// The wows played by the real app (moonshot M6 Task 6, rulings 1–7; M7–M9
/// added runs). macOS only; NOT part of `flutter test` or
/// `scripts/fverify.sh`:
///
///     flutter test integration_test/wow_capture_test.dart -d macos \
///       --dart-define=WOW=wow1            # wow2, wow3, npc, tour,
///                                         # scene, pairs, tour7
///     flutter test ... --dart-define=WOW=scene --dart-define=SCENE=cafe
///     flutter test ... --dart-define=WOW=wow1 --dart-define=CAPTURE=false
///
/// The real `App` boots on an in-memory store (one dummy LLM config, English)
/// with no network: the debug `FakeLlmService` plays a scripted reply (wow2:
/// a `getCurrentWeather` tool round, then the answer), a canned weather tool
/// answers after 2.5 s, and macOS `say` stands in for on-device TTS. The user
/// line is typed into the real composer and sent; everything else is the
/// app's own pipeline. The render view is grabbed every 66 ms (raw RGBA;
/// `pairs` every 500 ms) and the app state sampled every 33 ms;
/// `rive/tools/wow_capture.py` assembles the GIF, the MP4 (with the WAVs)
/// and the gates. CAPTURE=false grabs nothing and records `FrameTiming`
/// instead.
///
/// M9 (ruling 20): `scene` starts in `SCENE` at a pinned evening, pokes its
/// NPC through the director, drags its handle with synthesised pointer
/// gestures on the real scene view, then speaks one short reply (the beach
/// first waits for the gulls to land and startles them); `pairs` runs all 42
/// ordered scene pairs as one Eulerian circuit from the living room (sparse
/// frames); `tour7` chains the seven scenes on a pinned December night at a
/// full moon.
///
/// Output: `~/Library/Caches/fr.yofardev.yofardevAi/wow/<wow>[_<scene>][_timing]/`,
/// printed as `WOW_DIR <path>`.
const String _wow = String.fromEnvironment('WOW', defaultValue: 'wow1');
const String _sceneArg = String.fromEnvironment(
  'SCENE',
  defaultValue: 'livingRoom',
);
const bool _capture = bool.fromEnvironment('CAPTURE', defaultValue: true);

/// M9 `scene`: what the run says and pokes in one scene.
class _SceneRun {
  const _SceneRun({
    required this.npcProp,
    required this.user,
    required this.reply,
  });

  /// The prop id that pokes the scene's NPC (`NpcKind.propId`).
  final String npcProp;
  final String user;
  final String reply;
}

class _Script {
  const _Script({
    required this.scene,
    required this.rain,
    required this.user,
    required this.responses,
    this.clock,
    this.pinnedAt,
    this.tour = const <AvatarScene>[],
    this.poke,
    this.sceneRun,
    this.frameInterval = const Duration(milliseconds: 66),
    this.defaultOutfit = false,
  });

  final AvatarScene scene;
  final double rain;
  final String user;
  final List<FakeLlmResponse> responses;

  /// The local time the world clock is pinned to (M7: Wow #3 at sunset);
  /// null leaves the real clock.
  final ({int hour, int minute})? clock;

  /// M9 `tour7`: a whole local date and time (the moon phase and December
  /// follow the date); wins over [clock].
  final DateTime? pinnedAt;

  /// M7 `tour`: scene journeys driven one after another, no speech.
  final List<AvatarScene> tour;

  /// M8 `npc`: the scene prop poked (as a tap would) before the user types.
  final String? poke;

  /// M9 `scene`: the NPC poke, the drag and the reply of one scene.
  final _SceneRun? sceneRun;

  /// How often a frame is grabbed (M9 `pairs`: sparse).
  final Duration frameInterval;

  /// M9 `tour7`: the chat's stored outfit is the default one (no hat, the
  /// pink hoodie, no costume), so December shows it in its festive outfit.
  final bool defaultOutfit;
}

String _answer(String text, String mood, {String? background}) => jsonEncode(
  <String, String>{'text': text, 'mood': mood, 'background': ?background},
);

/// The pinned sun (M7 Wow #3): sunset at 18:00 local, sunrise 07:30.
const ({int hour, int minute}) _sunset = (hour: 18, minute: 0);

/// M9 `scene`: one per scene (the NPC's prop, a short exchange).
const Map<AvatarScene, _SceneRun> _sceneRuns = <AvatarScene, _SceneRun>{
  AvatarScene.livingRoom: _SceneRun(
    npcProp: 'cat',
    user: 'Cosy evening, right?',
    reply: 'So cosy! Just the lamp, the cat and you.',
  ),
  AvatarScene.campfire: _SceneRun(
    npcProp: 'owl',
    user: 'The fire looks great.',
    reply: 'Listen to it crackle. The owl likes it too.',
  ),
  AvatarScene.beach: _SceneRun(
    npcProp: 'crab',
    user: 'The waves are so calm.',
    reply: 'They are! Look at the little crab dancing.',
  ),
  AvatarScene.deepSpace: _SceneRun(
    npcProp: 'ufo',
    user: 'Any aliens out here?',
    reply: 'Just one friendly ship. Wave hello!',
  ),
  AvatarScene.cafe: _SceneRun(
    npcProp: 'fish',
    user: 'Nice little café.',
    reply: 'I love the rain on the window. And the goldfish!',
  ),
  AvatarScene.rooftop: _SceneRun(
    npcProp: 'pigeon',
    user: 'What a view tonight.',
    reply: 'The whole city is lit up. Want to look through the telescope?',
  ),
  AvatarScene.mountainHut: _SceneRun(
    npcProp: 'dog',
    user: 'It is snowing again.',
    reply: 'Perfect night to stay by the stove with the dog.',
  ),
};

/// M9 `pairs`: an Eulerian circuit of the complete directed graph on
/// [nodes] from [start] (every ordered pair once; in-degree = out-degree, so
/// it exists). Hierholzer, deterministic. The destinations, in order.
List<AvatarScene> _eulerCircuit(List<AvatarScene> nodes, AvatarScene start) {
  final Map<AvatarScene, List<AvatarScene>> out =
      <AvatarScene, List<AvatarScene>>{
        for (final AvatarScene n in nodes)
          n: <AvatarScene>[
            for (final AvatarScene m in nodes)
              if (m != n) m,
          ],
      };
  final List<AvatarScene> stack = <AvatarScene>[start];
  final List<AvatarScene> circuit = <AvatarScene>[];
  while (stack.isNotEmpty) {
    final List<AvatarScene> next = out[stack.last]!;
    if (next.isNotEmpty) {
      stack.add(next.removeAt(0));
    } else {
      circuit.add(stack.removeLast());
    }
  }
  return circuit.reversed.skip(1).toList();
}

_Script _sceneScript(AvatarScene scene) {
  final _SceneRun run = _sceneRuns[scene]!;
  return _Script(
    scene: scene,
    rain: 0,
    user: run.user,
    clock: (hour: 19, minute: 30),
    sceneRun: run,
    responses: <FakeLlmResponse>[
      FakeLlmResponse(jsonBody: _answer(run.reply, 'happy')),
    ],
  );
}

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
  // M7 Wow #3: changing scene is a journey (living room → beach, the door),
  // landing at the user's local sunset (the harness pins the clock).
  'wow3': _Script(
    scene: AvatarScene.livingRoom,
    rain: 0,
    user: 'Can we go to the beach? I want to see the sunset.',
    clock: _sunset,
    responses: <FakeLlmResponse>[
      FakeLlmResponse(
        jsonBody: _answer(
          "Let's go! Let me grab my jacket. "
              'Here we are, just in time for the sunset.',
          'happy',
          background: 'beach',
        ),
      ),
    ],
  ),
  // M8: the living-room cat's behaviour tree: poked, named, then a sad reply
  // (it walks to the rug by the avatar).
  'npc': _Script(
    scene: AvatarScene.livingRoom,
    rain: 0,
    user: 'Is your cat awake?',
    poke: 'cat',
    responses: <FakeLlmResponse>[
      FakeLlmResponse(
        jsonBody: _answer(
          'She just woke up. '
              'I miss the days she slept on my lap, I feel a bit lonely.',
          'sad',
        ),
      ),
    ],
  ),
  // M7: one journey per threshold family, no speech (door, path, rocket,
  // portal), in the morning.
  'tour': _Script(
    scene: AvatarScene.livingRoom,
    rain: 0,
    user: '',
    clock: (hour: 10, minute: 0),
    responses: <FakeLlmResponse>[],
    tour: <AvatarScene>[
      AvatarScene.campfire,
      AvatarScene.beach,
      AvatarScene.deepSpace,
      AvatarScene.livingRoom,
    ],
  ),
  // M9: one scene (SCENE): its NPC, its drag, a short reply.
  'scene': _sceneScript(AvatarScene.values.byName(_sceneArg)),
  // M9: all 42 ordered pairs back to back, no speech, sparse frames.
  'pairs': _Script(
    scene: AvatarScene.livingRoom,
    rain: 0,
    user: '',
    clock: (hour: 10, minute: 0),
    responses: <FakeLlmResponse>[],
    tour: _eulerCircuit(AvatarScene.values, AvatarScene.livingRoom),
    frameInterval: const Duration(milliseconds: 500),
  ),
  // M9: the seven scenes in one chain on Christmas Eve at 22:00 (a near-full
  // moon, December: festive dressing and the December outfit).
  'tour7': _Script(
    scene: AvatarScene.livingRoom,
    rain: 0,
    user: '',
    pinnedAt: DateTime(2026, 12, 24, 22),
    defaultOutfit: true,
    responses: <FakeLlmResponse>[],
    tour: <AvatarScene>[
      AvatarScene.cafe,
      AvatarScene.rooftop,
      AvatarScene.mountainHut,
      AvatarScene.campfire,
      AvatarScene.beach,
      AvatarScene.deepSpace,
      AvatarScene.livingRoom,
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

/// Plays like the app's foley player and logs what played (M8 ruling 18),
/// so the capture can gate the footsteps and mix them into the MP4.
class _LoggingFoleyPlayer implements FoleyPlayer {
  _LoggingFoleyPlayer(this.log);

  final List<({DateTime at, String asset})> log;
  final AudioPlayersFoleyPlayer _player = AudioPlayersFoleyPlayer();

  @override
  Future<void> play(String asset, double volume) {
    log.add((at: DateTime.now(), asset: asset));
    return _player.play(asset, volume);
  }

  @override
  Future<void> dispose() => _player.dispose();
}

/// Passes the haptics on and logs them (M9: the drag haptics are gated).
class _LoggingHaptics implements HapticsSink {
  _LoggingHaptics(this.log);

  final List<({DateTime at, String kind})> log;

  @override
  void selectionClick() {
    log.add((at: DateTime.now(), kind: 'selection'));
    const SystemHaptics().selectionClick();
  }

  @override
  void lightImpact() {
    log.add((at: DateTime.now(), kind: 'impact'));
    const SystemHaptics().lightImpact();
  }
}

/// The number that says a handle moved: the trail's dot count, else the
/// handle's first number.
String _primary(SceneDragHandle handle) =>
    handle.kind == DragKind.trail ? 'trailN' : handle.numbers.first.name;

/// The finger's path for [handle]'s kind, in artboard px relative to the
/// start point, one point per ~16 ms step.
List<Offset> _dragPath(SceneDragHandle handle) {
  final List<Offset> path = <Offset>[];
  void line(Offset to, double step) {
    final Offset from = path.isEmpty ? Offset.zero : path.last;
    final int n = ((to - from).distance / step).ceil().clamp(1, 1000);
    for (int k = 1; k <= n; k++) {
      path.add(Offset.lerp(from, to, k / n)!);
    }
  }

  switch (handle.kind) {
    case DragKind.pull:
      // down 150 px, slowly
      line(const Offset(0, 150), 5);
    case DragKind.poke:
      // in, a slow stir (~280 px/s), then a fast one (~2000 px/s)
      line(const Offset(0, 6), 2);
      for (int k = 1; k <= 60; k++) {
        final double a = k / 60 * 2 * math.pi;
        path.add(Offset(45 * (1 - math.cos(a)), 6 + 30 * math.sin(a)));
      }
      for (int k = 0; k < 10; k++) {
        path.add(path.last + Offset(k.isEven ? 34 : -34, 0));
      }
    case DragKind.trail:
      final Rect r = handle.rect;
      // zig-zag across the rect (start: its upper left quarter)
      final double w = r.width * 0.6;
      final double h = r.height * 0.5;
      line(Offset(w, 0), 10);
      line(Offset(0, h * 0.5), 10);
      line(Offset(w, h), 10);
    case DragKind.spin:
      // a fling to the right
      line(const Offset(300, 0), 12);
    case DragKind.aim:
      // a slow swing to the left, then held
      line(const Offset(-160, 0), 5);
  }
  return path;
}

/// Where a drag of [handle] starts (artboard px, the handle's rest frame).
Offset _dragStart(SceneDragHandle handle) => switch (handle.kind) {
  // the stick's tip (task 7: the poke is absolute at the tip)
  DragKind.poke => const Offset(196, 1130),
  DragKind.trail => Offset(
    handle.rect.left + handle.rect.width * 0.2,
    handle.rect.top + handle.rect.height * 0.2,
  ),
  DragKind.aim => Offset(
    handle.rect.left + handle.rect.width * 0.7,
    handle.rect.center.dy,
  ),
  DragKind.pull || DragKind.spin => handle.rect.center,
};

void main() {
  final IntegrationTestWidgetsFlutterBinding binding =
      IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  final String runName = _wow == 'scene' ? 'scene_$_sceneArg' : _wow;

  testWidgets(
    'wow capture: $runName',
    (WidgetTester tester) async {
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
        '$runName${_capture ? '' : '_timing'}',
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
      final List<({DateTime at, String asset})> foleyLog =
          <({DateTime at, String asset})>[];
      final List<({DateTime at, String kind})> hapticLog =
          <({DateTime at, String kind})>[];
      await setupServiceLocator(
        ttsSynthesizer: tts,
        tools: <CannedWeatherTool>[
          CannedWeatherTool(
            onReport: (WeatherReport r) =>
                getIt<TabletWeatherSource>().report(r),
          ),
        ],
        foleyPlayer: () => _LoggingFoleyPlayer(foleyLog),
        haptics: _LoggingHaptics(hapticLog),
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
      final CameraDirector camera = getIt<CameraDirector>();
      final NpcDirector npc = getIt<NpcDirector>();

      if (!chat.state.functionCallingEnabled) {
        chat.toggleFunctionCalling();
      }
      // A new chat starts on a random background: set the script's scene on
      // the chat too, so a reply's background change is seen as a change.
      final AvatarConfig start = script.defaultOutfit
          ? AvatarConfig(
              background: script.scene,
              hat: AvatarHat.noHat,
              top: AvatarTop.pinkHoodie,
              costume: AvatarCostume.none,
            )
          : AvatarConfig(background: script.scene);
      await chat.updateAvatarOpenedChat(start);
      avatar.onNewAvatarConfig(chat.state.currentChat.id, start);
      world.setRain(script.rain);
      final ({int hour, int minute})? pinned = script.clock;
      final DateTime? pinnedAt = script.pinnedAt;
      if (pinned != null || pinnedAt != null) {
        final DateTime day = pinnedAt ?? DateTime.now();
        DateTime at(int h, int m) =>
            DateTime(day.year, day.month, day.day, h, m);
        world.applyWeather(
          WeatherReport(
            conditionId: 800,
            sunrise: at(7, 30),
            sunset: at(_sunset.hour, _sunset.minute),
          ),
        );
        world.pinClock(pinnedAt ?? at(pinned!.hour, pinned.minute));
        addTearDown(() => world.pinClock(null));
      }
      await _settle(tester, const Duration(seconds: 4));
      expect(avatar.state.scene, script.scene);

      FakeLlmService().activate(script.responses, title: 'Wow');

      // The scene view's drag controller (M9): read from the drag surface
      // (Home's scene view owns it; re-found now and then).
      PropDragController? drags;
      int dragLookups = 0;
      PropDragController? dragsNow() {
        if (drags == null || dragLookups++ % 30 == 0) {
          // from a timer: no guarded tester call (they would collide with
          // the test body's own)
          final Iterable<Element> found = find
              .byType(SceneDragSurface)
              .evaluate();
          drags = found.isEmpty
              ? null
              : (found.first.widget as SceneDragSurface).controller;
        }
        return drags;
      }

      // ---- recording
      final Stopwatch clock = Stopwatch()..start();
      final DateTime clockStart = DateTime.now();
      final List<Map<String, Object?>> samples = <Map<String, Object?>>[];
      final List<Map<String, Object?>> events = <Map<String, Object?>>[];
      void log(
        String type, [
        Map<String, Object?> more = const <String, Object?>{},
      ]) {
        events.add(<String, Object?>{
          'ms': clock.elapsedMilliseconds,
          'type': type,
          ...more,
        });
      }

      bool speaking = false;
      bool spoke = false;
      int lastStop = 0;
      final StreamSubscription<PlaybackEvent> playback =
          getIt<TtsPlaybackService>().events.listen((PlaybackEvent e) {
            switch (e) {
              case SpeakingStartedEvent():
                speaking = true;
                spoke = true;
                log('start');
              case SpeakingStoppedEvent(:final bool interrupted):
                speaking = false;
                lastStop = clock.elapsedMilliseconds;
                log('stop', <String, Object?>{'interrupted': interrupted});
              case SpeechPrerollEvent(:final Duration lead):
                log('preroll', <String, Object?>{'lead': lead.inMilliseconds});
              case CaptionEvent(:final String text):
                log('caption', <String, Object?>{'text': text});
              default:
                break;
            }
          });
      // M9: every scene event played (a drag's action, a journey's)
      int sceneEventSeq = avatar.state.sceneEvent.seq;
      final StreamSubscription<AvatarState> sceneEvents = avatar.stream.listen((
        AvatarState s,
      ) {
        if (s.sceneEvent.seq != sceneEventSeq) {
          sceneEventSeq = s.sceneEvent.seq;
          log('sceneEvent', <String, Object?>{
            'name': s.sceneEvent.sceneEvent.name,
            'scene': s.scene.name,
          });
        }
      });
      String? lastFile;
      void sample() {
        final PerformanceIntent intent = director.current;
        final HeadTarget head = headTargetFor(
          intent.gaze,
          activeTool: intent.activeTool,
          prop: intent.prop,
        );
        final FaceFrame face = performer.frame;
        final PropDragController? d = dragsNow();
        final SceneDragHandle? handle = d?.handle;
        final String? file = d?.scene?.name;
        if (file != null && file != lastFile) {
          lastFile = file;
          log('file', <String, Object?>{'scene': file});
        }
        final Avatar shown = shownWardrobe(
          avatar.state.avatar,
          world.localDay.value,
        );
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
          // M7: the journey, the camera and the clock
          'journey': avatar.state.journey?.phase.name,
          'family': avatar.state.journey?.family.name,
          'presence': avatar.state.presence.name,
          'preload': avatar.state.preloadScene?.name,
          'shot': camera.shot.value.shot.name,
          'move': camera.shot.value.move.name,
          'shotSerial': camera.shot.value.serial,
          'daylight': world.daylight.value,
          'dusk': world.dusk.value,
          // M8: the jacket, the tablet card, the scene's NPC
          'jacket': avatar.state.jacket,
          'journeyJacket': avatar.state.journeyJacket,
          'tabletWeather': intent.tabletWeather.name,
          'tabletTemp': intent.tabletTemp,
          'npc': npc.intent.value.npc.name,
          'npcX': npc.intent.value.npcX,
          'npcLook': npc.intent.value.npcLook,
          // M9: the gulls, the file on screen, its drag, the sky, December
          'npc2': npc.gullIntent.value.npc.name,
          'npc2X': npc.gullIntent.value.npcX,
          'npc2Look': npc.gullIntent.value.npcLook,
          'fileScene': file,
          'dragging': d?.dragging ?? false,
          'drag': <String, double>{
            if (d != null)
              for (final MapEntry<String, double> e in d.values.entries)
                if (!e.key.startsWith('trailX') && !e.key.startsWith('trailY'))
                  e.key: e.value,
          },
          'dragRead': handle == null ? null : d!.readNumber(_primary(handle)),
          'moonPhase': world.moonPhase.value,
          'festive': world.festive.value,
          'moonRead': d?.readNumber('moonPhase'),
          'festiveRead': d?.readNumber('festive'),
          'hat': shown.hat.name,
          'top': shown.top.name,
        });
      }

      final Timer sampler = Timer.periodic(
        const Duration(milliseconds: 33),
        (_) => sample(),
      );
      addTearDown(sampler.cancel);
      final RenderView view = tester.binding.renderViews.first;
      final FrameGrabber grabber = FrameGrabber(
        view,
        frameDir,
        interval: script.frameInterval,
      );
      final List<FrameTiming> timings = <FrameTiming>[];
      void onTimings(List<FrameTiming> t) => timings.addAll(t);
      addTearDown(grabber.stop);
      addTearDown(playback.cancel);
      addTearDown(sceneEvents.cancel);
      if (_capture) {
        grabber.start(clock);
      } else {
        SchedulerBinding.instance.addTimingsCallback(onTimings);
      }

      // establishing shot, then the user types (composer activity → lean)
      await _settle(tester, const Duration(seconds: 2));
      if (script.tour.isNotEmpty) {
        // M7 tour (M9 pairs, tour7): one journey after another, each to its
        // end
        for (final AvatarScene to in script.tour) {
          log('journey', <String, Object?>{
            'from': avatar.state.scene.name,
            'to': to.name,
          });
          avatar.onNewAvatarConfig(
            chat.state.currentChat.id,
            AvatarConfig(
              background: to,
              specials: AvatarSpecials.leaveAndComeBack,
            ),
          );
          final int limit = clock.elapsedMilliseconds + 20000;
          await _settle(tester, const Duration(milliseconds: 300));
          while (avatar.state.journey != null &&
              clock.elapsedMilliseconds < limit) {
            await tester.pump();
            await Future<void>.delayed(const Duration(milliseconds: 100));
          }
          await _settle(tester, const Duration(milliseconds: 1200));
        }
        spoke = true;
      }
      final String? poke = script.poke;
      if (poke != null) {
        log('poke', <String, Object?>{'prop': poke});
        npc.poke(poke);
        await _settle(tester, const Duration(seconds: 3));
      }
      final _SceneRun? sceneRun = script.sceneRun;
      Map<String, Object?>? dragInfo;
      if (sceneRun != null) {
        if (script.scene == AvatarScene.beach) {
          // the gulls land after 12 s of calm; then a poke sends them off
          log('gullWait');
          final int by = clock.elapsedMilliseconds + 40000;
          while (npc.gullIntent.value.npc != NpcState.idle &&
              clock.elapsedMilliseconds < by) {
            await _settle(tester, const Duration(milliseconds: 200));
          }
          await _settle(tester, const Duration(milliseconds: 1500));
          log('gullPoke', <String, Object?>{'prop': NpcDirector.gullPropId});
          npc.poke(NpcDirector.gullPropId);
          await _settle(tester, const Duration(milliseconds: 3000));
        }
        log('poke', <String, Object?>{'prop': sceneRun.npcProp});
        npc.poke(sceneRun.npcProp);
        await _settle(tester, const Duration(milliseconds: 2500));
        dragInfo = await _performDrag(tester, dragsNow(), log);
        await _settle(tester, const Duration(seconds: 3));
      }
      final Finder field = find.byType(TextField);
      if (script.tour.isEmpty) {
        log('typing');
      }
      for (int i = 1; script.tour.isEmpty && i <= script.user.length; i++) {
        await tester.enterText(field, script.user.substring(0, i));
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 90));
      }
      await _settle(tester, const Duration(milliseconds: 500));
      log('send');
      if (script.tour.isEmpty) {
        await tester.testTextInput.receiveAction(TextInputAction.send);
      }

      // until the reply has been spoken and the face has settled
      final int deadline = clock.elapsedMilliseconds + 45000;
      while (clock.elapsedMilliseconds < deadline) {
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 100));
        final bool consumed = FakeLlmService().remainingResponses == 0;
        if (consumed &&
            spoke &&
            !speaking &&
            avatar.state.journey == null &&
            clock.elapsedMilliseconds - lastStop > 1800) {
          break;
        }
      }
      if (script.poke != null) {
        // the cat's walk to the rug outlasts the reply
        await _settle(tester, const Duration(seconds: 5));
      }
      if (sceneRun != null) {
        // the handle's animation to its end (the cafe's window mists back
        // over 20 s): no drag frame left scheduled when the test ends
        final int by = clock.elapsedMilliseconds + 25000;
        while ((dragsNow()?.animating ?? false) &&
            clock.elapsedMilliseconds < by) {
          await _settle(tester, const Duration(milliseconds: 200));
        }
        log('dragSettled');
      }
      sampler.cancel();
      await grabber.stop();
      if (_capture && script.rain > 0) {
        // the front layer's proof: the same pose wet, then dry, both in the
        // wide shot (M7: the camera pulls back 2.5 s after the reply, in 1.5 s)
        final int wideBy = clock.elapsedMilliseconds + 8000;
        while (camera.shot.value.shot != Shot.wide &&
            clock.elapsedMilliseconds < wideBy) {
          await _settle(tester, const Duration(milliseconds: 200));
        }
        await _settle(tester, const Duration(milliseconds: 1800));
        await grabber.grabOnce('wet');
        world.setRain(0);
        await _settle(tester, const Duration(milliseconds: 1200));
        await grabber.grabOnce('dry');
      }
      if (!_capture) {
        SchedulerBinding.instance.removeTimingsCallback(onTimings);
      }
      await playback.cancel();
      await sceneEvents.cancel();
      for (final ({DateTime at, String asset}) f in foleyLog) {
        final String name = f.asset.split('/').last;
        events.add(<String, Object?>{
          'ms': f.at.difference(clockStart).inMilliseconds,
          'type': 'foley',
          'kind': name.substring(0, name.lastIndexOf('_')),
          'file': 'assets/${f.asset}',
        });
      }
      for (final ({DateTime at, String kind}) h in hapticLog) {
        events.add(<String, Object?>{
          'ms': h.at.difference(clockStart).inMilliseconds,
          'type': 'haptic',
          'kind': h.kind,
        });
      }
      events.sort(
        (Map<String, Object?> a, Map<String, Object?> b) =>
            (a['ms']! as int).compareTo(b['ms']! as int),
      );
      FakeLlmService().deactivate();
      HttpOverrides.global = null;

      final Map<String, Object?> timeline = <String, Object?>{
        'wow': runName,
        'kind': _wow,
        'capture': _capture,
        'scene': script.scene.name,
        'rain': script.rain,
        'tour': <String>[for (final AvatarScene s in script.tour) s.name],
        'pinnedAt':
            (pinnedAt ??
                    (pinned == null
                        ? null
                        : DateTime(
                            DateTime.now().year,
                            DateTime.now().month,
                            DateTime.now().day,
                            pinned.hour,
                            pinned.minute,
                          )))
                ?.toIso8601String(),
        'drag': dragInfo,
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
    },
    timeout: Timeout(
      _wow == 'pairs'
          ? const Duration(minutes: 20)
          : const Duration(minutes: 5),
    ),
  );
}

/// M9 `scene`: drags the scene's handle with a synthesised touch on the real
/// scene view (the in-app drag proof): from a start point inside the handle
/// that hits the scene's drag surface, along the kind's path in real time
/// (~16 ms a step; the controller's velocities run on the wall clock), then
/// held and released. Returns what was done (for the timeline).
Future<Map<String, Object?>> _performDrag(
  WidgetTester tester,
  PropDragController? drags,
  void Function(String type, [Map<String, Object?> more]) log,
) async {
  final SceneDragHandle? handle = drags?.handle;
  if (drags == null || handle == null) {
    log('dragMissing');
    return <String, Object?>{'missing': true};
  }
  final Finder surface = find.descendant(
    of: find.byType(SceneDragSurface),
    matching: find.byType(Listener),
  );
  final RenderBox box = tester.renderObject<RenderBox>(surface.first);
  Offset toGlobal(Offset art) => box.localToGlobal(
    SceneDrags.toLocal(
      art + SceneDrags.planeOffset(handle.plane, drags.parallax()),
      box.size,
    ),
  );
  bool hits(Offset art) {
    final Offset global = toGlobal(art);
    final Size window = tester.view.physicalSize / tester.view.devicePixelRatio;
    if (!(Offset.zero & window).contains(global)) {
      return false;
    }
    final HitTestResult result = tester.hitTestOnBinding(global);
    final bool onSurface = result.path.any(
      (HitTestEntry e) => identical(e.target, box),
    );
    return onSurface && drags.canStart(box.globalToLocal(global), box.size);
  }

  // the kind's start point, else the first point of a grid over the handle
  // that the surface hears (the chrome may cover a part of it)
  Offset start = _dragStart(handle);
  if (!hits(start)) {
    final Rect r = handle.rect.deflate(handle.rect.shortestSide * 0.1);
    Offset? found;
    for (int j = 0; j < 7 && found == null; j++) {
      for (int i = 0; i < 7 && found == null; i++) {
        final Offset p = Offset(
          r.left + r.width * i / 6,
          r.top + r.height * j / 6,
        );
        if (hits(p)) {
          found = p;
        }
      }
    }
    if (found == null) {
      log('dragMissing', <String, Object?>{'id': handle.id});
      return <String, Object?>{'id': handle.id, 'missing': true};
    }
    start = found;
  }
  final List<Offset> path = <Offset>[
    for (final Offset p in _dragPath(handle)) toGlobal(start + p),
  ];
  final Offset down = toGlobal(start);
  log('dragStart', <String, Object?>{
    'id': handle.id,
    'kind': handle.kind.name,
    'scene': drags.scene?.name,
    'x': start.dx,
    'y': start.dy,
  });
  final TestGesture gesture = await tester.startGesture(
    down,
    kind: PointerDeviceKind.touch,
  );
  await tester.pump();
  for (final Offset p in path) {
    await gesture.moveTo(p);
    await tester.pump();
    await Future<void>.delayed(const Duration(milliseconds: 16));
  }
  if (handle.kind != DragKind.spin) {
    // held a moment before the release (a fling lets go while moving)
    await _settle(tester, const Duration(milliseconds: 400));
  }
  await gesture.up();
  await tester.pump();
  log('dragEnd', <String, Object?>{'id': handle.id});
  return <String, Object?>{
    'id': handle.id,
    'kind': handle.kind.name,
    'primary': _primary(handle),
    'start': <double>[start.dx, start.dy],
    'steps': path.length,
  };
}

/// Lets real time pass with the engine producing frames.
Future<void> _settle(WidgetTester tester, Duration time) async {
  await tester.pump();
  await Future<void>.delayed(time);
  await tester.pump();
}
