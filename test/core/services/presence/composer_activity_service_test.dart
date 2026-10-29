import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/services/presence/composer_activity_service.dart';

void main() {
  group('ComposerActivityService', () {
    test('starts idle', () {
      final ComposerActivityService service = ComposerActivityService();
      expect(service.current, ComposerActivity.idle);
      expect(service.current.typing, isFalse);
      expect(service.current.lastChar, isNull);
      service.dispose();
    });

    test('report publishes to every listener and updates current', () async {
      final ComposerActivityService service = ComposerActivityService();
      final List<ComposerActivity> a = <ComposerActivity>[];
      final List<ComposerActivity> b = <ComposerActivity>[];
      service.activity.listen(a.add);
      service.activity.listen(b.add);

      const ComposerActivity typed = ComposerActivity(
        typing: true,
        caretFraction: 0.8,
        lastChar: '?',
      );
      service.report(typed);
      await Future<void>.delayed(Duration.zero);

      expect(service.current, typed);
      expect(a, <ComposerActivity>[typed]);
      expect(b, <ComposerActivity>[typed]);
      await service.dispose();
    });

    test('identical consecutive reports are both delivered', () async {
      final ComposerActivityService service = ComposerActivityService();
      final List<ComposerActivity> seen = <ComposerActivity>[];
      service.activity.listen(seen.add);
      const ComposerActivity typed = ComposerActivity(
        typing: true,
        lastChar: 'a',
      );
      service.report(typed);
      service.report(typed);
      await Future<void>.delayed(Duration.zero);
      expect(seen.length, 2);
      await service.dispose();
    });

    test('clear reports the idle state', () async {
      final ComposerActivityService service = ComposerActivityService();
      final List<ComposerActivity> seen = <ComposerActivity>[];
      service.activity.listen(seen.add);
      service.report(const ComposerActivity(typing: true, lastChar: 'a'));
      service.clear();
      await Future<void>.delayed(Duration.zero);
      expect(service.current, ComposerActivity.idle);
      expect(seen.last, ComposerActivity.idle);
      await service.dispose();
    });

    test('report after dispose is ignored', () async {
      final ComposerActivityService service = ComposerActivityService();
      await service.dispose();
      service.report(const ComposerActivity(typing: true));
      expect(service.current.typing, isTrue);
    });

    test('value equality', () {
      expect(
        const ComposerActivity(typing: true, caretFraction: 0.2, lastChar: 'x'),
        const ComposerActivity(typing: true, caretFraction: 0.2, lastChar: 'x'),
      );
      expect(
        const ComposerActivity(typing: true),
        isNot(const ComposerActivity()),
      );
    });
  });
}
