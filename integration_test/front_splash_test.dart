import 'dart:convert';
import 'dart:io' as io;
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:rive/rive.dart';
import 'package:yofardev_ai/core/design/rive/rive_vm_binding.dart';
import 'package:yofardev_ai/features/avatar/presentation/rive/avatar_rive_contract.dart';

/// The front weather's splashes, read from the real runtime (M12 ruling 6).
///
/// Every scene with a `SceneFront` ([AvatarRiveContract.sceneFrontScenes])
/// gets its front drawn the way `RiveSceneView` draws it (the same artboard,
/// state machine, `rain` write and `Fit.cover`), alone in a repaint boundary,
/// at rain 1. Its frames are grabbed in real time (`OffsetLayer.toImage`
/// includes the Rive texture, alpha and all) and each one counts, in the
/// bottom band where the splashes land, the strong pixels (alpha > [_strong])
/// that lie in a flat run of at least [_minRun] px: a splash ring's rim (0xA0
/// over the mist). A streak (0x50) over the mist stays under the line, and
/// where two streaks cross (forestCabin's sheet) the run stays short. Before
/// M12 the splash keys pointed at another artboard's ease and the runtime
/// dropped them: no grab of any front scene had one such pixel (M12 lane F:
/// 0 of 30 in each; after the fix 19-25 of 30).
///
///     flutter test integration_test/front_splash_test.dart -d macos \
///       [--dart-define=OUT=<dir>] [--dart-define=FRONT_SCALE=1]
///
/// The front's texture has the artboard's resolution (1080 x 1920, a
/// 1080-wide phone's), times `FRONT_SCALE` (default 1), and is grabbed at it.
/// One `FRONT_SPLASH <scene> {json}` line per scene; with `OUT`, the
/// grabbed frames' bottom bands go there as `<scene>_band.png` and one whole
/// grab over grey as `<scene>_front.png` (evidence).
const String _out = String.fromEnvironment('OUT');

/// Texture px per artboard px (1: the artboard's own resolution).
const String _scale = String.fromEnvironment('FRONT_SCALE');
final double _frontScale = _scale.isEmpty ? 1 : double.parse(_scale);

/// The layout scale that gives the texture the artboard's resolution in a
/// box [height] logical px tall.
double _texelsPerPx(WidgetTester tester, double height) =>
    1920 / (height * tester.view.devicePixelRatio);

/// A splash ring's alpha over the mist clears it; a streak's does not.
const int _strong = 128;

/// The band the splashes land in: artboard y 1760..1920 of 1920.
const double _bandTop = 1760 / 1920;

/// A splash ring's rim runs flat over at least this many artboard px; a
/// streak's cross-section (5 px at a 0.22 slant) does not.
const int _minRun = 8;

const int _grabs = 30;
const Duration _every = Duration(milliseconds: 70);

