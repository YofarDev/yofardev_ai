/// Constants mirroring `rive/CONTRACT.md`, the single source of truth shared
/// with the asset agent (Plan A).
///
/// Names are case-sensitive and must match the `.riv` files exactly. Any
/// contract change happens in `rive/CONTRACT.md` first, then here.
library;

abstract final class AvatarRiveContract {
  // ── assets/rive/avatar.riv ────────────────────────────────────────────────
  static const String avatarAssetPath = 'assets/rive/avatar.riv';
  static const String avatarArtboard = 'Avatar';
  static const String avatarStateMachine = 'Main';
  static const String avatarViewModel = 'AvatarVM';

  // View model properties.
  static const String propMood = 'mood';
  static const String propMouth = 'mouth';
  static const String propPhase = 'phase';
  static const String propGestureId = 'gestureId';
  static const String propGestureTrigger = 'gesture';
  static const String propHat = 'hat';
  static const String propTop = 'top';
  static const String propGlasses = 'glasses';
  static const String propCostume = 'costume';
  static const String propPresence = 'presence';

  // 2.5D head rig numbers (all −1..1). `yaw`/`pitch` are the head turn
  // (+yaw toward the viewer's right, +pitch up); `hairLag*` are the hair's
  // offset from the head (0 = locked); `eyeLeadYaw` is extra iris shift;
  // `eyeLeadPitch` the held vertical look (+ = up, negative drops the lids).
  static const String propYaw = 'yaw';
  static const String propPitch = 'pitch';
  static const String propHairLagYaw = 'hairLagYaw';
  static const String propHairLagPitch = 'hairLagPitch';
  static const String propEyeLeadYaw = 'eyeLeadYaw';
  static const String propEyeLeadPitch = 'eyeLeadPitch';

  // Contract v5 face: FACS-lite action units (all 0..1, additive,
  // history-free), the speech mouth extras, head roll and breath.
  static const String propAuBrowInnerUp = 'auBrowInnerUp';
  static const String propAuBrowOuterUp = 'auBrowOuterUp';
  static const String propAuBrowLower = 'auBrowLower';
  static const String propAuLidTighten = 'auLidTighten';
  static const String propAuUpperLidRaise = 'auUpperLidRaise';
  static const String propAuCheekRaise = 'auCheekRaise';
  static const String propAuNoseWrinkle = 'auNoseWrinkle';
  static const String propAuLipCornerPull = 'auLipCornerPull';
  static const String propAuLipCornerDepress = 'auLipCornerDepress';
  static const String propAuLipStretch = 'auLipStretch';
  static const String propAuLipPucker = 'auLipPucker';
  static const String propAuLipPress = 'auLipPress';
  static const String propAuJawDrop = 'auJawDrop';
  static const String propAuDimpler = 'auDimpler';
  static const String propLipTuck = 'lipTuck';
  static const String propTongueUp = 'tongueUp';
  static const String propRoll = 'roll';
  static const String propBreath = 'breath';
  static const String propAutoBlink = 'autoBlink';
  static const String propBlinkTrigger = 'blink';

  /// The 14 action-unit numbers, in `ActionUnits` field order.
  static const List<String> actionUnitProps = <String>[
    propAuBrowInnerUp,
    propAuBrowOuterUp,
    propAuBrowLower,
    propAuLidTighten,
    propAuUpperLidRaise,
    propAuCheekRaise,
    propAuNoseWrinkle,
    propAuLipCornerPull,
    propAuLipCornerDepress,
    propAuLipStretch,
    propAuLipPucker,
    propAuLipPress,
    propAuJawDrop,
    propAuDimpler,
  ];

