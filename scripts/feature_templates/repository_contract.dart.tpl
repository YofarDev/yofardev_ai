import '../../../../core/models/result.dart';
import '../models/{{FEATURE_SNAKE}}.dart';

abstract class {{FEATURE_PASCAL}}Repository {
  Future<Result<{{FEATURE_PASCAL}}>> getData();
}
