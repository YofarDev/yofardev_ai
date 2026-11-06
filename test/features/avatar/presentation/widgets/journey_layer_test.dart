import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/design/tokens/scene_lights.dart';
import 'package:yofardev_ai/core/models/avatar_scene.dart';
import 'package:yofardev_ai/core/models/performance/light_rig.dart';
import 'package:yofardev_ai/features/avatar/domain/models/journey.dart';
import 'package:yofardev_ai/features/avatar/presentation/rive/avatar_face_writer.dart';
import 'package:yofardev_ai/features/avatar/presentation/rive/avatar_rive_contract.dart';
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

/// The write tests' journey: livingRoom → beach by book.
JourneyState _book(JourneyPhase phase, {int serial = 7}) => JourneyState(
  from: AvatarScene.livingRoom,
  to: AvatarScene.beach,
  family: JourneyFamily.book,
  phase: phase,
  serial: serial,
);

/// A fake view-model binding: records every number and colour write.
class _RecordingSink implements AvatarVmSink {
  final Map<String, double> numbers = <String, double>{};
  final Map<String, int> colors = <String, int>{};
  final List<String> calls = <String>[];

  @override
  void setNumber(String name, double value) {
    numbers[name] = value;
    calls.add('number $name');
  }

  @override
  void setColor(String name, int argb) {
    colors[name] = argb;
    calls.add('color $name');
  }

  @override
  void setBool(String name, bool value) => calls.add('bool $name');

  @override
  void fireTrigger(String name) => calls.add('trigger $name');
}

/// Pumps [journey] for one tick and returns the fake binding it wrote to.
Future<_RecordingSink> _pumpJourney(
  WidgetTester tester,
  JourneyState journey, {
  double jacket = 0,
}) async {
  final _RecordingSink sink = _RecordingSink();
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: JourneyLayer(
        journey: journey,
        avatar: const _Avatar(),
        jacket: jacket,
        daylight: ValueNotifier<double>(0),
        vmSink: sink,
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 16));
  return sink;
}

void main() {
  // fake bytes: journey.riv resolves to null, so the layer never loads a
  // file — the clip runs directly and the write tests use a fake binding.
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

  testWidgets('a grab book frame writes the book, its vignette number and '
      'the jacket', (WidgetTester tester) async {
    final _RecordingSink sink = await _pumpJourney(
      tester,
      _book(JourneyPhase.grab),
      jacket: 1,
    );
    expect(sink.numbers[AvatarRiveContract.journeyPropBook], 1);
    expect(sink.numbers[AvatarRiveContract.journeyPropOpen], 1);
    expect(sink.numbers[AvatarRiveContract.journeyPropUnfold], 1);
    expect(sink.numbers[AvatarRiveContract.journeyPropJacket], 1);
    // The exit side's vignette shows the destination; the others are dark.
    expect(
      sink.numbers[AvatarRiveContract.journeyDestProp(AvatarScene.beach)],
      1,
    );
    expect(
      sink.numbers[AvatarRiveContract.journeyDestProp(AvatarScene.campfire)],
      0,
    );
    expect(
      sink.numbers[AvatarRiveContract.journeyDestProp(AvatarScene.livingRoom)],
      0,
    );
    expect(sink.numbers[AvatarRiveContract.journeyPropPath], 0);
    expect(sink.numbers[AvatarRiveContract.journeyPropPortal], 0);
    expect(sink.numbers[AvatarRiveContract.journeyPropRocket], 0);
  });

  testWidgets('an arriveOpen book frame points the vignette at the origin', (
    WidgetTester tester,
  ) async {
    final _RecordingSink sink = await _pumpJourney(
      tester,
      _book(JourneyPhase.arriveOpen),
    );
    expect(
      sink.numbers[AvatarRiveContract.journeyDestProp(AvatarScene.livingRoom)],
      1,
    );
    expect(
      sink.numbers[AvatarRiveContract.journeyDestProp(AvatarScene.beach)],
      0,
    );
  });

  testWidgets('a rocket journey writes no book, no jacket and no vignette', (
    WidgetTester tester,
  ) async {
    final _RecordingSink sink = await _pumpJourney(
      tester,
      const JourneyState(
        from: AvatarScene.livingRoom,
        to: AvatarScene.beach,
        family: JourneyFamily.rocket,
        phase: JourneyPhase.exit,
        serial: 5,
      ),
    );
    expect(sink.numbers[AvatarRiveContract.journeyPropBook], 0);
    expect(sink.numbers[AvatarRiveContract.journeyPropRocket], 1);
    expect(sink.numbers[AvatarRiveContract.journeyPropJacket], 0);
    for (final AvatarScene scene in AvatarScene.values) {
      expect(
        sink.numbers[AvatarRiveContract.journeyDestProp(scene)],
        0,
        reason: scene.name,
      );
    }
    expect(
      sink.colors.keys.where((String name) => name.startsWith('vignette')),
      isEmpty,
    );
  });

  testWidgets('the lights follow the scene on screen, the vignette the other '
      'one', (WidgetTester tester) async {
    final _RecordingSink sink = await _pumpJourney(
      tester,
      _book(JourneyPhase.grab),
    );
    // daylight 0: the rigs are the scenes' plain night values.
    final LightRig onScreen = SceneLights.at(AvatarScene.livingRoom, 0);
    final LightRig other = SceneLights.at(AvatarScene.beach, 0);
    expect(
      sink.colors[AvatarRiveContract.journeyPropLightKey],
      onScreen.keyColor,
    );
    expect(
      sink.colors[AvatarRiveContract.journeyPropLightAmbient],
      onScreen.ambientColor,
    );
    expect(
      sink.colors[AvatarRiveContract.journeyPropVignetteKey],
      other.keyColor,
    );
    expect(
      sink.colors[AvatarRiveContract.journeyPropVignetteAmbient],
      other.ambientColor,
    );
  });

  testWidgets('an unchanged frame writes nothing; the jacket handoff '
      'rewrites only the jacket', (WidgetTester tester) async {
    final _RecordingSink sink = _RecordingSink();
    final ValueNotifier<double> daylight = ValueNotifier<double>(0);
    Widget layer({required double jacket}) => Directionality(
      textDirection: TextDirection.ltr,
      child: JourneyLayer(
        journey: _book(JourneyPhase.grab),
        avatar: const _Avatar(),
        jacket: jacket,
        daylight: daylight,
        vmSink: sink,
      ),
    );
    await tester.pumpWidget(layer(jacket: 0));
    await tester.pump(const Duration(milliseconds: 16));
    expect(sink.numbers[AvatarRiveContract.journeyPropJacket], 0);
    final int writes = sink.calls.length;

    // A second tick over the same constant frame rewrites nothing.
    await tester.pump(const Duration(milliseconds: 16));
    expect(sink.calls.length, writes);

    // The jacket handoff (didUpdateWidget) rewrites only the jacket.
    await tester.pumpWidget(layer(jacket: 1));
    await tester.pump(const Duration(milliseconds: 16));
    expect(sink.calls.sublist(writes), <String>['number jacket']);
    expect(sink.numbers[AvatarRiveContract.journeyPropJacket], 1);
  });
}
