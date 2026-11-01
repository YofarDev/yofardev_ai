import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/models/avatar_config.dart';
import 'package:yofardev_ai/core/models/avatar_scene.dart';
import 'package:yofardev_ai/core/models/chat.dart';

/// M10 rulings 5 and 7: tints are new fields with defaults; every avatar
/// stored before v13 loads unchanged, with both tints `none`.
void main() {
  /// Every stored avatar shape M9 wrote (the legacy `top` = hat, `bottom` =
  /// top key swap), with and without a costume, with legacy backgrounds.
  final List<({Map<String, dynamic> map, Avatar expected})> m9Fixtures =
      <({Map<String, dynamic> map, Avatar expected})>[
        (
          map: <String, dynamic>{
            'background': 'livingRoom',
            'top': 'noHat',
            'bottom': 'pinkHoodie',
            'glasses': 'glasses',
            'specials': 'onScreen',
            'costume': 'none',
          },
          expected: const Avatar(),
        ),
        (
          map: <String, dynamic>{
            'background': 'beach',
            'top': 'backwardsCap',
            'bottom': 'swimsuit',
            'glasses': 'sunglasses',
            'specials': 'onScreen',
            'costume': 'none',
          },
          expected: const Avatar(
            background: AvatarScene.beach,
            hat: AvatarHat.backwardsCap,
            top: AvatarTop.swimsuit,
            glasses: AvatarGlasses.sunglasses,
          ),
        ),
        (
          map: <String, dynamic>{
            'background': 'deepSpace',
            'top': 'noHat',
            'bottom': 'pinkHoodie',
            'glasses': 'glasses',
            'specials': 'onScreen',
            'costume': 'singularity',
          },
          expected: const Avatar(
            background: AvatarScene.deepSpace,
            costume: AvatarCostume.singularity,
          ),
        ),
        (
          map: <String, dynamic>{
            'background': 'parisianCafe',
            'top': 'frenchBeret',
            'bottom': 'longCoat',
            'glasses': 'glasses',
            'specials': 'outOfScreen',
            'costume': 'batman',
          },
          expected: Avatar(
            background: sceneFromStoredBackground('parisianCafe'),
            hat: AvatarHat.frenchBeret,
            top: AvatarTop.longCoat,
            specials: AvatarSpecials.outOfScreen,
            costume: AvatarCostume.batman,
          ),
        ),
        (
          map: <String, dynamic>{
            'background': 'christmasLivingRoom',
            'top': 'santaHat',
            'bottom': 'christmasSweater',
            'glasses': 'glasses',
            'specials': 'onScreen',
            'costume': 'robocop',
          },
          expected: const Avatar(
            hat: AvatarHat.santaHat,
            top: AvatarTop.christmasSweater,
            costume: AvatarCostume.robocop,
          ),
        ),
        (
          map: <String, dynamic>{
            'background': 'rooftop',
            'top': 'redMagaCap',
            'bottom': 'blackSuitAndTie',
            'glasses': 'sunglasses',
            'specials': 'leaveAndComeBack',
            'costume': 'soubrette',
          },
          expected: const Avatar(
            background: AvatarScene.rooftop,
            hat: AvatarHat.redMagaCap,
            top: AvatarTop.blackSuitAndTie,
            glasses: AvatarGlasses.sunglasses,
            specials: AvatarSpecials.leaveAndComeBack,
            costume: AvatarCostume.soubrette,
          ),
        ),
      ];

  group('old chats (M9 stored shapes)', () {
    test('every M9 shape loads unchanged with both tints none', () {
      for (final ({Map<String, dynamic> map, Avatar expected}) f
          in m9Fixtures) {
        final Avatar loaded = Avatar.fromMap(f.map);
        expect(loaded, f.expected, reason: '${f.map}');
        expect(loaded.topTint, AvatarTint.none);
        expect(loaded.hatTint, AvatarTint.none);
      }
    });

    test('an M9 chat map loads through Chat.fromMap', () {
      final Chat chat = Chat.fromMap(<String, dynamic>{
        'id': 'c1',
        'entries': <dynamic>[],
        'avatar': m9Fixtures[3].map,
        'language': 'fr',
        'persona': 'normal',
      });
      expect(chat.avatar, m9Fixtures[3].expected);
    });

    test('the stored map keeps its legacy keys and gains the tints', () {
      final Map<String, dynamic> map = const Avatar(
        hat: AvatarHat.beanie,
        top: AvatarTop.tshirt,
        topTint: AvatarTint.teal,
      ).toMap();
      expect(map['top'], 'beanie');
      expect(map['bottom'], 'tshirt');
      expect(map['topTint'], 'teal');
      expect(map['hatTint'], 'none');
      // the M9 keys are all still there, unchanged
      for (final String key in m9Fixtures.first.map.keys) {
        expect(map.containsKey(key), isTrue, reason: key);
      }
    });

    test('round trip: an M9 shape stored again reads back the same', () {
      for (final ({Map<String, dynamic> map, Avatar expected}) f
          in m9Fixtures) {
        final Avatar once = Avatar.fromMap(f.map);
        expect(Avatar.fromMap(once.toMap()), once);
      }
    });

    test('round trip with every tint, on the top and on the hat', () {
      for (final AvatarTint tint in AvatarTint.values) {
        final Avatar avatar = Avatar(
          hat: AvatarHat.beanie,
          topTint: tint,
          hatTint: AvatarTint.values.reversed.elementAt(tint.index),
        );
        expect(Avatar.fromMap(avatar.toMap()), avatar);
        expect(Avatar.fromJson(avatar.toJson()), avatar);
      }
    });

    test('an unknown or malformed tint reads none', () {
      final Map<String, dynamic> map = <String, dynamic>{
        ...m9Fixtures.first.map,
        'topTint': 'chartreuse',
        'hatTint': 42,
      };
      final Avatar loaded = Avatar.fromMap(map);
      expect(loaded.topTint, AvatarTint.none);
      expect(loaded.hatTint, AvatarTint.none);
      expect(
        Avatar.fromJson(<String, dynamic>{'topTint': 'chartreuse'}).topTint,
        AvatarTint.none,
      );
    });
  });

  test('none is the first value and values are only appended', () {
    expect(AvatarTint.values.map((AvatarTint t) => t.name).toList(), <String>[
      'none',
      'red',
      'orange',
      'yellow',
      'green',
      'teal',
      'blue',
      'purple',
      'pink',
      'grey',
    ]);
  });

  group('AvatarConfig (the patch)', () {
    test(
      'reads the tints from a reply map; missing or unknown is no change',
      () {
        final AvatarConfig config = AvatarConfig.fromMap(<String, dynamic>{
          'topTint': 'blue',
          'hatTint': 'nope',
        });
        expect(config.topTint, AvatarTint.blue);
        expect(config.hatTint, isNull);
        expect(AvatarConfig.fromMap(<String, dynamic>{}).topTint, isNull);
        expect(
          AvatarConfig.fromJson(<String, dynamic>{'topTint': 'nope'}).topTint,
          isNull,
        );
      },
    );
  });

  test('the avatar context the LLM reads names the tints', () {
    final String text = const Avatar(
      topTint: AvatarTint.pink,
      hatTint: AvatarTint.grey,
    ).toString();
    expect(text, contains('"topTint": "pink"'));
    expect(text, contains('"hatTint": "grey"'));
  });
}
