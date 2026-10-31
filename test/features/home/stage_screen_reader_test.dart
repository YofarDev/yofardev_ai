import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yofardev_ai/core/design/rive/ui_kit_file.dart';
import 'package:yofardev_ai/core/models/avatar_scene.dart';
import 'package:yofardev_ai/core/services/app_lifecycle_service.dart';
import 'package:yofardev_ai/features/avatar/avatar.dart';
import 'package:yofardev_ai/features/home/widgets/home_content_stack.dart';

import '../../helpers/rive_test_assets.dart';
import 'stage_harness.dart';

/// M11 rulings 17, 18 and 20 on the whole Home stage: the screen-reader
/// path (top chips, the stage node, the bottom chrome), the stage's actions
/// reaching the tap's path, the More menu's rows and the picker's tiles in
/// order, and reduce motion's cross-fade cut.
void main() {
  late StageHarness h;
  late AppLifecycleService lifecycle;

  setUpAll(() => registerFallbackValue(AvatarScene.livingRoom));

  setUp(() {
    serveFakeRiveAssets();
    UiKitFile.resetForTest();
    h = StageHarness();
    lifecycle = AppLifecycleService();
    when(() => h.avatarCubit.onPropTapped(any(), any())).thenReturn(null);
  });

  tearDown(() => lifecycle.dispose());

  Future<void> pumpStage(WidgetTester tester, {String? tool}) async {
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    h.chat.emit(h.chat.state.copyWith(activeTool: tool));
    await tester.pumpWidget(
      h.app(
        Scaffold(
          resizeToAvoidBottomInset: false,
          body: HomeContentStack(
            speech: h.speech,
            lifecycle: lifecycle,
            onStartDemo: () {},
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// The labelled nodes a screen reader visits, in order.
  List<SemanticsNode> walk(WidgetTester tester) => <SemanticsNode>[
    for (final SemanticsNode node
        in tester.semantics.simulatedAccessibilityTraversal())
      if (node.label.isNotEmpty) node,
  ];

  List<String> labels(WidgetTester tester) => <String>[
    for (final SemanticsNode node in walk(tester)) node.label,
  ];

  testWidgets('the stage reads after the top chips, before the composer', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await pumpStage(tester, tool: 'getCurrentWeather');
    expect(labels(tester), <String>[
      'History',
      'Menu',
      'Yofardev AI in the Living room scene',
      'Checking the weather…',
      'More options',
      'Ask anything…',
      'Talk',
    ]);
    final SemanticsNode stage = walk(tester)[2];
    expect(stage.value, 'idle');
    // no stray node under it: the Rive layers are excluded
    expect(stage.childrenCount, 0);
    handle.dispose();
  });

  testWidgets("a prop action runs the tap's path (the cubit's reaction)", (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await pumpStage(tester);
    final SemanticsNode stage = tester.getSemantics(
      find.bySemanticsLabel('Yofardev AI in the Living room scene'),
    );
    final int cat = stage
        .getSemanticsData()
        .customSemanticsActionIds!
        .firstWhere(
          (int id) =>
              CustomSemanticsAction.getAction(id)!.label == 'Poke the cat',
        );
    stage.owner!.performAction(stage.id, SemanticsAction.customAction, cat);
    verify(
      () => h.avatarCubit.onPropTapped(AvatarScene.livingRoom, 'cat'),
    ).called(1);
    handle.dispose();
  });

  testWidgets('the More menu rows are labelled buttons, in order', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await pumpStage(tester);
    await tester.tap(find.bySemanticsLabel('Menu'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final List<SemanticsNode> rows = <SemanticsNode>[
      for (final SemanticsNode node in walk(tester))
        if (node.getSemanticsData().flagsCollection.isButton &&
            !<String>{
              'History',
              'Menu',
              'More options',
              'Talk',
            }.contains(node.label))
          node,
    ];
    expect(
      <String>[for (final SemanticsNode n in rows) n.label],
      <String>[
        'New chat',
        'Language: Français',
        'Hide captions',
        'Scenes',
        'Settings',
        'Play the demo',
      ],
    );
    handle.dispose();
  });

  testWidgets('the picker: ten buttons in order, the current one selected '
      'with a "current scene" hint', (WidgetTester tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    h.avatar.emit(h.avatar.state.copyWith(scene: AvatarScene.forestCabin));
    await pumpStage(tester);
    await tester.tap(find.bySemanticsLabel('Menu'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Scenes'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    final List<SemanticsNode> nodes = walk(tester);
    final int title = nodes.indexWhere(
      (SemanticsNode n) => n.label == 'Choose a scene',
    );
    expect(title, isNot(-1));
    expect(nodes[title].getSemanticsData().flagsCollection.isHeader, isTrue);
    final List<SemanticsNode> tiles = nodes.sublist(title + 1, title + 11);
    expect(
      <String>[for (final SemanticsNode n in tiles) n.label],
      <String>[
        'Living room',
        'Campfire',
        'Beach',
        'Deep space',
        'Café',
        'Rooftop',
        'Mountain hut',
        'Forest cabin',
        'Train compartment',
        'Library',
      ],
    );
    for (final SemanticsNode tile in tiles) {
      final SemanticsData data = tile.getSemanticsData();
      final bool current = tile.label == 'Forest cabin';
      expect(data.flagsCollection.isButton, isTrue, reason: tile.label);
      expect(data.flagsCollection.isSelected.toBoolOrNull(), current);
      expect(data.hint, current ? 'Current scene' : '');
      // the current scene cannot be picked again
      expect(data.hasAction(SemanticsAction.tap), !current);
    }
    handle.dispose();
  });

  group('reduce motion: the cross-fade cut', () {
    double fade(WidgetTester tester) => tester
        .widget<AnimatedOpacity>(
          find.byKey(const ValueKey<String>('journey-fade')),
        )
        .opacity;

    JourneyState journey(JourneyPhase phase) => JourneyState(
      from: AvatarScene.livingRoom,
      to: AvatarScene.beach,
      family: JourneyFamily.door,
      phase: phase,
      serial: phase.index,
      reduced: true,
    );

    testWidgets('the stage fades out for the cut and back in after it', (
      WidgetTester tester,
    ) async {
      await pumpStage(tester);
      expect(fade(tester), 0);
      h.avatar.emit(
        h.avatar.state.copyWith(journey: journey(JourneyPhase.close)),
      );
      await tester.idle();
      await tester.pump();
      expect(fade(tester), 1);
      final AnimatedOpacity opacity = tester.widget<AnimatedOpacity>(
        find.byKey(const ValueKey<String>('journey-fade')),
      );
      expect(opacity.duration, JourneyTiming.reducedFade);
      h.avatar.emit(
        h.avatar.state.copyWith(
          journey: journey(JourneyPhase.cut),
          scene: AvatarScene.beach,
        ),
      );
      await tester.idle();
      await tester.pump();
      expect(fade(tester), 1);
      h.avatar.emit(
        h.avatar.state.copyWith(journey: journey(JourneyPhase.vanish)),
      );
      await tester.idle();
      await tester.pump();
      expect(fade(tester), 0);
      h.avatar.emit(h.avatar.state.copyWith(journey: null));
      await tester.pump(JourneyTiming.reducedFade);
      expect(fade(tester), 0);
    });

    testWidgets('a full journey never fades the stage', (
      WidgetTester tester,
    ) async {
      await pumpStage(tester);
      h.avatar.emit(
        h.avatar.state.copyWith(
          journey: const JourneyState(
            from: AvatarScene.livingRoom,
            to: AvatarScene.beach,
            family: JourneyFamily.door,
            phase: JourneyPhase.cut,
            serial: 1,
          ),
        ),
      );
      await tester.idle();
      await tester.pump();
      expect(fade(tester), 0);
    });
  });
}
