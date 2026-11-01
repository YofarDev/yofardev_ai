import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/models/performance/quality_tier.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yofardev_ai/core/design/components/components.dart';
import 'package:yofardev_ai/core/design/design.dart';
import 'package:yofardev_ai/core/design/rive/ui_kit.dart';
import 'package:yofardev_ai/core/models/avatar_config.dart';
import 'package:yofardev_ai/core/models/avatar_scene.dart';
import 'package:yofardev_ai/core/models/performance/shot.dart';
import 'package:yofardev_ai/features/avatar/avatar.dart';
import 'package:yofardev_ai/features/home/widgets/stage/stage_bubble_layout.dart';
import 'package:yofardev_ai/features/home/widgets/stage/stage_caption.dart';
import 'package:yofardev_ai/features/home/widgets/stage/stage_caption_bubble.dart';
import 'package:yofardev_ai/features/talking/talking.dart';

import '../../../../helpers/golden_test_helper.dart';
import '../../stage_harness.dart';

const String _line = 'The cat thinks the lamp is a second moon.';

/// The mouth in the artboard, about where `MouthAnchor` sits.
const Offset _mouth = Offset(400, 480);

const Size _landscape = Size(1280, 800);
const Size _portrait = Size(390, 844);

/// The chrome's reserve: chips on top, tool chip and composer below.
const EdgeInsets _reserved = EdgeInsets.fromLTRB(16, 72, 16, 140);

/// The whole test stage, for pixel sampling.
const Key _stageKey = ValueKey<String>('test-stage');

