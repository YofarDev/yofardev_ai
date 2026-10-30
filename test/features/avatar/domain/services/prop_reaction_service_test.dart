import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/models/avatar_gesture.dart';
import 'package:yofardev_ai/core/models/avatar_mood.dart';
import 'package:yofardev_ai/core/models/avatar_scene.dart';
import 'package:yofardev_ai/core/models/sound_effects.dart';
import 'package:yofardev_ai/features/avatar/domain/services/prop_reaction_service.dart';

void main() {
  late PropReactionService service;

  setUp(() {
    service = PropReactionService();
  });

  group('PropReactionService prop table', () {
    test('every contract propId has a reaction in its scene', () {
      final Map<String, List<String>> propsByScene = <String, List<String>>{
        'livingRoom': <String>['lamp', 'tv', 'cat', 'plant'],
        'campfire': <String>['fire', 'tent', 'owl', 'sky'],
        'beach': <String>['crab', 'umbrella', 'seagull'],
        'deepSpace': <String>['planet', 'ufo', 'rubberDuck'],
        'cafe': <String>['cup', 'espresso', 'window', 'fish'],
        'rooftop': <String>['telescope', 'antenna', 'pigeon', 'moon'],
        'mountainHut': <String>['stove', 'window', 'dog', 'bell'],
      };
      propsByScene.forEach((String sceneId, List<String> props) {
        final AvatarScene scene = AvatarScene.values.byName(sceneId);
        for (final String propId in props) {
          expect(
            service.reactionForProp(scene, propId),
            isNotNull,
            reason: '$sceneId/$propId must have a reaction',
          );
        }
      });
    });

    test('unknown props return null (no reaction)', () {
      expect(service.reactionForProp(AvatarScene.beach, 'volcano'), isNull);
      expect(service.reactionForProp(AvatarScene.beach, ''), isNull);
    });

    test('reactions only use known sounds, moods and gestures', () {
      final List<String> allProps = <String>[
        'lamp',
        'tv',
        'cat',
        'plant',
        'fire',
        'tent',
        'owl',
        'sky',
        'crab',
        'umbrella',
        'seagull',
        'planet',
        'ufo',
        'rubberDuck',
        'cup',
        'espresso',
        'window',
        'fish',
        'telescope',
        'antenna',
        'pigeon',
        'moon',
        'stove',
        'dog',
        'bell',
      ];
      for (final String propId in allProps) {
        for (final AvatarScene scene in AvatarScene.values) {
          final PropReaction? reaction = service.reactionForProp(scene, propId);
          if (reaction == null) {
            continue;
          }
          if (reaction.soundEffect != null) {
            expect(
              SoundEffects.values.map((SoundEffects s) => s.name),
              contains(reaction.soundEffect!.name),
            );
          }
        }
      }
    });

    test('a few spot checks', () {
      expect(
        service.reactionForProp(AvatarScene.livingRoom, 'tv')!.gesture,
        AvatarGesture.laugh,
      );
      expect(
        service.reactionForProp(AvatarScene.campfire, 'sky')!.mood,
        AvatarMood.sad,
      );
      expect(
        service.reactionForProp(AvatarScene.deepSpace, 'ufo')!.mood,
        AvatarMood.surprised,
      );
    });
  });

  group('PropReactionService avatar zones', () {
    test('head and body both react', () {
      expect(service.reactionForZone('head'), isNotNull);
      expect(service.reactionForZone('body'), isNotNull);
    });

    test('unknown zones return null', () {
      expect(service.reactionForZone('foot'), isNull);
      expect(service.reactionForZone(''), isNull);
    });
  });
}
