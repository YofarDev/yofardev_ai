import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/models/avatar_scene.dart';
import 'package:yofardev_ai/features/avatar/domain/models/scene_drag.dart';
import 'package:yofardev_ai/features/avatar/presentation/rive/avatar_rive_contract.dart';

/// One parsed row of the contract's "Drag handles (v12)" table.
typedef _Row = ({
  String id,
  String kind,
  Rect rect,
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
      rect: Rect.fromLTRB(rect[0], rect[1], rect[2], rect[3]),
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
    const Size phone = Size(390, 844);

    test('Fit.cover, centred: the box centre is the artboard centre', () {
      expect(
        SceneDrags.toArtboard(const Offset(195, 422), phone),
        offsetMoreOrLessEquals(const Offset(540, 960)),
      );
      // tall box: height-bound scale, the sides cropped evenly
      final double scale = SceneDrags.coverScale(phone);
      expect(scale, closeTo(844 / 1920, 1e-9));
      expect(
        SceneDrags.toArtboard(Offset.zero, phone).dx,
        closeTo((1080 - 390 / scale) / 2, 1e-9),
      );
      // wide box: width-bound, top and bottom cropped
      const Size desk = Size(1600, 900);
      expect(SceneDrags.coverScale(desk), closeTo(1600 / 1080, 1e-9));
      expect(
        SceneDrags.toArtboard(const Offset(800, 450), desk),
        offsetMoreOrLessEquals(const Offset(540, 960)),
      );
    });

    test('toLocal is the inverse of toArtboard', () {
      for (final Size box in const <Size>[
        Size(390, 844),
        Size(800, 600),
        Size(1600, 900),
      ]) {
        for (final Offset p in const <Offset>[
          Offset(0, 0),
          Offset(300, 760),
          Offset(1080, 1920),
        ]) {
          expect(
            SceneDrags.toArtboard(SceneDrags.toLocal(p, box), box),
            offsetMoreOrLessEquals(p),
          );
        }
      }
    });

    test('plane offset: gain x (40, 24) x parallax, clamped', () {
      expect(SceneDrags.planeOffset(0, const Offset(1, 1)), Offset.zero);
      expect(
        SceneDrags.planeOffset(3, const Offset(1, -1)),
        const Offset(20, -12),
      );
      expect(
        SceneDrags.planeOffset(5, const Offset(-2, 2)),
        const Offset(-40, 24),
      );
    });

    test('a handle hit follows its plane at parallax +-1', () {
      final SceneDragHandle cord = SceneDrags.of(AvatarScene.livingRoom)!;
      final Offset shift = SceneDrags.planeOffset(
        cord.plane,
        const Offset(1, 0),
      );
      // just inside the moved right edge: outside the rest rect
      final Offset lead = Offset(cord.rect.right + shift.dx - 2, 880);
      expect(cord.rect.contains(lead), isFalse);
      expect(SceneDrags.hits(cord, lead, const Offset(1, 0)), isTrue);
      // the strip the handle left is no longer it
      final Offset left = Offset(cord.rect.left + 2, 880);
      expect(SceneDrags.hits(cord, left, const Offset(1, 0)), isFalse);
      expect(SceneDrags.hits(cord, left, Offset.zero), isTrue);
    });
  });
}
