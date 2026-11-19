import 'dart:io';
import 'package:yofardev_ai/core/models/geometry.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/models/avatar_scene.dart';
import 'package:yofardev_ai/features/avatar/domain/models/scene_drag.dart';
import 'package:yofardev_ai/features/avatar/presentation/rive/avatar_rive_contract.dart';

Offset _off(Vec2 v) => Offset(v.x, v.y);

/// One parsed row of the contract's "Drag handles (v12)" table.
typedef _Row = ({
  String id,
  String kind,
  Box2 rect,
  int plane,
  List<DragNumber> numbers,
});

double _num(String s) => double.parse(s.trim().replaceAll('−', '-'));

/// Parses `rive/CONTRACT.md`'s drag table like `world_kit.parse_drags`: a
/// `trail` row's numbers are the canonical trail set; other rows list each
/// number in backticks with its default in the first "(n)" after it.
Map<String, _Row> _parseDragTable() {
  final List<String> lines = File('rive/CONTRACT.md').readAsLinesSync();
  final int at = lines.indexOf('### Drag handles (v12)');
  expect(at, greaterThan(-1), reason: 'the drag table exists');
  final List<List<String>> rows = <List<String>>[];
  for (final String line in lines.skip(at + 1)) {
    if (line.startsWith('|')) {
      final List<String> cells = line
          .trim()
          .substring(1, line.trim().length - 1)
          .split('|')
          .map((String c) => c.trim())
          .toList();
      if (!RegExp(r'^[-: ]*$').hasMatch(cells.join())) {
        rows.add(cells);
      }
    } else if (rows.isNotEmpty) {
      break;
    }
  }
  final Map<String, _Row> out = <String, _Row>{};
  for (final List<String> cells in rows.skip(1)) {
    final List<double> rect = cells[3]
        .replaceAll('(', '')
        .replaceAll(')', '')
        .split(',')
        .map(_num)
        .toList();
    final List<DragNumber> numbers = <DragNumber>[];
    if (cells[2] == 'trail') {
      // world_kit.TRAIL_NUMBERS: trailN, trailX0..15, trailY0..15, trailFade
      numbers
        ..add((name: 'trailN', value: 0.0))
        ..addAll(<DragNumber>[
          for (int i = 0; i < 16; i++) (name: 'trailX$i', value: 0.0),
        ])
        ..addAll(<DragNumber>[
          for (int i = 0; i < 16; i++) (name: 'trailY$i', value: 0.0),
        ])
        ..add((name: 'trailFade', value: 1.0));
    } else {
      final List<String> parts = cells[5].split(RegExp(r'`(\w+)`'));
      final List<String> names = RegExp(
        r'`(\w+)`',
      ).allMatches(cells[5]).map((RegExpMatch m) => m.group(1)!).toList();
      for (int i = 0; i < names.length; i++) {
        final RegExpMatch? def = RegExp(
          r'\(([−\d.-]+)\)',
        ).firstMatch(parts[i + 1]);
        numbers.add((
          name: names[i],
          value: def == null ? 0.0 : _num(def.group(1)!),
        ));
      }
    }
    out[cells[0]] = (
      id: cells[1],
      kind: cells[2],
      rect: Box2.fromLTRB(rect[0], rect[1], rect[2], rect[3]),
      plane: int.parse(cells[4]),
      numbers: numbers,
    );
  }
  return out;
}

