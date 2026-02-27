/// Fake LLM response for demo mode
///
/// Contains the JSON response that would normally come from an LLM,
/// plus optional audio and amplitude data for synchronized TTS playback
class FakeLlmResponse {
  final String jsonBody;
  final String? audioPath;
  final List<int>? amplitudes;

  const FakeLlmResponse({
    required this.jsonBody,
    this.audioPath,
    this.amplitudes,
  });

  /// Create a FakeLlmResponse from JSON
  factory FakeLlmResponse.fromJson(Map<String, dynamic> json) {
    return FakeLlmResponse(
      jsonBody: json['jsonBody'] as String,
      audioPath: json['audioPath'] as String?,
      amplitudes: json['amplitudes'] as List<int>?,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'jsonBody': jsonBody,
      'audioPath': audioPath,
      'amplitudes': amplitudes,
    };
  }

  @override
  String toString() {
    return 'FakeLlmResponse(jsonBody: $jsonBody, audioPath: $audioPath, '
        'amplitudes: ${amplitudes?.length ?? 0} values)';
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
          .map((dynamic e) => FakeLlmResponse.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
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
    initialBackground: 'office',
    responses: <FakeLlmResponse>[
      FakeLlmResponse(
        jsonBody:
            '{"message": "À Saint-Malo, il fait actuellement 18 degrés avec un ciel dégagé et un grand soleil. C\'est une belle journée pour une promenade sur les remparts !"}',
      ),
      FakeLlmResponse(
        jsonBody:
            '{"message": "Excellente idée ! Allons à la plage. Je vois déjà les vagues qui s\'écrasent sur le sable... C\'est tellement relaxant.", "background": "beach"}',
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
    } catch (_) {
      return null;
    }
  }
}
