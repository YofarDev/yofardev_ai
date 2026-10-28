import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/models/performance/performance.dart';
import 'package:yofardev_ai/features/avatar/domain/models/face_frame.dart';
import 'package:yofardev_ai/features/avatar/presentation/rive/avatar_face_writer.dart';
import 'package:yofardev_ai/features/avatar/presentation/rive/avatar_rive_contract.dart';

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

  test('a forced write sets every v5 face property and no blink', () {
    writer.write(const FaceFrame(blinkSerial: 3), force: true);
    expect(sink.numbers.keys, <String>{
      ...AvatarRiveContract.actionUnitProps,
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

  test('after a reset the next write is complete and fires no stale blink', () {
    writer.write(const FaceFrame(blinkSerial: 1), force: true);
    writer.reset();
    sink.calls.clear();
    writer.write(const FaceFrame(blinkSerial: 5));
    expect(
      sink.calls.where((String c) => c.startsWith('number')),
      hasLength(18),
    );
    expect(sink.calls.where((String c) => c.startsWith('trigger')), isEmpty);
  });
}
