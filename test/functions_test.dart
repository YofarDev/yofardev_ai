import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/services/agent/calculator_tool.dart';
import 'package:yofardev_ai/core/services/agent/character_counter_tool.dart';

void main() {
  group('CalculatorTool', () {
    test('should return the correct result for a valid expression', () async {
      final CalculatorTool tool = CalculatorTool();

      expect(
        await tool.execute(<String, dynamic>{
          'expression': '2 + 2',
        }, <String, dynamic>{}),
        equals('4.0'),
      );
      expect(
        await tool.execute(<String, dynamic>{
          'expression': '123456*654332',
        }, <String, dynamic>{}),
        equals('80781211392.0'),
      );
      expect(
        await tool.execute(<String, dynamic>{
          'expression': '10 / 2',
        }, <String, dynamic>{}),
        equals('5.0'),
      );
      expect(
        await tool.execute(<String, dynamic>{
          'expression': '2^3',
        }, <String, dynamic>{}),
        equals('8.0'),
      );
    });
  });

  group('CharacterCounterTool', () {
    test(
      'should return the correct count for a valid text and character',
      () async {
        final CharacterCounterTool tool = CharacterCounterTool();

        expect(
          await tool.execute(<String, dynamic>{
            'text': 'Hello, world!',
            'character': 'l',
          }, <String, dynamic>{}),
          equals('3'),
        );
        expect(
          await tool.execute(<String, dynamic>{
            'text': 'Hello, world!',
            'character': 'o',
          }, <String, dynamic>{}),
          equals('2'),
        );
        expect(
          await tool.execute(<String, dynamic>{
            'text': 'strawberry',
            'character': 'r',
          }, <String, dynamic>{}),
          equals('3'),
        );
      },
    );
  });
}
