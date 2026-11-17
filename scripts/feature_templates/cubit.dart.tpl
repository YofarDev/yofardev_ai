import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fpdart/fpdart.dart' show Either;

import '../../../../core/bloc/latest_request_wins.dart';
import '../../../../core/models/failure.dart';
import '../../domain/models/{{FEATURE_SNAKE}}.dart';
import {{CUBIT_DEP_IMPORT}};
import '{{FEATURE_SNAKE}}_state.dart';

class {{FEATURE_PASCAL}}Cubit extends Cubit<{{FEATURE_PASCAL}}State>
    with LatestRequestWins<{{FEATURE_PASCAL}}State> {
  final {{CUBIT_DEP_TYPE}} _source;

  {{FEATURE_PASCAL}}Cubit(this._source) : super(const {{FEATURE_PASCAL}}State.initial());

  /// Latest-request-wins read (see [LatestRequestWins]).
  Future<void> loadData() => runLatest<Either<Failure, {{FEATURE_PASCAL}}>>(
    _source.getData,
    onStart: () => emit(const {{FEATURE_PASCAL}}State.loading()),
    onResult: (Either<Failure, {{FEATURE_PASCAL}}> result) => result.fold(
      (Failure failure) => emit({{FEATURE_PASCAL}}State.error(failure: failure)),
      ({{FEATURE_PASCAL}} data) => emit({{FEATURE_PASCAL}}State.loaded(data)),
    ),
  );
}
