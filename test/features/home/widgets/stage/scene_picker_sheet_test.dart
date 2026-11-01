import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:yofardev_ai/core/models/app_lifecycle_event.dart';
import 'package:yofardev_ai/core/models/avatar_config.dart';
import 'package:yofardev_ai/core/models/avatar_scene.dart';
import 'package:yofardev_ai/core/services/agent/avatar_tool.dart';
import 'package:yofardev_ai/core/services/app_lifecycle_service.dart';
import 'package:yofardev_ai/features/avatar/avatar.dart';
import 'package:yofardev_ai/features/home/widgets/stage/scene_picker_sheet.dart';

import '../../stage_harness.dart';

void main() {
  late StageHarness h;
  late AppLifecycleService lifecycle;
  late List<AvatarChangeRequested> requests;
  late StreamSubscription<AvatarChangeRequested> subscription;

  setUp(() {
    h = StageHarness();
    lifecycle = AppLifecycleService();
    requests = <AvatarChangeRequested>[];
    subscription = lifecycle.avatarChangeRequestedEvents.listen(requests.add);
  });

  tearDown(() async {
    await subscription.cancel();
    lifecycle.dispose();
  });

  Future<void> openSheet(
    WidgetTester tester, {
    Locale locale = const Locale('en'),
  }) async {
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      h.app(
        Builder(
          builder: (BuildContext context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () =>
                    ScenePickerSheet.show(context, lifecycle: lifecycle),
                child: const Text('open'),
              ),
            ),
          ),
        ),
        locale: locale,
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  AvatarState state({AvatarScene scene = AvatarScene.livingRoom}) =>
      AvatarState(
        avatar: const Avatar(),
        avatarConfig: const AvatarConfig(),
        scene: scene,
      );

  testWidgets('shows the ten scenes with their English names', (
    WidgetTester tester,
  ) async {
    await openSheet(tester);
    expect(find.text('Choose a scene'), findsOneWidget);
    for (final String name in <String>[
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
    ]) {
      expect(find.text(name), findsOneWidget, reason: name);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('the names are localized in French', (WidgetTester tester) async {
    await openSheet(tester, locale: const Locale('fr'));
    expect(find.text('Choisir un décor'), findsOneWidget);
    for (final String name in <String>[
      'Salon',
      'Feu de camp',
      'Plage',
      'Espace',
      'Café',
      'Toit-terrasse',
      'Refuge',
      'Cabane en forêt',
      'Compartiment de train',
      'Bibliothèque',
    ]) {
      expect(find.text(name), findsOneWidget, reason: name);
    }
  });

  // A 1x1 transparent PNG: a poster that is bundled and decodes.
  final Uint8List png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA'
    '60e6kgAAAABJRU5ErkJggg==',
  );

  /// Serves [bundled] scenes' posters as a PNG and every other poster as
  /// missing (the asset load throws, so the tile's errorBuilder runs).
  void servePosters(Set<AvatarScene> bundled) {
    // the image cache is global: a poster decoded by an earlier test would
    // hide a missing one
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (ByteData? message) async {
          final String key = const StringCodec().decodeMessage(message)!;
          for (final AvatarScene scene in bundled) {
            if (key == 'assets/rive/posters/${scene.name}.webp') {
              return ByteData.sublistView(png);
            }
          }
          if (key.startsWith('assets/rive/posters/')) {
            return null;
          }
          // everything else (fonts, the manifest) from the unit-test bundle
          final String? assetDir = io.Platform.environment['UNIT_TEST_ASSETS'];
          if (assetDir == null) {
            return null;
          }
          final io.File file = io.File(p.join(assetDir, key));
          if (!file.existsSync()) {
            return null;
          }
          return ByteData.sublistView(file.readAsBytesSync());
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler('flutter/assets', null),
    );
  }

  Finder fallbackOf(AvatarScene scene) =>
      find.byKey(ValueKey<String>('poster-fallback-${scene.name}'));

  testWidgets('a scene whose poster is not bundled shows the accent tile, '
      'a bundled one shows its poster', (WidgetTester tester) async {
    servePosters(<AvatarScene>{
      AvatarScene.livingRoom,
      AvatarScene.campfire,
      AvatarScene.beach,
      AvatarScene.deepSpace,
    });
    await openSheet(tester);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    for (final AvatarScene scene in <AvatarScene>[
      AvatarScene.cafe,
      AvatarScene.rooftop,
      AvatarScene.mountainHut,
      AvatarScene.forestCabin,
      AvatarScene.trainCompartment,
      AvatarScene.library,
    ]) {
      expect(fallbackOf(scene), findsOneWidget, reason: scene.name);
    }
    for (final AvatarScene scene in <AvatarScene>[
      AvatarScene.livingRoom,
      AvatarScene.campfire,
      AvatarScene.beach,
      AvatarScene.deepSpace,
    ]) {
      expect(fallbackOf(scene), findsNothing, reason: scene.name);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('with no poster bundled every tile still shows and works', (
    WidgetTester tester,
  ) async {
    servePosters(<AvatarScene>{});
    await openSheet(tester);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    for (final AvatarScene scene in AvatarScene.values) {
      expect(fallbackOf(scene), findsOneWidget, reason: scene.name);
    }
    await tester.tap(find.text('Beach'));
    await tester.pumpAndSettle();
    expect(requests.single.newConfig.background, AvatarScene.beach);
  });

  testWidgets('the scene on screen is marked and cannot be picked', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    h.avatar.state = state(scene: AvatarScene.campfire);
    await openSheet(tester);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    expect(
      tester.getSemantics(find.bySemanticsLabel('Campfire')),
      isSemantics(isSelected: true, isButton: true),
    );
    await tester.tap(find.text('Campfire'));
    await tester.pumpAndSettle();
    expect(requests, isEmpty);
    expect(find.text('Choose a scene'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('picking a scene emits the change_avatar request and closes', (
    WidgetTester tester,
  ) async {
    await openSheet(tester);
    await tester.tap(find.text('Rooftop'));
    await tester.pumpAndSettle();
    expect(requests, hasLength(1));
    final AvatarChangeRequested request = requests.single;
    expect(request.backgroundOnly, isTrue);
    expect(request.newConfig.background, AvatarScene.rooftop);
    expect(request.newConfig.specials, isNull);
    expect(request.configWithAnimation.background, AvatarScene.rooftop);
    expect(
      request.configWithAnimation.specials,
      AvatarSpecials.leaveAndComeBack,
    );
    expect(find.text('Choose a scene'), findsNothing);
  });

  testWidgets('every tile is disabled while a journey runs', (
    WidgetTester tester,
  ) async {
    await openSheet(tester);
    h.avatar.emit(
      state().copyWith(
        journey: const JourneyState(
          from: AvatarScene.livingRoom,
          to: AvatarScene.beach,
          family: JourneyFamily.door,
          phase: JourneyPhase.open,
          serial: 1,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Beach'));
    await tester.pumpAndSettle();
    expect(requests, isEmpty);
    expect(find.text('Choose a scene'), findsOneWidget);

    // and live again once it ends
    h.avatar.emit(state(scene: AvatarScene.beach));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Café'));
    await tester.pumpAndSettle();
    expect(requests.single.newConfig.background, AvatarScene.cafe);
  });

  test('sceneChangeRequest equals what the change_avatar tool emits', () async {
    final List<AvatarChangeRequested> emitted = <AvatarChangeRequested>[];
    final StreamSubscription<AvatarChangeRequested> toolSub = lifecycle
        .avatarChangeRequestedEvents
        .listen(emitted.add);
    addTearDown(toolSub.cancel);
    await AvatarTool(lifecycle).execute(<String, dynamic>{
      'background': 'mountainHut',
    }, <String, dynamic>{});
    await Future<void>.delayed(Duration.zero);
    expect(emitted, hasLength(1));
    final AvatarChangeRequested fromTool = emitted.single;
    final AvatarChangeRequested fromPicker = sceneChangeRequest(
      AvatarScene.mountainHut,
    );
    expect(fromPicker.backgroundOnly, fromTool.backgroundOnly);
    expect(fromPicker.newConfig, fromTool.newConfig);
    expect(fromPicker.configWithAnimation, fromTool.configWithAnimation);
  });
}
