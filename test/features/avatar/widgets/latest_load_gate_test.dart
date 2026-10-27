import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/features/avatar/presentation/widgets/rive/latest_load_gate.dart';

void main() {
  group('LatestLoadGate', () {
    test('a single load is the latest', () {
      final LatestLoadGate gate = LatestLoadGate();
      final int ticket = gate.begin();
      expect(gate.isLatest(ticket), isTrue);
    });

    test('an older load finishing after a newer one is stale', () {
      // Home builds with the default scene, then loadAvatar switches to the
      // chat's scene while the first load is still in flight.
      final LatestLoadGate gate = LatestLoadGate();
      final int livingRoom = gate.begin();
      final int campfire = gate.begin();

      // campfire completes first, then livingRoom completes last.
      expect(gate.isLatest(campfire), isTrue);
      expect(gate.isLatest(livingRoom), isFalse);
    });

    test('cancelAll makes every pending load stale', () {
      final LatestLoadGate gate = LatestLoadGate();
      final int ticket = gate.begin();
      gate.cancelAll();
      expect(gate.isLatest(ticket), isFalse);
    });
  });
}
