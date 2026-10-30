/// The Rive scenes replacing photo backgrounds. Names mirror
/// `rive/CONTRACT.md` (`assets/rive/scenes/<sceneId>.riv`).
enum AvatarScene {
  livingRoom,
  campfire,
  beach,
  deepSpace,
  cafe,
  rooftop,
  mountainHut;

  /// The scene used when nothing else is set (new chats, unmappable values).
  static const AvatarScene defaultScene = AvatarScene.livingRoom;

  /// Whether the scene is a diorama with depth planes, so its file reads the
  /// parallax numbers (and the sensors are worth running). Every scene is one
  /// since M5; the getter stays for a future scene without planes.
  bool get isDiorama => switch (this) {
    AvatarScene.livingRoom ||
    AvatarScene.campfire ||
    AvatarScene.beach ||
    AvatarScene.deepSpace ||
    AvatarScene.cafe ||
    AvatarScene.rooftop ||
    AvatarScene.mountainHut => true,
  };

  /// The scene events this scene's `.riv` state machine can play.
  List<SceneEvent> get allowedEvents => switch (this) {
    AvatarScene.livingRoom => const <SceneEvent>[
      SceneEvent.lightsOff,
      SceneEvent.lightsOn,
      SceneEvent.tvOn,
      SceneEvent.catWalksBy,
    ],
    AvatarScene.campfire => const <SceneEvent>[
      SceneEvent.flare,
      SceneEvent.rain,
      SceneEvent.shootingStar,
      SceneEvent.owlHoot,
    ],
    AvatarScene.beach => const <SceneEvent>[
      SceneEvent.bigWave,
      SceneEvent.seagulls,
      SceneEvent.sunset,
      SceneEvent.rain,
    ],
    AvatarScene.deepSpace => const <SceneEvent>[
      SceneEvent.meteor,
      SceneEvent.warp,
      SceneEvent.alienShip,
      SceneEvent.nebulaPulse,
    ],
    AvatarScene.cafe => const <SceneEvent>[
      SceneEvent.espresso,
      SceneEvent.doorbell,
      SceneEvent.rain,
      SceneEvent.neonFlicker,
    ],
    AvatarScene.rooftop => const <SceneEvent>[
      SceneEvent.fireworks,
      SceneEvent.plane,
      SceneEvent.shootingStar,
      SceneEvent.windowsLit,
    ],
    AvatarScene.mountainHut => const <SceneEvent>[
      SceneEvent.snowfall,
      SceneEvent.flare,
      SceneEvent.aurora,
      SceneEvent.bell,
    ],
  };
}

/// Every scene's `eventId` values, in contract order. `rain` is shared by
/// campfire, beach and cafe, `shootingStar` by campfire and rooftop, `flare`
/// by campfire and mountainHut; per-scene validity is decided by
/// [AvatarScene.allowedEvents].
enum SceneEvent {
  lightsOff,
  lightsOn,
  tvOn,
  catWalksBy,
  flare,
  rain,
  shootingStar,
  owlHoot,
  bigWave,
  seagulls,
  sunset,
  meteor,
  warp,
  alienShip,
  nebulaPulse,
  espresso,
  doorbell,
  neonFlicker,
  fireworks,
  plane,
  windowsLit,
  snowfall,
  aurora,
  bell,
}

/// v3 photo-background names mapped to the nearest scene. Used when stored
/// data or replies mention a legacy background; stored data is never
/// rewritten (design decision §2).
const Map<String, AvatarScene> _legacyBackgroundToScene = <String, AvatarScene>{
  // Indoors → livingRoom
  'bedroom': AvatarScene.livingRoom,
  'library': AvatarScene.livingRoom,
  'classroom': AvatarScene.livingRoom,
  'office': AvatarScene.livingRoom,
  'mall': AvatarScene.livingRoom,
  'hallMansion': AvatarScene.livingRoom,
  'artGallery': AvatarScene.livingRoom,
  'cinema': AvatarScene.livingRoom,
  'livingRoom': AvatarScene.livingRoom,
  'christmasLivingRoom': AvatarScene.livingRoom,
  // Nature → campfire
  'lake': AvatarScene.campfire,
  'forest': AvatarScene.campfire,
  'park': AvatarScene.campfire,
  'sakuraTrees': AvatarScene.campfire,
  'japaneseGarden': AvatarScene.campfire,
  'campfire': AvatarScene.campfire,
  // Water → beach
  'beach': AvatarScene.beach,
  'tropicalIsland': AvatarScene.beach,
  'swimmingPool': AvatarScene.beach,
  // Cafés and restaurants → cafe (M9)
  'restaurant': AvatarScene.cafe,
  'parisianCafe': AvatarScene.cafe,
  'cafe': AvatarScene.cafe,
  // City by night → rooftop (M9)
  'cityscrape': AvatarScene.rooftop,
  'balconyViewOfCityByNight': AvatarScene.rooftop,
  'rooftop': AvatarScene.rooftop,
  // Snow → mountainHut (M9)
  'snowyMountain': AvatarScene.mountainHut,
  'mountainHut': AvatarScene.mountainHut,
  // Space and the rest of the urban set → deepSpace
  'deepSpace': AvatarScene.deepSpace,
  'street': AvatarScene.deepSpace,
  'facadeMansion': AvatarScene.deepSpace,
};

/// Maps any stored background name to a scene; anything unknown (or absent)
/// falls back to the default scene. Use for `Chat.avatar`, where a
/// background value always exists.
AvatarScene sceneFromStoredBackground(String? name) =>
    _legacyBackgroundToScene[name] ?? AvatarScene.defaultScene;

/// Maps a stored background name to a scene, or null when the value is not
/// recognized. Use for optional config fields, where null means "no change".
AvatarScene? maybeSceneFromStoredBackground(String? name) =>
    _legacyBackgroundToScene[name];