  // Contract v6: signed per-side offsets (−1..1) for seven AUs, added to the
  // symmetric AU on the viewer's left (`L`) or right (`R`) side; the file
  // clamps the sum to 0..1.
  static const String propAuBrowInnerUpL = 'auBrowInnerUpL';
  static const String propAuBrowInnerUpR = 'auBrowInnerUpR';
  static const String propAuBrowOuterUpL = 'auBrowOuterUpL';
  static const String propAuBrowOuterUpR = 'auBrowOuterUpR';
  static const String propAuBrowLowerL = 'auBrowLowerL';
  static const String propAuBrowLowerR = 'auBrowLowerR';
  static const String propAuLidTightenL = 'auLidTightenL';
  static const String propAuLidTightenR = 'auLidTightenR';
  static const String propAuCheekRaiseL = 'auCheekRaiseL';
  static const String propAuCheekRaiseR = 'auCheekRaiseR';
  static const String propAuLipCornerPullL = 'auLipCornerPullL';
  static const String propAuLipCornerPullR = 'auLipCornerPullR';
  static const String propAuLipCornerDepressL = 'auLipCornerDepressL';
  static const String propAuLipCornerDepressR = 'auLipCornerDepressR';

  /// The 7 viewer's-left offsets, in `ActionUnitSides` field order.
  static const List<String> actionUnitLeftProps = <String>[
    propAuBrowInnerUpL,
    propAuBrowOuterUpL,
    propAuBrowLowerL,
    propAuLidTightenL,
    propAuCheekRaiseL,
    propAuLipCornerPullL,
    propAuLipCornerDepressL,
  ];

  /// The 7 viewer's-right offsets, in `ActionUnitSides` field order.
  static const List<String> actionUnitRightProps = <String>[
    propAuBrowInnerUpR,
    propAuBrowOuterUpR,
    propAuBrowLowerR,
    propAuLidTightenR,
    propAuCheekRaiseR,
    propAuLipCornerPullR,
    propAuLipCornerDepressR,
  ];

  /// All 14 v6 side offsets: the left ones, then the right ones.
  static const List<String> actionUnitSideProps = <String>[
    ...actionUnitLeftProps,
    ...actionUnitRightProps,
  ];

  // Contract v7: the light rig (colours are ARGB view-model colours, the
  // numbers are written once per scene change), the held prop and the
  // listening lean. `lean` (0..1) is written by the face writer.
  static const String propLightKey = 'lightKey';
  static const String propLightKeyIntensity = 'lightKeyIntensity';
  static const String propLightKeyX = 'lightKeyX';
  static const String propLightKeyY = 'lightKeyY';
  static const String propLightRim = 'lightRim';
  static const String propLightRimIntensity = 'lightRimIntensity';
  static const String propLightAmbient = 'lightAmbient';
  static const String propLightAmbientAmount = 'lightAmbientAmount';
  static const String propLightFlicker = 'lightFlicker';
  static const String propProp = 'prop';
  static const String propLean = 'lean';

  // Contract v11: the held jacket (boolean, flipped at a `grab` contact), the
  // tablet's weather card (enum [tabletWeatherValues]) and its temperature
  // (number, °C, rounded by the app, [tabletTempMin]..[tabletTempMax]).
  static const String propJacket = 'jacket';
  static const String propTabletWeather = 'tabletWeather';
  static const String propTabletTemp = 'tabletTemp';
  static const double tabletTempMin = -40;
  static const double tabletTempMax = 50;

  // Contract v13: the wardrobe's colour variants (ARGB colours, default
  // `00000000` = none: drawn with blend mode color over the top's / hat's
  // painted shapes; the app writes alpha 0 while a costume is worn) and the
  // mouth's named node (its world translation anchors the speech bubble).
  static const String propTopTint = 'topTint';
  static const String propHatTint = 'hatTint';
  static const String mouthAnchorNode = 'MouthAnchor';

  /// The v7 light numbers on `AvatarVM`, in `LightRig` field order.
  static const List<String> lightNumberProps = <String>[
    propLightKeyIntensity,
    propLightKeyX,
    propLightKeyY,
    propLightRimIntensity,
    propLightAmbientAmount,
    propLightFlicker,
  ];

  /// The v7 light colours on `AvatarVM`.
  static const List<String> lightColorProps = <String>[
    propLightKey,
    propLightRim,
    propLightAmbient,
  ];

