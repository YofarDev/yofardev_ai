import 'package:flutter/foundation.dart';

import '../../domain/models/npc_intent.dart';
import 'avatar_rive_contract.dart';

/// Writes an [NpcIntent] to `SceneVM` (contract v11): `npc` (enum), `npcX`
/// and `npcLook` (numbers, written when they moved by more than [epsilon]).
class SceneNpcWriter {
  SceneNpcWriter({
    required void Function(String name, List<String> values, String value)
    setEnum,
    required void Function(String name, double value) setNumber,
  }) : _setEnum = setEnum,
       _setNumber = setNumber;

  final void Function(String name, List<String> values, String value) _setEnum;
  final void Function(String name, double value) _setNumber;

  /// Smallest number change worth writing.
  static const double epsilon = 0.001;

  NpcState? _npc;
  double? _x;
  double? _look;

  /// Writes what changed in [intent] ([force]: all of it).
  void write(NpcIntent intent, {bool force = false}) {
    if (force || intent.npc != _npc) {
      _setEnum(
        AvatarRiveContract.scenePropNpc,
        AvatarRiveContract.npcValues,
        intent.npc.name,
      );
      _npc = intent.npc;
    }
    final double x = intent.npcX.clamp(0.0, 1.0);
    final double? lastX = _x;
    if (force || lastX == null || (x - lastX).abs() > epsilon) {
      _setNumber(AvatarRiveContract.scenePropNpcX, x);
      _x = x;
    }
    final double look = intent.npcLook.clamp(-1.0, 1.0);
    final double? lastLook = _look;
    if (force || lastLook == null || (look - lastLook).abs() > epsilon) {
      _setNumber(AvatarRiveContract.scenePropNpcLook, look);
      _look = look;
    }
  }
}

/// Follows the NPC director's intent (or a hand-set override, the UI lab)
/// and writes it to the loaded scene file: the scene view's NPC logic, free
/// of Rive so it can be tested. Like `SceneRainFollower`: [follow] swaps the
/// source, [load] writes the current intent into a fresh file in full,
/// [unload] drops it. Without a source the NPC rests ([NpcIntent.rest]).
class SceneNpcFollower {
  ValueListenable<NpcIntent>? _source;
  NpcIntent? _override;
  SceneNpcWriter? _writer;

  /// Follows [source] in place of the previous one; a non-null [override]
  /// is written instead of it.
  void follow(ValueListenable<NpcIntent>? source, {NpcIntent? override}) {
    if (source != _source) {
      _source?.removeListener(_write);
      _source = source;
      source?.addListener(_write);
    }
    _override = override;
    _write();
  }

  /// A scene file loaded: writes the current intent to it.
  void load(
    void Function(String name, List<String> values, String value) setEnum,
    void Function(String name, double value) setNumber,
  ) {
    _writer = SceneNpcWriter(setEnum: setEnum, setNumber: setNumber)
      ..write(_current, force: true);
  }

  /// The scene file is gone.
  void unload() => _writer = null;

  /// Stops listening.
  void dispose() {
    _source?.removeListener(_write);
    _source = null;
    _writer = null;
  }

  NpcIntent get _current => _override ?? _source?.value ?? NpcIntent.rest;

  void _write() => _writer?.write(_current);
}
