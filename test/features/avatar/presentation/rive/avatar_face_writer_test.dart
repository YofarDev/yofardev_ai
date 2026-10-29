import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/models/avatar_mood.dart';
import 'package:yofardev_ai/core/models/performance/performance.dart';
import 'package:yofardev_ai/features/avatar/domain/models/face_frame.dart';
import 'package:yofardev_ai/features/avatar/domain/models/performance_intent.dart';
import 'package:yofardev_ai/features/avatar/domain/services/face_performer.dart';
import 'package:yofardev_ai/features/avatar/presentation/rive/avatar_face_writer.dart';
import 'package:yofardev_ai/features/avatar/presentation/rive/avatar_rive_contract.dart';
import 'package:yofardev_ai/features/avatar/presentation/widgets/rive/rive_avatar_view.dart';
import 'package:yofardev_ai/features/talking/talking.dart';

class _RecordingSink implements AvatarVmSink {
  final Map<String, double> numbers = <String, double>{};
  final List<String> calls = <String>[];

  @override
  void setNumber(String name, double value) {
    numbers[name] = value;
    calls.add('number $name');
  }

  @override
  void setBool(String name, bool value) => calls.add('bool $name=$value');

  @override
  void fireTrigger(String name) => calls.add('trigger $name');
}

void main() {
  late _RecordingSink sink;
  late AvatarFaceWriter writer;

  setUp(() {
    sink = _RecordingSink();
    writer = AvatarFaceWriter(sink);
  });

  test('a forced write sets every v6 face property and no blink', () {
    writer.write(const FaceFrame(blinkSerial: 3), force: true);
    expect(sink.numbers.keys, <String>{
      ...AvatarRiveContract.actionUnitProps,
      ...AvatarRiveContract.actionUnitSideProps,
      AvatarRiveContract.propLipTuck,
      AvatarRiveContract.propTongueUp,
      AvatarRiveContract.propRoll,
      AvatarRiveContract.propBreath,
    });
    expect(sink.calls, contains('bool autoBlink=true'));
    expect(sink.calls.where((String c) => c.startsWith('trigger')), isEmpty);
  });

  test('unchanged and sub-epsilon values are not written again', () {
    writer.write(const FaceFrame(), force: true);
    sink.calls.clear();
    writer.write(const FaceFrame());
    writer.write(const FaceFrame(au: ActionUnits(jawDrop: 0.0005)));
    expect(sink.calls, isEmpty);
    writer.write(const FaceFrame(au: ActionUnits(jawDrop: 0.4)));
    expect(sink.calls, <String>['number auJawDrop']);
    expect(sink.numbers[AvatarRiveContract.propAuJawDrop], 0.4);
  });

  test('blink fires once per new serial; autoBlink only when it flips', () {
    writer.write(const FaceFrame(blinkSerial: 1), force: true);
    sink.calls.clear();
    writer.write(const FaceFrame(blinkSerial: 2, autoBlink: false));
    writer.write(const FaceFrame(blinkSerial: 2, autoBlink: false));
    expect(sink.calls, <String>['bool autoBlink=false', 'trigger blink']);
  });

  test('side offsets go to the viewer\'s L and R names, signed', () {
    writer.write(
      const FaceFrame(
        left: ActionUnitSides(browLower: -0.4, lipCornerDepress: 0.2),
        right: ActionUnitSides(cheekRaise: 0.7),
      ),
      force: true,
    );
    expect(sink.numbers[AvatarRiveContract.propAuBrowLowerL], -0.4);
    expect(sink.numbers[AvatarRiveContract.propAuLipCornerDepressL], 0.2);
    expect(sink.numbers[AvatarRiveContract.propAuCheekRaiseR], 0.7);
    expect(sink.numbers[AvatarRiveContract.propAuCheekRaiseL], 0);
    expect(sink.numbers[AvatarRiveContract.propAuBrowLowerR], 0);
  });

  test('side offsets skip sub-epsilon changes like the AUs', () {
    writer.write(const FaceFrame(), force: true);
    sink.calls.clear();
    writer.write(const FaceFrame(right: ActionUnitSides(browOuterUp: 0.0008)));
    expect(sink.calls, isEmpty);
    writer.write(const FaceFrame(right: ActionUnitSides(browOuterUp: -0.3)));
    expect(sink.calls, <String>['number auBrowOuterUpR']);
  });

  test('the thinking mood lifts the viewer\'s right outer brow (static)', () {
    writer.write(RiveAvatarView.staticFace(AvatarMood.thinking), force: true);
    expect(
      sink.numbers[AvatarRiveContract.propAuBrowOuterUpR],
      closeTo(0.35, 1e-9),
    );
    expect(
      sink.numbers[AvatarRiveContract.propAuBrowLowerL],
      closeTo(0.25, 1e-9),
    );
    expect(sink.numbers[AvatarRiveContract.propAuBrowOuterUpL], 0);
  });

  test('the thinking mood lifts the right outer brow (performer)', () async {
    final StreamController<PerformanceIntent> intents =
        StreamController<PerformanceIntent>.broadcast(sync: true);
    final StreamController<PlaybackEvent> playback =
        StreamController<PlaybackEvent>.broadcast(sync: true);
    final FacePerformer performer = FacePerformer(
      intents: intents.stream,
      playback: playback.stream,
      speechPosition: () => null,
    );
    addTearDown(() async {
      await performer.dispose();
      await intents.close();
      await playback.close();
    });
    writer.write(performer.frame, force: true);
    intents.add(
      PerformanceIntent(
        emotion: emotionForMood(AvatarMood.thinking),
        face: actionUnitsForMood(AvatarMood.thinking),
      ),
    );
    for (int i = 0; i < 120; i++) {
      writer.write(performer.step(const Duration(microseconds: 16667)));
    }
    expect(
      sink.numbers[AvatarRiveContract.propAuBrowOuterUpR],
      closeTo(0.35, 0.02),
    );
  });

  test('an adopted blink serial is a new baseline that does not fire', () {
    writer.write(const FaceFrame(blinkSerial: 7), force: true);
    sink.calls.clear();
    // switching to a source that counts from 0 (the lab override)
    writer.adoptBlinkSerial(0);
    writer.write(const FaceFrame());
    expect(sink.calls.where((String c) => c.startsWith('trigger')), isEmpty);
    writer.write(const FaceFrame(blinkSerial: 1));
    expect(sink.calls, contains('trigger blink'));
  });

  test('after a reset the next write is complete and fires no stale blink', () {
    writer.write(const FaceFrame(blinkSerial: 1), force: true);
    writer.reset();
    sink.calls.clear();
    writer.write(const FaceFrame(blinkSerial: 5));
    expect(
      sink.calls.where((String c) => c.startsWith('number')),
      hasLength(32),
    );
    expect(sink.calls.where((String c) => c.startsWith('trigger')), isEmpty);
  });
}
