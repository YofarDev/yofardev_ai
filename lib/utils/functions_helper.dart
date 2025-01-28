import 'package:flutter/foundation.dart';
import 'package:llm_api_picker/llm_api_picker.dart';
import 'package:math_expressions/math_expressions.dart';

import '../res/app_constants.dart';
import '../services/alarm_service.dart';
import '../services/google_search_service.dart';
import '../services/news_service.dart';
import '../services/weather_service.dart';
import '../services/wikipedia_service.dart';
import 'extensions.dart';

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
      name: 'searchWikipedia',
      description:
          'Returns a list of Wikipedia pages that match a search query',
      parameters: <Parameter>[
        Parameter(
          name: 'query',
          description: 'The search query',
          type: 'string',
        ),
      ],
      function: (String query) => WikipediaService.searchWikipedia(query),
      nextStep: FunctionInfo(
        name: 'getWikipediaPage',
        description: 'Returns the content of a Wikipedia page',
        parameters: <Parameter>[
          Parameter(
            name: 'title',
            description: 'The title of the Wikipedia page to open',
            type: 'string',
          ),
        ],
        function: (String title) => WikipediaService.getWikipediaPage(title),
      ),
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
      nextStep: FunctionInfo(
        name: 'getHtmlFromUrl',
        description: 'Gets the HTML content of a given URL',
        parameters: <Parameter>[
          Parameter(
            name: 'url',
            description: 'The URL to get the HTML content from',
            type: 'string',
          ),
        ],
        function: (String url) => GoogleSearchService.getHtmlFromUrl(url),
        nextStep: FunctionInfo(
          name: 'summarizeWebPage',
          description: 'Summarizes a web page based on the given HTML content',
          parameters: <Parameter>[
            Parameter(
              name: 'html',
              description: 'The HTML content of the web page',
              type: 'string',
            ),
            Parameter(
              name: 'originalPrompt',
              description:
                  'The original prompt used to generate the HTML content',
              type: 'string',
            ),
          ],
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
    return response.limitWords(AppConstants.maxWordsLimit);
  }
}
