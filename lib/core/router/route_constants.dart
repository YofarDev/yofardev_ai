/// Centralized route path constants for the application.
class RouteConstants {
  RouteConstants._();

  // Home
  static const String home = '/';

  // Chat routes
  static const String chats = '/chats';
  static const String chatDetails = '/chats/:id';

  // Settings routes
  static const String settings = '/settings';
  static const String llmSelection = '/settings/llm';
  static const String llmConfig = '/settings/llm/config';

  // Image routes
  static const String imageFullScreen = '/image/:path';
}
