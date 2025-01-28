import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/utils/functions_helper.dart';

void main() {
  group('FunctionsHelper - calculatorFunction', () {
    test('should return the correct result for a valid expression', () {
      expect(FunctionsHelper.getResultOfMathExpression('2 + 2'), equals(4.0));
      expect(FunctionsHelper.getResultOfMathExpression('123456*654332'), equals(80781211392));
      expect(FunctionsHelper.getResultOfMathExpression('10 / 2'), equals(5.0));
      expect(FunctionsHelper.getResultOfMathExpression('2^3'), equals(8.0));
    });
  });

  group('FunctionHelper - characterCounter', () {
    test('should return the correct count for a valid text and character', () {
      expect(FunctionsHelper.getCharacterCount('Hello, world!',  'l'), equals(3));
      expect(FunctionsHelper.getCharacterCount('Hello, world!',  'o'), equals(2));
      expect(FunctionsHelper.getCharacterCount( 'strawberry', 'r'), equals(3));
    });
  });


}
