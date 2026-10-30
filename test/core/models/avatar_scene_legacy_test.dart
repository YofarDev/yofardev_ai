import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/models/avatar_config.dart';
import 'package:yofardev_ai/core/models/avatar_scene.dart';

/// Old v3 photo-background names must map to the nearest scene **when
/// read** — stored chat data is never rewritten (design decision, §2).
void main() {
  group('legacy background → scene mapping', () {
    test('indoor backgrounds map to livingRoom', () {
      const List<String> indoor = <String>[
        'bedroom',
        'library',
        'classroom',
        'office',
        'mall',
        'hallMansion',
        'artGallery',
        'cinema',
        'livingRoom',
        'christmasLivingRoom',
      ];
      for (final String name in indoor) {
        expect(
          sceneFromStoredBackground(name),
          AvatarScene.livingRoom,
          reason: '$name should map to livingRoom',
        );
        expect(
          maybeSceneFromStoredBackground(name),
          isNotNull,
          reason: '$name should be recognized',
        );
      }
    });

    test('nature backgrounds map to campfire', () {
      const List<String> nature = <String>[
        'lake',
        'forest',
        'park',
        'sakuraTrees',
        'japaneseGarden',
        'campfire',
      ];
      for (final String name in nature) {
        expect(
          sceneFromStoredBackground(name),
          AvatarScene.campfire,
          reason: '$name should map to campfire',
        );
      }
    });

    test('water backgrounds map to beach', () {
      const List<String> water = <String>[
        'beach',
        'tropicalIsland',
        'swimmingPool',
      ];
      for (final String name in water) {
        expect(
          sceneFromStoredBackground(name),
          AvatarScene.beach,
          reason: '$name should map to beach',
        );
      }
    });

    test('cafés and restaurants map to cafe (M9)', () {
      for (final String name in <String>['restaurant', 'parisianCafe']) {
        expect(
          sceneFromStoredBackground(name),
          AvatarScene.cafe,
          reason: '$name should map to cafe',
        );
      }
    });

    test('night-city backgrounds map to rooftop (M9)', () {
      for (final String name in <String>[
        'cityscrape',
        'balconyViewOfCityByNight',
      ]) {
        expect(
          sceneFromStoredBackground(name),
          AvatarScene.rooftop,
          reason: '$name should map to rooftop',
        );
      }
    });

    test('snowyMountain maps to mountainHut (M9)', () {
      expect(
        sceneFromStoredBackground('snowyMountain'),
        AvatarScene.mountainHut,
      );
    });

    test('urban/space backgrounds map to deepSpace', () {
      const List<String> urban = <String>[
        'deepSpace',
        'street',
        'facadeMansion',
      ];
      for (final String name in urban) {
        expect(
          sceneFromStoredBackground(name),
          AvatarScene.deepSpace,
          reason: '$name should map to deepSpace',
        );
      }
    });

    test('anything unknown falls back to livingRoom', () {
      expect(sceneFromStoredBackground('mountain'), AvatarScene.livingRoom);
      expect(sceneFromStoredBackground('pirate'), AvatarScene.livingRoom);
      expect(sceneFromStoredBackground(''), AvatarScene.livingRoom);
      expect(sceneFromStoredBackground(null), AvatarScene.livingRoom);
    });

    test('maybeSceneFromStoredBackground returns null for unknown values', () {
      expect(maybeSceneFromStoredBackground('mountain'), isNull);
      expect(maybeSceneFromStoredBackground(''), isNull);
      expect(maybeSceneFromStoredBackground(null), isNull);
      expect(maybeSceneFromStoredBackground('beach'), AvatarScene.beach);
    });

    test('every current scene name maps to itself', () {
      for (final AvatarScene scene in AvatarScene.values) {
        expect(sceneFromStoredBackground(scene.name), scene);
      }
    });
  });

  group('Chat.avatar JSON legacy mapping', () {
    test('fromMap maps a legacy background name to a scene', () {
      final Avatar avatar = Avatar.fromMap(<String, dynamic>{
        'background': 'library',
        'top': 'beanie',
        'bottom': 'pinkHoodie',
        'glasses': 'glasses',
        'specials': 'onScreen',
        'costume': 'none',
      });
      expect(avatar.background, AvatarScene.livingRoom);
    });

    test('fromMap falls back to livingRoom for unknown backgrounds', () {
      final Avatar avatar = Avatar.fromMap(<String, dynamic>{
        'background': 'pirate',
        'top': 'noHat',
        'bottom': 'pinkHoodie',
        'glasses': 'glasses',
        'specials': 'onScreen',
        'costume': 'none',
      });
      expect(avatar.background, AvatarScene.livingRoom);
    });
  });

  group('AvatarConfig legacy mapping', () {
    test('fromMap maps recognized legacy names, keeps unknown as null', () {
      final AvatarConfig legacy = AvatarConfig.fromMap(<String, dynamic>{
        'background': 'swimmingPool',
      });
      expect(legacy.background, AvatarScene.beach);

      final AvatarConfig unknown = AvatarConfig.fromMap(<String, dynamic>{
        'background': 'narnia',
      });
      expect(unknown.background, isNull);
    });

    test('the JSON converter applies the same mapping', () {
      expect(
        const SceneNameConverter().fromJson('japaneseGarden'),
        AvatarScene.campfire,
      );
      expect(const SceneNameConverter().fromJson('narnia'), isNull);
      expect(const SceneNameConverter().toJson(AvatarScene.beach), 'beach');
    });
  });
}
