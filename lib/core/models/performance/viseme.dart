/// Mouth-shape visemes (the Oculus/MPEG-4 style set), used to drive the
/// avatar's lipsync targets.
enum Viseme {
  sil,
  pp,
  ff,
  th,
  dd,
  kk,
  ch,
  ss,
  nn,
  rr,
  aa,
  e,
  ih,
  oh,
  ou;

  /// Maps each viseme to today's 0-4 mouth-openness scale.
  int get mouthOpenness => switch (this) {
    Viseme.sil || Viseme.pp || Viseme.ff => 0,
    Viseme.th || Viseme.ss => 1,
    Viseme.dd || Viseme.kk || Viseme.ch || Viseme.nn => 2,
    Viseme.rr || Viseme.ih || Viseme.e || Viseme.ou => 3,
    Viseme.aa || Viseme.oh => 4,
  };
}
