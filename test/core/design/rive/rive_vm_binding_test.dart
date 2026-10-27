import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/design/rive/rive_vm_binding.dart';

/// The binding itself needs the native Rive runtime (covered by
/// `integration_test/rive_vm_binding_test.dart`); this tests the bookkeeping
/// it relies on to skip unchanged writes and log each missing name once.
void main() {
  group('RiveWriteMemo', () {
    test('a value is unchanged only after it was recorded', () {
      final RiveWriteMemo memo = RiveWriteMemo();
      expect(memo.isUnchanged('state', 'idle'), isFalse);
      memo.record('state', 'idle');
      expect(memo.isUnchanged('state', 'idle'), isTrue);
      expect(memo.isUnchanged('state', 'typing'), isFalse);
    });

    test('a changed value is written again, then deduplicated', () {
      final RiveWriteMemo memo = RiveWriteMemo();
      memo.record('level', 0.5);
      memo.record('level', 0.75);
      expect(memo.isUnchanged('level', 0.5), isFalse);
      expect(memo.isUnchanged('level', 0.75), isTrue);
    });

    test('names are tracked independently, across value types', () {
      final RiveWriteMemo memo = RiveWriteMemo();
      memo.record('running', true);
      memo.record('tint', const Color(0xFF16121D));
      expect(memo.isUnchanged('running', true), isTrue);
      expect(memo.isUnchanged('running', false), isFalse);
      expect(memo.isUnchanged('tint', const Color(0xFF16121D)), isTrue);
      expect(memo.isUnchanged('tint', const Color(0xFFF4B860)), isFalse);
    });

    test('firstReport is true once per key', () {
      final RiveWriteMemo memo = RiveWriteMemo();
      expect(memo.firstReport('missing'), isTrue);
      expect(memo.firstReport('missing'), isFalse);
      expect(memo.firstReport('other'), isTrue);
    });

    test('clearValues forgets values but keeps reported keys', () {
      final RiveWriteMemo memo = RiveWriteMemo();
      memo.record('value', true);
      memo.firstReport('missing');
      memo.clearValues();
      expect(memo.isUnchanged('value', true), isFalse);
      expect(memo.firstReport('missing'), isFalse);
    });

    test('counts only the writes that change a value', () {
      final RiveWriteMemo memo = RiveWriteMemo();
      expect(memo.writes, 0);
      memo.record('state', 'idle');
      memo.record('level', 0.5);
      expect(memo.writes, 2);
      expect(memo.isUnchanged('state', 'idle'), isTrue);
    });
  });
}
