/// The Rive scenes replacing photo backgrounds. Names mirror
/// `rive/CONTRACT.md` (`assets/rive/scenes/<sceneId>.riv`).
enum AvatarScene {
  livingRoom,
  campfire,
  beach,
  deepSpace;

  /// The scene used when nothing else is set (new chats, unmappable values).
  static const AvatarScene defaultScene = AvatarScene.livingRoom;

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
