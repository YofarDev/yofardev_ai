import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/models/avatar_cue.dart';
import 'package:yofardev_ai/core/models/avatar_gesture.dart';
import 'package:yofardev_ai/core/models/avatar_scene.dart';
import 'package:yofardev_ai/features/chat/domain/services/cue_parser.dart';

void main() {
  group('CueParser', () {
    test('plain text passes through untouched', () {
      final CueParser parser = CueParser();
      final ParsedChunk result = parser.parse('Hello world.');
      expect(result.text, 'Hello world.');
      expect(result.cues, isEmpty);
    });

    test('empty input produces empty output', () {
      final CueParser parser = CueParser();
      final ParsedChunk result = parser.parse('');
      expect(result.text, '');
      expect(result.cues, isEmpty);
    });

    test('a gesture cue is extracted and removed from the text', () {
      final CueParser parser = CueParser();
      final ParsedChunk result = parser.parse('Hi there [g:wave] welcome!');
      expect(result.text, 'Hi there  welcome!');
      expect(result.cues, <AvatarCue>[
        const AvatarCue.gesture(AvatarGesture.wave),
      ]);
    });

    test('a scene event cue is extracted and removed from the text', () {
      final CueParser parser = CueParser(currentScene: AvatarScene.livingRoom);
      final ParsedChunk result = parser.parse('Look! [s:tvOn] Nice.');
      expect(result.text, 'Look!  Nice.');
      expect(result.cues, <AvatarCue>[
        const AvatarCue.sceneEvent(SceneEvent.tvOn),
      ]);
    });

    test('multiple cues in one chunk are all returned', () {
      final CueParser parser = CueParser();
      final ParsedChunk result = parser.parse('[g:nod] a [s:flare] b [g:clap]');
      expect(result.cues, hasLength(3));
      expect(result.text, ' a  b ');
    });

    test('a cue split across two chunks still parses', () {
      final CueParser parser = CueParser();
      final ParsedChunk first = parser.parse('Hello [g:la');
      expect(first.text, 'Hello ');
      expect(first.cues, isEmpty);

      final ParsedChunk second = parser.parse('ugh] world');
      expect(second.text, ' world');
      expect(second.cues, <AvatarCue>[
        const AvatarCue.gesture(AvatarGesture.laugh),
      ]);
    });

    test('a scene event cue split at the colon still parses', () {
      final CueParser parser = CueParser(currentScene: AvatarScene.campfire);
      final ParsedChunk first = parser.parse('x [s:');
      expect(first.text, 'x ');
      final ParsedChunk second = parser.parse('owlHoot] y');
      expect(second.text, ' y');
      expect(second.cues, <AvatarCue>[
        const AvatarCue.sceneEvent(SceneEvent.owlHoot),
      ]);
    });

    test('text that only looks like a cue passes through untouched', () {
      final CueParser parser = CueParser();
      final ParsedChunk result = parser.parse('see [note] for details');
      expect(result.text, 'see [note] for details');
      expect(result.cues, isEmpty);
    });

    test('a bracketed lookalike split across chunks passes through', () {
      final CueParser parser = CueParser();
      final ParsedChunk first = parser.parse('see [no');
      expect(first.text, 'see [no');
      final ParsedChunk second = parser.parse('te] end');
      expect(second.text, 'te] end');
      expect(second.cues, isEmpty);
    });

    test('an unknown gesture cue is dropped', () {
      final CueParser parser = CueParser();
      final ParsedChunk result = parser.parse('hey [g:dance] there');
      expect(result.text, 'hey  there');
      expect(result.cues, isEmpty);
    });

    test('the signature move is not an LLM cue: dropped (M10 ruling 6)', () {
      final CueParser parser = CueParser();
      final ParsedChunk result = parser.parse('hey [g:signature] there');
      expect(result.text, 'hey  there');
      expect(result.cues, isEmpty);
      expect(AvatarGesture.llmCues, isNot(contains(AvatarGesture.signature)));
      expect(AvatarGesture.llmCues, hasLength(AvatarGesture.values.length - 1));
    });

    test('an unknown scene event cue is dropped', () {
      final CueParser parser = CueParser(currentScene: AvatarScene.beach);
      final ParsedChunk result = parser.parse('hey [s:volcano] there');
      expect(result.text, 'hey  there');
      expect(result.cues, isEmpty);
    });

    test('a scene event invalid for the current scene is dropped', () {
      final CueParser parser = CueParser(currentScene: AvatarScene.livingRoom);
      final ParsedChunk result = parser.parse('wow [s:bigWave] nice');
      expect(result.text, 'wow  nice');
      expect(result.cues, isEmpty);
    });

    test('the same scene event is kept when the scene allows it', () {
      final CueParser parser = CueParser(currentScene: AvatarScene.beach);
      final ParsedChunk result = parser.parse('wow [s:bigWave] nice');
      expect(result.cues, <AvatarCue>[
        const AvatarCue.sceneEvent(SceneEvent.bigWave),
      ]);
    });

    test('without a current scene, valid scene events are not filtered', () {
      final CueParser parser = CueParser();
      final ParsedChunk result = parser.parse('wow [s:bigWave] nice');
      expect(result.cues, <AvatarCue>[
        const AvatarCue.sceneEvent(SceneEvent.bigWave),
      ]);
    });

    test('an incomplete cue at end of stream is emitted as text by flush', () {
      final CueParser parser = CueParser();
      final ParsedChunk result = parser.parse('hello [g:wav');
      expect(result.text, 'hello ');
      expect(parser.flush(), '[g:wav');
    });

    test('flush on a clean parser yields nothing', () {
      final CueParser parser = CueParser();
      parser.parse('all good.');
      expect(parser.flush(), '');
    });

    test('reset clears held pending text', () {
      final CueParser parser = CueParser();
      parser.parse('hello [g:wav');
      parser.reset();
      expect(parser.flush(), '');
    });

    test('a long bracket tail that cannot be a cue is not held', () {
      final CueParser parser = CueParser();
      // Longer than the longest cue name and unclosed: cannot become a cue.
      final ParsedChunk result = parser.parse('a [g:thisIsWayTooLongForACue');
      expect(result.cues, isEmpty);
      expect(result.text, 'a [g:thisIsWayTooLongForACue');
    });

    test('a closed unknown cue is dropped, not passed through', () {
      final CueParser parser = CueParser();
      final ParsedChunk result = parser.parse('a [g:thisIsWayTooLong] b');
      expect(result.text, 'a  b');
      expect(result.cues, isEmpty);
    });

    test('stripCues removes every cue from a complete text', () {
      const String raw = 'Hi [g:wave] there [s:tvOn] friend [g:shrug]';
      expect(CueParser.stripCues(raw), 'Hi  there  friend ');
    });

    test('stripCues keeps non-cue brackets', () {
      expect(CueParser.stripCues('a [note] b'), 'a [note] b');
    });
  });

  group('CueParser look-alikes and split openings', () {
    test('cue-like text followed by a non-bracket does not stall the '
        'rest of the reply', () {
      final CueParser parser = CueParser();
      final ParsedChunk first = parser.parse('[g:wave hello] and more.');
      expect(first.text, '[g:wave hello] and more.');
      expect(first.cues, isEmpty);
      expect(parser.flush(), '');
    });

    test('a cue split right after the opening bracket still parses', () {
      final CueParser parser = CueParser();
      final ParsedChunk first = parser.parse('Ha! [');
      final ParsedChunk second = parser.parse('g:laugh] Funny.');
      expect(first.text, 'Ha! ');
      expect(second.text, ' Funny.');
      expect(second.cues, <AvatarCue>[
        const AvatarCue.gesture(AvatarGesture.laugh),
      ]);
    });

    test('a cue split before the colon still parses', () {
      final CueParser parser = CueParser();
      final ParsedChunk first = parser.parse('Ha! [g');
      final ParsedChunk second = parser.parse(':nod] Yes.');
      expect(first.text, 'Ha! ');
      expect(second.cues, <AvatarCue>[
        const AvatarCue.gesture(AvatarGesture.nod),
      ]);
    });

    test('a held "[" that never becomes a cue is flushed literally', () {
      final CueParser parser = CueParser();
      expect(parser.parse('Look [').text, 'Look ');
      expect(parser.flush(), '[');
    });
  });

  group('CueParser.stripCuesFromReplyJson', () {
    test('strips cues from the "message" field used by the system prompt', () {
      final String raw = jsonEncode(<String, dynamic>{
        'message': 'Ha! [g:laugh] That is wild.',
        'mood': 'happy',
      });
      final Map<String, dynamic> stripped =
          jsonDecode(CueParser.stripCuesFromReplyJson(raw)!)
              as Map<String, dynamic>;
      expect(stripped['message'], 'Ha!  That is wild.');
      expect(stripped['mood'], 'happy');
    });

    test('strips cues from every supported text key', () {
      for (final String key in <String>[
        'text',
        'content',
        'message',
        'response',
      ]) {
        final String raw = jsonEncode(<String, dynamic>{key: 'a [s:rain] b'});
        final Map<String, dynamic> stripped =
            jsonDecode(CueParser.stripCuesFromReplyJson(raw)!)
                as Map<String, dynamic>;
        expect(stripped[key], 'a  b', reason: key);
      }
    });

    test('returns the input unchanged when it is not JSON', () {
      expect(CueParser.stripCuesFromReplyJson('not json'), 'not json');
      expect(CueParser.stripCuesFromReplyJson('{broken'), '{broken');
      expect(CueParser.stripCuesFromReplyJson(null), isNull);
    });
  });

  group('CueSentenceCollector', () {
    test('a sentence delivers its own cues', () {
      final CueSentenceCollector collector = CueSentenceCollector(CueParser());
      final CueDelivery? delivery = collector.add('Hi [g:wave] there.');
      expect(delivery!.text, 'Hi  there.');
      expect(delivery.cues, <AvatarCue>[
        const AvatarCue.gesture(AvatarGesture.wave),
      ]);
    });

    test('cues from a cue-only chunk ride the next sentence', () {
      final CueSentenceCollector collector = CueSentenceCollector(CueParser());
      expect(collector.add('[g:nod]'), isNull);
      final CueDelivery? delivery = collector.add('Sure.');
      expect(delivery!.text, 'Sure.');
      expect(delivery.cues, <AvatarCue>[
        const AvatarCue.gesture(AvatarGesture.nod),
      ]);
    });

    test('a trailing cue-only chunk is delivered by finish', () {
      final CueSentenceCollector collector = CueSentenceCollector(CueParser());
      expect(collector.add('See you!')!.cues, isEmpty);
      expect(collector.add('[g:wave]'), isNull);
      final CueDelivery? leftover = collector.finish();
      expect(leftover!.text, '');
      expect(leftover.cues, <AvatarCue>[
        const AvatarCue.gesture(AvatarGesture.wave),
      ]);
      expect(collector.finish(), isNull);
    });

    test(
      'finish delivers an unclosed cue as literal text; earlier cues rode the sentence',
      () {
        final CueSentenceCollector collector = CueSentenceCollector(
          CueParser(currentScene: AvatarScene.campfire),
        );
        expect(collector.add('[s:rain]'), isNull);
        expect(collector.add('Bye [g:wa'), isNotNull);
        final CueDelivery? leftover = collector.finish();
        expect(leftover!.text, '[g:wa');
        expect(leftover.cues, isEmpty);
      },
    );

    test('finish returns null when nothing is left', () {
      final CueSentenceCollector collector = CueSentenceCollector(CueParser());
      collector.add('Done.');
      expect(collector.finish(), isNull);
    });
  });
}
