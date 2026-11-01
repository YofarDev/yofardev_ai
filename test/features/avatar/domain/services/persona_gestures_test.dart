import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/models/avatar_gesture.dart';
import 'package:yofardev_ai/core/models/chat.dart';
import 'package:yofardev_ai/core/models/performance/performance.dart';
import 'package:yofardev_ai/features/avatar/domain/services/auto_acting_rules.dart';

void main() {
  const List<String> script = <String>[
    'Yes, that is a good idea.',
    'What do you think about it?',
    'First eggs, second flour, third milk.',
    'No, not today.',
    'This is a plain sentence.',
    'That is amazing!',
    'You can do it!',
    'Exactly my point.',
  ];

  List<AvatarGesture> gesturesOf(ChatPersona persona, String text, int i) =>
      personaGesturesFor(text, BodyLanguageProfile.of(persona), i);

  group('personaGesturesFor', () {
    test('normal gives exactly the plain rules, whatever the index', () {
      for (int i = 0; i < script.length; i++) {
        for (final int index in <int>[0, 1, 2, 7]) {
          expect(
            gesturesOf(ChatPersona.normal, script[i], index),
            gesturesFor(script[i]),
            reason: script[i],
          );
        }
      }
    });

    test('doomer: a beat becomes a shrug, a yes is shrugged too', () {
      expect(
        gesturesOf(ChatPersona.doomer, 'That is amazing!', 0),
        <AvatarGesture>[AvatarGesture.shrug],
      );
      expect(gesturesOf(ChatPersona.doomer, 'Yes, sure.', 3), <AvatarGesture>[
        AvatarGesture.shrug,
      ]);
      // a question still thinks, a no still shakes
      expect(gesturesOf(ChatPersona.doomer, 'Why bother?', 0), <AvatarGesture>[
        AvatarGesture.think,
      ]);
      expect(gesturesOf(ChatPersona.doomer, 'No.', 0), <AvatarGesture>[
        AvatarGesture.headshake,
      ]);
      // a plain sentence stays bare
      expect(gesturesOf(ChatPersona.doomer, 'It is raining.', 0), isEmpty);
    });

    test('coach: beats alternate thumbsUp and clap by sentence index', () {
      expect(
        gesturesOf(ChatPersona.coach, 'You can do it!', 0),
        <AvatarGesture>[AvatarGesture.thumbsUp],
      );
      expect(
        gesturesOf(ChatPersona.coach, 'You can do it!', 1),
        <AvatarGesture>[AvatarGesture.clap],
      );
      expect(
        gesturesOf(ChatPersona.coach, 'You can do it!', 2),
        <AvatarGesture>[AvatarGesture.thumbsUp],
      );
      expect(gesturesOf(ChatPersona.coach, 'Yes, go on.', 5), <AvatarGesture>[
        AvatarGesture.thumbsUp,
      ]);
    });

    test('philosopher: beats and yeses become think', () {
      expect(
        gesturesOf(ChatPersona.philosopher, 'How strange!', 4),
        <AvatarGesture>[AvatarGesture.think],
      );
      expect(
        gesturesOf(ChatPersona.philosopher, 'Yes, perhaps.', 1),
        <AvatarGesture>[AvatarGesture.think],
      );
      expect(
        gesturesOf(
          ChatPersona.philosopher,
          'First eggs, second flour, third milk.',
          0,
        ),
        <AvatarGesture>[AvatarGesture.count],
      );
    });

    test('psychologist nods, geek counts and thumbs up', () {
      expect(
        gesturesOf(ChatPersona.psychologist, 'I hear you!', 0),
        <AvatarGesture>[AvatarGesture.nod],
      );
      expect(
        gesturesOf(ChatPersona.geek, 'That is so cool!', 0),
        <AvatarGesture>[AvatarGesture.count],
      );
      expect(
        gesturesOf(ChatPersona.geek, 'That is so cool!', 1),
        <AvatarGesture>[AvatarGesture.thumbsUp],
      );
    });

    test(
      'deterministic: the same sentence and index give the same gesture',
      () {
        for (final ChatPersona persona in ChatPersona.values) {
          for (int i = 0; i < script.length; i++) {
            expect(
              gesturesOf(persona, script[i], i),
              gesturesOf(persona, script[i], i),
            );
          }
        }
      },
    );
  });

  group('isBeat', () {
    test('an exclaimed sentence the rules leave bare is a beat', () {
      expect(isBeat('That is amazing!'), isTrue);
      expect(isBeat('Plain.'), isFalse);
      expect(isBeat('Really?!'), isTrue);
      expect(isBeat('Yes!'), isFalse);
      expect(isBeat(''), isFalse);
    });
  });
}
