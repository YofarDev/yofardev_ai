// M11 ruling 20 evidence: the semantics tree a screen reader walks on Home
// (the stage in livingRoom and in forestCabin) and on the scene picker,
// dumped with `debugDumpSemanticsTree` in traversal order into
// `rive/review/m11/a11y/`.
//
//   flutter test tool/a11y_semantics_dump_test.dart
//
// Not part of `flutter test` (tool/ is outside test/): run it by hand after
// a change to the stage's semantics, then review the diff.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/design/rive/ui_kit_file.dart';
import 'package:yofardev_ai/core/models/avatar_scene.dart';
import 'package:yofardev_ai/core/services/app_lifecycle_service.dart';
import 'package:yofardev_ai/features/home/widgets/home_content_stack.dart';

import '../test/features/home/stage_harness.dart';
import '../test/helpers/rive_test_assets.dart';

const String _outDir = 'rive/review/m11/a11y';

/// The semantics tree, in traversal order, as `debugDumpSemanticsTree`
/// prints it, then every labelled node's custom actions and value.
String _dump(WidgetTester tester, String title) {
  final StringBuffer out = StringBuffer()
    ..writeln('# $title')
    ..writeln()
    ..writeln('## debugDumpSemanticsTree (traversal order)')
    ..writeln();
  final DebugPrintCallback previous = debugPrint;
  debugPrint = (String? message, {int? wrapWidth}) => out.writeln(message);
  try {
    debugDumpSemanticsTree(DebugSemanticsDumpOrder.traversalOrder);
  } finally {
    debugPrint = previous;
  }
  out
    ..writeln()
    ..writeln('## Screen-reader walk (simulatedAccessibilityTraversal)')
    ..writeln();
  int i = 0;
  for (final SemanticsNode node
      in tester.semantics.simulatedAccessibilityTraversal()) {
    if (node.label.isEmpty) {
      continue;
    }
    final SemanticsData data = node.getSemanticsData();
    final List<String> traits = <String>[
      if (data.flagsCollection.isButton) 'button',
      if (data.flagsCollection.isHeader) 'header',
      if (data.flagsCollection.isTextField) 'text field',
      if (data.flagsCollection.isSelected.toBoolOrNull() ?? false) 'selected',
      if (data.flagsCollection.isLiveRegion) 'live region',
    ];
    out.writeln(
      '${++i}. "${node.label}"'
      '${data.value.isEmpty ? '' : ', value "${data.value}"'}'
      '${data.hint.isEmpty ? '' : ', hint "${data.hint}"'}'
      '${traits.isEmpty ? '' : ' [${traits.join(', ')}]'}',
    );
    for (final int id in data.customSemanticsActionIds ?? const <int>[]) {
      final CustomSemanticsAction action = CustomSemanticsAction.getAction(id)!;
      out.writeln(
        '   - action: ${action.label ?? 'override of ${action.action}, '
                'hint "${action.hint}"'}',
      );
    }
  }
  return out.toString();
}

void main() {
  late StageHarness h;
  late AppLifecycleService lifecycle;

  setUp(() {
    serveFakeRiveAssets();
    // ignore: invalid_use_of_visible_for_testing_member
    UiKitFile.resetForTest();
    h = StageHarness();
    lifecycle = AppLifecycleService();
  });

  tearDown(() => lifecycle.dispose());

  Future<void> pumpStage(WidgetTester tester, AvatarScene scene) async {
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    h.avatar.emit(h.avatar.state.copyWith(scene: scene));
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
        scene: scene,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  void write(String name, String text) {
    Directory(_outDir).createSync(recursive: true);
    File('$_outDir/$name').writeAsStringSync(text);
  }

  for (final AvatarScene scene in <AvatarScene>[
    AvatarScene.livingRoom,
    AvatarScene.forestCabin,
  ]) {
    testWidgets('Home, the stage in ${scene.name}', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpStage(tester, scene);
      write(
        'semantics_home_${scene.name}.txt',
        _dump(tester, 'Home, the stage in ${scene.name} (en, 390×844)'),
      );
      handle.dispose();
    });
  }

  testWidgets('the scene picker', (WidgetTester tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await pumpStage(tester, AvatarScene.livingRoom);
    await tester.tap(find.bySemanticsLabel('Menu'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Scenes'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    write(
      'semantics_scene_picker.txt',
      _dump(tester, 'The scene picker over Home, livingRoom current (en)'),
    );
    handle.dispose();
  });
}
