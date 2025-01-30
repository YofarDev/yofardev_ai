import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:llm_api_picker/llm_api_picker.dart';
import 'package:math_expressions/math_expressions.dart';

import '../services/alarm_service.dart';
import '../services/google_search_service.dart';
import '../services/news_service.dart';
import '../services/weather_service.dart';

class FunctionsHelper {
  static final List<FunctionInfo> getFunctions = <FunctionInfo>[
    FunctionInfo(
      name: 'getCurrentWeather',
      description: 'Returns the current weather',
      parameters: <Parameter>[
        Parameter(
          name: 'location',
          description: 'The location to get the weather for',
          type: 'string',
        ),
      ],
      function: (String location) => WeatherService.getCurrentWeather(location),
    ),
    FunctionInfo(
      name: 'getMostPopularNewsOfTheDay',
      description:
          'Returns an array of the most shared articles on NYTimes.com in the last 24 hours',
      parameters: <Parameter>[],
      function: () => NewsService.getMostPopularNewsOfTheDay(),
    ),
    FunctionInfo(
      name: 'characterCounter',
      description:
          'Returns the number of times a specific character appears in a string',
      parameters: <Parameter>[
        Parameter(
          name: 'text',
          description: 'The string to count characters in',
          type: 'string',
        ),
        Parameter(
          name: 'character',
          description: 'The character to count',
          type: 'string',
        ),
      ],
      function: (String text, String character) =>
          FunctionsHelper.getCharacterCount(text, character),
    ),
    FunctionInfo(
      name: 'calculateExpression',
      description: 'Evaluates a mathematical expression and returns the result',
      parameters: <Parameter>[
        Parameter(
          name: 'expression',
          description: 'The mathematical expression to evaluate',
          type: 'string',
        ),
      ],
      function: (String expression) =>
          FunctionsHelper.getResultOfMathExpression(expression),
    ),
    FunctionInfo(
      name: 'setAlarm',
      description: 'Sets an alarm for a specific time',
      parameters: <Parameter>[
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
      ],
      function: (int minutesFromNow, String message) =>
          AlarmService.setAlarm(minutesFromNow, message),
    ),
    FunctionInfo(
      name: 'searchGoogle',
      description: 'Searches Google for a given query and returns the results',
      parameters: <Parameter>[
        Parameter(
          name: 'query',
          description: 'The query to search for',
          type: 'string',
        ),
      ],
      function: (String query) => GoogleSearchService.searchGoogle(query),
    ),
    FunctionInfo(
      name: 'getTextContentFromWebsite',
      description: 'Get the rendered text content of a webpage.',
      parameters: <Parameter>[
        Parameter(
          name: 'url',
          type: 'String',
          description: 'The URL of the webpage.',
        ),
      ],
      function: (String url) => getRenderedTextOfWebsite(url),
    ),
    // Test.multiStepsFunction,
  ];

  static int getCharacterCount(
    String text,
    String characterToCount,
  ) {
    int count = 0;
    for (int i = 0; i < text.length; i++) {
      if (text[i].toLowerCase() == characterToCount.toLowerCase()) {
        count++;
      }
    }
    return count;
  }

  static double? getResultOfMathExpression(String expression) {
    try {
      final Parser parser = Parser();
      final Expression exp = parser.parse(expression);
      final ContextModel contextModel =
          ContextModel(); // To support variable evaluation if needed
      final double result =
          exp.evaluate(EvaluationType.REAL, contextModel) as double;
      return result;
    } catch (e) {
      debugPrint(e.toString());
      return null;
    }
  }

  static Future<String> getRenderedTextOfWebsite(String url) async {
    final Uri uri = Uri.parse(url);
    final Completer<String> completer = Completer<String>();
    final HeadlessInAppWebView headlessWebView = HeadlessInAppWebView(
      initialUrlRequest: URLRequest(url: WebUri.uri(uri)),
      onLoadStop: (InAppWebViewController controller, WebUri? url) async {
        try {
          // Extract text using JavaScript
          final String results = await controller.evaluateJavascript(
                source: "document.body.innerText;",
              ) as String? ??
              'null';
          completer.complete(results);
        } catch (e) {
          completer.completeError(e);
        }
      },
    );
    await headlessWebView.run();
    return completer.future.whenComplete(() {
      // Dispose the headlessWebView once the future completes
      headlessWebView.dispose();
    });
  }
}
