import 'package:math_expressions/math_expressions.dart';

import '../../models/function_info.dart';
import '../../utils/logger.dart';
import 'agent_tool.dart';

class CalculatorTool extends AgentTool {
  @override
  String get name => 'calculateExpression';

  @override
  String get description =>
      'Evaluates a mathematical expression and returns the result';

  @override
  List<Parameter> get parameters => <Parameter>[
    Parameter(
      name: 'expression',
      description: 'The mathematical expression to evaluate',
      type: 'string',
    ),
  ];

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final String expression = args['expression'] as String? ?? '';

    try {
      final ShuntingYardParser parser = ShuntingYardParser();
      final Expression exp = parser.parse(expression);
      final RealEvaluator evaluator = RealEvaluator();
      final double result = evaluator.evaluate(exp).toDouble();
      return result.toString();
    } catch (e) {
      AppLogger.error(
        'Error evaluating expression',
        tag: 'CalculatorTool',
        error: e,
      );
      return 'Invalid expression';
    }
  }
}
