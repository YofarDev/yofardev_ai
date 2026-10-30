import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/models/performance/shot.dart';
import 'package:yofardev_ai/features/avatar/presentation/rive/stage_framing.dart';

typedef _Framing = ({double zoom, Offset translate});

const Size _portrait = Size(390, 844);
const Size _landscape = Size(1280, 800);

/// The avatar artboard's rect on the stage (contain, bottom-centre).
Rect _artboardOnStage(Size stage) {
  final double s = math.min(stage.width / 800, stage.height / 1000);
  final double w = 800 * s;
  final double h = 1000 * s;
  return Rect.fromLTWH((stage.width - w) / 2, stage.height - h, w, h);
}

/// [StageFraming.rectOf] on the stage.
Rect _shotRect(Shot shot, Size stage) {
  final Rect a = StageFraming.rectOf(shot);
  final Rect board = _artboardOnStage(stage);
  final double s = board.width / 800;
  return Rect.fromLTRB(
    board.left + a.left * s,
    board.top + a.top * s,
    board.left + a.right * s,
    board.top + a.bottom * s,
  );
}

Offset _apply(_Framing f, Offset p) =>
    Offset(p.dx * f.zoom + f.translate.dx, p.dy * f.zoom + f.translate.dy);

void main() {
  group('rects', () {
    test('are the corrected artboard rects', () {
      expect(
        StageFraming.rectOf(Shot.medium),
        const Rect.fromLTRB(130, 100, 670, 900),
      );
      expect(
        StageFraming.rectOf(Shot.closeUp),
        const Rect.fromLTRB(210, 120, 590, 620),
      );
      expect(
        StageFraming.rectOf(Shot.propInsert),
        const Rect.fromLTRB(250, 380, 750, 1000),
      );
    });

    test('the caps', () {
      expect(StageFraming.capOf(Shot.wide), 1);
      expect(StageFraming.capOf(Shot.medium), 1.35);
      expect(StageFraming.capOf(Shot.closeUp), 2.0);
      expect(StageFraming.capOf(Shot.propInsert), 1.8);
    });
  });

  for (final Size stage in <Size>[_portrait, _landscape]) {
    group('on ${stage.width.toInt()}x${stage.height.toInt()}', () {
      test('wide is the identity, whatever the creep', () {
        for (final double creep in <double>[0, 0.1]) {
          final _Framing f = StageFraming.of(Shot.wide, stage, creep: creep);
          expect(f.zoom, 1);
          expect(f.translate, Offset.zero);
        }
      });

      test('zoom is the smallest of the cap and the two fits, never < 1', () {
        for (final Shot shot in <Shot>[
          Shot.medium,
          Shot.closeUp,
          Shot.propInsert,
        ]) {
          final Rect r = _shotRect(shot, stage);
          final double expected = math.max(
            1,
            math.min(
              StageFraming.capOf(shot),
              math.min(stage.height / r.height, stage.width / r.width),
            ),
          );
          expect(
            StageFraming.of(shot, stage).zoom,
            closeTo(expected, 1e-9),
            reason: shot.name,
          );
          expect(StageFraming.of(shot, stage).zoom, greaterThanOrEqualTo(1));
        }
      });

      test('creep multiplies the zoom', () {
        final double base = StageFraming.of(Shot.medium, stage).zoom;
        expect(
          StageFraming.of(Shot.medium, stage, creep: 0.1).zoom,
          closeTo(base * 1.1, 1e-9),
        );
      });

      test('the four corners of the viewport map inside the stage', () {
        for (final Shot shot in Shot.values) {
          for (final double creep in <double>[0, 0.1]) {
            final _Framing f = StageFraming.of(shot, stage, creep: creep);
            // The viewport corner v shows stage point (v - t) / z.
            for (final Offset corner in <Offset>[
              Offset.zero,
              Offset(stage.width, 0),
              Offset(0, stage.height),
              Offset(stage.width, stage.height),
            ]) {
              final Offset p = Offset(
                (corner.dx - f.translate.dx) / f.zoom,
                (corner.dy - f.translate.dy) / f.zoom,
              );
              expect(p.dx, inInclusiveRange(-1e-6, stage.width + 1e-6));
              expect(p.dy, inInclusiveRange(-1e-6, stage.height + 1e-6));
            }
          }
        }
      });
    });
  }

  group('focus', () {
    test('landscape medium: the rect centre is at 45 % of the height', () {
      // Unclamped there: the focus lands exactly at (width / 2, 0.45 height).
      final _Framing f = StageFraming.of(Shot.medium, _landscape);
      final Rect r = _shotRect(Shot.medium, _landscape);
      final Offset at = _apply(f, r.center);
      expect(at.dx, closeTo(_landscape.width / 2, 1e-6));
      expect(at.dy, closeTo(_landscape.height * 0.45, 1e-6));
    });

    test(
      'portrait medium: the bust sits low, so the clamp pins the bottom',
      () {
        // 45 % headroom would pull the stage's bottom edge into view.
        final _Framing f = StageFraming.of(Shot.medium, _portrait);
        expect(f.translate.dy, closeTo(_portrait.height * (1 - f.zoom), 1e-9));
        expect(
          _apply(f, Offset(0, _portrait.height)).dy,
          closeTo(_portrait.height, 1e-9),
        );
      },
    );

    test('a rect near the bottom is pulled up by the clamp, not past it', () {
      // propInsert reaches the bottom edge: the unclamped translation would
      // show below the stage, so the clamp pins the bottom edge.
      final _Framing f = StageFraming.of(Shot.propInsert, _portrait);
      expect(
        f.translate.dy,
        greaterThanOrEqualTo(_portrait.height * (1 - f.zoom) - 1e-6),
      );
      final Offset bottomRight = _apply(
        f,
        Offset(_portrait.width, _portrait.height),
      );
      expect(bottomRight.dy, greaterThanOrEqualTo(_portrait.height - 1e-6));
    });

    test('landscape closeUp frames the face centre horizontally', () {
      final _Framing f = StageFraming.of(Shot.closeUp, _landscape);
      final Rect r = _shotRect(Shot.closeUp, _landscape);
      expect(_apply(f, r.center).dx, closeTo(_landscape.width / 2, 1e-6));
    });
  });

  group('width limit', () {
    test('a width-limited stage clamps propInsert by the rect width', () {
      // On a stage as wide as the artboard's aspect allows, the prop rect is
      // 500 / 800 of the width: 1.6x fits it, under its 1.8 cap.
      final Rect r = _shotRect(Shot.propInsert, _portrait);
      final double zoom = StageFraming.of(Shot.propInsert, _portrait).zoom;
      expect(zoom, closeTo(_portrait.width / r.width, 1e-9));
      expect(zoom, closeTo(1.6, 1e-9));
      expect(zoom, lessThan(StageFraming.capOf(Shot.propInsert)));
    });

    test('the caps bind where the width would allow more', () {
      expect(StageFraming.of(Shot.medium, _portrait).zoom, 1.35);
      expect(StageFraming.of(Shot.closeUp, _portrait).zoom, 2);
    });

    test('a short wide stage is limited by the rect height', () {
      const Size wide = Size(2000, 500);
      final Rect r = _shotRect(Shot.medium, wide);
      expect(
        StageFraming.of(Shot.medium, wide).zoom,
        closeTo(math.max(1, wide.height / r.height), 1e-9),
      );
    });
  });

  group('cameraRenderScale', () {
    test('is min(zoom, max(1, 3 / dpr)), at least 1', () {
      // dpr 1: up to 3x
      expect(cameraRenderScale(2, 1), 2);
      expect(cameraRenderScale(5, 1), 3);
      // dpr 2: up to 1.5x
      expect(cameraRenderScale(2, 2), 1.5);
      expect(cameraRenderScale(1.2, 2), 1.2);
      // dpr 3 and above: screen size
      expect(cameraRenderScale(2.2, 3), 1);
      expect(cameraRenderScale(2.2, 4), 1);
      // never below 1
      expect(cameraRenderScale(0.5, 1), 1);
    });
  });
}
