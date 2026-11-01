import '../utils/logger.dart';

/// A scripted tool call, as an LLM would request it.
class FakeToolCall {
  final String name;
  final Map<String, dynamic> arguments;

  const FakeToolCall({
    required this.name,
    this.arguments = const <String, dynamic>{},
  });

  factory FakeToolCall.fromJson(Map<String, dynamic> json) {
    return FakeToolCall(
      name: json['name'] as String,
      arguments:
          (json['arguments'] as Map<String, dynamic>?) ??
          const <String, dynamic>{},
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{'name': name, 'arguments': arguments};
  }

  @override
  String toString() => 'FakeToolCall(name: $name, arguments: $arguments)';
}

/// Fake LLM response for demo mode
///
/// Contains the JSON response that would normally come from an LLM,
/// plus optional audio and amplitude data for synchronized TTS playback.
///
/// A response with non-empty [toolCalls] is a tool round: the fake LLM
/// streams the calls (no text) and the next queued response is the answer.
class FakeLlmResponse {
  final String jsonBody;
  final String? audioPath;
  final List<int>? amplitudes;
  final List<FakeToolCall> toolCalls;

  const FakeLlmResponse({
    required this.jsonBody,
    this.audioPath,
    this.amplitudes,
    this.toolCalls = const <FakeToolCall>[],
  });

  /// Create a FakeLlmResponse from JSON
  factory FakeLlmResponse.fromJson(Map<String, dynamic> json) {
    return FakeLlmResponse(
      jsonBody: json['jsonBody'] as String,
      audioPath: json['audioPath'] as String?,
      amplitudes: json['amplitudes'] as List<int>?,
      toolCalls: (json['toolCalls'] as List<dynamic>? ?? const <dynamic>[])
          .map((dynamic e) => FakeToolCall.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'jsonBody': jsonBody,
      'audioPath': audioPath,
      'amplitudes': amplitudes,
      if (toolCalls.isNotEmpty)
        'toolCalls': toolCalls.map((FakeToolCall c) => c.toJson()).toList(),
    };
  }

  @override
  String toString() {
    return 'FakeLlmResponse(jsonBody: $jsonBody, audioPath: $audioPath, '
        'amplitudes: ${amplitudes?.length ?? 0} values, '
        'toolCalls: ${toolCalls.length})';
  }
}

/// Demo script with pre-scripted AI responses
///
/// Defines a demo scenario where the user can type naturally
/// while AI responses are injected from a pre-defined script.
class DemoScript {
  final String name;
  final String description;
  final String initialBackground;
  final List<FakeLlmResponse> responses;

  const DemoScript({
    required this.name,
    required this.description,
    required this.responses,
    this.initialBackground = 'office',
  });

  /// Create a DemoScript from JSON
  factory DemoScript.fromJson(Map<String, dynamic> json) {
    return DemoScript(
      name: json['name'] as String,
      description: json['description'] as String,
      initialBackground: json['initialBackground'] as String? ?? 'office',
      responses: (json['responses'] as List<dynamic>)
          .map(
            (dynamic e) => FakeLlmResponse.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'name': name,
      'description': description,
      'initialBackground': initialBackground,
      'responses': responses.map((FakeLlmResponse r) => r.toJson()).toList(),
    };
  }

  @override
  String toString() {
    return 'DemoScript(name: $name, description: $description, '
        '${responses.length} responses, initialBackground: $initialBackground)';
  }
}

/// Predefined demo scripts
class DemoScripts {
  /// Beach demo: Office → Beach → Swimsuit
  ///
  /// Demonstrates background change and avatar outfit updates
  static const DemoScript beachDemo = DemoScript(
    name: 'Plage Demo',
    description: 'Office → Plage → Maillot de bain',
    responses: <FakeLlmResponse>[
      FakeLlmResponse(
        jsonBody:
            '{"message": "À Saint-Malo, il fait actuellement 18 degrés avec un ciel dégagé et un grand soleil. C\'est une belle journée pour une promenade sur les remparts !"}',
      ),
      FakeLlmResponse(
        jsonBody:
            '{"message": "Excellente idée ! Allons à la plage. Je vois déjà les vagues qui s\'écrasent sur le sable. C\'est tellement relaxant.", "background": "beach"}',
      ),
      FakeLlmResponse(
        jsonBody:
            '{"message": "Tout à fait ! Un maillot de bain serait beaucoup plus approprié pour profiter du soleil et de la mer.", "top": "swimsuit", "glasses": "sunglasses"}',
      ),
    ],
  );

  /// Get all available demo scripts
  static const List<DemoScript> all = <DemoScript>[beachDemo];

  /// Find a script by name
  static DemoScript? findByName(String name) {
    try {
      return all.firstWhere((DemoScript script) => script.name == name);
    } catch (e) {
      AppLogger.debug(
        'Demo script not found by name: $name ($e)',
        tag: 'DemoScript',
      );
      return null;
    }
  }
}
