import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/models/avatar_scene.dart';
import 'package:yofardev_ai/features/avatar/presentation/widgets/rive/rive_scene_view.dart';

import '../../../../helpers/rive_test_assets.dart';

/// A scene whose `.riv` is not bundled makes `rootBundle.load` throw a
/// `FlutterError` (an `Error`, not an `Exception`): the view must catch it,
/// show the error path and let a journey's cut go on, never leave an
/// uncaught async error behind.
void main() {
  /// Serves the fake Rive bytes, except that [missing] is not bundled.
  void serveWithout(AvatarScene missing) {
    serveFakeRiveAssets();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (ByteData? message) async {
          final String key = const StringCodec().decodeMessage(message)!;
          if (key == 'assets/rive/scenes/${missing.name}.riv') {
            return null;
          }
          if (key.startsWith('assets/rive/') && key.endsWith('.riv')) {
            return ByteData(4);
          }
          return null;
        });
  }

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', null);
  });

  test('a missing asset really throws an Error, not an Exception', () async {
    serveWithout(AvatarScene.cafe);
    Object? thrown;
    try {
      await rootBundle.load('assets/rive/scenes/cafe.riv');
    } on Object catch (e) {
      thrown = e;
    }
    expect(thrown, isA<FlutterError>());
    expect(thrown, isNot(isA<Exception>()));
  });

  testWidgets('a scene load that throws an Error sets the error path and '
      'announces the scene', (WidgetTester tester) async {
    serveWithout(AvatarScene.cafe);
    final List<AvatarScene> shown = <AvatarScene>[];
    await tester.pumpWidget(
      MaterialApp(
        home: RiveSceneView(
          scene: AvatarScene.cafe,
          sceneEvent: (sceneEvent: SceneEvent.espresso, seq: 0),
          onSceneShown: shown.add,
        ),
      ),
    );
    await tester.pumpAndSettle();
    // not escaped to the zone ...
    expect(tester.takeException(), isNull);
    // ... but shown like a decode failure (debug builds) ...
    expect(kReleaseMode, isFalse);
    expect(find.textContaining('cafe: '), findsOneWidget);
    expect(find.textContaining('Unable to load asset'), findsOneWidget);
    // ... and the journey's cut is released
    expect(shown, <AvatarScene>[AvatarScene.cafe]);
  });

  testWidgets('a failing preload is logged and swallowed', (
    WidgetTester tester,
  ) async {
    serveWithout(AvatarScene.rooftop);
    await tester.pumpWidget(
      const MaterialApp(
        home: RiveSceneView(
          scene: AvatarScene.livingRoom,
          sceneEvent: (sceneEvent: SceneEvent.lightsOff, seq: 0),
          preload: AvatarScene.rooftop,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('switching to a missing scene shows the error and recovers on '
      'the next switch', (WidgetTester tester) async {
    serveWithout(AvatarScene.mountainHut);
    Widget stage(AvatarScene scene) => MaterialApp(
      home: RiveSceneView(
        scene: scene,
        sceneEvent: (sceneEvent: SceneEvent.flare, seq: 0),
      ),
    );
    await tester.pumpWidget(stage(AvatarScene.campfire));
    await tester.pumpAndSettle();
    await tester.pumpWidget(stage(AvatarScene.mountainHut));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.textContaining('mountainHut: '), findsOneWidget);
    await tester.pumpWidget(stage(AvatarScene.beach));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