  // Enum values, in contract order. On the SM-input fallback an enum property
  // becomes a number: its index in these lists.
  static const List<String> moodValues = <String>[
    'neutral',
    'happy',
    'sad',
    'angry',
    'surprised',
    'thinking',
    'embarrassed',
  ];
  static const List<String> gestureIdValues = <String>[
    'wave',
    'laugh',
    'facepalm',
    'shrug',
    'nod',
    'headshake',
    'clap',
    'think',
    'thumbsUp',
    'count',
    'grab',
    'signature',
  ];
  static const List<String> phaseValues = <String>[
    'idle',
    'waiting',
    'generating',
    'speaking',
    'error',
  ];
  static const List<String> hatValues = <String>[
    'noHat',
    'beanie',
    'backwardsCap',
    'frenchBeret',
    'swimCap',
    'santaHat',
    'redMagaCap',
  ];
  static const List<String> topValues = <String>[
    'pinkHoodie',
    'longCoat',
    'tshirt',
    'underwear',
    'swimsuit',
    'christmasSweater',
    'blackSuitAndTie',
  ];
  static const List<String> glassesValues = <String>['glasses', 'sunglasses'];
  static const List<String> costumeValues = <String>[
    'none',
    'batman',
    'robocop',
    'soubrette',
    'singularity',
  ];
  static const List<String> propValues = <String>[
    'none',
    'tablet',
    'newspaper',
  ];
  static const List<String> tabletWeatherValues = <String>[
    'none',
    'clear',
    'clouds',
    'rain',
    'snow',
    'storm',
    'fog',
  ];
  static const List<String> presenceValues = <String>[
    'onScreen',
    'outOfScreen',
    'leaveAndComeBack',
  ];

  /// `mouth` number range (closed, slightly, semi, open, wide).
  static const double mouthMin = 0;
  static const double mouthMax = 4;

  /// Range of `yaw` and `pitch`.
  static const double yawMin = -1;
  static const double yawMax = 1;
  static const double pitchMin = -1;
  static const double pitchMax = 1;

  /// Range of `hairLagYaw` and `hairLagPitch`.
  static const double hairLagMin = -1;
  static const double hairLagMax = 1;

  /// Range of `eyeLeadYaw` and `eyeLeadPitch`.
  static const double eyeLeadMin = -1;
  static const double eyeLeadMax = 1;

  /// Range of every `au*` number, `lipTuck`, `tongueUp` and `breath`.
  static const double faceMin = 0;
  static const double faceMax = 1;

  /// Range of the v6 `au<Name>L` / `au<Name>R` side offsets.
  static const double sideMin = -1;
  static const double sideMax = 1;

  /// Range of `lean`, the light intensities, `lightAmbientAmount` and
  /// `lightFlicker`.
  static const double leanMin = 0;
  static const double leanMax = 1;

  /// Range of `lightKeyX` / `lightKeyY` and of the scene's parallax numbers.
  static const double lightDirMin = -1;
  static const double lightDirMax = 1;

  /// Range of `roll`.
  static const double rollMin = -1;
  static const double rollMax = 1;

  // Rive events emitted by avatar.riv.
  static const String eventAvatarTapped = 'avatar_tapped';
  static const String eventGestureDone = 'gesture_done';
  static const String eventPresenceDone = 'presence_done';

  /// v11: a sound belongs to this frame (footfall, cloth, latch, paper).
  static const String eventFoley = 'foley';
  static const String avatarEventKindProperty = 'kind';
  static const String foleyStep = 'step';
  static const String foleyCloth = 'cloth';
  static const String foleyClick = 'click';
  static const String foleyPaper = 'paper';
  static const List<String> foleyKinds = <String>[
    foleyStep,
    foleyCloth,
    foleyClick,
    foleyPaper,
  ];
  static const String avatarEventZoneProperty = 'zone';
  static const String avatarEventGestureIdProperty = 'gestureId';
  static const String avatarEventPresenceProperty = 'presence';
  static const String zoneHead = 'head';
  static const String zoneBody = 'body';

  // ── assets/rive/scenes/<sceneId>.riv ──────────────────────────────────────
  static const String scenesAssetDir = 'assets/rive/scenes';
  static const String sceneArtboard = 'Scene';
  static const String sceneStateMachine = 'Main';
  static const String sceneViewModel = 'SceneVM';
  static const String scenePropEventId = 'eventId';
  static const String scenePropEventTrigger = 'event';

