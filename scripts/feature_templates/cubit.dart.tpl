import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/models/failure.dart';
import '../../domain/models/{{FEATURE_SNAKE}}.dart';
import {{CUBIT_DEP_IMPORT}};
import '{{FEATURE_SNAKE}}_state.dart';

class {{FEATURE_PASCAL}}Cubit extends Cubit<{{FEATURE_PASCAL}}State> {
  final {{CUBIT_DEP_TYPE}} _source;

  /// Monotonically increasing identifier for read requests (latest-request-wins):
  /// each accepted request captures its identifier before awaiting, and after
  /// the await only the newest request may emit.
  int _requestId = 0;

  {{FEATURE_PASCAL}}Cubit(this._source) : super(const {{FEATURE_PASCAL}}State.initial());

  Future<void> loadData() async {
    // A request invoked after close must not emit (emit on a closed cubit
    // throws a StateError).
    if (isClosed) {
      return;
    }

    final int requestId = ++_requestId;
    emit(const {{FEATURE_PASCAL}}State.loading());

    // Note: ignoring a stale result does not cancel its underlying network
    // request. Add transport-level cancellation only if a data source needs it.
    final Either<Failure, {{FEATURE_PASCAL}}> result = await _source.getData();

    // Check before processing EITHER a success or a failure: after close,
    // emitting throws; and a stale (superseded) result must never overwrite a
    // newer request's state.
    if (isClosed || requestId != _requestId) {
      return;
    }

    result.fold(
      (Failure failure) => emit({{FEATURE_PASCAL}}State.error(failure: failure)),
      ({{FEATURE_PASCAL}} data) => emit({{FEATURE_PASCAL}}State.loaded(data)),
    );
  }
}
