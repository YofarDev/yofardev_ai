/// Public API of the {{FEATURE_SNAKE}} feature: other features import only
/// this file. It exposes domain models and contracts, never data or
/// presentation.
library;

export 'domain/models/{{FEATURE_SNAKE}}.dart';
export 'domain/repositories/{{FEATURE_SNAKE}}_repository.dart';
{{BARREL_SERVICE_EXPORT}}
