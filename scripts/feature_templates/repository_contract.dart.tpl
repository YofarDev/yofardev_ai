import 'package:fpdart/fpdart.dart' show Either;

import '../../../../core/models/failure.dart';
import '../models/{{FEATURE_SNAKE}}.dart';

abstract class I{{FEATURE_PASCAL}}Repository {
  Future<Either<Failure, {{FEATURE_PASCAL}}>> getData();
}
