import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/models/avatar_scene.dart';
import 'package:yofardev_ai/features/avatar/presentation/rive/avatar_rive_contract.dart';

/// Contract v12 (moonshot M9): the Dart mirror equals the scene table of
/// `rive/CONTRACT.md`.
void main() {
  /// The rows `| sceneId | events | props |` of the contract's scene table.
  final Map<String, ({List<String> events, List<String> props})> table =
      <String, ({List<String> events, List<String> props})>{};

  setUpAll(() {
    final List<String> lines = File('rive/CONTRACT.md').readAsLinesSync();
    final int header = lines.indexWhere(
      (String l) =>
          l.startsWith('| sceneId | eventId values | propId values |'),
    );
    expect(header, greaterThan(-1), reason: 'the scene table exists');
    for (final String line in lines.skip(header + 2)) {
      if (!line.startsWith('|')) {
        break;
      }
      final List<String> cells = line
          .split('|')
          .map((String c) => c.trim())
          .where((String c) => c.isNotEmpty)
          .toList();
      List<String> split(String cell) =>
          cell.split(',').map((String v) => v.trim()).toList();
      table[cells[0]] = (events: split(cells[1]), props: split(cells[2]));
    }
  });

  test('the scene ids start with the seven v12 names, in order', () {
    expect(AvatarRiveContract.sceneIds.take(7).toList(), <String>[
      'livingRoom',
      'campfire',
      'beach',
      'deepSpace',
      'cafe',
      'rooftop',
      'mountainHut',
    ]);
    expect(table.keys.toList(), AvatarRiveContract.sceneIds);
    expect(
      AvatarScene.values.map((AvatarScene s) => s.name).toList(),
      AvatarRiveContract.sceneIds,
    );
  });

  test('events and props equal the contract table row by row', () {
    for (final String id in AvatarRiveContract.sceneIds) {
      expect(
        AvatarRiveContract.sceneEvents[id],
        table[id]!.events,
        reason: '$id events',
      );
      expect(
        AvatarRiveContract.sceneProps[id],
        table[id]!.props,
        reason: '$id props',
      );
      expect(
        AvatarScene.values
            .byName(id)
            .allowedEvents
            .map((SceneEvent e) => e.name),
        table[id]!.events,
        reason: '$id allowedEvents',
      );
    }
  });

  test('the new SceneEvent values are appended in contract order', () {
    expect(
      SceneEvent.values.skip(15).take(9).map((SceneEvent e) => e.name).toList(),
      <String>[
        'espresso',
        'doorbell',
        'neonFlicker',
        'fireworks',
        'plane',
        'windowsLit',
        'snowfall',
        'aurora',
        'bell',
      ],
    );
  });

  test('rooftop has a SceneFront next to campfire and beach', () {
    expect(
      AvatarRiveContract.sceneFrontScenes,
      containsAll(<String>{'campfire', 'beach', 'rooftop'}),
    );
    for (final String id in <String>[
      'livingRoom',
      'deepSpace',
      'cafe',
      'mountainHut',
    ]) {
      expect(AvatarRiveContract.sceneFrontScenes, isNot(contains(id)));
    }
  });

  test('the v12 SceneVM names', () {
    expect(AvatarRiveContract.scenePropNpc2, 'npc2');
    expect(AvatarRiveContract.scenePropNpc2X, 'npc2X');
    expect(AvatarRiveContract.scenePropNpc2Look, 'npc2Look');
    expect(AvatarRiveContract.scenePropMoonPhase, 'moonPhase');
    expect(AvatarRiveContract.moonPhaseDefault, -1);
    expect(AvatarRiveContract.scenePropFestive, 'festive');
    expect(AvatarRiveContract.scenePropTrailX, hasLength(16));
    expect(AvatarRiveContract.scenePropTrailX.first, 'trailX0');
    expect(AvatarRiveContract.scenePropTrailX.last, 'trailX15');
    expect(AvatarRiveContract.scenePropTrailY.last, 'trailY15');
  });

  test('every scene declares its own drag numbers (CONTRACT.md table)', () {
    final String contract = File('rive/CONTRACT.md').readAsStringSync();
    final Map<String, List<String>> drags = AvatarRiveContract.sceneDragProps;
    expect(drags.keys.toList(), AvatarRiveContract.sceneIds);
    expect(drags['livingRoom'], <String>['cord']);
    expect(drags['campfire'], <String>['poke', 'pokeX', 'pokeY']);
    expect(drags['deepSpace'], <String>['spin']);
    expect(drags['rooftop'], <String>['aim']);
    expect(drags['mountainHut'], <String>['rope']);
    expect(drags['beach'], drags['cafe']);
    expect(drags['beach'], hasLength(2 + 16 + 16));
    for (final String name in <String>[
      'cord',
      'poke',
      'pokeX',
      'pokeY',
      'trailN',
      'trailFade',
      'spin',
      'aim',
      'rope',
    ]) {
      expect(contract, contains('`$name`'), reason: name);
    }
  });
}
