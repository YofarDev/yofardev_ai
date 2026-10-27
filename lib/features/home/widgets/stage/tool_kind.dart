import '../../../../core/design/rive/ui_kit.dart';
import '../../../../core/l10n/generated/app_localizations.dart';

/// Icon family of the Stage tool chip for the agent tool named [toolName]
/// (names from `core/services/agent/*_tool.dart`).
ToolIconKind toolKindFor(String toolName) => switch (toolName) {
  'searchGoogle' || 'getTextContentFromWebsite' => ToolIconKind.search,
  'getCurrentWeather' => ToolIconKind.weather,
  'getMostPopularNewsOfTheDay' => ToolIconKind.news,
  _ => ToolIconKind.generic,
};

/// What the avatar says it is doing while a tool of [kind] runs.
String toolLabel(AppLocalizations l10n, ToolIconKind kind) => switch (kind) {
  ToolIconKind.search => l10n.toolSearching,
  ToolIconKind.weather => l10n.toolWeather,
  ToolIconKind.news => l10n.toolNews,
  ToolIconKind.memory => l10n.toolMemory,
  ToolIconKind.generic => l10n.toolWorking,
};
