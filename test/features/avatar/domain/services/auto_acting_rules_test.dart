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

    group('count for lists of three or more (M8 ruling 4)', () {
      test('ordinal words (English and French)', () {
        expect(
          gesturesFor('First the eggs, second the flour, third the milk.'),
          <AvatarGesture>[AvatarGesture.count],
        );
        expect(
          gesturesFor("D'abord le café, ensuite le pain, enfin la confiture."),
          <AvatarGesture>[AvatarGesture.count],
        );
        expect(
          gesturesFor(
            'Premièrement ceci, deuxièmement cela, troisièmement '
            'le reste.',
          ),
          <AvatarGesture>[AvatarGesture.count],
        );
      });

      test('numbered items', () {
        expect(
          gesturesFor('Three steps: 1. mix 2. bake 3. eat.'),
          <AvatarGesture>[AvatarGesture.count],
        );
        expect(gesturesFor('1) red 2) green 3) blue'), <AvatarGesture>[
          AvatarGesture.count,
        ]);
      });

      test('bullet items', () {
        expect(
          gesturesFor('You need:\n- eggs\n- flour\n- milk'),
          <AvatarGesture>[AvatarGesture.count],
        );
        expect(gesturesFor('- un\n• deux\n* trois'), <AvatarGesture>[
          AvatarGesture.count,
        ]);
      });

      test('fewer than three items is not a list', () {
        expect(gesturesFor('First this, second that.'), isEmpty);
        expect(gesturesFor('1. mix 2. bake'), isEmpty);
        expect(gesturesFor('- eggs\n- flour'), isEmpty);
        expect(gesturesFor('It costs 3.50 or 4.20 or 5.10 euros.'), isEmpty);
        expect(gesturesFor('My first, my first, my first love.'), isEmpty);
      });

      test('a question still thinks; a list wins over yes / no', () {
        expect(gesturesFor('Want 1. tea 2. coffee 3. juice?'), <AvatarGesture>[
          AvatarGesture.think,
        ]);
        expect(
          gesturesFor('Yes: first eggs, second flour, third milk.'),
          <AvatarGesture>[AvatarGesture.count],
        );
      });
    });
  });
}