void main() {
  group('SceneDrags equals the contract drag table', () {
    late Map<String, _Row> table;
    setUpAll(() => table = _parseDragTable());

    test('one handle per scene, every scene', () {
      expect(table.keys.toSet(), AvatarRiveContract.sceneIds.toSet());
      expect(
        SceneDrags.handles.keys.map((AvatarScene s) => s.name).toSet(),
        table.keys.toSet(),
      );
    });

    for (final AvatarScene scene in AvatarScene.values) {
      test('${scene.name}: id, kind, rect, plane, numbers', () {
        final SceneDragHandle handle = SceneDrags.of(scene)!;
        final _Row row = table[scene.name]!;
        const String hint =
            'rive/CONTRACT.md changed: update SceneDrags (scene_drag.dart)';
        expect(handle.id, row.id, reason: hint);
        expect(handle.kind.name, row.kind, reason: hint);
        expect(handle.rect, row.rect, reason: hint);
        expect(handle.plane, row.plane, reason: hint);
        expect(handle.numbers, row.numbers, reason: hint);
      });
    }

    test('the numbers are the Dart contract mirror\'s drag props', () {
      for (final AvatarScene scene in AvatarScene.values) {
        expect(
          SceneDrags.of(scene)!.numbers.map((DragNumber n) => n.name).toSet(),
          AvatarRiveContract.sceneDragProps[scene.name]!.toSet(),
          reason: scene.name,
        );
      }
    });

    test('defaults: everything 0 but trailFade 1', () {
      final SceneDragHandle sand = SceneDrags.of(AvatarScene.beach)!;
      expect(sand.defaults, hasLength(34));
      expect(sand.defaults['trailFade'], 1);
      expect(
        sand.defaults.entries
            .where((MapEntry<String, double> e) => e.key != 'trailFade')
            .every((MapEntry<String, double> e) => e.value == 0),
        isTrue,
      );
    });
  });

  group('mapping', () {
    const Size2 phone = Size2(390, 844);

    test('Fit.cover, centred: the box centre is the artboard centre', () {
      expect(
        _off(SceneDrags.toArtboard(const Vec2(195, 422), phone)),
        offsetMoreOrLessEquals(const Offset(540, 960)),
      );
      // tall box: height-bound scale, the sides cropped evenly
      final double scale = SceneDrags.coverScale(phone);
      expect(scale, closeTo(844 / 1920, 1e-9));
      expect(
        SceneDrags.toArtboard(Vec2.zero, phone).x,
        closeTo((1080 - 390 / scale) / 2, 1e-9),
      );
      // wide box: width-bound, top and bottom cropped
      const Size2 desk = Size2(1600, 900);
      expect(SceneDrags.coverScale(desk), closeTo(1600 / 1080, 1e-9));
      expect(
        _off(SceneDrags.toArtboard(const Vec2(800, 450), desk)),
        offsetMoreOrLessEquals(const Offset(540, 960)),
      );
    });

    test('toLocal is the inverse of toArtboard', () {
      for (final Size2 box in const <Size2>[
        Size2(390, 844),
        Size2(800, 600),
        Size2(1600, 900),
      ]) {
        for (final Vec2 p in const <Vec2>[
          Vec2(0, 0),
          Vec2(300, 760),
          Vec2(1080, 1920),
        ]) {
          expect(
            _off(SceneDrags.toArtboard(SceneDrags.toLocal(p, box), box)),
            offsetMoreOrLessEquals(Offset(p.x, p.y)),
          );
        }
      }
    });

    test('plane offset: gain x (40, 24) x parallax, clamped', () {
      expect(SceneDrags.planeOffset(0, const Vec2(1, 1)), Vec2.zero);
      expect(SceneDrags.planeOffset(3, const Vec2(1, -1)), const Vec2(20, -12));
      expect(SceneDrags.planeOffset(5, const Vec2(-2, 2)), const Vec2(-40, 24));
    });

    test('a handle hit follows its plane at parallax +-1', () {
      final SceneDragHandle cord = SceneDrags.of(AvatarScene.livingRoom)!;
      final Vec2 shift = SceneDrags.planeOffset(cord.plane, const Vec2(1, 0));
      // just inside the moved right edge: outside the rest rect
      final Vec2 lead = Vec2(cord.rect.right + shift.x - 2, 880);
      expect(cord.rect.contains(lead), isFalse);
      expect(SceneDrags.hits(cord, lead, const Vec2(1, 0)), isTrue);
      // the strip the handle left is no longer it
      final Vec2 left = Vec2(cord.rect.left + 2, 880);
      expect(SceneDrags.hits(cord, left, const Vec2(1, 0)), isFalse);
      expect(SceneDrags.hits(cord, left, Vec2.zero), isTrue);
    });
  });
}