  // Contract v7 `SceneVM`: the parallax numbers (−1..1, default 0) and the
  // scene's own light defaults (the app does not write these: it writes the
  // same rig to `AvatarVM`; the fog is scene-only).
  static const String scenePropParallaxX = 'parallaxX';
  static const String scenePropParallaxY = 'parallaxY';
  static const String scenePropLightFog = 'lightFog';

  /// Contract v8 `SceneVM`: steady rain intensity (0..1, default 0), written
  /// from the app's world state; a scene without rain art ignores it.
  static const String scenePropRain = 'rain';

  /// Contract v9: the optional artboard drawn above the avatar (weather in
  /// front of it), with its own `Main` state machine and the same `SceneVM`.
  static const String sceneFrontArtboard = 'SceneFront';

  /// The scenes whose file has a [sceneFrontArtboard] (rooftop since v12,
  /// forestCabin since v14).
  static const Set<String> sceneFrontScenes = <String>{
    'campfire',
    'beach',
    'rooftop',
    'forestCabin',
  };

  /// Contract v10 `SceneVM`: the time of day (0..1, default 0), written from
  /// the app's world clock. `daylight` 0 is night, 1 full day; `dusk` peaks
  /// at sunrise and sunset. deepSpace ignores both.
  static const String scenePropDaylight = 'daylight';
  static const String scenePropDusk = 'dusk';

  /// Contract v11 `SceneVM`: weather fog (0..1, default 0; deepSpace ignores
  /// it) and the scene's NPC: its state (enum [npcValues], default `rest`),
  /// where along its path it is (`npcX`, 0..1) and where it looks
  /// (`npcLook`, −1..1, + = the viewer's right).
  static const String scenePropFog = 'fog';
  static const String scenePropNpc = 'npc';
  static const String scenePropNpcX = 'npcX';
  static const String scenePropNpcLook = 'npcLook';
  static const List<String> npcValues = <String>[
    'away',
    'rest',
    'idle',
    'move',
    'notice',
    'react',
  ];

  /// Contract v12 `SceneVM`: the second NPC slot (beach's gulls; the other
  /// scenes declare and ignore it). Same values and meaning as [scenePropNpc],
  /// [scenePropNpcX] and [scenePropNpcLook]; `npc2` defaults to `away`.
  static const String scenePropNpc2 = 'npc2';
  static const String scenePropNpc2X = 'npc2X';
  static const String scenePropNpc2Look = 'npc2Look';

  /// Contract v12 `SceneVM`: the moon phase (number; [moonPhaseDefault] = the
  /// moon as drawn before v12, 0..1 = that phase: 0 new, 0.25 first quarter,
  /// 0.5 full, 0.75 last quarter) and December dressing (0..1, default 0).
  static const String scenePropMoonPhase = 'moonPhase';
  static const String scenePropFestive = 'festive';
  static const double moonPhaseDefault = -1;
  static const double moonPhaseMin = 0;
  static const double moonPhaseMax = 1;
  static const double festiveMin = 0;
  static const double festiveMax = 1;

  /// Contract v13 `SceneVM`: how much of the night shows (0..1, default 0 =
  /// the v12 look), written as `(1 − daylight) × (1 − dusk)`; the beach binds
  /// it, every other scene declares and ignores it.
  static const String scenePropNight = 'night';

  /// Contract v14 `SceneVM`: the device's quality tier (enum [tierValues],
  /// default [tierDefault] = the v13 look), written by the app on every scene
  /// load and tier change (M11 ruling 13); an older file without it ignores
  /// the write.
  static const String scenePropTier = 'tier';
  static const List<String> tierValues = <String>['low', 'high', 'ultra'];
  static const String tierDefault = 'ultra';

  /// Contract v14 `SceneVM`: seasonal dressing (0..1, default 0 = the v13
  /// look), written from the local date (M11 ruling 9). forestCabin,
  /// campfire, livingRoom and trainCompartment bind them; the others declare
  /// and ignore them.
  static const String scenePropSpring = 'spring';
  static const String scenePropAutumn = 'autumn';
  static const double seasonMin = 0;
  static const double seasonMax = 1;

