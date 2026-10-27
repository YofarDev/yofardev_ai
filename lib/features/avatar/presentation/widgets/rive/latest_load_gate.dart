/// Latest-load-wins guard for overlapping async loads.
///
/// Each load takes a ticket before awaiting; after the await, only the
/// newest ticket may publish its result. An older load that finishes later
/// is stale and must discard what it loaded.
class LatestLoadGate {
  int _latest = 0;

  /// Starts a load and returns its ticket.
  int begin() => ++_latest;

  /// Whether [ticket] belongs to the most recent load.
  bool isLatest(int ticket) => ticket == _latest;

  /// Makes every pending load stale (e.g. on dispose).
  void cancelAll() => _latest++;
}
