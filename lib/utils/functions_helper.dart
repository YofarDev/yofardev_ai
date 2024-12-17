import 'package:flutter/foundation.dart';
import 'package:llm_api_picker/llm_api_picker.dart';
import 'package:math_expressions/math_expressions.dart';

import '../services/news_service.dart';
import '../services/weather_service.dart';
import '../services/wikipedia_service.dart';

typedef WeatherFunction = Future<String> Function(String location);
typedef NewsFunction = Future<String> Function();
typedef CharacterCounterFunction = int Function(
  String text,
  String characterToCount,
);
typedef CalculatorFunction = double? Function(String expression);
typedef SearchWikipediaFunction = Future<String> Function(String query);
typedef GetWikipediaPageFunction = Future<String> Function(String title);

class FunctionsHelper {
  static const WeatherFunction getCurrentWeather =
      WeatherService.getCurrentWeather;
  static const NewsFunction getMostPopularNewsOfTheDay =
      NewsService.getMostPopularNewsOfTheDay;
  static const SearchWikipediaFunction searchWikipediaFunction =
      WikipediaService.searchWikipedia;
  static const GetWikipediaPageFunction getWikiPage =
      WikipediaService.getWikipediaPage;
  static const CalculatorFunction calculatorFunction =
      FunctionsHelper.getResultOfMathExpression;
  static const CharacterCounterFunction characterCounterFunction =
      FunctionsHelper.getCharacterCount;

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
      function: getCurrentWeather,
    ),
    FunctionInfo(
      name: 'getMostPopularNewsOfTheDay',
      description:
          'Returns an array of the most shared articles on NYTimes.com in the last 24 hours',
      parameters: <String, dynamic>{},
      function: getMostPopularNewsOfTheDay,
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
      function: getCharacterCount,
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
          FunctionsHelper.calculatorFunction(expression),
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
      function: searchWikipediaFunction,
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
        function: getWikiPage,
      ),
    ),
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
}
