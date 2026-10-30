import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/models/avatar_scene.dart';
import 'package:yofardev_ai/features/avatar/presentation/widgets/rive/rive_scene_view.dart';

import '../../../../helpers/rive_test_assets.dart';

/// Counts its own `State`s, so a remount shows.
class _Middle extends StatefulWidget {
  const _Middle({required this.onTap});

  final VoidCallback onTap;

  static int created = 0;

  @override
  State<_Middle> createState() => _MiddleState();
}

class _MiddleState extends State<_Middle> {
  @override
  void initState() {
    super.initState();
    _Middle.created++;
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: widget.onTap,
    child: const SizedBox.expand(),
  );
}

void main() {
  setUp(serveFakeRiveAssets);

  testWidgets('the middle (the avatar) survives scene switches and gets taps', (
    WidgetTester tester,
  ) async {
    _Middle.created = 0;
    int taps = 0;
    final ValueNotifier<double> rain = ValueNotifier<double>(1);
    addTearDown(rain.dispose);
    Widget stage(AvatarScene scene) => MaterialApp(
      home: Scaffold(
        body: RiveSceneView(
          scene: scene,
          sceneEvent: (sceneEvent: SceneEvent.flare, seq: 0),
          rain: rain,
          middle: _Middle(onTap: () => taps++),
        ),
      ),
    );
    // No Rive file decodes in a widget test (fake bytes): the back is the
    // fallback, as while a slow load is in flight.
    await tester.pumpWidget(stage(AvatarScene.campfire));
    await tester.pumpWidget(stage(AvatarScene.livingRoom));
    rain.value = 0;
    await tester.pumpWidget(stage(AvatarScene.beach));
    expect(_Middle.created, 1);
    await tester.tap(find.byType(_Middle));
    expect(taps, 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('without a middle the view is the scene alone', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: RiveSceneView(
          scene: AvatarScene.campfire,
          sceneEvent: (sceneEvent: SceneEvent.flare, seq: 0),
        ),
      ),
    );
    expect(
      find.descendant(
        of: find.byType(RiveSceneView),
        matching: find.byType(Stack),
      ),
      findsNothing,
    );
  });
}