void main() {
  final IntegrationTestWidgetsFlutterBinding binding =
      IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  for (final String scene in AvatarRiveContract.sceneFrontScenes) {
    testWidgets('$scene SceneFront splashes draw at rain 1', (
      WidgetTester tester,
    ) async {
      _keepResumed();
      final File? file = await File.asset(
        AvatarRiveContract.sceneAssetPath(scene),
        riveFactory: Factory.rive,
      );
      expect(file, isNotNull, reason: '$scene.riv must load');
      final RiveWidgetController controller = RiveWidgetController(
        file!,
        artboardSelector: ArtboardSelector.byName(
          AvatarRiveContract.sceneFrontArtboard,
        ),
        stateMachineSelector: StateMachineSelector.byName(
          AvatarRiveContract.sceneStateMachine,
        ),
      );
      final RiveVmBinding vm = RiveVmBinding(controller)
        ..setNumber(AvatarRiveContract.scenePropRain, 1);
      final GlobalKey key = GlobalKey();
      final Size window =
          tester.view.physicalSize / tester.view.devicePixelRatio;
      final double height = math.min(window.height, 640).floorToDouble();
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Align(
            alignment: Alignment.topLeft,
            child: RepaintBoundary(
              key: key,
              child: SizedBox(
                width: height * 1080 / 1920,
                height: height,
                child: RiveWidget(
                  controller: controller,
                  fit: Fit.cover,
                  // one texture px per artboard px (a 1080-wide phone at
                  // the back's scale), times FRONT_SCALE
                  renderResolution: RenderResolution.layout(
                    scale: _texelsPerPx(tester, height) * _frontScale,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await _live(tester, const Duration(milliseconds: 400));

      final List<int> strong = <int>[];
      final List<Uint8List> bands = <Uint8List>[];
      int width = 0;
      int bandHeight = 0;
      int streakMax = 0;
      int bandMax = 0;
      Uint8List? best;
      int bestHeight = 0;
      for (int i = 0; i < _grabs; i++) {
        _keepResumed();
        await tester.pump();
        final RenderRepaintBoundary boundary = tester.renderObject(
          find.byKey(key),
        );
        final OffsetLayer layer = boundary.debugLayer! as OffsetLayer;
        final ui.Image image = await layer.toImage(
          Offset.zero & boundary.size,
          pixelRatio: 1920 / height,
        );
        final ByteData data = (await image.toByteData())!;
        width = image.width;
        final int h = image.height;
        image.dispose();
        final Uint8List rgba = data.buffer.asUint8List();
        final int top = (h * _bandTop).floor();
        bandHeight = h - top;
        int count = 0;
        for (int y = top; y < h; y++) {
          int run = 0;
          for (int x = 0; x <= width; x++) {
            final int a = x < width ? rgba[(y * width + x) * 4 + 3] : 0;
            bandMax = math.max(bandMax, a);
            if (a > _strong) {
              run++;
            } else {
              // a ring's rim lies flat; a streak (or two crossing) is steep
              if (run >= _minRun) {
                count += run;
              }
              run = 0;
            }
          }
        }
        // the streaks alone, above the mist (artboard y 100..1000)
        for (int y = (h * 100 / 1920).floor(); y < h * 1000 / 1920; y++) {
          for (int x = 0; x < width; x++) {
            streakMax = math.max(streakMax, rgba[(y * width + x) * 4 + 3]);
          }
        }
        if (strong.isEmpty || count > strong.reduce(math.max)) {
          best = Uint8List.fromList(rgba);
          bestHeight = h;
        }
        strong.add(count);
        bands.add(Uint8List.sublistView(rgba, top * width * 4, h * width * 4));
        await _live(tester, _every);
      }
      final int withSplash = strong.where((int c) => c > 0).length;
      final Map<String, Object> report = <String, Object>{
        'grabs': _grabs,
        'grabs_with_splash': withSplash,
        'strong_px_max': strong.reduce(math.max),
        'band_alpha_max': bandMax,
        'streak_alpha_max': streakMax,
        'size': '${width}x${bands.isEmpty ? 0 : bandHeight}',
      };
      // ignore: avoid_print
      print('FRONT_SPLASH $scene ${jsonEncode(report)}');
      if (_out.isNotEmpty) {
        await _writePng(
          '$_out/${scene}_band.png',
          _stack(bands),
          width,
          bandHeight * bands.length,
        );
        await _writePng(
          '$_out/${scene}_front.png',
          _overGrey(best!),
          width,
          bestHeight,
        );
      }

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      vm.dispose();
      controller.dispose();
      file.dispose();

      // A splash pops for 12 of every 44 frames, ten of them out of phase
      // (the file's default tier, ultra): most grabs catch one.
      expect(
        withSplash,
        greaterThanOrEqualTo(_grabs ~/ 3),
        reason: '$scene: splashes in $withSplash of $_grabs grabs',
      );
    });
  }
}

/// The grabbed bands one under the other. Raw RGBA is premultiplied: as
/// it is, it is the band over black.
Uint8List _stack(List<Uint8List> bands) {
  final BytesBuilder out = BytesBuilder(copy: false);
  for (final Uint8List band in bands) {
    final Uint8List opaque = Uint8List.fromList(band);
    for (int i = 3; i < opaque.length; i += 4) {
      opaque[i] = 255;
    }
    out.add(opaque);
  }
  return out.takeBytes();
}

/// A premultiplied grab over mid grey.
Uint8List _overGrey(Uint8List rgba) {
  final Uint8List out = Uint8List(rgba.length);
  for (int i = 0; i < rgba.length; i += 4) {
    final int under = 128 * (255 - rgba[i + 3]) ~/ 255;
    out[i] = math.min(255, rgba[i] + under);
    out[i + 1] = math.min(255, rgba[i + 1] + under);
    out[i + 2] = math.min(255, rgba[i + 2] + under);
    out[i + 3] = 255;
  }
  return out;
}

/// Encodes opaque RGBA as a PNG at [path].
Future<void> _writePng(
  String path,
  Uint8List rgba,
  int width,
  int height,
) async {
  final ui.ImmutableBuffer buffer = await ui.ImmutableBuffer.fromUint8List(
    rgba,
  );
  final ui.ImageDescriptor descriptor = ui.ImageDescriptor.raw(
    buffer,
    width: width,
    height: height,
    pixelFormat: ui.PixelFormat.rgba8888,
  );
  final ui.Codec codec = await descriptor.instantiateCodec();
  final ui.FrameInfo frame = await codec.getNextFrame();
  final ByteData? png = await frame.image.toByteData(
    format: ui.ImageByteFormat.png,
  );
  frame.image.dispose();
  codec.dispose();
  descriptor.dispose();
  buffer.dispose();
  final io.File out = io.File(path);
  await out.parent.create(recursive: true);
  await out.writeAsBytes(png!.buffer.asUint8List());
  // ignore: avoid_print
  print('FRONT_SPLASH_PNG $path');
}

void _keepResumed() {
  final WidgetsBinding binding = WidgetsBinding.instance;
  if (binding.lifecycleState != AppLifecycleState.resumed) {
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  }
}

/// Lets [time] pass for real, frames running.
Future<void> _live(WidgetTester tester, Duration time) async {
  final Stopwatch clock = Stopwatch()..start();
  while (clock.elapsed < time) {
    await tester.pump(const Duration(milliseconds: 16));
    await Future<void>.delayed(const Duration(milliseconds: 16));
  }
}
