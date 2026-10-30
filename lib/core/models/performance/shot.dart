/// Camera framing of the avatar scene.
enum Shot { wide, medium, closeUp, propInsert }

/// How the camera gets to a new [CameraShot].
enum CameraMove {
  /// Jump straight to the new framing.
  cut,

  /// Glide to the new framing over [CameraShot.duration].
  ease,
}

/// One command of the camera director: where to look and how to get there.
///
/// A view applies it when [serial] changes, so two identical consecutive
/// commands stay distinguishable.
class CameraShot {
  const CameraShot({
    required this.shot,
    required this.move,
    this.duration = Duration.zero,
    this.creep = 0,
    this.creepDuration = Duration.zero,
    this.serial = 0,
  });

  /// The opening command: the whole stage, no move.
  static const CameraShot initial = CameraShot(
    shot: Shot.wide,
    move: CameraMove.cut,
  );

  /// The framing to reach.
  final Shot shot;

  /// Cut or ease to [shot].
  final CameraMove move;

  /// Length of the ease; zero for a cut.
  final Duration duration;

  /// Extra zoom, as a fraction of the shot's zoom, to be at after
  /// [creepDuration] (reached linearly). Total since the last cut; 0 = none.
  final double creep;

  /// Time over which [creep] is reached.
  final Duration creepDuration;

  /// Increments on every new command.
  final int serial;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CameraShot &&
          other.shot == shot &&
          other.move == move &&
          other.duration == duration &&
          other.creep == creep &&
          other.creepDuration == creepDuration &&
          other.serial == serial;

  @override
  int get hashCode =>
      Object.hash(shot, move, duration, creep, creepDuration, serial);

  @override
  String toString() =>
      'CameraShot(${shot.name}, ${move.name}, $duration, creep $creep over '
      '$creepDuration, #$serial)';
}
