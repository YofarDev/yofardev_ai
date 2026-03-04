/// Represents different task types that can use different LLM configurations
enum LlmTaskType {
  /// Main chat assistant responses
  assistant,

  /// Chat title generation
  titleGeneration,

  /// Function/tool calling detection
  functionCalling,
}
