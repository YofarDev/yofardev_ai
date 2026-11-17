import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/bloc/latest_request_wins.dart';
import '../../../../core/models/failure.dart';
import '../../../../core/models/result.dart';
import '../../domain/models/{{FEATURE_SNAKE}}.dart';
import {{CUBIT_DEP_IMPORT}};
import '{{FEATURE_SNAKE}}_state.dart';

class {{FEATURE_PASCAL}}Cubit extends Cubit<{{FEATURE_PASCAL}}State>
    with LatestRequestWins<{{FEATURE_PASCAL}}State> {
  final {{CUBIT_DEP_TYPE}} _source;

  {{FEATURE_PASCAL}}Cubit(this._source) : super(const {{FEATURE_PASCAL}}State.initial());

  /// Latest-request-wins read (see [LatestRequestWins]).
  Future<void> loadData() => runLatest<Result<{{FEATURE_PASCAL}}>>(
    _source.getData,
    onStart: () => emit(const {{FEATURE_PASCAL}}State.loading()),
    onResult: (Result<{{FEATURE_PASCAL}}> result) => result.when(
      ok: ({{FEATURE_PASCAL}} data) => emit({{FEATURE_PASCAL}}State.loaded(data)),
      err: (Failure failure) => emit({{FEATURE_PASCAL}}State.error(failure: failure)),
    ),
  );
}
