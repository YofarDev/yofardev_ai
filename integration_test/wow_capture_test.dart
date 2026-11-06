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
import 'package:yofardev_ai/core/models/avatar_gesture.dart';
import 'package:yofardev_ai/core/models/avatar_scene.dart';
import 'package:yofardev_ai/core/models/chat.dart';
import 'package:yofardev_ai/core/models/demo_script.dart';
import 'package:yofardev_ai/core/models/function_info.dart';
import 'package:yofardev_ai/core/models/llm_config.dart';
import 'package:yofardev_ai/core/models/performance/performance.dart';
import 'package:yofardev_ai/core/models/seasonal_wardrobe.dart';
import 'package:yofardev_ai/core/models/weather_report.dart';
import 'package:yofardev_ai/core/services/agent/agent_tool.dart';
import 'package:yofardev_ai/core/services/agent/avatar_tool.dart';
import 'package:yofardev_ai/core/services/app_lifecycle_service.dart';
import 'package:yofardev_ai/core/services/audio/foley_service.dart';
import 'package:yofardev_ai/core/services/llm/fake_llm_service.dart';
import 'package:yofardev_ai/core/services/quality/quality_tier_service.dart';
import 'package:yofardev_ai/core/services/world/tablet_weather_source.dart';
import 'package:yofardev_ai/core/services/world/world_state_service.dart';
import 'package:yofardev_ai/features/avatar/avatar.dart';
import 'package:yofardev_ai/features/avatar/domain/services/head_target_mapper.dart';
import 'package:yofardev_ai/features/avatar/presentation/rive/avatar_tint_writer.dart';
import 'package:yofardev_ai/features/avatar/presentation/widgets/rive/scene_drag_surface.dart';
import 'package:yofardev_ai/features/chat/chat.dart';
import 'package:yofardev_ai/features/home/widgets/home_content_stack.dart';
import 'package:yofardev_ai/features/home/widgets/stage/stage_caption.dart';
import 'package:yofardev_ai/features/home/widgets/stage/stage_caption_bubble.dart';
import 'dart:typed_data';

import 'package:yofardev_ai/features/sound/sound.dart';
import 'package:yofardev_ai/features/talking/talking.dart';

import 'support/canned_weather_tool.dart';
import 'support/frame_grabber.dart';
import 'support/kokoro_capture_synthesizer.dart';
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
/// first waits for the gulls to land and startles them); `pairs` runs every
/// ordered scene pair (M11: all 90 of the ten scenes, derived from
/// `AvatarScene.values`) as one Eulerian circuit from the living room (sparse
/// frames); `tour7` chains the seven M9 scenes on a pinned December night at
/// a full moon. M11: `scene` covers the three v14 scenes too
/// (`SCENE=forestCabin|trainCompartment|library`).
///
/// M10 (ruling 20; several user turns each, frames every 100 ms):
/// `wardrobe` dresses the avatar through `change_avatar` tool rounds in the
/// living room at noon (a blue hoodie, a red beanie, the four costumes, each
/// with its signature move, back to normal) and reads the tints, the costume
/// and `gestureId` back from the avatar file; `persona` speaks one scripted
/// reply as the doomer, the coach and the philosopher (the current chat's
/// persona) and reads lean, pitch and roll back from `AvatarVM`; `caption`
/// speaks one four-sentence reply three times (default, reduce motion, text
/// scale 1.6) and samples the speech bubble, the classic caption, the mouth
/// anchor and the shot.
///
/// Output: `~/Library/Caches/fr.yofardev.yofardevAi/wow/<wow>[_<scene>][_timing]/`,
/// printed as `WOW_DIR <path>`.
const String _wow = String.fromEnvironment('WOW', defaultValue: 'wow1');
const String _sceneArg = String.fromEnvironment(
  'SCENE',
  defaultValue: 'livingRoom',
);
const bool _capture = bool.fromEnvironment('CAPTURE', defaultValue: true);

/// M12 (rulings 11–12): `TIER=ultra|high|low` forces the quality tier for the
/// run (`QualityTierService.forceTier`); empty (the default) leaves the app's
/// own tier, as before M12. A tier other than ultra suffixes the run name.
const String _tierArg = String.fromEnvironment('TIER');

