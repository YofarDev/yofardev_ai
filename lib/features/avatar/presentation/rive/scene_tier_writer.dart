import 'package:flutter/foundation.dart';

import '../../../../core/models/performance/performance.dart';
import 'avatar_rive_contract.dart';

/// Writes the quality tier to `SceneVM.tier` (contract v14 enum low / high /
/// ultra, M11 ruling 13), only when it changed.
///
/// A scene file without the property ignores the write (`RiveVmBinding`
/// resolves a missing property once and skips it), so an older file is
/// simply drawn at its default (ultra, the v13 look).
class SceneTierWriter {
  SceneTierWriter(this._setEnum);

  final void Function(String name, List<String> values, String value) _setEnum;

  QualityTier? _tier;

  /// Writes [tier] ([force]: even when unchanged).
  void write(QualityTier tier, {bool force = false}) {
    if (!force && tier == _tier) {
      return;
    }
    _setEnum(
      AvatarRiveContract.scenePropTier,
      AvatarRiveContract.tierValues,
      tier.name,
    );
    _tier = tier;
  }
}

/// Follows the effective tier and writes it to the loaded scene file: the
/// scene view's tier logic, free of Rive so it can be tested.
///
/// Like the other scene followers: [follow] swaps the source, [load] writes
/// the current tier into a fresh file in full, [unload] drops the file.
/// Without a source nothing is written (the file's default, ultra).
class SceneTierFollower {
  ValueListenable<QualityTier>? _source;
  SceneTierWriter? _writer;

  /// The tier in force (ultra without a source).
  QualityTier get value => _source?.value ?? QualityTier.ultra;

  /// Follows [source] in place of the previous one and writes it to the
  /// loaded file, if any.
  void follow(ValueListenable<QualityTier>? source) {
    if (source == _source) {
      return;
    }
    _source?.removeListener(_write);
    _source = source;
    source?.addListener(_write);
    _write();
  }

  /// A scene file loaded: writes the current tier to its `setEnum`.
  void load(
    void Function(String name, List<String> values, String value) setEnum,
  ) {
    _writer = SceneTierWriter(setEnum);
    _write(force: true);
  }

  /// The scene file is gone.
  void unload() => _writer = null;

  /// Stops listening.
  void dispose() {
    _source?.removeListener(_write);
    _source = null;
    _writer = null;
  }

  void _write({bool force = false}) {
    final ValueListenable<QualityTier>? source = _source;
    if (source == null) {
      return;
    }
    _writer?.write(source.value, force: force);
  }
}
