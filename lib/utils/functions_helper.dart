import 'package:flutter/foundation.dart';
import 'package:llm_api_picker/llm_api_picker.dart';
import 'package:math_expressions/math_expressions.dart';

import '../services/alarm_service.dart';
import '../services/google_search_service.dart';
import '../services/news_service.dart';
import '../services/weather_service.dart';
import '../services/wikipedia_service.dart';

class FunctionsHelper {
  static final List<FunctionInfo> getFunctions = <FunctionInfo>[
    FunctionInfo(
      name: 'getCurrentWeather',
      description: 'Returns the current weather',
      parameters: <String, dynamic>{
        'type': 'object',
        'properties': <String, dynamic>{
          'location': <String, dynamic>{
            'type': 'string',
            'description': 'The location to get the weather for',
          },
        },
      },
      function: (String location) => WeatherService.getCurrentWeather(location),
    ),
    FunctionInfo(
      name: 'getMostPopularNewsOfTheDay',
      description:
          'Returns an array of the most shared articles on NYTimes.com in the last 24 hours',
      parameters: <String, dynamic>{},
      function: () => NewsService.getMostPopularNewsOfTheDay(),
    ),
    FunctionInfo(
      name: 'characterCounter',
      description:
          'Returns the number of times a specific character appears in a string',
      parameters: <String, dynamic>{
        'type': 'object',
        'properties': <String, dynamic>{
          'text': <String, dynamic>{
            'type': 'string',
            'description': 'The string to count characters in',
          },
          'character': <String, dynamic>{
            'type': 'string',
            'description': 'The character to count',
          },
        },
      },
      function: (String text, String character) =>
          FunctionsHelper.getCharacterCount(text, character),
    ),
    FunctionInfo(
      name: 'calculateExpression',
      description: 'Evaluates a mathematical expression and returns the result',
      parameters: <String, dynamic>{
        'type': 'object',
        'properties': <String, dynamic>{
          'expression': <String, dynamic>{
            'type': 'string',
            'description':
                'The mathematical expression to evaluate (e.g., "3 * (2 + 4)").',
          },
        },
      },
      function: (String expression) =>
          FunctionsHelper.getResultOfMathExpression(expression),
    ),
    FunctionInfo(
      name: 'searchWikipedia',
      description:
          'Returns a list of Wikipedia pages that match a search query',
      parameters: <String, dynamic>{
        'type': 'object',
        'properties': <String, dynamic>{
          'query': <String, dynamic>{
            'type': 'string',
            'description': 'The topic to search for',
          },
        },
      },
      function: (String query) => WikipediaService.searchWikipedia(query),
      nextStep: FunctionInfo(
        name: 'getWikipediaPage',
        description: 'Returns the content of a Wikipedia page',
        parameters: <String, dynamic>{
          'type': 'object',
          'properties': <String, dynamic>{
            'title': <String, dynamic>{
              'type': 'string',
              'description': 'The title of the Wikipedia page to open',
            },
          },
        },
        function: (String title) => WikipediaService.getWikipediaPage(title),
      ),
    ),
    FunctionInfo(
      name: 'setAlarm',
      description: 'Sets an alarm for a specific time',
      parameters: <String, dynamic>{
        'type': 'object',
        'properties': <String, dynamic>{
          'minutesFromNow': <String, dynamic>{
            'type': 'number',
            'description': 'The number of minutes from now to set the alarm',
          },
          'message': <String, dynamic>{
            'type': 'string',
            'description': 'The message to display in the alarm notification',
          },
        },
      },
      function: (int minutesFromNow, String message) =>
          AlarmService.setAlarm(minutesFromNow, message),
    ),
    FunctionInfo(
      name: 'searchGoogle',
      description: 'Searches Google for a given query and returns the results',
      parameters: <String, dynamic>{
        'query': <String, dynamic>{
          'type': 'string',
          'description': 'The query to search for',
        },
      },
      function: (String query) => GoogleSearchService.searchGoogle(query),
      nextStep: FunctionInfo(
        name: 'getHtmlFromUrl',
        description: 'Gets the HTML content of a given URL',
        parameters: <String, dynamic>{
          'url': <String, dynamic>{
            'type': 'string',
            'description': 'The URL to get the HTML content from',
          },
        },
        function: (String url) => GoogleSearchService.getHtmlFromUrl(url),
        nextStep: FunctionInfo(
          name: 'summarizeWebPage',
          description: 'Summarizes a web page based on the given HTML content',
          parameters: <String, dynamic>{
            'html': <String, dynamic>{
              'type': 'string',
              'description': 'The HTML content of the web page',
            },
            'originalPrompt': <String, dynamic>{
              'type': 'string',
              'description':
                  'The original prompt used to generate the HTML content',
            },
          },
          function: (String html, String originalPrompt) =>
              FunctionsHelper.sumUpWebPage(html, originalPrompt),
        ),
      ),
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

  static Future<String> sumUpWebPage(String html, String originalPrompt) async {
    final String response = await LLMRepository.promptModel(
      systemPrompt:
          'You are a helpful assistant that summarizes web pages based on an user request. You only answer with the text summary, remove html tags and do NOT add additional comments.',
      messages: <Message>[
        Message(
          role: MessageRole.user,
          body:
              'Here is the original user’s message : $originalPrompt\nAfter a web query search, we got the following html web page result. Make a text summary with all relevant informations : \n$html',
        ),
      ],
    );
    debugPrint(response);
    return response;
  }
}
