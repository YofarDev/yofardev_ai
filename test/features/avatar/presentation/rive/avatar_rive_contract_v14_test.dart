import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/models/avatar_scene.dart';
import 'package:yofardev_ai/features/avatar/presentation/rive/avatar_rive_contract.dart';

/// Contract v14 (moonshot M11): the Dart mirror equals `rive/CONTRACT.md`
/// for the three new scenes, the seasons and the tier.
void main() {
  late String contract;
  late List<String> lines;

  setUpAll(() {
    contract = File('rive/CONTRACT.md').readAsStringSync();
    lines = contract.split('\n');
  });

  /// The `SceneVM` bullet that starts with [prefix] (e.g. "- `tier`:").
  String bullet(String prefix) => lines.firstWhere(
    (String l) => l.trimLeft().startsWith(prefix),
    orElse: () => '',
  );

  test('the contract is v14', () {
    expect(lines.first, '# Rive contract (v14)');
  });

  test('the scene ids are the ten AvatarScene names, in order', () {
    expect(AvatarRiveContract.sceneIds, <String>[
      'livingRoom',
      'campfire',
      'beach',
      'deepSpace',
      'cafe',
      'rooftop',
      'mountainHut',
      'forestCabin',
      'trainCompartment',
      'library',
    ]);
    expect(
      AvatarScene.values.map((AvatarScene s) => s.name).toList(),
      AvatarRiveContract.sceneIds,
    );
  });

  test('the v14 scenes\' events and props (ruling 2)', () {
    expect(AvatarRiveContract.sceneEvents['forestCabin'], <String>[
      'gust',
      'fireflies',
      'rain',
      'lanternFlicker',
    ]);
    expect(AvatarRiveContract.sceneEvents['trainCompartment'], <String>[
      'tunnel',
      'whistle',
      'station',
      'rain',
    ]);
    expect(AvatarRiveContract.sceneEvents['library'], <String>[
      'lightning',
      'bookFlutter',
      'clockChime',
      'rain',
    ]);
    expect(AvatarRiveContract.sceneProps['forestCabin'], <String>[
      'lantern',
      'pinwheel',
      'squirrel',
      'woodpile',
    ]);
    expect(AvatarRiveContract.sceneProps['trainCompartment'], <String>[
      'window',
      'lamp',
      'suitcase',
      'ladybug',
    ]);
    expect(AvatarRiveContract.sceneProps['library'], <String>[
      'book',
      'globe',
      'clock',
      'mouse',
    ]);
  });

  test('the v14 SceneEvent values are appended in ruling 2\'s order', () {
    expect(
      SceneEvent.values.skip(24).map((SceneEvent e) => e.name).toList(),
      <String>[
        'gust',
        'fireflies',
        'lanternFlicker',
        'tunnel',
        'whistle',
        'station',
        'lightning',
        'bookFlutter',
        'clockChime',
      ],
    );
  });

  test('forestCabin has a SceneFront; the train and the library do not', () {
    expect(AvatarRiveContract.sceneFrontScenes, <String>{
      'campfire',
      'beach',
      'rooftop',
      'forestCabin',
    });
    expect(contract, contains('v14: forestCabin has one'));
  });

  test('the v14 drag numbers (CONTRACT.md table)', () {
    expect(AvatarRiveContract.scenePropPinwheel, 'pinwheel');
    expect(AvatarRiveContract.scenePropChain, 'chain');
    expect(AvatarRiveContract.scenePropLadder, 'ladder');
    final Map<String, List<String>> drags = AvatarRiveContract.sceneDragProps;
    expect(drags.keys.toList(), AvatarRiveContract.sceneIds);
    expect(drags['forestCabin'], <String>['pinwheel']);
    expect(drags['trainCompartment'], <String>['chain']);
    expect(drags['library'], <String>['ladder']);
    for (final String name in <String>['pinwheel', 'chain', 'ladder']) {
      expect(contract, contains('`$name` '), reason: name);
    }
  });

  test('spring and autumn are v14 numbers, default 0', () {
    expect(AvatarRiveContract.scenePropSpring, 'spring');
    expect(AvatarRiveContract.scenePropAutumn, 'autumn');
    expect(AvatarRiveContract.seasonMin, 0);
    expect(AvatarRiveContract.seasonMax, 1);
    expect(
      bullet('- `spring`, `autumn`:'),
      contains('numbers, 0–1, default 0 (v14)'),
    );
  });

  test('tier is a v14 enum, default ultra', () {
    expect(AvatarRiveContract.scenePropTier, 'tier');
    expect(
      bullet('- `tier`:'),
      contains('enum, low, high, ultra; default **ultra** (v14)'),
    );
  });

  test('the v14 NPCs are poked through their own props', () {
    for (final (String scene, String npc) in <(String, String)>[
      ('forestCabin', 'squirrel'),
      ('trainCompartment', 'ladybug'),
      ('library', 'mouse'),
    ]) {
      expect(AvatarRiveContract.sceneProps[scene], contains(npc));
      expect(contract, contains('**$npc**'), reason: npc);
    }
  });
}