  // Contract v12 drag handle numbers on `SceneVM` (table in CONTRACT.md):
  // each scene declares only its own; the app writes them every frame.
  /// livingRoom `cord` (pull): 0..1.
  static const String scenePropCord = 'cord';

  /// campfire `poke`: 0..1 the stick shows; `pokeX` / `pokeY` −1..1 the tip.
  static const String scenePropPoke = 'poke';
  static const String scenePropPokeX = 'pokeX';
  static const String scenePropPokeY = 'pokeY';

  /// beach `sand` and cafe `wipe` (trail): 0..[trailMaxDots] dots drawn,
  /// their artboard-px positions, and 0..1 fade (1 = gone).
  static const String scenePropTrailN = 'trailN';
  static const String scenePropTrailFade = 'trailFade';
  static const int trailMaxDots = 16;

  /// `trailX0`…`trailX15`.
  static const List<String> scenePropTrailX = <String>[
    'trailX0',
    'trailX1',
    'trailX2',
    'trailX3',
    'trailX4',
    'trailX5',
    'trailX6',
    'trailX7',
    'trailX8',
    'trailX9',
    'trailX10',
    'trailX11',
    'trailX12',
    'trailX13',
    'trailX14',
    'trailX15',
  ];

  /// `trailY0`…`trailY15`.
  static const List<String> scenePropTrailY = <String>[
    'trailY0',
    'trailY1',
    'trailY2',
    'trailY3',
    'trailY4',
    'trailY5',
    'trailY6',
    'trailY7',
    'trailY8',
    'trailY9',
    'trailY10',
    'trailY11',
    'trailY12',
    'trailY13',
    'trailY14',
    'trailY15',
  ];

  /// deepSpace `spin`: 0..1 = one revolution of the planet's bands (wraps).
  static const String scenePropSpin = 'spin';

  /// rooftop `aim`: −1..1, the telescope's swivel (±35°).
  static const String scenePropAim = 'aim';

  /// mountainHut `rope` (pull): 0..1.
  static const String scenePropRope = 'rope';

  /// forestCabin `pinwheel` (spin, v14): 0..1 = one turn (wraps).
  static const String scenePropPinwheel = 'pinwheel';

  /// trainCompartment `chain` (pull, v14): 0..1.
  static const String scenePropChain = 'chain';

  /// library `ladder` (aim, v14): −1..1, the ladder along its rail.
  static const String scenePropLadder = 'ladder';

  /// Every v12 drag number, by scene (the numbers a scene declares for its
  /// drag handle; defaults render the scene as it was in v11).
  static const Map<String, List<String>> sceneDragProps =
      <String, List<String>>{
        'livingRoom': <String>[scenePropCord],
        'campfire': <String>[scenePropPoke, scenePropPokeX, scenePropPokeY],
        'beach': <String>[
          scenePropTrailN,
          scenePropTrailFade,
          ...scenePropTrailX,
          ...scenePropTrailY,
        ],
        'deepSpace': <String>[scenePropSpin],
        'cafe': <String>[
          scenePropTrailN,
          scenePropTrailFade,
          ...scenePropTrailX,
          ...scenePropTrailY,
        ],
        'rooftop': <String>[scenePropAim],
        'mountainHut': <String>[scenePropRope],
        'forestCabin': <String>[scenePropPinwheel],
        'trainCompartment': <String>[scenePropChain],
        'library': <String>[scenePropLadder],
      };

  /// Names `SceneVM` carries as light defaults (equal to `AvatarVM`'s, plus
  /// `lightFog`, minus `lightAmbientAmount`).
  static const List<String> sceneLightProps = <String>[
    propLightKey,
    propLightKeyIntensity,
    propLightKeyX,
    propLightKeyY,
    propLightRim,
    propLightRimIntensity,
    propLightAmbient,
    scenePropLightFog,
    propLightFlicker,
  ];
  static const String eventPropTapped = 'prop_tapped';
  static const String sceneEventPropIdProperty = 'propId';

  /// Scene ids (file names are `<sceneId>.riv`).
  static const List<String> sceneIds = <String>[
    'livingRoom',
    'campfire',
    'beach',
    'deepSpace',
    'cafe',
    'rooftop',
    'mountainHut',
    'forestCabin',
    'trainCompartment',
    'library',
  ];
  static const String defaultSceneId = 'livingRoom';

