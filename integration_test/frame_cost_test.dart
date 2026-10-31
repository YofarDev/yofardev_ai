import 'dart:convert';
import 'dart:ui' show FrameTiming, Offset;

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:yofardev_ai/app.dart';
import 'package:yofardev_ai/core/di/service_locator.dart';
import 'package:yofardev_ai/core/models/avatar_config.dart';
import 'package:yofardev_ai/core/models/avatar_scene.dart';
import 'package:yofardev_ai/core/models/performance/performance.dart';
import 'package:yofardev_ai/core/services/motion/parallax_source.dart';
import 'package:yofardev_ai/core/services/quality/frame_stats.dart';
import 'package:yofardev_ai/core/services/quality/quality_tier_service.dart';
import 'package:yofardev_ai/core/services/quality/thermal_source.dart';
import 'package:yofardev_ai/core/services/world/world_state_service.dart';
import 'package:yofardev_ai/features/avatar/avatar.dart';

/// Frame cost per scene × quality tier, the tilt signs and the battery drain,
/// on a device, an emulator or the Mac (M5 Task 10, M11 rulings 14–16). It is
/// NOT part of `flutter test` or `scripts/fverify.sh`; the owner's steps are
/// in `rive/review/m11/device/README.md`.
///
/// Frame cost (default): the real app's Home on every [AvatarScene] with the
/// avatar on screen; per scene, for every tier in `TIERS` (forced through
/// [QualityTierService.forceTier]), `SECONDS` of `FrameTiming`. Every scene
/// with a `SceneFront` ([AvatarRiveContract.sceneFrontScenes]) is measured
/// again at rain 1 per tier (its front weather is drawn too, except on low).
/// One `FRAME_COST <scene> <tier> {json}` line per pass, and everything as the
/// driver's response data:
///
///     flutter drive --profile -d <device> \
///       --driver=test_driver/integration_test.dart \
///       --target=integration_test/frame_cost_test.dart \
///       [--dart-define=TIERS=low,high,ultra] [--dart-define=SECONDS=8]
///
/// Each pass reports frames, P50 / P95 / P99 of build, raster and
/// max(build, raster), the share of frames whose max(build, raster) is over
/// the tier's budget ([QualityTier.frameBudgetMs]) and `pass` (ruling 14: P95
/// of max(build, raster) ≤ the budget and ≤ 5 % over it), plus M6's
/// mid-tier rule (`m6_pass`: ≤ 1 % over 16.6 ms, build and raster P95 ≤ 14 ms).
///
/// Tilt (`--dart-define=PHASE=tilt`): prints the parallax offset twice a
/// second for 60 s while the device is tilted from outside (`adb -s <serial>
/// emu sensor set acceleration x:y:z`).
///
/// Battery (`--dart-define=PHASE=battery`, ruling 16): the campfire at one
/// forced tier (`TIER`, default high) for `MINUTES` (default 30), printing
/// `BATTERY {json}` each minute (battery level, its state, the thermal level,
/// the tier in force). Unplug the device first.
///
/// Every number is the device it ran on; an emulator or a Mac is not a tier.
const String _phase = String.fromEnvironment('PHASE', defaultValue: 'frame');
const int _seconds = int.fromEnvironment('SECONDS', defaultValue: 8);
const String _tiers = String.fromEnvironment(
  'TIERS',
  defaultValue: 'low,high,ultra',
);
const String _batteryTier = String.fromEnvironment(
  'TIER',
  defaultValue: 'high',
);
const int _minutes = int.fromEnvironment('MINUTES', defaultValue: 30);

/// The share of frames over budget a pass may have (ruling 14).
const double _maxOverShare = 0.05;

