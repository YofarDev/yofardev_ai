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
  // offset from the head (0 = locked); `eyeLeadYaw` is extra iris shift.
  static const String propYaw = 'yaw';
  static const String propPitch = 'pitch';
  static const String propHairLagYaw = 'hairLagYaw';
  static const String propHairLagPitch = 'hairLagPitch';
  static const String propEyeLeadYaw = 'eyeLeadYaw';

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

  /// Range of `eyeLeadYaw`.
  static const double eyeLeadMin = -1;
  static const double eyeLeadMax = 1;

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
