import 'dart:async';
import 'dart:ui' show FrameTiming;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yofardev_ai/core/design/rive/ui_kit_file.dart';
import 'package:yofardev_ai/core/models/performance/performance.dart';
import 'package:yofardev_ai/core/services/quality/frame_timing_source.dart';
import 'package:yofardev_ai/core/services/quality/quality_tier_service.dart';
import 'package:yofardev_ai/core/services/settings_local_datasource.dart';
import 'package:yofardev_ai/features/avatar/presentation/widgets/rive/rive_avatar_view.dart';
import 'package:yofardev_ai/features/avatar/presentation/widgets/rive/rive_scene_view.dart';
import 'package:yofardev_ai/features/home/widgets/home_content_stack.dart';
import 'package:yofardev_ai/features/home/widgets/stage/stage_caption_bubble.dart';

import '../../helpers/rive_test_assets.dart';
import 'stage_harness.dart';

class _Timings implements FrameTimingSource {
  @override
  Stream<List<FrameTiming>> get timings =>
      const Stream<List<FrameTiming>>.empty();

  @override
  double get refreshRate => 60;

  @override
  Future<void> get firstFrameDrawn => Completer<void>().future;
}

/// Records what the stage tells the tier service.
class _SpyQuality extends QualityTierService {
  _SpyQuality()
    : super(timingSource: _Timings(), settings: SettingsLocalDatasource());

  int shown = 0;
  final List<bool> active = <bool>[];

  @override
  void notifyStageShown() {
    shown++;
    super.notifyStageShown();
  }

  @override
  void setStageActive(bool value) {
    active.add(value);
    super.setStageActive(value);
  }
}

void main() {
  late StageHarness h;
  late _SpyQuality quality;

  setUp(() {
    serveFakeRiveAssets();
    UiKitFile.resetForTest();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    h = StageHarness();
    quality = _SpyQuality();
  });

  tearDown(() => quality.dispose());

  Future<void> pumpStack(WidgetTester tester, {bool mounted = true}) async {
    await tester.pumpWidget(
      h.app(
        Scaffold(
          resizeToAvoidBottomInset: false,
          body: mounted
              ? HomeContentStack(
                  speech: h.speech,
                  quality: quality,
                  onStartDemo: () {},
                )
              : const SizedBox(),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('the scene, the avatar and the bubble follow the tier', (
    WidgetTester tester,
  ) async {
    await pumpStack(tester);
    expect(
      tester.widget<RiveSceneView>(find.byType(RiveSceneView)).tier,
      same(quality.tier),
    );
    expect(
      tester.widget<RiveAvatarView>(find.byType(RiveAvatarView)).tier,
      same(quality.tier),
    );
    expect(
      tester.widget<StageCaptionBubble>(find.byType(StageCaptionBubble)).tier,
      same(quality.tier),
    );
    quality.forceTier(QualityTier.low);
    await tester.pump();
    await pumpStack(tester, mounted: false);
  });

  testWidgets('a shown scene reaches the benchmark; the drift watch runs '
      'only while the stage is up and resumed', (WidgetTester tester) async {
    await pumpStack(tester);
    // No Rive file decodes in a widget test: the failed load is announced
    // as shown too (the stage is up either way).
    await tester.pump();
    expect(quality.shown, greaterThanOrEqualTo(1));
    expect(quality.active.last, isTrue);
    expect(quality.driftWatching, isTrue);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    expect(quality.active.last, isFalse);
    expect(quality.driftWatching, isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    expect(quality.active.last, isTrue);

    await pumpStack(tester, mounted: false);
    expect(quality.active.last, isFalse);
    expect(quality.driftWatching, isFalse);
  });
}
