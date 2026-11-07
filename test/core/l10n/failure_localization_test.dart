
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/l10n/failure_localization.dart';
import 'package:yofardev_ai/core/l10n/generated/app_localizations.dart';
import 'package:yofardev_ai/core/models/failure.dart';

void main() {
  // Exact strings from lib/core/l10n/app_localizations_en.arb (lines 347-351)
  // and app_localizations_fr.arb (lines 125-129).
  const List<(Failure, String, String)> cases = <(Failure, String, String)>[
    (StorageFailure('disk'), 'Failed to save or load data',
      'Échec de l\'enregistrement ou de la lecture des données'),
    (NetworkFailure('offline'), 'Network error', 'Erreur réseau'),
    (TtsFailure('engine'), 'Text-to-speech error',
      'Erreur de synthèse vocale'),
    (ConfigFailure('key'), 'Configuration error', 'Erreur de configuration'),
    (UnknownFailure('??'), 'An unexpected error occurred',
      'Une erreur inattendue est survenue'),
  ];

  test('every Failure variant maps to its own localized string, both locales',
      () {
    final AppLocalizations en = lookupAppLocalizations(const Locale('en'));
    final AppLocalizations fr = lookupAppLocalizations(const Locale('fr'));
    for (final (Failure failure, String enText, String frText) in cases) {
      expect(localizeFailure(en, failure), enText, reason: '$failure en');
      expect(localizeFailure(fr, failure), frText, reason: '$failure fr');
    }
  });

  test('each variant maps to a distinct string (no mis-routed variant)', () {
    final AppLocalizations en = lookupAppLocalizations(const Locale('en'));
    final Set<String> seen = <String>{};
    for (final (Failure failure, _, _) in cases) {
      final String text = localizeFailure(en, failure);
      expect(seen.contains(text), isFalse,
          reason: '$failure reused another variant\'s string');
      seen.add(text);
    }
  });

  test('the diagnostic message never leaks into the localized text', () {
    final AppLocalizations en = lookupAppLocalizations(const Locale('en'));
    expect(localizeFailure(en, StorageFailure('SECRET-diagnostic')),
        isNot(contains('SECRET-diagnostic')));
  });
}
