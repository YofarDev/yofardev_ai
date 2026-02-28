/// Exception thrown when the response format is not accepted by the LLM API
class ResponseFormatException implements Exception {
  final String message;
  ResponseFormatException(this.message);

  @override
  String toString() => 'ResponseFormatException: $message';
}
