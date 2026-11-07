import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/services/agent/alarm_tool.dart';

void main() {
  test('forwards minutes and message, returns the confirmation', () async {
    final List<String> calls = <String>[];
    final AlarmTool tool = AlarmTool(
      setAlarm: (int minutesFromNow, String message) async {
        calls.add('$minutesFromNow|$message');
        return 'Alarm set for soon';
      },
    );

    final String out = await tool.execute(<String, dynamic>{
      'minutesFromNow': 10,
      'message': 'tea time',
    }, <String, dynamic>{});

    expect(calls, <String>['10|tea time']);
    expect(out, 'Alarm set for 10 minutes from now with message: "tea time"');
  });

  test('defaults are 0 minutes and Hello world!', () async {
    final List<String> calls = <String>[];
    final AlarmTool tool = AlarmTool(
      setAlarm: (int minutesFromNow, String message) async {
        calls.add('$minutesFromNow|$message');
        return 'ok';
      },
    );

    await tool.execute(<String, dynamic>{}, <String, dynamic>{});

    expect(calls, <String>['0|Hello world!']);
  });

  test('metadata exposes the contract the LLM sees', () {
    final AlarmTool tool = AlarmTool(setAlarm: (int m, String s) async => '');
    expect(tool.name, 'setAlarm');
    expect(tool.requiredConfigKeys, isEmpty);
    expect(
      tool.parameters.map((dynamic p) => (p as dynamic).name as String),
      containsAll(<String>['minutesFromNow', 'message']),
    );
  });
}
