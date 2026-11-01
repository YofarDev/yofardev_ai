import 'package:flutter/foundation.dart';

import '../../domain/models/npc_intent.dart';
import 'avatar_rive_contract.dart';

/// One NPC slot's `SceneVM` property names and the last values written.
class _NpcSlot {
  const _NpcSlot(this.npc, this.x, this.look);

  static const _NpcSlot first = _NpcSlot(
    AvatarRiveContract.scenePropNpc,
    AvatarRiveContract.scenePropNpcX,
    AvatarRiveContract.scenePropNpcLook,
  );
  static const _NpcSlot second = _NpcSlot(
    AvatarRiveContract.scenePropNpc2,
    AvatarRiveContract.scenePropNpc2X,
    AvatarRiveContract.scenePropNpc2Look,
  );

  final String npc;
  final String x;
  final String look;
}

class _SlotMemo {
  NpcState? npc;
  double? x;
  double? look;
}

/// Writes [NpcIntent]s to `SceneVM`: `npc` (enum), `npcX` and `npcLook`
/// (numbers, written when they moved by more than [epsilon]) for the scene's
/// NPC (contract v11) and the same three as `npc2*` for its second slot (v12:
/// the beach's gulls).
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

  final _SlotMemo _first = _SlotMemo();
  final _SlotMemo _secondMemo = _SlotMemo();

  /// Writes what changed in [intent] ([force]: all of it), and, when given,
  /// in [second] (the `npc2*` slot).
  void write(NpcIntent intent, {NpcIntent? second, bool force = false}) {
    _write(_NpcSlot.first, _first, intent, force);
    if (second != null) {
      _write(_NpcSlot.second, _secondMemo, second, force);
    }
  }

  void _write(_NpcSlot slot, _SlotMemo memo, NpcIntent intent, bool force) {
    if (force || intent.npc != memo.npc) {
      _setEnum(slot.npc, AvatarRiveContract.npcValues, intent.npc.name);
      memo.npc = intent.npc;
    }
    final double x = intent.npcX.clamp(0.0, 1.0);
    final double? lastX = memo.x;
    if (force || lastX == null || (x - lastX).abs() > epsilon) {
      _setNumber(slot.x, x);
      memo.x = x;
    }
    final double look = intent.npcLook.clamp(-1.0, 1.0);
    final double? lastLook = memo.look;
    if (force || lastLook == null || (look - lastLook).abs() > epsilon) {
      _setNumber(slot.look, look);
      memo.look = look;
    }
  }
}

/// Follows the NPC director's intents (or hand-set overrides, the UI lab)
/// and writes them to the loaded scene file: the scene view's NPC logic, free
/// of Rive so it can be tested. Like `SceneRainFollower`: [follow] swaps the
/// sources, [load] writes the current intents into a fresh file in full,
/// [unload] drops it. Without a source the NPC rests ([NpcIntent.rest]). The
/// second slot (the gulls) is written only when it has a source or an
/// override; otherwise the file keeps its `away` default.
class SceneNpcFollower {
  ValueListenable<NpcIntent>? _source;
  ValueListenable<NpcIntent>? _secondSource;
  NpcIntent? _override;
  NpcIntent? _secondOverride;
  SceneNpcWriter? _writer;

  /// Follows [source] (and [second], the gulls) in place of the previous
  /// ones; a non-null [override] ([secondOverride]) is written instead.
  void follow(
    ValueListenable<NpcIntent>? source, {
    NpcIntent? override,
    ValueListenable<NpcIntent>? second,
    NpcIntent? secondOverride,
  }) {
    if (source != _source) {
      _source?.removeListener(_write);
      _source = source;
      source?.addListener(_write);
    }
    if (second != _secondSource) {
      _secondSource?.removeListener(_write);
      _secondSource = second;
      second?.addListener(_write);
    }
    _override = override;
    _secondOverride = secondOverride;
    _write();
  }

  /// A scene file loaded: writes the current intents to it.
  void load(
    void Function(String name, List<String> values, String value) setEnum,
    void Function(String name, double value) setNumber,
  ) {
    _writer = SceneNpcWriter(setEnum: setEnum, setNumber: setNumber)
      ..write(_current, second: _currentSecond, force: true);
  }

  /// The scene file is gone.
  void unload() => _writer = null;

  /// Stops listening.
  void dispose() {
    _source?.removeListener(_write);
    _secondSource?.removeListener(_write);
    _source = null;
    _secondSource = null;
    _writer = null;
  }

  NpcIntent get _current => _override ?? _source?.value ?? NpcIntent.rest;

  NpcIntent? get _currentSecond => _secondOverride ?? _secondSource?.value;

  void _write() => _writer?.write(_current, second: _currentSecond);
}
