import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/models/avatar_gesture.dart';
import 'package:yofardev_ai/features/avatar/domain/services/auto_acting_rules.dart';

void main() {
  group('gesturesFor', () {
    test('a question gives think', () {
      expect(gesturesFor('How is the weather today?'), <AvatarGesture>[
        AvatarGesture.think,
      ]);
    });

    test('an affirmation gives nod (English and French)', () {
      expect(gesturesFor('yes, that is right'), <AvatarGesture>[
        AvatarGesture.nod,
      ]);
      expect(gesturesFor('oui, exactement'), <AvatarGesture>[
        AvatarGesture.nod,
      ]);
      expect(gesturesFor('exactly my point'), <AvatarGesture>[
        AvatarGesture.nod,
      ]);
      expect(gesturesFor('exactement ce que je pensais'), <AvatarGesture>[
        AvatarGesture.nod,
      ]);
    });

    test('a negation gives headshake (English and French)', () {
      expect(gesturesFor('no, I disagree'), <AvatarGesture>[
        AvatarGesture.headshake,
      ]);
      expect(gesturesFor('non, pas du tout'), <AvatarGesture>[
        AvatarGesture.headshake,
      ]);
    });

    test('anything else gives nothing', () {
      expect(gesturesFor('Hello there.'), isEmpty);
      expect(gesturesFor('The weather is nice today.'), isEmpty);
      expect(gesturesFor(''), isEmpty);
    });

    test('rules ignore case and leading whitespace', () {
      expect(gesturesFor('  YES please'), <AvatarGesture>[AvatarGesture.nod]);
      expect(gesturesFor('\t non merci'), <AvatarGesture>[
        AvatarGesture.headshake,
      ]);
      expect(gesturesFor('  EXACTEMENT'), <AvatarGesture>[AvatarGesture.nod]);
      expect(gesturesFor('  How about now?'), <AvatarGesture>[
        AvatarGesture.think,
      ]);
    });

    test('a question beats an affirmation when both match', () {
      expect(gesturesFor('yes, really?'), <AvatarGesture>[AvatarGesture.think]);
    });
  });
}
