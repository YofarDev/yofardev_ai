import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' show FrameTiming, Offset;

import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:yofardev_ai/app.dart';
import 'package:yofardev_ai/core/di/service_locator.dart';
import 'package:yofardev_ai/core/models/avatar_config.dart';
import 'package:yofardev_ai/core/models/avatar_scene.dart';
import 'package:yofardev_ai/core/services/motion/parallax_source.dart';
import 'package:yofardev_ai/core/services/world/world_state_service.dart';
import 'package:yofardev_ai/features/avatar/avatar.dart';

/// Frame cost per scene and the tilt signs, on a device or emulator (M5
/// Task 10). It is NOT part of `flutter test` or `scripts/fverify.sh`.
///
/// Frame cost (default): the real app's Home on each scene with the avatar on
/// screen, 10 s each; build and raster times of
/// every frame from `FrameTiming`. Campfire and beach are measured again at
/// rain 1 (M6: their front weather layer is then drawn too).
///
///     flutter drive --profile -d emulator-5554 \
///       --driver=test_driver/integration_test.dart \
///       --target=integration_test/frame_cost_test.dart
///
/// Tilt (`--dart-define=PHASE=tilt`): prints the parallax offset twice a
/// second for 60 s while the device is tilted from outside (`adb -s <serial>
/// emu sensor set acceleration x:y:z`).
///
/// Every number is the device it ran on; an emulator is not a tier.
const String _phase = String.fromEnvironment('PHASE', defaultValue: 'frame');
const int _seconds = int.fromEnvironment('SECONDS', defaultValue: 10);

void main() {
  final IntegrationTestWidgetsFlutterBinding binding =
      IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('frame cost per scene / tilt', (WidgetTester tester) async {
    await setupServiceLocator();
    await bootstrapApp();
    await tester.pumpWidget(const App());
    await _settle(tester, const Duration(seconds: 6));

    final AvatarCubit avatar = getIt<AvatarCubit>();
    Future<void> showScene(AvatarScene scene) async {
      avatar.onNewAvatarConfig('frame-cost', AvatarConfig(background: scene));
      await _settle(tester, const Duration(seconds: 4));
      expect(avatar.state.scene, scene);
    }

    if (_phase == 'tilt') {
      await showScene(AvatarScene.campfire);
      await _tilt(tester);
      return;
    }

    final Map<String, Object?> report = <String, Object?>{
      'mode': const bool.fromEnvironment('dart.vm.product')
          ? 'release'
          : const bool.fromEnvironment('dart.vm.profile')
          ? 'profile'
          : 'debug',
    };
    final WorldStateService world = getIt<WorldStateService>();
    for (final AvatarScene scene in AvatarScene.values) {
      await showScene(scene);
      world.setRain(0);
      report[scene.name] = await _measure(tester, scene.name);
      // At rain 1 the outdoor scenes also draw their front weather over the
      // avatar (contract v9, M6).
      if (scene == AvatarScene.campfire || scene == AvatarScene.beach) {
        world.setRain(1);
        await _settle(tester, const Duration(seconds: 2));
        report['${scene.name}_rain1'] = await _measure(
          tester,
          '${scene.name}_rain1',
        );
        world.setRain(0);
      }
    }
    // ignore: avoid_print
    print('FRAME_COST_REPORT ${jsonEncode(report)}');
    binding.reportData = report;
  }, timeout: const Timeout(Duration(minutes: 10)));
}

/// Lets real time pass with the engine producing frames.
Future<void> _settle(WidgetTester tester, Duration time) async {
  await tester.pump();
  await Future<void>.delayed(time);
  await tester.pump();
}

Future<Map<String, Object?>> _measure(WidgetTester tester, String label) async {
  final List<FrameTiming> frames = <FrameTiming>[];
  void onTimings(List<FrameTiming> timings) => frames.addAll(timings);
  SchedulerBinding.instance.addTimingsCallback(onTimings);
  await Future<void>.delayed(const Duration(seconds: _seconds));
  // FrameTiming arrives in batches; give the last one time to land.
  await Future<void>.delayed(const Duration(seconds: 1));
  SchedulerBinding.instance.removeTimingsCallback(onTimings);

  final List<double> build = frames
      .map((FrameTiming f) => f.buildDuration.inMicroseconds / 1000)
      .toList();
  final List<double> raster = frames
      .map((FrameTiming f) => f.rasterDuration.inMicroseconds / 1000)
      .toList();
  final List<double> total = frames
      .map((FrameTiming f) => f.totalSpan.inMicroseconds / 1000)
      .toList();
  // Over budget the way the Flutter docs count it: a thread alone takes
  // longer than one 60 Hz frame (totalSpan also holds the vsync wait).
  int over = 0;
  for (int i = 0; i < frames.length; i++) {
    if (build[i] > 16.6 || raster[i] > 16.6) {
      over++;
    }
  }
  final Map<String, Object?> result = <String, Object?>{
    'frames': frames.length,
    'build_p50': _pct(build, 0.50),
    'build_p95': _pct(build, 0.95),
    'build_p99': _pct(build, 0.99),
    'raster_p50': _pct(raster, 0.50),
    'raster_p95': _pct(raster, 0.95),
    'raster_p99': _pct(raster, 0.99),
    'total_p95': _pct(total, 0.95),
    'over_16_6_share': frames.isEmpty ? 0 : over / frames.length,
  };
  // ignore: avoid_print
  print('FRAME_COST $label ${jsonEncode(result)}');
  return result;
}

double _pct(List<double> values, double q) {
  if (values.isEmpty) {
    return 0;
  }
  final List<double> sorted = List<double>.of(values)..sort();
  final int i = math.min(sorted.length - 1, (q * sorted.length).floor());
  return double.parse(sorted[i].toStringAsFixed(2));
}

Future<void> _tilt(WidgetTester tester) async {
  final ParallaxSource source = getIt<ParallaxSource>();
  // ignore: avoid_print
  print(
    'TILT usesAccelerometer=${source.usesAccelerometer} '
    'active=${source.active}',
  );
  final Stopwatch clock = Stopwatch()..start();
  while (clock.elapsed < const Duration(seconds: 60)) {
    final Offset v = source.value;
    // ignore: avoid_print
    print(
      'TILT t=${clock.elapsed.inMilliseconds} '
      'x=${v.dx.toStringAsFixed(3)} y=${v.dy.toStringAsFixed(3)}',
    );
    await Future<void>.delayed(const Duration(milliseconds: 500));
    await tester.pump();
  }
}
