import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:yofardev_ai/core/l10n/app_localization_delegates.dart';
import 'package:yofardev_ai/core/l10n/generated/app_localizations.dart';

/// Every supported locale must resolve both material_ui's own strings and the
/// app's. The generated `appLocalizationsDelegates` fails this
/// for non-English locales (deprecated flutter_localizations delegates).
void main() {
  for (final Locale locale in AppLocalizations.supportedLocales) {
    testWidgets('material and app strings resolve in $locale', (
      WidgetTester tester,
    ) async {
      late MaterialLocalizations material;
      late AppLocalizations app;
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (BuildContext context) {
              material = MaterialLocalizations.of(context);
              app = AppLocalizations.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(app.localeName, locale.languageCode);
      expect(
        material.cancelButtonLabel,
        locale.languageCode == 'fr' ? 'Annuler' : 'Cancel',
      );
    });
  }
}
