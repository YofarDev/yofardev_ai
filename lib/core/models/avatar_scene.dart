/// The Rive scenes replacing photo backgrounds. Names mirror
/// `rive/CONTRACT.md` (`assets/rive/scenes/<sceneId>.riv`).
enum AvatarScene {
  livingRoom,
  campfire,
  beach,
  deepSpace;

  /// The scene used when nothing else is set (new chats, unmappable values).
  static const AvatarScene defaultScene = AvatarScene.livingRoom;

  /// Whether the scene is a diorama with depth planes, so its file reads the
  /// parallax numbers (and the sensors are worth running). Campfire and
  /// livingRoom so far; beach and deepSpace join when their dioramas are
  /// rebuilt (M5).
  bool get isDiorama =>
      this == AvatarScene.campfire || this == AvatarScene.livingRoom;

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
  };
}

/// Every scene's `eventId` values, in contract order. `rain` is shared by
/// campfire and beach; per-scene validity is decided by
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
  'restaurant': AvatarScene.livingRoom,
  'parisianCafe': AvatarScene.livingRoom,
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
  'snowyMountain': AvatarScene.campfire,
  'campfire': AvatarScene.campfire,
  // Water → beach
  'beach': AvatarScene.beach,
  'tropicalIsland': AvatarScene.beach,
  'swimmingPool': AvatarScene.beach,
  // Urban/night → deepSpace
  'deepSpace': AvatarScene.deepSpace,
  'cityscrape': AvatarScene.deepSpace,
  'balconyViewOfCityByNight': AvatarScene.deepSpace,
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