/// Showcase (2026-11-02): `VOICE=kokoro` swaps `say` for the app's real voice
/// (KokoroTtsDatasource through the capture synthesizer, which keeps a copy of
/// each WAV for the mux). `KOKORO_SRC` is an installed model folder on the
/// host (`.../tts`), copied into the app's fresh container on iOS before the
/// app boots. `PXR` is the frame grab's pixel ratio (1 = as before; the
/// simulator capture grabs at 3 = the device's backing scale).
const String _voiceArg = String.fromEnvironment('VOICE', defaultValue: 'say');
const String _kokoroSrc = String.fromEnvironment('KOKORO_SRC');
const String _pxrArg = String.fromEnvironment('PXR', defaultValue: '1');
final double _pixelRatio = double.tryParse(_pxrArg) ?? 1;

/// Showcase (2026-11-02): `SHOW_OUT` redirects the run's output directory
/// (default: the app's cache dir). The iOS simulator wipe's its container
/// when the test tears down, so the simulator capture writes straight to a
/// host directory instead.
const String _showOut = String.fromEnvironment('SHOW_OUT');

/// Showcase (2026-11-02): on macOS, `WIN_POS` parks the capture window
/// (`{x, y}` via System Events) so the window stays visible — a covered
/// window stops rendering and the grabs freeze. `WIN_SIZE` restores its
/// content size (macOS remembers the last frame). Nothing changes when empty.
const String _winPos = String.fromEnvironment('WIN_POS');
const String _winSize = String.fromEnvironment('WIN_SIZE');

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

/// M10: one user turn of a multi-turn run (its own scripted responses), and
/// how the app is set before it.
class _Turn {
  const _Turn({
    required this.label,
    required this.user,
    required this.responses,
    this.persona,
    this.reduceMotion = false,
    this.textScale = 1,
    this.signature = false,
  });

  /// The beat's name in the timeline (`turn` / `turnEnd` events).
  final String label;
  final String user;
  final List<FakeLlmResponse> responses;

  /// `persona`: the current chat's persona for this turn (null: unchanged).
  final ChatPersona? persona;

  /// `caption`: the platform's reduce motion (`disableAnimations`).
  final bool reduceMotion;

  /// `caption`: the platform's text scale.
  final double textScale;

