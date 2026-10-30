import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rive/rive.dart' show RiveHitTestBehavior;
import 'package:yofardev_ai/core/models/avatar_scene.dart';
import 'package:yofardev_ai/core/services/audio/foley_service.dart';
import 'package:yofardev_ai/core/models/performance/shot.dart';
import 'package:yofardev_ai/features/avatar/domain/models/scene_drag.dart';
import 'package:yofardev_ai/features/avatar/presentation/rive/prop_drag_controller.dart';
import 'package:yofardev_ai/features/avatar/presentation/rive/stage_framing.dart';
import 'package:yofardev_ai/features/avatar/presentation/widgets/rive/rive_avatar_view.dart';
import 'package:yofardev_ai/features/avatar/presentation/widgets/rive/rive_scene_view.dart';
import 'package:yofardev_ai/features/avatar/presentation/widgets/stage_camera.dart';

import '../../../../helpers/rive_test_assets.dart';

const Size _phone = Size(390, 844);

/// The avatar as the real one hit-tests (`RiveHitTestBehavior.translucent`):
/// only its own zones claim a pointer; elsewhere it lets it through.
class _FakeAvatar extends StatelessWidget {
  const _FakeAvatar({required this.head, required this.onHead});

  final Rect head;
  final VoidCallback onHead;

  @override
  Widget build(BuildContext context) => Stack(
    children: <Widget>[
      Positioned.fromRect(
        rect: head,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onHead,
          onPanUpdate: (DragUpdateDetails _) {},
        ),
      ),
    ],
  );
}

