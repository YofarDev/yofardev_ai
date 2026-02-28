class FakeLlmResponse {
  final String jsonBody;
  final String? audioPath;
  final List<int>? amplitudes;

  const FakeLlmResponse({
    required this.jsonBody,
    this.audioPath,
    this.amplitudes,
  });
}

/// Simple demo script with just the fake LLM responses
/// User types naturally, responses are injected
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
}

// Predefined demo scripts
class DemoScripts {
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
            '{"message": "Excellente idée ! Allons à la plage. Je vois déjà les vagues qui s\'écrasent sur le sable... C\'est tellement relaxant.", "background": "beach"}',
      ),
      FakeLlmResponse(
        jsonBody:
            '{"message": "Tout à fait ! Un maillot de bain serait beaucoup plus approprié pour profiter du soleil et de la mer.", "top": "swimsuit", "glasses": "sunglasses"}',
      ),
    ],
  );
}