  /// `wardrobe`: a costume goes on, so the turn waits for its signature
  /// move's `gesture_done`.
  final bool signature;
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
    this.turns = const <_Turn>[],
    this.captionsOn = false,
  });

  /// M10: user turns played one after another ([responses] is all of
  /// theirs, in order); empty: the single [user] line.
  final List<_Turn> turns;

  /// M10 `caption`: captions are switched on before the run.
  final bool captionsOn;

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
  // M11 (ruling 7): the three v14 scenes.
  AvatarScene.forestCabin: _SceneRun(
    npcProp: 'squirrel',
    user: 'What a lovely porch.',
    reply: 'The squirrel thinks so too. It runs this whole yard.',
  ),
  AvatarScene.trainCompartment: _SceneRun(
    npcProp: 'ladybug',
    user: 'Where is this train going?',
    reply: 'Somewhere green. A ladybug is riding with us on the sill.',
  ),
  AvatarScene.library: _SceneRun(
    npcProp: 'mouse',
    user: 'Is that a mouse by the shelf?',
    reply: 'Shh, the mouse is reading. Or sleeping. Hard to tell.',
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

/// M10: a fixed noon in October (daylight; never December, whose festive
/// outfit rule would dress the default outfit).
final DateTime _m10Noon = DateTime(2026, 10, 31, 12);

/// M10: a turn's scripted responses (a `change_avatar` round first when
/// [avatarArgs] is given, then the spoken answer).
List<FakeLlmResponse> _turnResponses(
  String reply, {
  String mood = 'happy',
  Map<String, dynamic>? avatarArgs,
}) => <FakeLlmResponse>[
  if (avatarArgs != null)
    FakeLlmResponse(
      jsonBody: '',
      toolCalls: <FakeToolCall>[
        FakeToolCall(name: 'change_avatar', arguments: avatarArgs),
      ],
    ),
  FakeLlmResponse(jsonBody: _answer(reply, mood)),
];

/// M10: a multi-turn script (its responses are all of its turns').
_Script _turnScript(
  List<_Turn> turns, {
  bool defaultOutfit = false,
  bool captionsOn = false,
}) => _Script(
  scene: AvatarScene.livingRoom,
  rain: 0,
  user: turns.map((_Turn t) => t.user).join(' | '),
  pinnedAt: _m10Noon,
  defaultOutfit: defaultOutfit,
  captionsOn: captionsOn,
  frameInterval: const Duration(milliseconds: 100),
  turns: turns,
  responses: <FakeLlmResponse>[for (final _Turn t in turns) ...t.responses],
);

/// M10 `wardrobe`: the tints, then each costume (its signature after the
/// walk back), then back to the plain hoodie (the red beanie stays).
_Script _wardrobeScript() {
  _Turn costume(String name, String user, String reply) => _Turn(
    label: name,
    user: user,
    signature: true,
    responses: _turnResponses(
      reply,
      avatarArgs: <String, dynamic>{'costume': name},
    ),
  );
  return _turnScript(defaultOutfit: true, <_Turn>[
    _Turn(
      label: 'topTint blue',
      user: 'Can your hoodie be blue?',
      responses: _turnResponses(
        'Blue it is. Same hoodie, new colour.',
        avatarArgs: <String, dynamic>{'top': 'pinkHoodie', 'topTint': 'blue'},
      ),
    ),
    _Turn(
      label: 'hatTint red',
      user: 'Add a red beanie.',
      responses: _turnResponses(
        'A red beanie, nice and warm.',
        avatarArgs: <String, dynamic>{'hat': 'beanie', 'hatTint': 'red'},
      ),
    ),
    costume('batman', 'Be Batman!', 'I am the night.'),
    costume('robocop', 'Now Robocop.', 'Scanning. All clear.'),
    costume('soubrette', 'Try the soubrette.', 'Enchantée!'),
    costume('singularity', 'And the singularity?', 'I contain multitudes.'),
    _Turn(
      label: 'back to normal',
      user: 'Back to your plain hoodie.',
      responses: _turnResponses(
        'Back to normal, beanie and all.',
        avatarArgs: <String, dynamic>{'costume': 'none', 'topTint': 'none'},
      ),
    ),
  ]);
}

/// M10 `persona`: one reply with a yes, a list, an exclamation and a
/// question (every auto rule fires), spoken by three personas.
const String _personaReply =
    'Yes, I have a plan for your week. '
    'First rest, second walk, third read a little. '
    'You are going to love it! '
    'Shall we start tomorrow?';

_Script _personaScript() => _turnScript(<_Turn>[
  for (final ChatPersona p in <ChatPersona>[
    ChatPersona.doomer,
    ChatPersona.coach,
    ChatPersona.philosopher,
  ])
    _Turn(
      label: p.name,
      user: 'Plan my week?',
      persona: p,
      responses: _turnResponses(_personaReply),
    ),
]);

/// M10 `caption`: four sentences, short to long (the last one the longest a
/// bubble takes), three passes.
const String _captionReply =
    'Good morning! '
    'The sun is already over the rooftops. '
    'I made a pot of tea while you were away. '
    'Tell me, what would you like to do first today, read or go out?';

_Script _captionScript() => _turnScript(captionsOn: true, <_Turn>[
  _Turn(
    label: 'default',
    user: 'Morning!',
    responses: _turnResponses(_captionReply),
  ),
  _Turn(
    label: 'reduceMotion',
    user: 'Morning again!',
    reduceMotion: true,
    responses: _turnResponses(_captionReply),
  ),
  _Turn(
    label: 'textScale',
    user: 'And once more!',
    textScale: 1.6,
    responses: _turnResponses(_captionReply),
  ),
]);

final Map<String, _Script> _scripts = <String, _Script>{
  // Campfire at night, raining (world sync is M7–M9: the harness sets it;
  // M12 ruling 11: the clock is pinned to the night).
  'wow1': _Script(
    scene: AvatarScene.campfire,
    rain: 1,
    clock: (hour: 22, minute: 0),
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
  // M7 Wow #3 (v15): changing scene is a journey (living room → beach, the book),
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
  // M7 (v15): one journey per threshold family, no speech (book, path,
  // rocket, portal), in the morning.
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
  // M9 / M11: every ordered pair (90 over the ten scenes) back to back, no
  // speech, sparse frames.
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
  // M10: the wardrobe (tints, the four signatures), three personas, the
  // speech bubble (default, reduce motion, large text).
  'wardrobe': _wardrobeScript(),
  'persona': _personaScript(),
  'caption': _captionScript(),
};

/// Showcase scripts (2026-11-02), one short beat each, for the 9:16 showcase
/// cut: the same machinery as the wows, grabbing at ~30 fps. They live in
/// their own map because two of them re-time entries of [_scripts].
final Map<String, _Script> _showcaseScripts = <String, _Script>{
  // The greeting: a warm close-up moment with a wave.
  'show_hook': _showScript(
    scene: AvatarScene.livingRoom,
    rain: 0,
    clock: (hour: 19, minute: 30),
    user: 'Hi!',
    responses: <FakeLlmResponse>[
      FakeLlmResponse(
        jsonBody: _answer(
          "[g:wave] Oh, hi! You're just in time. "
              'The film is about to start.',
          'happy',
        ),
      ),
    ],
  ),
  // The weather beat: wow2's proven exchange, unchanged.
  'show_weather': _scriptAt(_scripts['wow2']!),
  // The journey beat: wow3's proven exchange, unchanged.
  'show_journey': _scriptAt(_scripts['wow3']!),
  // Rainy night by the fire, the owl out.
  'show_campfire': _showScript(
    scene: AvatarScene.campfire,
    rain: 1,
    clock: (hour: 22, minute: 0),
    user: "It's really coming down out there.",
    responses: <FakeLlmResponse>[
      FakeLlmResponse(
        jsonBody: _answer(
          'Listen to the rain on the leaves. '
              "The owl doesn't mind one bit.",
          'happy',
        ),
      ),
    ],
  ),
  // The train: the landscape scrolls by while it answers.
  'show_train': _showScript(
    scene: AvatarScene.trainCompartment,
    rain: 0,
    clock: (hour: 19, minute: 30),
    user: 'Where is this train going?',
    responses: <FakeLlmResponse>[
      FakeLlmResponse(
        jsonBody: _answer(
          'Somewhere green. The ladybug is riding with us.',
          'happy',
        ),
      ),
    ],
  ),
  // Deep space: pokes the UFO, spins the stars, then a short reply.
  'show_space': _showScript(
    scene: AvatarScene.deepSpace,
    rain: 0,
    clock: (hour: 19, minute: 30),
    user: 'Anyone else out here?',
    sceneRun: _sceneRuns[AvatarScene.deepSpace]!,
    responses: <FakeLlmResponse>[
      FakeLlmResponse(
        jsonBody: _answer(_sceneRuns[AvatarScene.deepSpace]!.reply, 'happy'),
      ),
    ],
  ),
  // The emotional finish: the beach at dusk, a calm complete sentence.
  'show_finish': _showScript(
    scene: AvatarScene.beach,
    rain: 0,
    clock: (hour: 18, minute: 40),
    user: "I'm glad we came.",
    responses: <FakeLlmResponse>[
      FakeLlmResponse(
        jsonBody: _answer(
          "Me too. Soon the moon will take the sun's place.",
          'happy',
        ),
      ),
    ],
  ),
};

/// Everything the WOW define can select (the showcase beats included).
final Map<String, _Script> _allScripts = <String, _Script>{
  ..._scripts,
  ..._showcaseScripts,
};

/// A showcase script: the wows' defaults at a 33 ms grab interval (~30 fps).
_Script _showScript({
  required AvatarScene scene,
  required double rain,
  required String user,
  required List<FakeLlmResponse> responses,
  ({int hour, int minute})? clock,
  _SceneRun? sceneRun,
}) => _Script(
  scene: scene,
  rain: rain,
  clock: clock,
  user: user,
  sceneRun: sceneRun,
  frameInterval: const Duration(milliseconds: 33),
  responses: responses,
);

/// Re-times an existing script at the showcase grab interval.
_Script _scriptAt(_Script script) => _Script(
  scene: script.scene,
  rain: script.rain,
  clock: script.clock,
  user: script.user,
  responses: script.responses,
  frameInterval: const Duration(milliseconds: 33),
);

/// M10: `change_avatar` for the harness's tool list (which replaces the
/// app's): the real [AvatarTool], built on first use (the lifecycle service
/// it talks to exists only once the service locator ran).
class _AvatarToolProxy extends AgentTool {
  late final AvatarTool _tool = AvatarTool(getIt<AppLifecycleService>());

  @override
  String get name => 'change_avatar';

  @override
  String get description => _tool.description;

  @override
  List<Parameter> get parameters => _tool.parameters;

  @override
  Map<String, String> get requiredConfigKeys => _tool.requiredConfigKeys;

  @override
  Future<dynamic> execute(
    Map<String, dynamic> args,
    Map<String, dynamic> configValues,
  ) => _tool.execute(args, configValues);
}

/// M10: how visible [element] is: the product of the opacities above it
/// (`Opacity` widgets and `FadeTransition`s), 0..1.
double _opacityOf(Element element) {
  double opacity = 1;
  element.visitAncestorElements((Element e) {
    final Widget w = e.widget;
    if (w is Opacity) {
      opacity *= w.opacity;
    } else if (w is FadeTransition) {
      opacity *= w.opacity.value;
    }
    return opacity > 0;
  });
  return opacity;
}

/// M10 `caption`: what the stage's caption shows now: the bubble (most
/// visible copy, its rect on screen) and the classic line, each visible at
/// an opacity of at least 0.5.
Map<String, Object?> _captionSample() {
  Element? best;
  double bestOpacity = 0;
  for (final Element e in find.byKey(StageCaptionBubble.bubbleKey).evaluate()) {
    final double o = _opacityOf(e);
    if (best == null || o > bestOpacity) {
      best = e;
      bestOpacity = o;
    }
  }
  Rect? rect;
  final RenderObject? box = best?.renderObject;
  if (box is RenderBox && box.hasSize && box.attached) {
    rect = box.localToGlobal(Offset.zero) & box.size;
  }
  double classic = 0;
  for (final Element e in find.byKey(StageCaption.lineKey).evaluate()) {
    classic = math.max(classic, _opacityOf(e));
  }
  final Iterable<Element> bubbles = find.byType(StageCaptionBubble).evaluate();
  final StageCaptionBubble? widget = bubbles.isEmpty
      ? null
      : bubbles.first.widget as StageCaptionBubble;
  final Offset? anchor = widget?.anchor.value;
  return <String, Object?>{
    'bubble': bestOpacity >= 0.5,
    'bubbleOpacity': bestOpacity,
    'bubbleRect': rect == null
        ? null
        : <double>[rect.left, rect.top, rect.width, rect.height],
    'bubbleFlag': widget?.shown.value,
    'classic': classic >= 0.5,
    'classicOpacity': classic,
    'anchor': anchor == null ? null : <double>[anchor.dx, anchor.dy],
  };
}

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
      // a fling toward the frame's centre (M11: the pinwheel sits by the
      // right edge, so it is flung left)
      final double toward =
          handle.rect.center.dx > SceneDrags.artboard.width / 2 ? -1 : 1;
      line(Offset(300 * toward, 0), 12);
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

  final String baseName = _wow == 'scene' ? 'scene_$_sceneArg' : _wow;
  final QualityTier? forcedTier = _tierArg.isEmpty
      ? null
      : QualityTier.values.byName(_tierArg);
  final String runName = forcedTier == null || forcedTier == QualityTier.ultra
      ? baseName
      : '${baseName}_${forcedTier.name}';

  testWidgets(
    'wow capture: $runName',
    (WidgetTester tester) async {
      final _Script script = _allScripts[_wow]!;
      final _NoNetwork network = _NoNetwork();
      HttpOverrides.global = network;
      // A failing step still restores the process (the explicit cleanup below
      // runs on success; both are idempotent).
      addTearDown(() {
        HttpOverrides.global = null;
        FakeLlmService().deactivate();
      });

      final Directory root = Directory(
        '${_showOut.isEmpty ? (await getTemporaryDirectory()).path : _showOut}'
        '/wow/$runName${_capture ? '' : '_timing'}',
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
      final KokoroCaptureSynthesizer? kokoro = _voiceArg == 'kokoro'
          ? KokoroCaptureSynthesizer(audioDir, modelSource: _kokoroSrc)
          : null;
      final TtsSynthesizer captureTts = kokoro ?? tts;
      final List<({DateTime at, String asset})> foleyLog =
          <({DateTime at, String asset})>[];
      final List<({DateTime at, String kind})> hapticLog =
          <({DateTime at, String kind})>[];
      if (kokoro != null) {
        // The fresh container has no model and the harness blocks network:
        // copy the host's installed model in before the app boots.
        await kokoro.ensureModel();
      }
      await setupServiceLocator(
        ttsSynthesizer: captureTts,
        tools: <AgentTool>[
          CannedWeatherTool(
            onReport: (WeatherReport r) =>
                getIt<TabletWeatherSource>().report(r),
          ),
          // M10 wardrobe: the real change_avatar
          _AvatarToolProxy(),
        ],
        foleyPlayer: () => _LoggingFoleyPlayer(foleyLog),
        haptics: _LoggingHaptics(hapticLog),
      );
      await bootstrapApp();
      await tester.pumpWidget(const App());
      if (Platform.isMacOS && _winPos.isNotEmpty) {
        // Keep the window visible: macOS stops rendering covered windows and
        // the grabs freeze (M12 execution notes). Park it on the second
        // display's free corner, where nothing covers it.
        final List<String> xy = _winPos
            .replaceAll('{', '')
            .replaceAll('}', '')
            .split(',');
        await Process.run('osascript', <String>[
          '-e',
          'tell application "System Events" to set position of window 1 of '
              '(first application process whose unix id is $pid) to '
              '{${xy[0].trim()}, ${xy[1].trim()}}',
        ]);
        if (_winSize.isNotEmpty) {
          final List<String> wh = _winSize
              .replaceAll('{', '')
              .replaceAll('}', '')
              .split(',');
          await Process.run('osascript', <String>[
            '-e',
            'tell application "System Events" to set size of window 1 of '
                '(first application process whose unix id is $pid) to '
                '{${wh[0].trim()}, ${wh[1].trim()}}',
          ]);
        }
      }
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
      final CaptionCubit captions = home.read<CaptionCubit>();
      if (script.captionsOn && !captions.state.enabled) {
        await captions.toggle();
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
      // After the clock: `applyWeather` sets the rain from its report.
      world.setRain(script.rain);
      if (forcedTier != null) {
        final QualityTierService quality = getIt<QualityTierService>();
        quality.forceTier(forcedTier);
        addTearDown(() => quality.forceTier(null));
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
      int lastStart = -1;
      int lastSpeechActivity = -1;
      final StreamSubscription<PlaybackEvent> playback =
          getIt<TtsPlaybackService>().events.listen((PlaybackEvent e) {
            switch (e) {
              case SpeakingStartedEvent():
                speaking = true;
                spoke = true;
                lastStart = clock.elapsedMilliseconds;
                lastSpeechActivity = clock.elapsedMilliseconds;
                log('start');
              case SpeakingStoppedEvent(:final bool interrupted):
                speaking = false;
                lastStop = clock.elapsedMilliseconds;
                lastSpeechActivity = clock.elapsedMilliseconds;
                log('stop', <String, Object?>{'interrupted': interrupted});
              case SpeechPrerollEvent(:final Duration lead):
                // the inhale before a sentence: while it settles the next
                // sentence is still synthesising, so the final wait measures
                // from the last speech activity, not the last stop
                lastSpeechActivity = clock.elapsedMilliseconds;
                log('preroll', <String, Object?>{'lead': lead.inMilliseconds});
              case CaptionEvent(:final String text):
                log('caption', <String, Object?>{'text': text});
              default:
                break;
            }
          });
      // M9: every scene event played (a drag's action, a journey's)
      int sceneEventSeq = avatar.state.sceneEvent.seq;
      // M10: every gesture sent to the avatar file (its `gesture` trigger)
      int gestureSeq = avatar.state.gestureEvent.seq;
      int lastSignature = -1;
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
        if (s.gestureEvent.seq != gestureSeq) {
          gestureSeq = s.gestureEvent.seq;
          if (s.gestureEvent.gesture == AvatarGesture.signature) {
            lastSignature = clock.elapsedMilliseconds;
          }
          log('gesture', <String, Object?>{
            'name': s.gestureEvent.gesture.name,
            'costume': s.avatar.costume.name,
          });
        }
      });
      // M10: the avatar file read back (the live avatar view's state), and
      // its `gesture_done` / `presence_done` events, polled per sample
      AvatarFileReadBack? avatarFile;
      int avatarLookups = 0;
      AvatarFileReadBack? avatarFileNow() {
        if (avatarFile == null || avatarLookups++ % 30 == 0) {
          final Iterable<Element> found = find
              .byType(RiveAvatarView)
              .evaluate();
          final Element? e = found.isEmpty ? null : found.first;
          avatarFile = e is StatefulElement && e.state is AvatarFileReadBack
              ? e.state as AvatarFileReadBack
              : null;
        }
        return avatarFile;
      }

      int gestureDones = 0;
      int presenceDones = 0;
      int lastGestureDone = -1;
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
        final AvatarFileReadBack? vm = avatarFileNow();
        if (vm != null) {
          // the file's own events (a new view counts from 0 again)
          if (vm.gestureDoneCount < gestureDones) {
            gestureDones = 0;
          }
          if (vm.presenceDoneCount < presenceDones) {
            presenceDones = 0;
          }
          for (; gestureDones < vm.gestureDoneCount; gestureDones++) {
            lastGestureDone = clock.elapsedMilliseconds;
            log('gestureDone', <String, Object?>{
              'gestureId': vm.enumValue(AvatarRiveContract.propGestureId),
            });
          }
          for (; presenceDones < vm.presenceDoneCount; presenceDones++) {
            log('presenceDone', <String, Object?>{
              'presence': avatar.state.presence.name,
            });
          }
        }
        final ({int top, int hat}) tintWant = AvatarTintWriter.colorsFor(shown);
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
          // M10: the wardrobe and the persona's body, as written and as the
          // avatar file holds them
          'costume': shown.costume.name,
          'topTint': shown.topTint.name,
          'hatTint': shown.hatTint.name,
          'tintTopWant': tintWant.top,
          'tintHatWant': tintWant.hat,
          'vmTopTint': vm?.colorValue(AvatarRiveContract.propTopTint),
          'vmHatTint': vm?.colorValue(AvatarRiveContract.propHatTint),
          'vmCostume': vm?.enumValue(AvatarRiveContract.propCostume),
          'vmTop': vm?.enumValue(AvatarRiveContract.propTop),
          'vmHat': vm?.enumValue(AvatarRiveContract.propHat),
          'vmGesture': vm?.enumValue(AvatarRiveContract.propGestureId),
          'vmLean': vm?.numberValue(AvatarRiveContract.propLean),
          'vmPitch': vm?.numberValue(AvatarRiveContract.propPitch),
          'vmRoll': vm?.numberValue(AvatarRiveContract.propRoll),
          'faceLean': face.lean,
          'faceRoll': face.roll,
          'nodPitch': face.nodPitch,
          'persona': chat.state.currentChat.persona.name,
          'chatStatus': chat.state.status.name,
          'gestureSerial': intent.gestureSerial,
          'captionSeq': captions.state.seq,
          'captionOn':
              captions.state.enabled && (captions.state.text ?? '').isNotEmpty,
          if (_wow == 'caption') ..._captionSample(),
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
        pixelRatio: _pixelRatio,
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
      // M10: the user turns, one after another, each to its end
      bool reducedMotion = false;
      double textScale = 1;
      addTearDown(() {
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });
      for (int k = 0; k < script.turns.length; k++) {
        final _Turn turn = script.turns[k];
        final ChatPersona? persona = turn.persona;
        if (persona != null) {
          // the current chat's persona (as a chat started with it): the
          // avatar's body language follows it through the lifecycle service
          final Chat c = chat.state.currentChat.copyWith(persona: persona);
          chat.setOpenedChat(c);
          chat.setCurrentChat(c);
        }
        if (turn.reduceMotion != reducedMotion) {
          reducedMotion = turn.reduceMotion;
          if (reducedMotion) {
            tester.platformDispatcher.accessibilityFeaturesTestValue =
                const FakeAccessibilityFeatures(disableAnimations: true);
          } else {
            tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
          }
        }
        if (turn.textScale != textScale) {
          textScale = turn.textScale;
          if (textScale == 1) {
            tester.platformDispatcher.clearTextScaleFactorTestValue();
          } else {
            tester.platformDispatcher.textScaleFactorTestValue = textScale;
          }
        }
        await _settle(tester, const Duration(milliseconds: 1500));
        final int turnStart = clock.elapsedMilliseconds;
        final ChatPersona current = chat.state.currentChat.persona;
        log('turn', <String, Object?>{
          'i': k,
          'label': turn.label,
          'persona': current.name,
          'profileArmed': director.profile == BodyLanguageProfile.of(current),
          'reduceMotion': reducedMotion,
          'textScale': textScale,
          'signature': turn.signature,
        });
        final int remainingAfter =
            FakeLlmService().remainingResponses - turn.responses.length;
        log('typing', <String, Object?>{'turn': k});
        // the previous send unfocused the field: a tap focuses it again (a
        // fresh text input connection for the typed text)
        await tester.tap(field);
        await _settle(tester, const Duration(milliseconds: 300));
        for (int i = 1; i <= turn.user.length; i++) {
          await tester.enterText(field, turn.user.substring(0, i));
          await tester.pump();
          await Future<void>.delayed(const Duration(milliseconds: 70));
        }
        await _settle(tester, const Duration(milliseconds: 400));
        log('send', <String, Object?>{
          'turn': k,
          'field': tester.widget<TextField>(field).controller?.text,
          'chatStatus': chat.state.status.name,
        });
        await tester.testTextInput.receiveAction(TextInputAction.send);
        // until the reply is spoken, the avatar is back on screen and (a
        // costume put on) its signature has played: at most 6 s more for it
        final int by = clock.elapsedMilliseconds + 45000;
        int? readyAt;
        while (clock.elapsedMilliseconds < by) {
          await tester.pump();
          await Future<void>.delayed(const Duration(milliseconds: 100));
          final int now = clock.elapsedMilliseconds;
          final bool ready =
              FakeLlmService().remainingResponses <= remainingAfter &&
              lastStart >= turnStart &&
              !speaking &&
              avatar.state.journey == null &&
              avatar.state.presence == AvatarSpecials.onScreen &&
              now - lastStop > 1500;
          if (!ready) {
            readyAt = null;
            continue;
          }
          readyAt ??= now;
          final bool signed =
              lastSignature >= turnStart && lastGestureDone > lastSignature;
          if (!turn.signature || signed || now - readyAt > 6000) {
            break;
          }
        }
        await _settle(tester, const Duration(milliseconds: 800));
        log('turnEnd', <String, Object?>{'i': k, 'label': turn.label});
      }
      final bool oneLine = script.tour.isEmpty && script.turns.isEmpty;
      if (oneLine) {
        log('typing');
      }
      for (int i = 1; oneLine && i <= script.user.length; i++) {
        await tester.enterText(field, script.user.substring(0, i));
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 90));
      }
      if (script.turns.isEmpty) {
        await _settle(tester, const Duration(milliseconds: 500));
        log('send');
      }
      if (oneLine) {
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
            clock.elapsedMilliseconds - lastStop > 1800 &&
            clock.elapsedMilliseconds - lastSpeechActivity > 1800) {
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
      _printLiveness(root, grabber);

      // The timeline is written twice: this early snapshot, and the final one
      // after the foley log and the wet / dry grabs below. The early one is
      // what a host-side sync reads when the app's container is wiped at the
      // end of the test (iOS simulator installs are removed on teardown).
      Map<String, Object?> timelineSnapshot() => <String, Object?>{
        'wow': runName,
        'kind': _wow,
        'capture': _capture,
        'tier': forcedTier?.name,
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
        'turns': <Map<String, Object?>>[
          for (final _Turn t in script.turns)
            <String, Object?>{
              'label': t.label,
              'user': t.user,
              'persona': t.persona?.name,
              'reduceMotion': t.reduceMotion,
              'textScale': t.textScale,
              'signature': t.signature,
            },
        ],
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
          for (final ({String text, String file}) a
              in (kokoro?.spoken ?? tts.spoken))
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
      File('${root.path}/timeline.json').writeAsStringSync(
        const JsonEncoder.withIndent(' ').convert(timelineSnapshot()),
      );
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

      File('${root.path}/timeline.json').writeAsStringSync(
        const JsonEncoder.withIndent(' ').convert(timelineSnapshot()),
      );
      // ignore: avoid_print
      print('WOW_DIR ${root.path}');

      expect(spoke, isTrue, reason: 'the reply was never spoken');
      expect(network.attempts, 0, reason: network.urls.join('\n'));
    },
    timeout: Timeout(
      _wow == 'pairs'
          ? const Duration(minutes: 35)
          : _wow == 'wardrobe'
          ? const Duration(minutes: 8)
          : const Duration(minutes: 5),
    ),
  );
}

/// Prints how many of five sampled grabs are byte-distinct, so a frozen
/// window (macOS occlusion) or a stalled simulator shows up in the log.
void _printLiveness(Directory root, FrameGrabber grabber) {
  final int count = grabber.frames.length;
  if (count == 0) {
    // ignore: avoid_print
    print('LIVENESS 0 of 5 (no frames)');
    return;
  }
  final Set<String> seen = <String>{};
  for (int k = 0; k < 5; k++) {
    final ({int index, int ms}) frame =
        grabber.frames[count * (2 * k + 1) ~/ 10];
    final File file = File(
      '${root.path}/frames/${frame.index.toString().padLeft(4, '0')}.rgba',
    );
    final RandomAccessFile handle = file.openSync();
    final Uint8List head = handle.readSync(8192);
    handle.setPositionSync(handle.lengthSync() ~/ 2);
    final Uint8List middle = handle.readSync(8192);
    handle.closeSync();
    seen.add(base64Encode(head) + base64Encode(middle));
  }
  // ignore: avoid_print
  print('LIVENESS distinct ${seen.length} of 5');
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