void main() {
  final IntegrationTestWidgetsFlutterBinding binding =
      IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('frame cost per scene x tier / tilt / battery', (
    WidgetTester tester,
  ) async {
    await setupServiceLocator();
    await bootstrapApp();
    await tester.pumpWidget(const App());
    await _settle(tester, const Duration(seconds: 6));

    final AvatarCubit avatar = getIt<AvatarCubit>();
    final QualityTierService quality = getIt<QualityTierService>();
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
      'phase': _phase,
      'mode': const bool.fromEnvironment('dart.vm.product')
          ? 'release'
          : const bool.fromEnvironment('dart.vm.profile')
          ? 'profile'
          : 'debug',
    };

    /// The app's own tier, read last: its benchmark waits while a tier is
    /// forced and needs ~3 s of unforced stage once released (8 s here).
    Future<void> readBenchmark() async {
      quality.forceTier(null);
      await _settle(tester, const Duration(seconds: 8));
      report['benchmark'] = quality.benchmark.name;
    }

    if (_phase == 'battery') {
      final QualityTier tier = QualityTier.values.byName(_batteryTier);
      await showScene(AvatarScene.campfire);
      quality.forceTier(tier);
      report['tier'] = tier.name;
      report['samples'] = await _battery(tester, quality);
      await readBenchmark();
      binding.reportData = report;
      return;
    }

    final List<QualityTier> tiers = _tiers
        .split(',')
        .map((String name) => name.trim())
        .where((String name) => name.isNotEmpty)
        .map(QualityTier.values.byName)
        .toList();
    report['tiers'] = tiers.map((QualityTier t) => t.name).toList();
    report['seconds'] = _seconds;
    final Map<String, Object?> results = <String, Object?>{};
    report['results'] = results;
    final WorldStateService world = getIt<WorldStateService>();
    for (final AvatarScene scene in AvatarScene.values) {
      await showScene(scene);
      final bool front = AvatarRiveContract.sceneFrontScenes.contains(
        scene.name,
      );
      final Map<String, Object?> dry = <String, Object?>{};
      final Map<String, Object?> wet = <String, Object?>{};
      results[scene.name] = dry;
      if (front) {
        results['${scene.name}_rain1'] = wet;
      }
      for (final QualityTier tier in tiers) {
        quality.forceTier(tier);
        world.setRain(0);
        await _settle(tester, const Duration(seconds: 2));
        dry[tier.name] = await _measure(scene.name, tier);
        if (front) {
          // At rain 1 the front weather is drawn over the avatar too
          // (contract v9), except on low (ruling 13).
          world.setRain(1);
          await _settle(tester, const Duration(seconds: 2));
          wet[tier.name] = await _measure('${scene.name}_rain1', tier);
          world.setRain(0);
        }
      }
    }
    await readBenchmark();
    // ignore: avoid_print
    print('FRAME_COST_REPORT ${jsonEncode(report)}');
    binding.reportData = report;
  }, timeout: const Timeout(Duration(minutes: 80)));
}

/// Lets real time pass with the engine producing frames.
Future<void> _settle(WidgetTester tester, Duration time) async {
  await tester.pump();
  await Future<void>.delayed(time);
  await tester.pump();
}

Future<Map<String, Object?>> _measure(String label, QualityTier tier) async {
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
  final List<double> worst = frames.map(FrameStats.worstMs).toList();
  final double budget = tier.frameBudgetMs;
  final double worstP95 = FrameStats.p95Ms(worst);
  final double overShare = FrameStats.shareOver(worst, budget);
  // M6's mid-tier rule (ruling 14 keeps it for the owner's phone).
  final double over166 = FrameStats.shareOver(worst, 16.6);
  final double buildP95 = FrameStats.p95Ms(build);
  final double rasterP95 = FrameStats.p95Ms(raster);
  final Map<String, Object?> result = <String, Object?>{
    'frames': frames.length,
    'budget_ms': budget,
    'build_p50': _round(FrameStats.percentileMs(build, 0.50)),
    'build_p95': _round(buildP95),
    'build_p99': _round(FrameStats.percentileMs(build, 0.99)),
    'raster_p50': _round(FrameStats.percentileMs(raster, 0.50)),
    'raster_p95': _round(rasterP95),
    'raster_p99': _round(FrameStats.percentileMs(raster, 0.99)),
    'worst_p50': _round(FrameStats.percentileMs(worst, 0.50)),
    'worst_p95': _round(worstP95),
    'worst_p99': _round(FrameStats.percentileMs(worst, 0.99)),
    'over_budget_share': _round(overShare, 4),
    'pass':
        frames.isNotEmpty && worstP95 <= budget && overShare <= _maxOverShare,
    'over_16_6_share': _round(over166, 4),
    'm6_pass':
        frames.isNotEmpty &&
        over166 <= 0.01 &&
        buildP95 <= 14 &&
        rasterP95 <= 14,
  };
  // ignore: avoid_print
  print('FRAME_COST $label ${tier.name} ${jsonEncode(result)}');
  return result;
}

double _round(double value, [int digits = 2]) =>
    double.parse(value.toStringAsFixed(digits));

Future<List<Map<String, Object?>>> _battery(
  WidgetTester tester,
  QualityTierService quality,
) async {
  final Battery battery = Battery();
  final ThermalSource thermal = getIt<ThermalSource>();
  final List<Map<String, Object?>> samples = <Map<String, Object?>>[];
  final Stopwatch clock = Stopwatch()..start();
  for (int minute = 0; minute <= _minutes; minute++) {
    final Duration due = Duration(minutes: minute);
    while (clock.elapsed < due) {
      await Future<void>.delayed(const Duration(seconds: 1));
      await tester.pump();
    }
    final Map<String, Object?> sample = <String, Object?>{
      'minute': minute,
      'level': await _orNull(() => battery.batteryLevel),
      'state': (await _orNull(() => battery.batteryState))?.name,
      'saver': await _orNull(() => battery.isInBatterySaveMode),
      'thermal': (await thermal.current).name,
      'tier': quality.current.name,
    };
    samples.add(sample);
    // ignore: avoid_print
    print('BATTERY ${jsonEncode(sample)}');
  }
  return samples;
}

/// [read], or null when the platform cannot answer.
Future<T?> _orNull<T>(Future<T> Function() read) async {
  try {
    return await read();
  } on Object {
    return null;
  }
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