void main() {
  setUp(serveFakeRiveAssets);

  late PropDragController drags;
  late Map<String, double> vm;

  Future<void> mount(
    WidgetTester tester, {
    Widget? middle,
    ValueNotifier<CameraShot>? shot,
    AvatarScene sceneId = AvatarScene.livingRoom,
    ValueChanged<DragHaptic>? onDragHaptic,
    ValueChanged<String>? onDragFoley,
    ValueChanged<SceneEvent>? onDragEvent,
  }) async {
    // the test's fake clock, so springs settle under pumpAndSettle
    final DateTime start = tester.binding.clock.now();
    drags = PropDragController(
      now: () => tester.binding.clock.now().difference(start),
    );
    final Map<String, double> values = vm = <String, double>{};
    tester.view.physicalSize = _phone;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final Widget scene = RiveSceneView(
      scene: sceneId,
      sceneEvent: (sceneEvent: SceneEvent.lightsOn, seq: 0),
      dragController: drags,
      middle: middle,
      onDragHaptic: onDragHaptic,
      onDragFoley: onDragFoley,
      onDragEvent: onDragEvent,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: shot == null ? scene : StageCamera(shot: shot, child: scene),
        ),
      ),
    );
    // No Rive file decodes in a widget test: attach the controller to a
    // fake view model, as a loaded file would.
    await tester.pump();
    drags.attach(
      sceneId,
      setNumber: (String name, double value) => values[name] = value,
    );
  }

  /// The cord's rect on the scene widget (wide shot, parallax 0).
  Rect cordLocal() {
    final Rect r = SceneDrags.of(AvatarScene.livingRoom)!.rect;
    return Rect.fromPoints(
      SceneDrags.toLocal(r.topLeft, _phone),
      SceneDrags.toLocal(r.bottomRight, _phone),
    );
  }

  testWidgets('a pan on the cord pulls it (positive control)', (
    WidgetTester tester,
  ) async {
    await mount(tester);
    final TestGesture g = await tester.startGesture(cordLocal().center);
    await g.moveBy(const Offset(0, 20));
    await g.moveBy(const Offset(0, 20));
    await tester.pump();
    // 40 local px / 0.4396 = 91 artboard px of a 100 px pull
    expect(vm['cord'], closeTo(40 / SceneDrags.coverScale(_phone) / 100, 0.01));
    await g.up();
    await tester.pumpAndSettle();
    expect(vm['cord'], 0);
  });

  testWidgets(
    'Review Focus 1: a pan from the avatar head zone never drags the scene',
    (WidgetTester tester) async {
      int headTaps = 0;
      final Rect cord = cordLocal();
      // the head zone sits right over the cord's middle
      final Rect head = Rect.fromCenter(
        center: cord.center,
        width: 80,
        height: 40,
      );
      await mount(
        tester,
        middle: _FakeAvatar(head: head, onHead: () => headTaps++),
      );
      final TestGesture g = await tester.startGesture(head.center);
      await g.moveBy(const Offset(0, 30));
      await g.moveBy(const Offset(0, 30));
      await tester.pump();
      await g.up();
      await tester.pumpAndSettle();
      expect(vm['cord'] ?? 0, 0);
      expect(drags.dragging, isFalse);
      // the head still gets its own taps
      await tester.tapAt(head.center);
      expect(headTaps, 1);
      // and the cord below the head zone still drags
      final TestGesture h = await tester.startGesture(
        Offset(cord.center.dx, cord.bottom - 4),
      );
      await h.moveBy(const Offset(0, 20));
      await h.moveBy(const Offset(0, 20));
      await tester.pump();
      expect(vm['cord'], greaterThan(0));
      await h.up();
      await tester.pumpAndSettle();
    },
  );

  testWidgets('a pan off the handle is left alone', (
    WidgetTester tester,
  ) async {
    await mount(tester);
    final TestGesture g = await tester.startGesture(const Offset(300, 700));
    await g.moveBy(const Offset(0, 60));
    await tester.pump();
    await g.up();
    expect(vm, isEmpty);
  });

  testWidgets(
    'Review Focus 4: at a close-up the drag still lands on the cord',
    (WidgetTester tester) async {
      final ValueNotifier<CameraShot> shot = ValueNotifier<CameraShot>(
        const CameraShot(shot: Shot.closeUp, move: CameraMove.cut),
      );
      addTearDown(shot.dispose);
      await mount(tester, shot: shot);
      final ({double zoom, Offset translate}) f = StageFraming.of(
        Shot.closeUp,
        _phone,
      );
      expect(f.zoom, greaterThan(1.5));
      // the cord's centre, local to the scene, through the camera's transform
      final Offset local = drags.handleCentre(_phone)!;
      final Offset screen = local * f.zoom + f.translate;
      expect((Offset.zero & _phone).contains(screen), isTrue);
      final TestGesture g = await tester.startGesture(screen);
      await g.moveBy(const Offset(0, 20));
      await g.moveBy(const Offset(0, 20));
      await tester.pump();
      // 40 screen px at zoom 2 are 20 local px
      expect(
        vm['cord'],
        closeTo(40 / f.zoom / SceneDrags.coverScale(_phone) / 100, 0.01),
      );
      await g.up();
      await tester.pumpAndSettle();
      // the wide-shot position of the cord is not the cord at a close-up
      final TestGesture h = await tester.startGesture(local);
      await h.moveBy(const Offset(0, 40));
      await tester.pump();
      expect(drags.dragging, isFalse);
      await h.up();
    },
  );

  testWidgets('a scene swap ends the drag in flight', (
    WidgetTester tester,
  ) async {
    await mount(tester);
    final TestGesture g = await tester.startGesture(cordLocal().center);
    await g.moveBy(const Offset(0, 40));
    await tester.pump();
    expect(drags.dragging, isTrue);
    final double before = vm['cord']!;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RiveSceneView(
            scene: AvatarScene.campfire,
            sceneEvent: (sceneEvent: SceneEvent.flare, seq: 0),
            dragController: drags,
          ),
        ),
      ),
    );
    expect(drags.dragging, isFalse);
    expect(drags.scene, isNull);
    await g.moveBy(const Offset(0, 40));
    await g.up();
    await tester.pumpAndSettle();
    expect(vm['cord'], before);
  });

  group('the real gesture arena (fix round 1)', () {
    testWidgets('a slow drag on the campfire stick never flares', (
      WidgetTester tester,
    ) async {
      final List<SceneEvent> events = <SceneEvent>[];
      await mount(
        tester,
        sceneId: AvatarScene.campfire,
        onDragEvent: events.add,
      );
      // on the tip, then back and forth at 4 px per 16 ms (~570 artboard
      // px/s), past the accept distance from the first move
      final Offset tip = SceneDrags.toLocal(const Offset(196, 1130), _phone);
      final TestGesture g = await tester.startGesture(tip);
      double previousX = 0;
      for (int i = 1; i <= 60; i++) {
        final int k = i % 20;
        final double x = 4.0 * (k < 10 ? k : 20 - k);
        await g.moveBy(Offset(x - previousX, 0));
        previousX = x;
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(drags.dragging, isTrue);
      expect(vm['poke'], greaterThan(0));
      // the tip under the finger: at most a few px off
      expect(
        vm['pokeX']!,
        closeTo(
          (SceneDrags.toArtboard(tip + Offset(previousX, 0), _phone).dx - 196) /
              108,
          0.02,
        ),
      );
      await g.up();
      await tester.pumpAndSettle();
      expect(events, isEmpty);
    });

    testWidgets('a cord pull: the start click, then the threshold impact', (
      WidgetTester tester,
    ) async {
      final List<String> felt = <String>[];
      final ValueNotifier<bool> enabled = ValueNotifier<bool>(true);
      addTearDown(enabled.dispose);
      final FoleyService foley = FoleyService(
        createPlayer: _SilentPlayer.new,
        haptics: _Haptics(felt),
        enabled: enabled,
        now: () => tester.binding.clock.now(),
      );
      final List<SceneEvent> events = <SceneEvent>[];
      await mount(
        tester,
        onDragHaptic: foley.haptic,
        onDragFoley: (String kind) => foley.play(kind, haptic: false),
        onDragEvent: events.add,
      );
      final Offset a = cordLocal().center;
      final TestGesture g = await tester.startGesture(a);
      // the accept: the cord starts near the finger
      await g.moveBy(const Offset(0, 4));
      await tester.pump(const Duration(milliseconds: 16));
      expect(vm['cord'], lessThan(0.1));
      for (int i = 0; i < 8; i++) {
        await g.moveBy(const Offset(0, 4));
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(vm['cord'], greaterThan(0.6));
      expect(felt, <String>['selection', 'light']);
      expect(events, <SceneEvent>[SceneEvent.lightsOff]);
      await g.up();
      await tester.pumpAndSettle();
      // a flick: the impact still follows the start click within 60 ms
      felt.clear();
      final TestGesture h = await tester.startGesture(a);
      await h.moveBy(const Offset(0, 40));
      await tester.pump();
      expect(felt, <String>['selection', 'light']);
      await h.up();
      await tester.pumpAndSettle();
    });
  });

  test('the real avatar view hit-tests translucent (Review Focus 1)', () {
    expect(RiveAvatarView.hitTestBehavior, RiveHitTestBehavior.translucent);
    // and its RiveWidget uses it (the native runtime cannot load in a test)
    final String src = File(
      'lib/features/avatar/presentation/widgets/rive/rive_avatar_view.dart',
    ).readAsStringSync();
    final int widget = src.indexOf('return RiveWidget(');
    expect(widget, greaterThan(-1));
    expect(
      src.substring(widget, src.indexOf(');', widget)),
      contains('hitTestBehavior: RiveAvatarView.hitTestBehavior'),
    );
  });
}

class _SilentPlayer implements FoleyPlayer {
  @override
  Future<void> play(String asset, double volume) async {}

  @override
  Future<void> dispose() async {}
}

class _Haptics implements HapticsSink {
  _Haptics(this.felt);

  final List<String> felt;

  @override
  void lightImpact() => felt.add('light');

  @override
  void selectionClick() => felt.add('selection');
}
