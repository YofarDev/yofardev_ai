import '../../../../core/design/tokens/wardrobe_tints.dart';
import '../../../../core/models/avatar_config.dart';
import '../../../../core/models/performance/performance.dart';
import 'avatar_face_writer.dart';
import 'avatar_rive_contract.dart';

/// Writes the shown avatar's wardrobe tints to `AvatarVM` (contract v13
/// `topTint` / `hatTint`, M10 ruling 5): the colours of [WardrobeTints],
/// fully transparent (none) while a costume is worn (costumes are never
/// tinted), and on the low quality tier (M11 ruling 13: the garment's own
/// colour). Rive-free: a fake sink tests it.
///
/// Each colour is written when it changes; [reset] forgets what was written
/// (a fresh binding). A file without the properties ignores the writes
/// (the binding logs a missing colour once).
class AvatarTintWriter {
  AvatarTintWriter(this._sink);

  final AvatarVmSink _sink;
  int? _top;
  int? _hat;

  /// The ARGB colours [shown] wears at [tier]: its tints, or none under a
  /// costume or on the low tier.
  static ({int top, int hat}) colorsFor(
    Avatar shown, {
    QualityTier tier = QualityTier.ultra,
  }) {
    if (shown.costume != AvatarCostume.none || !tier.allowsTints) {
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

  /// Writes [shown]'s tint colours at [tier] that changed since the last
  /// write.
  void write(Avatar shown, {QualityTier tier = QualityTier.ultra}) {
    final ({int top, int hat}) colors = colorsFor(shown, tier: tier);
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
