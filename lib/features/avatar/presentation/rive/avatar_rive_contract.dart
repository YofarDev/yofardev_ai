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
  static const List<String> propValues = <String>['none', 'tablet'];
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
  ];
  static const String defaultSceneId = 'livingRoom';

  /// Every scene's allowed `eventId` values, and its tappable `propId`s.
  static const Map<String, List<String>> sceneEvents = <String, List<String>>{
    'livingRoom': <String>['lightsOff', 'lightsOn', 'tvOn', 'catWalksBy'],
    'campfire': <String>['flare', 'rain', 'shootingStar', 'owlHoot'],
    'beach': <String>['bigWave', 'seagulls', 'sunset', 'rain'],
    'deepSpace': <String>['meteor', 'warp', 'alienShip', 'nebulaPulse'],
  };
  static const Map<String, List<String>> sceneProps = <String, List<String>>{
    'livingRoom': <String>['lamp', 'tv', 'cat', 'plant'],
    'campfire': <String>['fire', 'tent', 'owl', 'sky'],
    'beach': <String>['crab', 'umbrella', 'seagull'],
    'deepSpace': <String>['planet', 'ufo', 'rubberDuck'],
  };

  /// Asset path for a scene id.
  static String sceneAssetPath(String sceneId) =>
      '$scenesAssetDir/$sceneId.riv';
}
