import '../../models/function_info.dart';

import 'alarm_service.dart';
import 'agent_tool.dart';

class AlarmTool extends AgentTool {
  @override
  String get name => 'setAlarm';

  @override
  String get description => 'Sets an alarm for a specific time';

  @override
  List<Parameter> get parameters => <Parameter>[
    Parameter(
      name: 'minutesFromNow',
      description: 'The number of minutes from now to set the alarm',
      type: 'number',
    ),
    Parameter(
      name: 'message',
      description: 'The message to display in the alarm notification',
      type: 'string',
    ),
  ];

  @override
  Map<String, String> get requiredConfigKeys => <String, String>{};

  @override
  Future<String> execute(
    Map<String, dynamic> args,
    Map<String, dynamic> configValues,
  ) async {
    final int minutesFromNow = args['minutesFromNow'] as int? ?? 0;
    final String message = args['message'] as String? ?? 'Hello world!';

    // Call the existing service
    await AlarmService.setAlarm(minutesFromNow, message);
    return 'Alarm set for $minutesFromNow minutes from now with message: "$message"';
  }
}
