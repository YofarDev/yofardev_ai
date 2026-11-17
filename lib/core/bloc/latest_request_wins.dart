import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Latest-request-wins for read operations in a Cubit or Bloc.
///
/// Every [runLatest] call supersedes the ones before it. After the await,
/// `onResult` runs only if the cubit is still open and no newer request has
/// started, so:
/// - a slow older response (success or failure) never overwrites a newer one;
/// - nothing is emitted after `close()` (which would throw a `StateError`).
///
/// Ignoring a stale result does not cancel the underlying work; add
/// transport-level cancellation only if a data source needs it.
///
/// The mechanism is tested once in
/// `test/core/bloc/latest_request_wins_test.dart`. Feature cubit tests cover
/// their own state transitions, not this plumbing.
mixin LatestRequestWins<S> on BlocBase<S> {
  int _latestRequestId = 0;

  /// Runs [request]; `onStart` runs first (e.g. emit a loading state) and
  /// `onResult` receives the result only if this is still the newest request
  /// and the cubit is open.
  @protected
  Future<void> runLatest<T>(
    Future<T> Function() request, {
    required void Function(T result) onResult,
    void Function()? onStart,
  }) async {
    if (isClosed) {
      return;
    }
    final int requestId = ++_latestRequestId;
    onStart?.call();
    final T result = await request();
    if (isClosed || requestId != _latestRequestId) {
      return;
    }
    onResult(result);
  }
}
