import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/design/rive/ui_kit.dart';
import 'package:yofardev_ai/core/l10n/generated/app_localizations.dart';
import 'package:yofardev_ai/features/home/widgets/stage/tool_kind.dart';

void main() {
  group('toolKindFor', () {
    const Map<String, ToolIconKind> table = <String, ToolIconKind>{
      'searchGoogle': ToolIconKind.search,
      'getTextContentFromWebsite': ToolIconKind.search,
      'getCurrentWeather': ToolIconKind.weather,
      'getMostPopularNewsOfTheDay': ToolIconKind.news,
      'calculateExpression': ToolIconKind.generic,
      'setAlarm': ToolIconKind.generic,
      '': ToolIconKind.generic,
    };

    for (final MapEntry<String, ToolIconKind> row in table.entries) {
      test('"${row.key}" -> ${row.value.name}', () {
        expect(toolKindFor(row.key), row.value);
      });
    }
  });

  group('toolLabel', () {
    test('every kind has its own English label', () {
      final AppLocalizations l10n = lookupAppLocalizations(const Locale('en'));
      expect(toolLabel(l10n, ToolIconKind.search), 'Searching the web…');
      expect(toolLabel(l10n, ToolIconKind.weather), 'Checking the weather…');
      expect(toolLabel(l10n, ToolIconKind.news), 'Reading the news…');
      expect(toolLabel(l10n, ToolIconKind.memory), 'Searching my memory…');
      expect(toolLabel(l10n, ToolIconKind.generic), 'Working on it…');
    });

    test('French labels', () {
      final AppLocalizations l10n = lookupAppLocalizations(const Locale('fr'));
      expect(toolLabel(l10n, ToolIconKind.search), 'Recherche sur le web…');
      expect(toolLabel(l10n, ToolIconKind.generic), "Je m'en occupe…");
    });
  });
}
