import 'dart:convert';

import 'package:yofardev_ai/core/models/function_info.dart';
import 'package:yofardev_ai/core/services/agent/agent_tool.dart';

/// `getMostPopularNewsOfTheDay` with a canned answer after [delay] (film,
/// 2026-11-07): long enough for the newspaper to come out and be read; the
/// real tool (the owner's NYT key, the network) is never called.
class CannedNewsTool extends AgentTool {
  CannedNewsTool({this.delay = const Duration(milliseconds: 2800)});

  final Duration delay;

  @override
  String get name => 'getMostPopularNewsOfTheDay';

  @override
  String get description => 'Returns the most popular news of the day';

  @override
  List<Parameter> get parameters => <Parameter>[];

  @override
  Map<String, String> get requiredConfigKeys => const <String, String>{};

  @override
  Future<String> execute(
    Map<String, dynamic> args,
    Map<String, dynamic> configValues,
  ) async {
    await Future<void>.delayed(delay);
    return jsonEncode(<String, Object>{
      'articles': <Map<String, String>>[
        <String, String>{
          'title': 'A bright comet is visible to the naked eye this week',
        },
      ],
    });
  }
}
