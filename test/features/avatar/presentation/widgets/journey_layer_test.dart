import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/models/avatar_scene.dart';
import 'package:yofardev_ai/features/avatar/domain/models/journey.dart';
import 'package:yofardev_ai/features/avatar/presentation/widgets/rive/journey_layer.dart';

import '../../../../helpers/rive_test_assets.dart';

class _Avatar extends StatefulWidget {
  const _Avatar({super.key});

  @override
  State<_Avatar> createState() => _AvatarState();
}

class _AvatarState extends State<_Avatar> {
  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}

JourneyState _j(JourneyPhase phase, int serial) => JourneyState(
  from: AvatarScene.livingRoom,
  to: AvatarScene.campfire,
  family: JourneyFamily.book,
  phase: phase,
  serial: serial,
);

void main() {
  // fake bytes: journey.riv resolves to null, only the clip runs
  setUp(serveFakeRiveAssets);

  bool clipping(WidgetTester tester) {
    final ClipRect clip = tester.widget<ClipRect>(
      find.ancestor(of: find.byType(_Avatar), matching: find.byType(ClipRect)),
    );
    return (clip.clipper! as ThresholdClipper).active.value;
  }

  testWidgets('the avatar keeps its state and is clipped only mid-journey', (
    WidgetTester tester,
  ) async {
    final GlobalKey<_AvatarState> key = GlobalKey<_AvatarState>();
    Widget layer(JourneyState? journey) => Directionality(
      textDirection: TextDirection.ltr,
      child: JourneyLayer(
        journey: journey,
        avatar: _Avatar(key: key),
      ),
    );
    await tester.pumpWidget(layer(null));
    final _AvatarState state = key.currentState!;
    expect(clipping(tester), isFalse);

    await tester.pumpWidget(layer(_j(JourneyPhase.exit, 3)));
    await tester.pump(const Duration(milliseconds: 16));
    expect(clipping(tester), isTrue);
    expect(key.currentState, same(state));

    await tester.pumpWidget(layer(_j(JourneyPhase.vanish, 9)));
    await tester.pump(const Duration(milliseconds: 16));
    expect(clipping(tester), isFalse);

    await tester.pumpWidget(layer(null));
    await tester.pump(const Duration(milliseconds: 16));
    expect(clipping(tester), isFalse);
    expect(key.currentState, same(state));
  });
}
