import '../../../../core/design/tokens/wardrobe_tints.dart';
import '../../../../core/models/avatar_config.dart';
import 'avatar_face_writer.dart';
import 'avatar_rive_contract.dart';

/// Writes the shown avatar's wardrobe tints to `AvatarVM` (contract v13
/// `topTint` / `hatTint`, M10 ruling 5): the colours of [WardrobeTints],
/// fully transparent (none) while a costume is worn (costumes are never
/// tinted). Rive-free: a fake sink tests it.
///
/// Each colour is written when it changes; [reset] forgets what was written
/// (a fresh binding). A file without the properties ignores the writes
/// (the binding logs a missing colour once).
class AvatarTintWriter {
  AvatarTintWriter(this._sink);

  final AvatarVmSink _sink;
  int? _top;
  int? _hat;

  /// The ARGB colours [shown] wears: its tints, or none under a costume.
  static ({int top, int hat}) colorsFor(Avatar shown) {
    if (shown.costume != AvatarCostume.none) {
      final int none = WardrobeTints.none.toARGB32();
      return (top: none, hat: none);
    }
    return (
      top: WardrobeTints.of(shown.topTint).toARGB32(),
      hat: WardrobeTints.of(shown.hatTint).toARGB32(),
    );
  }

  /// Forgets what was written (a fresh binding has none of it).
  void reset() {
    _top = null;
    _hat = null;
  }

  /// Writes [shown]'s tint colours that changed since the last write.
  void write(Avatar shown) {
    final ({int top, int hat}) colors = colorsFor(shown);
    if (colors.top != _top) {
      _sink.setColor(AvatarRiveContract.propTopTint, colors.top);
      _top = colors.top;
    }
    if (colors.hat != _hat) {
      _sink.setColor(AvatarRiveContract.propHatTint, colors.hat);
      _hat = colors.hat;
    }
  }
}
