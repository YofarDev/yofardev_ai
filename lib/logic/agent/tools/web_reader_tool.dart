import 'dart:async';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../../models/llm/function_info.dart';

import '../agent_tool.dart';

class WebReaderTool extends AgentTool {
  @override
  String get name => 'getTextContentFromWebsite';

  @override
  String get description => 'Get the rendered text content of a webpage.';

  @override
  List<Parameter> get parameters => <Parameter>[
    Parameter(
      name: 'url',
      type: 'string',
      description: 'The URL of the webpage.',
    ),
  ];

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final String url = args['url'] as String? ?? '';
    final Uri uri = Uri.parse(url);
    final Completer<String> completer = Completer<String>();

    // Note: HeadlessInAppWebView might need to be run on the main thread or have platform specific constraints.
    // Assuming the previous implementation worked, we replicate it here.
    final HeadlessInAppWebView headlessWebView = HeadlessInAppWebView(
      initialUrlRequest: URLRequest(url: WebUri.uri(uri)),
      onLoadStop: (InAppWebViewController controller, WebUri? url) async {
        try {
          final String results =
              await controller.evaluateJavascript(
                    source: "document.body.innerText;",
                  )
                  as String? ??
              'null';
          completer.complete(results);
        } catch (e) {
          completer.completeError(e);
        }
      },
    );

    await headlessWebView.run();
    return completer.future.whenComplete(() {
      headlessWebView.dispose();
    });
  }
}
