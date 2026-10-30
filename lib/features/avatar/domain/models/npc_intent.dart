/// The scene NPC's state (contract v11 `SceneVM.npc`), in contract order.
enum NpcState {
  /// Not drawn.
  away,

  /// The v10 look (the cat asleep, the owl blinking, the crab still, the
  /// alien inside the ufo).
  rest,

  /// Awake, small life.
  idle,

  /// Its walk / scuttle / drift cycle while `npcX` changes.
  move,

  /// It looks at the avatar (`npcLook` aims it).
  notice,

  /// One short reaction loop.
  react,
}

/// What the scene's NPC does this frame: its state, where along its path it
/// is (0..1, 0 = its v10 spot) and where it looks (−1..1, + = the viewer's
/// right). Written to `SceneVM` by the scene view.
class NpcIntent {
  const NpcIntent({this.npc = NpcState.rest, this.npcX = 0, this.npcLook = 0});

  /// The v10 look: rest, at its spot, looking ahead.
  static const NpcIntent rest = NpcIntent();

  final NpcState npc;
  final double npcX;
  final double npcLook;

  @override
  bool operator ==(Object other) =>
      other is NpcIntent &&
      other.npc == npc &&
      other.npcX == npcX &&
      other.npcLook == npcLook;

  @override
  int get hashCode => Object.hash(npc, npcX, npcLook);

  @override
  String toString() =>
      'NpcIntent(${npc.name}, x ${npcX.toStringAsFixed(3)}, '
      'look ${npcLook.toStringAsFixed(2)})';
}
