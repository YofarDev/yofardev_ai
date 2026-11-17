import '../../../../core/models/result.dart';
import '../models/{{FEATURE_SNAKE}}.dart';
import '../repositories/{{FEATURE_SNAKE}}_repository.dart';


/// PLACEHOLDER domain service.
///
/// A service earns its place by owning actual rules or coordination. Right
/// now this class only forwards to the repository: either grow it into real
/// domain logic, or delete it and let the cubit depend on
/// {{FEATURE_PASCAL}}Repository directly. A forwarding service is NOT
/// mandatory architecture.
class {{FEATURE_PASCAL}}Service {
  final {{FEATURE_PASCAL}}Repository _repository;

  {{FEATURE_PASCAL}}Service(this._repository);

  Future<Result<{{FEATURE_PASCAL}}>> getData() {
    return _repository.getData();
  }
}
