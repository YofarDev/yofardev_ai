import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/models/performance/shot.dart';
import 'package:yofardev_ai/features/avatar/presentation/rive/stage_framing.dart';

const Size _portrait = Size(390, 844);
const Size _landscape = Size(1280, 800);

/// The mouth, roughly where `MouthAnchor` sits in the artboard.
const Offset _mouth = Offset(400, 480);

/// [p] (artboard px) on a [stage] box, with the avatar's fit (contain,
/// bottom-centre) computed independently of [StageFraming].
Offset _contain(Offset p, Size stage) {
  final double s = math.min(stage.width / 800, stage.height / 1000);
  final double left = (stage.width - 800 * s) / 2;
  final double top = stage.height - 1000 * s;
  return Offset(left + p.dx * s, top + p.dy * s);
}

void main() {
  group('artboardToStage', () {
    test('without a camera is the avatar fit (contain, bottom-centre)', () {
      for (final Size stage in <Size>[_portrait, _landscape]) {
        for (final Offset p in <Offset>[
          Offset.zero,
          _mouth,
          const Offset(800, 1000),
        ]) {
          final Offset got = StageFraming.artboardToStage(p, stage);
          final Offset want = _contain(p, stage);
          expect(got.dx, closeTo(want.dx, 1e-9), reason: '$stage $p');
          expect(got.dy, closeTo(want.dy, 1e-9), reason: '$stage $p');
        }
      }
    });

    test('portrait: feet on the bottom edge, centred', () {
      final Offset feet = StageFraming.artboardToStage(
        const Offset(400, 1000),
        _portrait,
      );
      expect(feet.dx, closeTo(195, 1e-9));
      expect(feet.dy, closeTo(844, 1e-9));
    });

    test('landscape: the artboard is pillarboxed, the full height', () {
      final Offset topLeft = StageFraming.artboardToStage(
        Offset.zero,
        _landscape,
      );
      expect(topLeft.dx, closeTo((1280 - 640) / 2, 1e-9));
      expect(topLeft.dy, closeTo(0, 1e-9));
    });

    for (final Shot shot in Shot.values) {
      for (final Size stage in <Size>[_portrait, _landscape]) {
        test('${shot.name} on $stage applies the camera framing', () {
          final StageFrame frame = StageFraming.of(shot, stage);
          final Offset base = _contain(_mouth, stage);
          final Offset want = Offset(
            base.dx * frame.zoom + frame.translate.dx,
            base.dy * frame.zoom + frame.translate.dy,
          );
          final Offset got = StageFraming.artboardToStage(
            _mouth,
            stage,
            frame: frame,
          );
          expect(got.dx, closeTo(want.dx, 1e-9));
          expect(got.dy, closeTo(want.dy, 1e-9));
        });
      }
    }

    test('the mouth stays on the stage for every shot but the prop insert', () {
      for (final Size stage in <Size>[_portrait, _landscape]) {
        for (final Shot shot in <Shot>[Shot.wide, Shot.medium, Shot.closeUp]) {
          final Offset p = StageFraming.artboardToStage(
            _mouth,
            stage,
            frame: StageFraming.of(shot, stage),
          );
          expect(
            (Offset.zero & stage).contains(p),
            isTrue,
            reason: '${shot.name} $stage',
          );
        }
      }
    });

    test('a close-up moves the mouth by the zoom around the framing', () {
      final StageFrame frame = StageFraming.of(Shot.closeUp, _portrait);
      expect(frame.zoom, greaterThan(1));
      final Offset a = StageFraming.artboardToStage(
        _mouth,
        _portrait,
        frame: frame,
      );
      final Offset b = StageFraming.artboardToStage(
        _mouth + const Offset(10, 0),
        _portrait,
        frame: frame,
      );
      expect(
        b.dx - a.dx,
        closeTo(10 * StageFraming.stageScale(_portrait, frame), 1e-9),
      );
    });
  });

  group('stageScale', () {
    test('is the contain scale times the zoom', () {
      expect(StageFraming.stageScale(_portrait), closeTo(390 / 800, 1e-12));
      expect(StageFraming.stageScale(_landscape), closeTo(0.8, 1e-12));
      final StageFrame medium = StageFraming.of(Shot.medium, _landscape);
      expect(
        StageFraming.stageScale(_landscape, medium),
        closeTo(0.8 * medium.zoom, 1e-12),
      );
    });

    test('is 0 on an empty stage', () {
      expect(StageFraming.stageScale(Size.zero), 0);
    });
  });

  test('identity is no zoom, no move', () {
    expect(StageFraming.identity.zoom, 1);
    expect(StageFraming.identity.translate, Offset.zero);
  });
}