void main() {
  late StageHarness h;
  late ValueNotifier<ComposerOrbState> mode;
  late ValueNotifier<Offset?> anchor;
  late ValueNotifier<bool> shown;
  late StageCameraView camera;
  late ValueNotifier<CameraShot> shots;

  setUp(() {
    shots = ValueNotifier<CameraShot>(CameraShot.initial);
    h = StageHarness();
    mode = ValueNotifier<ComposerOrbState>(ComposerOrbState.speaking);
    anchor = ValueNotifier<Offset?>(_mouth);
    shown = ValueNotifier<bool>(false);
    camera = StageCameraView();
  });

  tearDown(() {
    mode.dispose();
    anchor.dispose();
    shown.dispose();
    camera.dispose();
    shots.dispose();
  });

  /// The bubble over a [size] stage, the classic caption at the bottom, with
  /// the given accessibility and motion settings. [shot] mounts a camera
  /// framing it.
  Future<void> pump(
    WidgetTester tester, {
    Size size = _landscape,
    bool reduceMotion = false,
    bool screenReader = false,
    double textScale = 1,
    Shot? shot,
    AvatarScene scene = AvatarScene.livingRoom,
    Widget? backdrop,
    ValueListenable<double>? composerHeight,
    ValueListenable<QualityTier>? tier,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    if (shot != null) {
      shots.value = CameraShot(shot: shot, move: CameraMove.cut, serial: 1);
    }
    await tester.pumpWidget(
      h.app(
        Builder(
          builder: (BuildContext context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              disableAnimations: reduceMotion,
              accessibleNavigation: screenReader,
              textScaler: TextScaler.linear(textScale),
            ),
            child: Scaffold(
              body: RepaintBoundary(
                key: _stageKey,
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    ?backdrop,
                    if (shot != null)
                      StageCamera(
                        shot: shots,
                        view: camera,
                        child: const SizedBox.expand(),
                      ),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: StageCaption(
                        composerMode: mode,
                        bubbleShown: shown,
                      ),
                    ),
                    Positioned.fill(
                      child: StageCaptionBubble(
                        composerMode: mode,
                        anchor: anchor,
                        shown: shown,
                        camera: camera,
                        reserved: _reserved,
                        composerHeight: composerHeight,
                        tier: tier,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        scene: scene,
      ),
    );
    await tester.pump();
  }

  Future<void> say(WidgetTester tester, CaptionState state) async {
    h.caption.emit(state);
    await tester.idle();
    await tester.pump();
    await tester.pump(); // the post-frame `shown`
    await tester.pump(AppMotion.slow);
  }

  Finder bubble() => find.byKey(StageCaptionBubble.bubbleKey);
  Finder classic() => find.byKey(StageCaption.lineKey);

  Rect safeOf(Size size) => Rect.fromLTRB(
    _reserved.left,
    _reserved.top,
    size.width - _reserved.right,
    size.height - _reserved.bottom,
  );

  Rect keepOutOf(Size size, Offset artboard, [Shot shot = Shot.wide]) {
    final StageFrame frame = StageFraming.of(shot, size);
    return StageBubbleLayout.keepOut(
      StageFraming.artboardToStage(artboard, size, frame: frame),
      StageFraming.stageScale(size, frame),
    );
  }

  void expectBubbleClear(WidgetTester tester, Size size, Offset artboard) {
    final Rect rect = tester.getRect(bubble());
    final Rect safe = safeOf(size);
    expect(rect.left, greaterThanOrEqualTo(safe.left - 0.01));
    expect(rect.right, lessThanOrEqualTo(safe.right + 0.01));
    expect(rect.top, greaterThanOrEqualTo(safe.top - 0.01));
    expect(rect.bottom, lessThanOrEqualTo(safe.bottom + 0.01));
    expect(
      rect.overlaps(keepOutOf(size, artboard)),
      isFalse,
      reason: 'the bubble covers the face',
    );
    expect(rect.width, lessThanOrEqualTo(size.width * 0.72 + 0.01));
  }

  group('layout', () {
    testWidgets('speaks in a bubble beside the face; classic hides', (
      WidgetTester tester,
    ) async {
      await pump(tester);
      await say(tester, const CaptionState(text: _line, seq: 1));

      expect(bubble(), findsOneWidget);
      expect(find.text(_line), findsOneWidget, reason: 'only the bubble');
      expect(classic(), findsNothing);
      expect(shown.value, isTrue);
      // centred mouth, equal room: the left side, tail towards the face
      final Rect rect = tester.getRect(bubble());
      final Rect face = keepOutOf(_landscape, _mouth);
      expect(rect.right, lessThanOrEqualTo(face.left));
      expectBubbleClear(tester, _landscape, _mouth);
    });

    testWidgets('takes the side with more room', (WidgetTester tester) async {
      // the mouth far left on the stage: the bubble goes right
      anchor.value = const Offset(40, 480);
      await pump(tester);
      await say(tester, const CaptionState(text: _line, seq: 1));
      final Rect rect = tester.getRect(bubble());
      final Rect face = keepOutOf(_landscape, const Offset(40, 480));
      expect(rect.left, greaterThanOrEqualTo(face.right));
      expectBubbleClear(tester, _landscape, const Offset(40, 480));
    });

    testWidgets('portrait: over the head, inside the chrome', (
      WidgetTester tester,
    ) async {
      await pump(tester, size: _portrait);
      await say(tester, const CaptionState(text: _line, seq: 1));
      final Rect rect = tester.getRect(bubble());
      final Rect face = keepOutOf(_portrait, _mouth);
      expect(rect.bottom, lessThanOrEqualTo(face.top));
      expectBubbleClear(tester, _portrait, _mouth);
    });

    testWidgets('clamped below the top chips when the mouth is high', (
      WidgetTester tester,
    ) async {
      anchor.value = const Offset(400, 60);
      await pump(tester);
      await say(tester, const CaptionState(text: _line, seq: 1));
      expect(tester.getRect(bubble()).top, closeTo(_reserved.top, 0.01));
      expectBubbleClear(tester, _landscape, const Offset(400, 60));
    });

    testWidgets('never covers the face, wherever the mouth is', (
      WidgetTester tester,
    ) async {
      for (final Offset a in <Offset>[
        const Offset(150, 300),
        const Offset(650, 700),
        const Offset(400, 900),
      ]) {
        anchor.value = a;
        await pump(tester);
        await say(tester, CaptionState(text: _line, seq: a.dx.round()));
        // every one of these leaves room beside the face
        expect(shown.value, isTrue, reason: '$a');
        expect(classic(), findsNothing, reason: '$a');
        expectBubbleClear(tester, _landscape, a);
      }
    });

    testWidgets('a tap turns captions off; it is a live region', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pump(tester);
      await say(tester, const CaptionState(text: _line, seq: 1));
      expect(
        tester.getSemantics(find.byKey(StageCaptionBubble.textKey)),
        isSemantics(
          isLiveRegion: true,
          label: _line,
          hasTapAction: true,
          onTapHint: 'Hide captions',
        ),
      );
      await tester.tap(bubble());
      verify(() => h.captionCubit.toggle()).called(1);
      handle.dispose();
    });

    testWidgets('steps aside while the composer listens', (
      WidgetTester tester,
    ) async {
      await pump(tester);
      await say(tester, const CaptionState(text: _line, seq: 1));
      mode.value = ComposerOrbState.listening;
      await tester.pump();
      await tester.pump(AppMotion.slow);
      expect(
        tester
            .widget<Opacity>(
              find.ancestor(of: bubble(), matching: find.byType(Opacity)).first,
            )
            .opacity,
        0,
      );
      expect(classic(), findsNothing);
    });

    testWidgets('lays out once per sentence, not per move', (
      WidgetTester tester,
    ) async {
      await pump(tester);
      await say(tester, const CaptionState(text: _line, seq: 1));
      final Size before = tester.getSize(bubble());
      anchor.value = _mouth + const Offset(30, 10);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.getSize(bubble()), before);
    });
  });

  group('follow', () {
    testWidgets('follows the mouth smoothly to its new place', (
      WidgetTester tester,
    ) async {
      await pump(tester);
      await say(tester, const CaptionState(text: _line, seq: 1));
      final Rect start = tester.getRect(bubble());
      const Offset move = Offset(0, -25); // artboard px: 20 stage px up
      anchor.value = _mouth + move;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      final double early = start.top - tester.getRect(bubble()).top;
      expect(early, greaterThan(0), reason: 'moving');
      expect(early, lessThan(20), reason: 'not a jump');
      await tester.pumpAndSettle();
      expect(start.top - tester.getRect(bubble()).top, closeTo(20, 0.05));
    });

    testWidgets('ignores sub-1 dp jitter', (WidgetTester tester) async {
      await pump(tester);
      await say(tester, const CaptionState(text: _line, seq: 1));
      final Rect start = tester.getRect(bubble());
      for (final Offset jitter in <Offset>[
        const Offset(0.6, -0.5),
        const Offset(-0.7, 0.4),
        const Offset(0.3, 0.9),
      ]) {
        // 1 artboard px = 0.8 stage px here
        anchor.value = _mouth + jitter;
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.pumpAndSettle();
      expect(tester.getRect(bubble()), start);
    });

    testWidgets('reduce motion: placed once, never follows', (
      WidgetTester tester,
    ) async {
      await pump(tester, reduceMotion: true);
      await say(tester, const CaptionState(text: _line, seq: 1));
      final Rect start = tester.getRect(bubble());
      anchor.value = _mouth + const Offset(0, -25);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.getRect(bubble()), start);
      expect(find.byType(Transform), findsWidgets);
      // a plain fade: no scale on the bubble
      final Iterable<Transform> scales = tester
          .widgetList<Transform>(
            find.ancestor(of: bubble(), matching: find.byType(Transform)),
          )
          .where((Transform t) => t.transform.getMaxScaleOnAxis() != 1);
      expect(scales, isEmpty);
    });

    testWidgets('the low tier places it once, like reduce motion', (
      WidgetTester tester,
    ) async {
      final ValueNotifier<QualityTier> tier = ValueNotifier<QualityTier>(
        QualityTier.low,
      );
      addTearDown(tier.dispose);
      await pump(tester, tier: tier);
      await say(tester, const CaptionState(text: _line, seq: 1));
      final Rect start = tester.getRect(bubble());
      anchor.value = _mouth + const Offset(0, -25);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.getRect(bubble()), start);

      // high follows again (the next sentence is laid out for it).
      tier.value = QualityTier.high;
      await tester.pump();
      await say(tester, const CaptionState(text: _line, seq: 2));
      final Rect second = tester.getRect(bubble());
      anchor.value = _mouth;
      await tester.pump();
      await tester.pumpAndSettle();
      expect(tester.getRect(bubble()), isNot(second));
    });

    testWidgets('reduce motion: fades in over AppMotion.fast', (
      WidgetTester tester,
    ) async {
      await pump(tester, reduceMotion: true);
      h.caption.emit(const CaptionState(text: _line, seq: 1));
      await tester.idle();
      await tester.pump();
      await tester.pump(AppMotion.fast);
      expect(
        tester
            .widget<Opacity>(
              find.ancestor(of: bubble(), matching: find.byType(Opacity)).first,
            )
            .opacity,
        1,
      );
    });

    testWidgets(
      'reduce motion: the face moving where nothing fits hands over',
      (WidgetTester tester) async {
        await pump(tester, size: _portrait, reduceMotion: true);
        await say(tester, const CaptionState(text: _line, seq: 1));
        expect(shown.value, isTrue);
        // the head rises onto the bubble: it jumps over the head once
        anchor.value = _mouth + const Offset(0, -330);
        await tester.pump();
        await tester.pump();
        expect(shown.value, isTrue);
        // and again, up under the top chips: no room over it, none beside
        anchor.value = _mouth + const Offset(0, -718);
        await tester.pump();
        await tester.pump();
        await tester.pump(AppMotion.slow);
        expect(shown.value, isFalse);
        expect(classic(), findsOneWidget);
      },
    );
  });

  group('stays through the face\'s own moves', () {
    /// The face's box now, through the live camera.
    Rect faceNow(Size size) {
      final StageFrame frame = camera.frame;
      return StageBubbleLayout.keepOut(
        StageFraming.artboardToStage(anchor.value!, size, frame: frame),
        StageFraming.stageScale(size, frame),
      );
    }

    /// Yaw sways, nods and leans of 20–60 artboard px around the mouth.
    const List<Offset> moves = <Offset>[
      Offset(-20, 0),
      Offset(20, 0),
      Offset(-40, 0),
      Offset(40, 0),
      Offset(-60, 0),
      Offset(60, 0),
      Offset(0, -40),
      Offset(0, 40),
      Offset(-30, 20),
      Offset(30, -20),
      Offset.zero,
    ];

    for (final bool reduce in <bool>[false, true]) {
      for (final Size size in <Size>[_landscape, _portrait]) {
        final String label =
            '${reduce ? 'reduce motion' : 'follow'}, '
            '${size == _landscape ? 'landscape' : 'portrait'}';
        testWidgets('$label: a sway, a nod, a lean keep the bubble', (
          WidgetTester tester,
        ) async {
          await pump(tester, size: size, reduceMotion: reduce);
          await say(tester, const CaptionState(text: _line, seq: 1));
          expect(shown.value, isTrue);
          final Rect placed = tester.getRect(bubble());
          for (final Offset m in moves) {
            // a sway takes a few frames, like the head does
            for (int i = 1; i <= 4; i++) {
              anchor.value = _mouth + m * (i / 4);
              await tester.pump(const Duration(milliseconds: 16));
            }
            for (int i = 0; i < 20; i++) {
              await tester.pump(const Duration(milliseconds: 16));
            }
            expect(shown.value, isTrue, reason: 'ejected at $m');
            expect(bubble(), findsOneWidget);
            expect(classic(), findsNothing);
            final Rect rect = tester.getRect(bubble());
            expect(
              StageBubbleLayout.covers(rect, faceNow(size)),
              isFalse,
              reason: 'covers the face at $m',
            );
            if (reduce) {
              expect(rect, placed, reason: 'reduce motion moved it at $m');
            }
          }
        });
      }
    }

    testWidgets('follow: a sudden head turn under the bubble moves it off', (
      WidgetTester tester,
    ) async {
      await pump(tester);
      await say(tester, const CaptionState(text: _line, seq: 1));
      // a turn of 100 artboard px towards the (left) bubble in one frame
      anchor.value = _mouth + const Offset(-100, 0);
      await tester.pumpAndSettle();
      expect(shown.value, isTrue);
      expect(
        StageBubbleLayout.covers(tester.getRect(bubble()), faceNow(_landscape)),
        isFalse,
      );
    });

    testWidgets('reduce motion: a large turn under it re-places it once', (
      WidgetTester tester,
    ) async {
      await pump(tester, reduceMotion: true);
      await say(tester, const CaptionState(text: _line, seq: 1));
      final Rect placed = tester.getRect(bubble());
      anchor.value = _mouth + const Offset(-160, 0);
      await tester.pump();
      await tester.pump();
      await tester.pump(AppMotion.slow);
      expect(shown.value, isTrue);
      final Rect rect = tester.getRect(bubble());
      expect(rect, isNot(placed));
      expect(StageBubbleLayout.covers(rect, faceNow(_landscape)), isFalse);
    });
  });

  group('camera', () {
    Rect faceNow(Size size) {
      final StageFrame frame = camera.frame;
      return StageBubbleLayout.keepOut(
        StageFraming.artboardToStage(anchor.value!, size, frame: frame),
        StageFraming.stageScale(size, frame),
      );
    }

    for (final Size size in <Size>[_landscape, _portrait]) {
      testWidgets('a cut to a close-up re-lays out and jumps ($size)', (
        WidgetTester tester,
      ) async {
        await pump(tester, size: size, shot: Shot.wide);
        await say(tester, const CaptionState(text: _line, seq: 1));
        shots.value = const CameraShot(
          shot: Shot.closeUp,
          move: CameraMove.cut,
          serial: 2,
        );
        await tester.pump();
        await tester.pump();
        // at once, no glide into the new face box
        expect(shown.value, isTrue);
        expect(
          tester.getRect(bubble()).overlaps(faceNow(size)),
          isFalse,
          reason: 'over the close-up face right after the cut',
        );
        await tester.pump(AppMotion.slow);
        expect(shown.value, isTrue);
        expect(tester.getRect(bubble()).overlaps(faceNow(size)), isFalse);
      });
    }

    testWidgets('a cut within the same shot (creep reset) jumps too', (
      WidgetTester tester,
    ) async {
      await pump(tester, shot: Shot.wide);
      await say(tester, const CaptionState(text: _line, seq: 1));
      shots.value = const CameraShot(
        shot: Shot.wide,
        move: CameraMove.cut,
        serial: 2,
      );
      shots.value = const CameraShot(
        shot: Shot.medium,
        move: CameraMove.cut,
        creep: 0.1,
        serial: 3,
      );
      await tester.pump();
      await tester.pump();
      expect(shown.value, isTrue);
      expect(tester.getRect(bubble()).overlaps(faceNow(_landscape)), isFalse);
    });

    testWidgets('a creep (zoom only, the mouth still) re-places the bubble', (
      WidgetTester tester,
    ) async {
      await pump(tester, shot: Shot.medium);
      await say(tester, const CaptionState(text: _line, seq: 1));
      shots.value = const CameraShot(
        shot: Shot.medium,
        move: CameraMove.ease,
        creep: 0.25,
        creepDuration: Duration(seconds: 2),
        serial: 2,
      );
      for (int i = 0; i < 140; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(
          StageBubbleLayout.covers(
            tester.getRect(bubble()),
            faceNow(_landscape),
          ),
          isFalse,
          reason: 'frame $i',
        );
      }
      await tester.pumpAndSettle();
      expect(shown.value, isTrue);
      expect(tester.getRect(bubble()).overlaps(faceNow(_landscape)), isFalse);
    });
  });

  testWidgets('stays above a composer grown to several lines', (
    WidgetTester tester,
  ) async {
    final ValueNotifier<double> composer = ValueNotifier<double>(56);
    addTearDown(composer.dispose);
    anchor.value = const Offset(400, 900); // low: clamped on the bottom
    await pump(tester, composerHeight: composer);
    await say(tester, const CaptionState(text: _line, seq: 1));
    expect(
      tester.getRect(bubble()).bottom,
      lessThanOrEqualTo(_landscape.height - _reserved.bottom - 56 + 0.01),
    );
    composer.value = 150;
    await tester.pump();
    await say(tester, const CaptionState(text: 'Second moon.', seq: 2));
    expect(
      tester.getRect(bubble()).bottom,
      lessThanOrEqualTo(_landscape.height - _reserved.bottom - 150 + 0.01),
    );
  });

  group('fallbacks: the classic caption', () {
    Future<void> expectClassic(WidgetTester tester) async {
      await say(tester, const CaptionState(text: _line, seq: 1));
      expect(shown.value, isFalse);
      expect(classic(), findsOneWidget);
      expect(find.text(_line), findsOneWidget);
    }

    testWidgets('no anchor (an older avatar file)', (
      WidgetTester tester,
    ) async {
      anchor.value = null;
      await pump(tester);
      await expectClassic(tester);
      expect(bubble(), findsNothing);
    });

    testWidgets('the anchor appears: the next sentence is a bubble', (
      WidgetTester tester,
    ) async {
      anchor.value = null;
      await pump(tester);
      await expectClassic(tester);
      anchor.value = _mouth;
      await tester.pump();
      await say(tester, const CaptionState(text: 'Second moon.', seq: 2));
      expect(shown.value, isTrue);
      expect(bubble(), findsOneWidget);
    });

    testWidgets('the mouth off the stage', (WidgetTester tester) async {
      anchor.value = const Offset(-900, 480);
      await pump(tester);
      await expectClassic(tester);
    });

    testWidgets('the camera on the prop insert', (WidgetTester tester) async {
      await pump(tester, shot: Shot.propInsert);
      await expectClassic(tester);
    });

    testWidgets('the camera on a close-up still has a bubble', (
      WidgetTester tester,
    ) async {
      await pump(tester, shot: Shot.closeUp);
      await say(tester, const CaptionState(text: _line, seq: 1));
      expect(shown.value, isTrue);
      final Rect face = keepOutOf(_landscape, _mouth, Shot.closeUp);
      expect(tester.getRect(bubble()).overlaps(face), isFalse);
    });

    testWidgets('a journey runs', (WidgetTester tester) async {
      h.avatar.state = h.avatar.state.copyWith(
        journey: const JourneyState(
          from: AvatarScene.livingRoom,
          to: AvatarScene.beach,
          family: JourneyFamily.door,
          phase: JourneyPhase.exit,
          serial: 1,
        ),
      );
      await pump(tester);
      await expectClassic(tester);
    });

    testWidgets('a presence walk runs', (WidgetTester tester) async {
      h.avatar.state = h.avatar.state.copyWith(
        presence: AvatarSpecials.leaveAndComeBack,
      );
      await pump(tester);
      await expectClassic(tester);
    });

    testWidgets('large text (scale 1.5)', (WidgetTester tester) async {
      await pump(tester, textScale: 1.5);
      await expectClassic(tester);
    });

    testWidgets('more than 4 lines', (WidgetTester tester) async {
      await pump(tester, size: _portrait);
      await say(
        tester,
        CaptionState(text: List<String>.filled(40, 'moon').join(' '), seq: 1),
      );
      expect(shown.value, isFalse);
      expect(classic(), findsOneWidget);
    });

    testWidgets('a screen reader is on', (WidgetTester tester) async {
      await pump(tester, screenReader: true);
      await expectClassic(tester);
    });

    testWidgets(
      'the anchor lost mid-sentence: the classic caption takes over',
      (WidgetTester tester) async {
        await pump(tester);
        await say(tester, const CaptionState(text: _line, seq: 1));
        expect(shown.value, isTrue);
        anchor.value = null;
        await tester.pump();
        await tester.pump();
        await tester.pump(AppMotion.slow);
        expect(shown.value, isFalse);
        expect(classic(), findsOneWidget);
      },
    );
  });

  test('fallbackFor: the order of the reasons', () {
    CaptionFallback? reason({
      bool screenReader = false,
      double textScale = 1,
      bool walking = false,
      Shot shot = Shot.medium,
      Offset? anchor = const Offset(100, 100),
    }) => StageCaptionBubble.fallbackFor(
      screenReader: screenReader,
      textScale: textScale,
      walking: walking,
      shot: shot,
      anchor: anchor,
      stage: _landscape,
    );
    expect(reason(), isNull);
    expect(
      reason(screenReader: true, anchor: null),
      CaptionFallback.screenReader,
    );
    expect(reason(textScale: 1.49), isNull);
    expect(reason(textScale: 1.5), CaptionFallback.largeText);
    expect(reason(walking: true), CaptionFallback.walking);
    expect(reason(shot: Shot.propInsert), CaptionFallback.propInsert);
    expect(reason(anchor: null), CaptionFallback.noAnchor);
    expect(reason(anchor: const Offset(-1, 100)), CaptionFallback.offStage);
  });

  group('contrast (sampled from the rendered bubble)', () {
    /// The opaque colour at [p] of the test stage's last frame.
    Future<Color> sample(WidgetTester tester, Offset p) async {
      final RenderRepaintBoundary boundary = tester
          .renderObject<RenderRepaintBoundary>(find.byKey(_stageKey));
      final ui.Image image = (await tester.runAsync(() => boundary.toImage()))!;
      final ByteData bytes = (await tester.runAsync<ByteData?>(
        () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
      ))!;
      final int i = (p.dy.round() * image.width + p.dx.round()) * 4;
      final Color c = Color.fromARGB(
        255,
        bytes.getUint8(i),
        bytes.getUint8(i + 1),
        bytes.getUint8(i + 2),
      );
      image.dispose();
      return c;
    }

    for (final AvatarScene scene in AvatarScene.values) {
      testWidgets('${scene.name}: the caption ink keeps 4.5:1 on the bubble', (
        WidgetTester tester,
      ) async {
        final AppTokens tokens = AppTheme.forScene(
          scene,
        ).extension<AppTokens>()!;
        for (final Color backdrop in <Color>[
          const Color(0xFFFFFFFF),
          const Color(0xFF000000),
          tokens.scene.accent,
          tokens.scene.captionInk,
        ]) {
          await pump(
            tester,
            scene: scene,
            backdrop: ColoredBox(color: backdrop),
          );
          await say(tester, const CaptionState(text: _line, seq: 1));
          final Rect rect = tester.getRect(bubble());
          final double midY =
              rect.top + (rect.height - SpeechBubbleBorder.tailHeight) / 2;
          // inside the text padding, on both ends of the glass gradient
          for (final Offset p in <Offset>[
            Offset(rect.left + 8, midY),
            Offset(rect.right - 8, midY),
            Offset(rect.center.dx, rect.top + 5),
          ]) {
            final Color fill = await sample(tester, p);
            final double ratio = contrastRatio(tokens.scene.captionInk, fill);
            expect(
              ratio,
              greaterThanOrEqualTo(4.5),
              reason: 'over $backdrop at $p (fill $fill): $ratio',
            );
          }
          h.caption.emit(const CaptionState());
          await tester.pumpWidget(const SizedBox());
        }
      });
    }
  });

  group('golden', () {
    setUpAll(GoldenTestHelper.init);

    /// A bright scene stand-in, and the face's keep-out box outlined.
    Widget backdrop(Size size) {
      final Rect face = keepOutOf(size, _mouth);
      return Stack(
        fit: StackFit.expand,
        children: <Widget>[
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[Color(0xFFFFE9B0), Color(0xFF6A4C93)],
              ),
            ),
          ),
          Positioned.fromRect(
            rect: face,
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFFF00FF), width: 2),
              ),
            ),
          ),
        ],
      );
    }

    testGoldens('the bubble beside the face (living room)', (
      WidgetTester tester,
    ) async {
      const Size size = Size(900, 600);
      await pump(tester, size: size, backdrop: backdrop(size));
      await say(tester, const CaptionState(text: _line, seq: 1));
      await GoldenTestHelper.matchGolden(
        tester,
        'stage_caption_bubble_living_room',
        customPump: (WidgetTester t) => t.pump(AppMotion.slow),
      );
    });

    testGoldens('the bubble over the head (portrait, campfire)', (
      WidgetTester tester,
    ) async {
      await pump(
        tester,
        size: _portrait,
        scene: AvatarScene.campfire,
        backdrop: backdrop(_portrait),
      );
      await say(tester, const CaptionState(text: _line, seq: 1));
      await GoldenTestHelper.matchGolden(
        tester,
        'stage_caption_bubble_portrait_campfire',
        customPump: (WidgetTester t) => t.pump(AppMotion.slow),
      );
    });
  });
}
