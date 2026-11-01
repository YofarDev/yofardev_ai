import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yofardev_ai/core/models/demo_script.dart';
import 'package:yofardev_ai/core/models/llm_message.dart';
import 'package:yofardev_ai/core/services/llm/fake_llm_service.dart';
import 'package:yofardev_ai/core/services/llm/llm_service_interface.dart';
import 'package:yofardev_ai/core/services/llm/llm_stream_chunk.dart';

class MockLlmService extends Mock implements LlmServiceInterface {}

void main() {
  late MockLlmService delegate;
  late FakeLlmService fake;

  const List<LlmMessage> messages = <LlmMessage>[
    LlmMessage(role: LlmMessageRole.user, body: 'Hi'),
  ];

  Future<List<LlmStreamChunk>> prompt() =>
      fake.promptModelStream(messages: messages, systemPrompt: 'sys').toList();

  const FakeLlmResponse toolRound = FakeLlmResponse(
    jsonBody: '',
    toolCalls: <FakeToolCall>[
      FakeToolCall(
        name: 'getCurrentWeather',
        arguments: <String, dynamic>{'location': 'Tokyo'},
      ),
    ],
  );
  const FakeLlmResponse answer = FakeLlmResponse(
    jsonBody: '{"message":"Rainy in Tokyo."}',
  );

  setUp(() {
    delegate = MockLlmService();
    fake = FakeLlmService.forTest(delegate);
  });

  group('scripted tool rounds', () {
    test('a tool response streams the delta then complete, no text', () async {
      fake.activate(<FakeLlmResponse>[toolRound, answer]);

      final List<LlmStreamChunk> chunks = await prompt();

      expect(chunks, const <LlmStreamChunk>[
        LlmStreamChunk.toolCallDelta(
          index: 0,
          id: 'call_0',
          name: 'getCurrentWeather',
          argumentsDelta: '{"location":"Tokyo"}',
        ),
        LlmStreamChunk.complete(),
      ]);
    });

    test('several calls get consecutive indexes and ids', () async {
      fake.activate(const <FakeLlmResponse>[
        FakeLlmResponse(
          jsonBody: '',
          toolCalls: <FakeToolCall>[
            FakeToolCall(name: 'a'),
            FakeToolCall(name: 'b', arguments: <String, dynamic>{'x': 1}),
          ],
        ),
      ]);

      final List<LlmStreamChunk> chunks = await prompt();

      expect(chunks, const <LlmStreamChunk>[
        LlmStreamChunk.toolCallDelta(
          index: 0,
          id: 'call_0',
          name: 'a',
          argumentsDelta: '{}',
        ),
        LlmStreamChunk.toolCallDelta(
          index: 1,
          id: 'call_1',
          name: 'b',
          argumentsDelta: '{"x":1}',
        ),
        LlmStreamChunk.complete(),
      ]);
    });

    test('the next prompt streams the answer text then complete', () async {
      fake.activate(<FakeLlmResponse>[toolRound, answer]);
      await prompt();

      final List<LlmStreamChunk> chunks = await prompt();

      expect(chunks, const <LlmStreamChunk>[
        LlmStreamChunk.text(
          content: '{"message":"Rainy in Tokyo."}',
          isComplete: true,
        ),
        LlmStreamChunk.complete(),
      ]);
      expect(fake.hasMore, isFalse);
    });

    test('promptModel returns the jsonBody of a tool response', () async {
      fake.activate(<FakeLlmResponse>[toolRound]);

      final String? body = await fake.promptModel(
        messages: messages,
        systemPrompt: 'sys',
      );

      expect(body, '');
    });

    test('deactivate then activate restarts with no leftover tool round', () {
      fake.activate(<FakeLlmResponse>[toolRound, answer]);
      // Consume the tool round only: the answer is still queued.
      expect(fake.getNextResponse(), toolRound);

      fake.deactivate();
      fake.activate(<FakeLlmResponse>[answer]);

      expect(fake.remainingResponses, 1);
      expect(fake.getNextResponse(), answer);
      expect(fake.hasMore, isFalse);
    });

    test('reset replays from the first response', () {
      fake.activate(<FakeLlmResponse>[toolRound, answer]);
      fake.getNextResponse();

      fake.reset();

      expect(fake.peekNextResponse(), toolRound);
    });
  });

  group('generateTitle', () {
    test(
      'while active returns the title and never calls the delegate',
      () async {
        fake.activate(<FakeLlmResponse>[answer], title: 'Wow');

        final String? title = await fake.generateTitle('hello');

        expect(title, 'Wow');
        verifyNever(
          () => delegate.generateTitle(
            any(),
            config: any(named: 'config'),
            language: any(named: 'language'),
          ),
        );
      },
    );

    test(
      'while active without a title returns null, no delegate call',
      () async {
        fake.activate(<FakeLlmResponse>[answer]);

        final String? title = await fake.generateTitle('hello');

        expect(title, isNull);
        verifyNever(
          () => delegate.generateTitle(
            any(),
            config: any(named: 'config'),
            language: any(named: 'language'),
          ),
        );
      },
    );

    test('while inactive delegates to the real service', () async {
      when(
        () => delegate.generateTitle(
          any(),
          config: any(named: 'config'),
          language: any(named: 'language'),
        ),
      ).thenAnswer((_) async => 'Real title');

      final String? title = await fake.generateTitle('hello', language: 'fr');

      expect(title, 'Real title');
      verify(
        () => delegate.generateTitle('hello', config: null, language: 'fr'),
      ).called(1);
    });

    test('after deactivate the old title is gone and it delegates', () async {
      when(
        () => delegate.generateTitle(
          any(),
          config: any(named: 'config'),
          language: any(named: 'language'),
        ),
      ).thenAnswer((_) async => null);
      fake.activate(<FakeLlmResponse>[answer], title: 'Wow');
      fake.deactivate();

      final String? title = await fake.generateTitle('hello');
      expect(title, isNull);
      verify(
        () => delegate.generateTitle(
          any(),
          config: any(named: 'config'),
          language: any(named: 'language'),
        ),
      ).called(1);

      fake.activate(<FakeLlmResponse>[answer]);
      expect(await fake.generateTitle('hello'), isNull);
    });
  });

  group('FakeLlmResponse.fromJson', () {
    test('parses toolCalls', () {
      final FakeLlmResponse response = FakeLlmResponse.fromJson(
        jsonDecode(
              '{"jsonBody":"","toolCalls":['
              '{"name":"getCurrentWeather","arguments":{"location":"Tokyo"}},'
              '{"name":"noArgs"}]}',
            )
            as Map<String, dynamic>,
      );

      expect(response.toolCalls, hasLength(2));
      expect(response.toolCalls[0].name, 'getCurrentWeather');
      expect(response.toolCalls[0].arguments, <String, dynamic>{
        'location': 'Tokyo',
      });
      expect(response.toolCalls[1].arguments, isEmpty);
    });

    test('toolCalls is empty when absent', () {
      final FakeLlmResponse response = FakeLlmResponse.fromJson(
        <String, dynamic>{'jsonBody': '{}'},
      );
      expect(response.toolCalls, isEmpty);
    });
  });
}
