import '../models/failure.dart';
import 'generated/app_localizations.dart';

/// Localized, user-facing text for a [Failure]. Exhaustive by construction —
/// adding a Failure variant is a compile error here.
/// Diagnostic [Failure.message] is for logs only; never display it.
String localizeFailure(AppLocalizations l10n, Failure failure) =>
    switch (failure) {
      StorageFailure() => l10n.failureStorage,
      NetworkFailure() => l10n.failureNetwork,
      TtsFailure() => l10n.failureTts,
      ConfigFailure() => l10n.failureConfig,
      UnknownFailure() => l10n.failureUnknown,
    };