  /// Every scene's allowed `eventId` values, and its tappable `propId`s.
  static const Map<String, List<String>> sceneEvents = <String, List<String>>{
    'livingRoom': <String>['lightsOff', 'lightsOn', 'tvOn', 'catWalksBy'],
    'campfire': <String>['flare', 'rain', 'shootingStar', 'owlHoot'],
    'beach': <String>['bigWave', 'seagulls', 'sunset', 'rain'],
    'deepSpace': <String>['meteor', 'warp', 'alienShip', 'nebulaPulse'],
    'cafe': <String>['espresso', 'doorbell', 'rain', 'neonFlicker'],
    'rooftop': <String>['fireworks', 'plane', 'shootingStar', 'windowsLit'],
    'mountainHut': <String>['snowfall', 'flare', 'aurora', 'bell'],
    'forestCabin': <String>['gust', 'fireflies', 'rain', 'lanternFlicker'],
    'trainCompartment': <String>['tunnel', 'whistle', 'station', 'rain'],
    'library': <String>['lightning', 'bookFlutter', 'clockChime', 'rain'],
  };
  static const Map<String, List<String>> sceneProps = <String, List<String>>{
    'livingRoom': <String>['lamp', 'tv', 'cat', 'plant'],
    'campfire': <String>['fire', 'tent', 'owl', 'sky'],
    'beach': <String>['crab', 'umbrella', 'seagull'],
    'deepSpace': <String>['planet', 'ufo', 'rubberDuck'],
    'cafe': <String>['cup', 'espresso', 'window', 'fish'],
    'rooftop': <String>['telescope', 'antenna', 'pigeon', 'moon'],
    'mountainHut': <String>['stove', 'window', 'dog', 'bell'],
    'forestCabin': <String>['lantern', 'pinwheel', 'squirrel', 'woodpile'],
    'trainCompartment': <String>['window', 'lamp', 'suitcase', 'ladybug'],
    'library': <String>['book', 'globe', 'clock', 'mouse'],
  };

  /// Asset path for a scene id.
  static String sceneAssetPath(String sceneId) =>
      '$scenesAssetDir/$sceneId.riv';

  /// Scene posters (v12): one `<sceneId>.webp` per scene, rendered from the
  /// scene's rest pose, [posterWidth]×[posterHeight], at most
  /// [posterMaxBytes] each.
  static const String postersAssetDir = 'assets/rive/posters';
  static const int posterWidth = 540;
  static const int posterHeight = 960;
  static const int posterMaxBytes = 40 * 1024;

  /// Poster asset path for a scene id.
  static String posterAssetPath(String sceneId) =>
      '$postersAssetDir/$sceneId.webp';

  // ── assets/rive/journeys/journey.riv (contract v10) ──────────────────────
  static const String journeyAssetPath = 'assets/rive/journeys/journey.riv';
  static const String journeyArtboard = 'Journey';
  static const String journeyStateMachine = 'Main';
  static const String journeyViewModel = 'JourneyVM';

  /// How much of each threshold shows (0..1); one at a time.
  static const String journeyPropDoor = 'door';
  static const String journeyPropPath = 'path';
  static const String journeyPropPortal = 'portal';
  static const String journeyPropRocket = 'rocket';

  /// The shown threshold opens (0..1).
  static const String journeyPropOpen = 'open';

  /// The rocket's height off the ground (0..1, 1 = out of frame).
  static const String journeyPropLift = 'lift';

  /// v11: the jacket on the door's peg (0..1, door only).
  static const String journeyPropJacket = 'jacket';

  /// v11: the door's peg, the avatar's `grab` contact (artboard space).
  static const double journeyHookX = 628;
  static const double journeyHookY = 560;

  /// The current scene's key and ambient colours.
  static const String journeyPropLightKey = 'lightKey';
  static const String journeyPropLightAmbient = 'lightAmbient';

  /// The `Journey` artboard's size: the avatar's.
  static const double journeyArtboardWidth = 800;
  static const double journeyArtboardHeight = 1000;

  /// Artboard x right of which the avatar is clipped during a journey.
  static const double journeyThresholdX = 640;
}
