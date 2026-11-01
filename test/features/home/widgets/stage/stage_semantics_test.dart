import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yofardev_ai/core/design/rive/ui_kit.dart';
import 'package:yofardev_ai/core/design/theme/app_theme.dart';
import 'package:yofardev_ai/core/l10n/generated/app_localizations.dart';
import 'package:yofardev_ai/core/models/avatar_config.dart';
import 'package:yofardev_ai/core/models/avatar_scene.dart';
import 'package:yofardev_ai/features/avatar/avatar.dart';
import 'package:yofardev_ai/features/home/widgets/stage/stage_semantics.dart';

import '../../stage_harness.dart';

/// The custom actions' labels on [node], in order.
List<String> actionLabels(SemanticsNode node) => <String>[
  for (final int id
      in node.getSemanticsData().customSemanticsActionIds ?? const <int>[])
    CustomSemanticsAction.getAction(id)!.label!,
];

/// Runs [node]'s custom action [label].
void perform(WidgetTester tester, SemanticsNode node, String label) {
  final int id = node.getSemanticsData().customSemanticsActionIds!.firstWhere(
    (int id) => CustomSemanticsAction.getAction(id)!.label == label,
  );
  node.owner!.performAction(node.id, SemanticsAction.customAction, id);
}

/// M11 ruling 17: the stage is one node with the scene's props and drag as
/// custom actions.
void main() {
  late MockAvatarCubit avatar;
  late Driven<AvatarState> state;
  late ValueNotifier<ComposerOrbState> mode;
  late List<String> props;
  late int drags;

  setUp(() {
    avatar = MockAvatarCubit();
    state = Driven<AvatarState>(
      const AvatarState(avatar: Avatar(), avatarConfig: AvatarConfig()),
    );
    when(() => avatar.state).thenAnswer((_) => state.state);
    when(() => avatar.stream).thenAnswer((_) => state.controller.stream);
    mode = ValueNotifier<ComposerOrbState>(ComposerOrbState.idle);
    props = <String>[];
    drags = 0;
  });

  tearDown(() => mode.dispose());

  Future<void> pump(WidgetTester tester, {Locale locale = const Locale('en')}) {
    return tester.pumpWidget(
      BlocProvider<AvatarCubit>.value(
        value: avatar,
        child: MaterialApp(
          theme: AppTheme.dark,
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: StageSemantics(
            composerMode: mode,
            onProp: props.add,
            onDrag: () => drags++,
            // a stand-in for the Rive layers: its semantics must not leak
            child: Semantics(
              label: 'stray rive node',
              button: true,
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
  }

  SemanticsNode stage(WidgetTester tester, String label) =>
      tester.getSemantics(find.bySemanticsLabel(label));

  testWidgets('label, value and the living room actions (en)', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await pump(tester);
    final SemanticsNode node = stage(
      tester,
      'Yofardev AI in the Living room scene',
    );
    expect(node.getSemanticsData().value, 'idle');
    expect(node.getSemanticsData().flagsCollection.isLiveRegion, isFalse);
    expect(actionLabels(node), <String>[
      'Tap the lamp',
      'Tap the TV',
      'Poke the cat',
      'Tap the plant',
      'Pull the lamp cord',
    ]);
    // the Rive layers are excluded
    expect(find.bySemanticsLabel('stray rive node'), findsNothing);
    expect(node.mergeAllDescendantsIntoThisNode, isFalse);
    expect(node.childrenCount, 0);
    handle.dispose();
  });

  testWidgets('a prop action runs the tap; the drag action runs the drag', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await pump(tester);
    final SemanticsNode node = stage(
      tester,
      'Yofardev AI in the Living room scene',
    );
    perform(tester, node, 'Poke the cat');
    perform(tester, node, 'Tap the lamp');
    expect(props, <String>['cat', 'lamp']);
    perform(tester, node, 'Pull the lamp cord');
    expect(drags, 1);
    handle.dispose();
  });

  testWidgets('the phase follows the composer', (WidgetTester tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await pump(tester);
    const String label = 'Yofardev AI in the Living room scene';
    for (final (ComposerOrbState m, String value)
        in <(ComposerOrbState, String)>[
          (ComposerOrbState.listening, 'listening'),
          (ComposerOrbState.thinking, 'thinking'),
          (ComposerOrbState.speaking, 'speaking'),
          (ComposerOrbState.typing, 'idle'),
          (ComposerOrbState.error, 'idle'),
          (ComposerOrbState.idle, 'idle'),
        ]) {
      mode.value = m;
      await tester.pump();
      expect(stage(tester, label).getSemanticsData().value, value);
    }
    handle.dispose();
  });

  testWidgets('a scene change swaps the actions (forestCabin, fr)', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await pump(tester, locale: const Locale('fr'));
    state.emit(state.state.copyWith(scene: AvatarScene.forestCabin));
    await tester.pump();
    final SemanticsNode node = stage(
      tester,
      'Yofardev AI dans le décor Cabane en forêt',
    );
    expect(node.getSemanticsData().value, 'au repos');
    expect(actionLabels(node), <String>[
      'Toucher la lanterne',
      'Toucher le moulinet',
      'Taquiner l’écureuil',
      'Toucher le tas de bois',
      'Faire tourner le moulinet',
    ]);
    perform(tester, node, 'Toucher le moulinet');
    perform(tester, node, 'Faire tourner le moulinet');
    expect(props, <String>['pinwheel']);
    expect(drags, 1);
    handle.dispose();
  });

  testWidgets('every scene: one action per prop and one for its drag, all '
      'localized in both languages', (WidgetTester tester) async {
    for (final Locale locale in const <Locale>[Locale('en'), Locale('fr')]) {
      final AppLocalizations l10n = await AppLocalizations.delegate.load(
        locale,
      );
      for (final AvatarScene scene in AvatarScene.values) {
        final List<String> props = AvatarRiveContract.sceneProps[scene.name]!;
        final List<String> labels = StageSemantics.actionLabels(l10n, scene);
        expect(
          labels,
          hasLength(props.length + (SceneDrags.of(scene) == null ? 0 : 1)),
          reason: '${scene.name} (${locale.languageCode})',
        );
        expect(labels.toSet(), hasLength(labels.length), reason: 'unique');
      }
    }
  });
}
