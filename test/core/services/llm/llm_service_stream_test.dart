import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yofardev_ai/core/services/llm/llm_service.dart';
import 'package:yofardev_ai/core/services/llm/llm_stream_chunk.dart';
import 'package:yofardev_ai/core/models/llm_config.dart';
import 'package:yofardev_ai/core/models/llm_message.dart';

class MockHttpClient extends Mock implements Client {}

void main() {
  // Initialize Flutter test bindings
  TestWidgetsFlutterBinding.ensureInitialized();

  // Register fallback values for mocktail
  setUpAll(() {
    registerFallbackValue(Request('GET', Uri.parse('http://example.com')));
  });

  late LlmService llmService;
  late MockHttpClient mockClient;

  setUp(() {
    mockClient = MockHttpClient();
    LlmService.setTestClient(mockClient);
    llmService = LlmService();
  });

  tearDown(() {
    LlmService.resetTestClient();
  });

  group('LlmService.promptModelStream', () {
    final List<LlmMessage> messages = <LlmMessage>[
      const LlmMessage(role: LlmMessageRole.user, body: 'Hello'),
    ];

    test('should emit error when no config is set', () async {
      // Create a new service instance with no configs
      final LlmService newService = LlmService();

      final List<LlmStreamChunk> chunks = <LlmStreamChunk>[];
      await for (final LlmStreamChunk chunk in newService.promptModelStream(
        messages: messages,
        systemPrompt: 'You are helpful.',
      )) {
        chunks.add(chunk);
      }

      expect(chunks.length, 1);
      expect(
        chunks[0].maybeWhen(
          error: (String msg) => msg.contains('No LLM Configuration'),
          orElse: () => false,
        ),
        isTrue,
      );
    });

    test('should have stream method defined', () {
      // Verify the method signature exists and returns a Stream
      final Stream<LlmStreamChunk> stream = llmService.promptModelStream(
        messages: messages,
        systemPrompt: 'Test',
      );

      expect(stream, isA<Stream<LlmStreamChunk>>());
    });

    test('should accept all required parameters', () {
      // Verify that the stream method accepts all parameters correctly
      const LlmConfig testConfig = LlmConfig(
        id: 'test-config-id',
        label: 'Test Config',
        baseUrl: 'https://api.test.com',
        apiKey: 'test-key',
        model: 'test-model',
        temperature: 0.7,
      );

      final Stream<LlmStreamChunk> stream = llmService.promptModelStream(
        messages: messages,
        systemPrompt: 'You are helpful.',
        config: testConfig,
        returnJson: true,
        debugLogs: true,
      );

      expect(stream, isA<Stream<LlmStreamChunk>>());
    });

    test('should emit text chunks from stream', () async {
      // Arrange: Set up test config
      const LlmConfig testConfig = LlmConfig(
        id: 'test-config-id',
        label: 'Test Config',
        baseUrl: 'https://api.test.com',
        apiKey: 'test-key',
        model: 'test-model',
        temperature: 0.7,
      );

      // Mock SSE stream response
      final StreamedResponse mockResponse = StreamedResponse(
        Stream<List<int>>.fromIterable(<List<int>>[
          'data: {"choices":[{"delta":{"content":"Hello"},"finish_reason":null}]}\n'
              .codeUnits,
          'data: {"choices":[{"delta":{"content":" world"},"finish_reason":null}]}\n'
              .codeUnits,
          'data: {"choices":[{"delta":{"content":"!"},"finish_reason":"stop"}]}\n'
              .codeUnits,
          'data: [DONE]\n'.codeUnits,
        ]),
        200,
        request: Request(
          'POST',
          Uri.parse('https://api.test.com/chat/completions'),
        ),
      );

      when(() => mockClient.send(any())).thenAnswer((_) async => mockResponse);

      // Act: Call the streaming method
      final List<LlmStreamChunk> chunks = <LlmStreamChunk>[];
      await for (final LlmStreamChunk chunk in llmService.promptModelStream(
        messages: messages,
        systemPrompt: 'You are helpful.',
        config: testConfig,
      )) {
        chunks.add(chunk);
      }

      // Assert: Verify chunks were emitted correctly
      expect(chunks.length, 4);

      // First chunk: "Hello"
      expect(
        chunks[0].maybeWhen(
          text: (String content, bool isComplete) =>
              content == 'Hello' && !isComplete,
          orElse: () => false,
        ),
        isTrue,
      );

      // Second chunk: " world"
      expect(
        chunks[1].maybeWhen(
          text: (String content, bool isComplete) =>
              content == ' world' && !isComplete,
          orElse: () => false,
        ),
        isTrue,
      );

      // Third chunk: "!" with isComplete=true
      expect(
        chunks[2].maybeWhen(
          text: (String content, bool isComplete) =>
              content == '!' && isComplete,
          orElse: () => false,
        ),
        isTrue,
      );

      // Fourth chunk: complete signal
      expect(
        chunks[3].maybeWhen(complete: () => true, orElse: () => false),
        isTrue,
      );

      // Verify the HTTP client was called
      verify(() => mockClient.send(any())).called(1);
    });

    test('should handle malformed SSE data gracefully', () async {
      // Arrange: Set up test config
      const LlmConfig testConfig = LlmConfig(
        id: 'test-config-id',
        label: 'Test Config',
        baseUrl: 'https://api.test.com',
        apiKey: 'test-key',
        model: 'test-model',
        temperature: 0.7,
      );

      // Mock response with some malformed data
      final StreamedResponse mockResponse = StreamedResponse(
        Stream<List<int>>.fromIterable(<List<int>>[
          'data: {"choices":[{"delta":{"content":"Valid"}}]}\n'.codeUnits,
          'invalid line\n'.codeUnits, // This will be skipped
          'data: {"choices":[{"delta":{"content":" chunk"}}]}\n'.codeUnits,
          'data: [DONE]\n'.codeUnits,
        ]),
        200,
        request: Request(
          'POST',
          Uri.parse('https://api.test.com/chat/completions'),
        ),
      );

      when(() => mockClient.send(any())).thenAnswer((_) async => mockResponse);

      // Act: Call the streaming method
      final List<LlmStreamChunk> chunks = <LlmStreamChunk>[];
      await for (final LlmStreamChunk chunk in llmService.promptModelStream(
        messages: messages,
        systemPrompt: 'You are helpful.',
        config: testConfig,
      )) {
        chunks.add(chunk);
      }

      // Assert: Should have 3 chunks (2 text + 1 complete), malformed line skipped
      expect(chunks.length, 3);

      // Verify valid chunks were emitted
      expect(
        chunks[0].maybeWhen(
          text: (String content, bool _) => content == 'Valid',
          orElse: () => false,
        ),
        isTrue,
      );

      expect(
        chunks[1].maybeWhen(
          text: (String content, bool _) => content == ' chunk',
          orElse: () => false,
        ),
        isTrue,
      );

      expect(
        chunks[2].maybeWhen(complete: () => true, orElse: () => false),
        isTrue,
      );
    });

    test('should emit error on HTTP error', () async {
      // Arrange: Set up test config
      const LlmConfig testConfig = LlmConfig(
        id: 'test-config-id',
        label: 'Test Config',
        baseUrl: 'https://api.test.com',
        apiKey: 'test-key',
        model: 'test-model',
        temperature: 0.7,
      );

      // Mock error response
      final StreamedResponse mockResponse = StreamedResponse(
        Stream<List<int>>.fromIterable(<List<int>>[
          'Internal Server Error'.codeUnits,
        ]),
        500,
        request: Request(
          'POST',
          Uri.parse('https://api.test.com/chat/completions'),
        ),
        reasonPhrase: 'Internal Server Error',
      );

      when(() => mockClient.send(any())).thenAnswer((_) async => mockResponse);

      // Act: Call the streaming method
      final List<LlmStreamChunk> chunks = <LlmStreamChunk>[];
      await for (final LlmStreamChunk chunk in llmService.promptModelStream(
        messages: messages,
        systemPrompt: 'You are helpful.',
        config: testConfig,
      )) {
        chunks.add(chunk);
      }

      // Assert: Should emit error chunk
      expect(chunks.length, 1);
      expect(
        chunks[0].maybeWhen(
          error: (String msg) => msg.contains('500'),
          orElse: () => false,
        ),
        isTrue,
      );
    });
    test('should emit toolCallDelta chunks from fragmented tool_calls', () async {
      const LlmConfig testConfig = LlmConfig(
        id: 'test-config-id',
        label: 'Test Config',
        baseUrl: 'https://api.test.com',
        apiKey: 'test-key',
        model: 'test-model',
        temperature: 0.7,
      );

      final StreamedResponse mockResponse = StreamedResponse(
        Stream<List<int>>.fromIterable(<List<int>>[
          'data: {"choices":[{"delta":{"tool_calls":[{"index":0,"id":"call_1","function":{"name":"getWeather","arguments":""}}]},"finish_reason":null}]}\n'
              .codeUnits,
          'data: {"choices":[{"delta":{"tool_calls":[{"index":0,"function":{"arguments":"{\\"city\\":\\"Par"}}]},"finish_reason":null}]}\n'
              .codeUnits,
          'data: {"choices":[{"delta":{"tool_calls":[{"index":0,"function":{"arguments":"is\\"}"}}]},"finish_reason":"tool_calls"}]}\n'
              .codeUnits,
          'data: [DONE]\n'.codeUnits,
        ]),
        200,
        request: Request(
          'POST',
          Uri.parse('https://api.test.com/chat/completions'),
        ),
      );

      when(() => mockClient.send(any())).thenAnswer((_) async => mockResponse);

      final List<LlmStreamChunk> chunks = <LlmStreamChunk>[];
      await for (final LlmStreamChunk chunk in llmService.promptModelStream(
        messages: messages,
        systemPrompt: 'You are helpful.',
        config: testConfig,
      )) {
        chunks.add(chunk);
      }

      final List<LlmStreamChunk> toolChunks = <LlmStreamChunk>[];
      for (final LlmStreamChunk chunk in chunks) {
        final bool isToolChunk = chunk.maybeWhen(
          toolCallDelta: (_, _, _, _) => true,
          orElse: () => false,
        );
        if (isToolChunk) toolChunks.add(chunk);
      }
      expect(toolChunks.length, 3);

      // Accumulate like ChatStreamingService does.
      String id = '';
      String name = '';
      String arguments = '';
      for (final LlmStreamChunk chunk in toolChunks) {
        chunk.maybeWhen(
          toolCallDelta:
              (int _, String? chunkId, String? chunkName, String? argsDelta) {
                if (chunkId != null) id = chunkId;
                if (chunkName != null) name = chunkName;
                if (argsDelta != null) arguments += argsDelta;
              },
          orElse: () {},
        );
      }
      expect(id, 'call_1');
      expect(name, 'getWeather');
      expect(arguments, '{"city":"Paris"}');
      expect(arguments.length, 16);
    });

    test(
      'user message with attached image sends a data-URL image part',
      () async {
        const LlmConfig testConfig = LlmConfig(
          id: 'image-config',
          label: 'Image Config',
          baseUrl: 'https://api.test.com',
          apiKey: 'test-key',
          model: 'test-model',
          temperature: 0.7,
        );

        final Directory tmp = await Directory.systemTemp.createTemp('img');
        final File image = File('${tmp.path}/photo.png');
        await image.writeAsBytes(<int>[1, 2, 3, 4]);

        late Request capturedRequest;
        when(() => mockClient.send(any())).thenAnswer((Invocation inv) async {
          capturedRequest = inv.positionalArguments[0] as Request;
          return StreamedResponse(
            Stream<List<int>>.fromIterable(<List<int>>[
              'data: {"choices":[{"delta":{"content":"ok"},"finish_reason":"stop"}]}\n\n'
                  .codeUnits,
              'data: [DONE]\n\n'.codeUnits,
            ]),
            200,
          );
        });

        await llmService
            .promptModelStream(
              messages: <LlmMessage>[
                LlmMessage(
                  role: LlmMessageRole.user,
                  body: 'what is this?',
                  attachedFile: image.path,
                ),
              ],
              systemPrompt: 'You are helpful.',
              config: testConfig,
            )
            .drain<void>();

        final Map<String, dynamic> body =
            jsonDecode(capturedRequest.body) as Map<String, dynamic>;
        final List<dynamic> apiMessages = body['messages'] as List<dynamic>;
        final Map<String, dynamic> userMessage =
            apiMessages.last as Map<String, dynamic>;
        final List<dynamic> content = userMessage['content'] as List<dynamic>;
        expect(content, hasLength(2));
        expect((content[0] as Map<String, dynamic>)['type'], 'text');
        expect((content[1] as Map<String, dynamic>)['type'], 'image_url');
        final Map<String, dynamic> imageUrl =
            (content[1] as Map<String, dynamic>)['image_url']
                as Map<String, dynamic>;
        expect(imageUrl['url'], startsWith('data:image/png;base64,'));
        expect(imageUrl['url'], endsWith(base64Encode(<int>[1, 2, 3, 4])));

        await tmp.delete(recursive: true);
      },
    );
  });
}
