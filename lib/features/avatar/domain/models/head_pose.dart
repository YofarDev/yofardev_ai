/// Where the head should be looking, in the `yaw` / `pitch` view-model units
/// of `rive/CONTRACT.md` (both −1..1; +yaw turns toward the viewer's right,
/// +pitch looks up).
class HeadTarget {
  const HeadTarget(this.yaw, this.pitch, {this.reading = false});

  /// Facing the viewer.
  static const HeadTarget zero = HeadTarget(0, 0);

  final double yaw;
  final double pitch;

  /// True while the avatar reads (the tablet glance): the eyes make small
  /// reading saccades on top of the held look.
  final bool reading;

  @override
  bool operator ==(Object other) =>
      other is HeadTarget &&
      other.yaw == yaw &&
      other.pitch == pitch &&
      other.reading == reading;

  @override
  int get hashCode => Object.hash(yaw, pitch, reading);

  @override
  String toString() =>
      'HeadTarget(yaw: $yaw, pitch: $pitch, reading: $reading)';
}

/// The six head-rig numbers written to `AvatarVM` each frame.
///
/// `hairLag*` are offsets of the hair relative to the head (0 = locked) and
/// `eyeLeadYaw` is the extra iris shift that lets the eyes lead a turn.
/// `eyeLeadPitch` is the held vertical look (+ = up; negative also drops the
/// upper lids).
class HeadPose {
  const HeadPose({
    this.yaw = 0,
    this.pitch = 0,
    this.hairLagYaw = 0,
    this.hairLagPitch = 0,
    this.eyeLeadYaw = 0,
    this.eyeLeadPitch = 0,
  });

  static const HeadPose zero = HeadPose();

  final double yaw;
  final double pitch;
  final double hairLagYaw;
  final double hairLagPitch;
  final double eyeLeadYaw;
  final double eyeLeadPitch;

  Map<String, double> toJson() => <String, double>{
    'yaw': yaw,
    'pitch': pitch,
    'hairLagYaw': hairLagYaw,
    'hairLagPitch': hairLagPitch,
    'eyeLeadYaw': eyeLeadYaw,
    'eyeLeadPitch': eyeLeadPitch,
  };

  @override
  bool operator ==(Object other) =>
      other is HeadPose &&
      other.yaw == yaw &&
      other.pitch == pitch &&
      other.hairLagYaw == hairLagYaw &&
      other.hairLagPitch == hairLagPitch &&
      other.eyeLeadYaw == eyeLeadYaw &&
      other.eyeLeadPitch == eyeLeadPitch;

  @override
  int get hashCode => Object.hash(
    yaw,
    pitch,
    hairLagYaw,
    hairLagPitch,
    eyeLeadYaw,
    eyeLeadPitch,
  );

  @override
  String toString() =>
      'HeadPose(yaw: $yaw, pitch: $pitch, hairLagYaw: $hairLagYaw, '
      'hairLagPitch: $hairLagPitch, eyeLeadYaw: $eyeLeadYaw, eyeLeadPitch: $eyeLeadPitch)';
}
