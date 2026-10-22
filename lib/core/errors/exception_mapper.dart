import 'dart:async';
import 'dart:io';

import '../models/failure.dart';
import '../utils/logger.dart';

/// Classifies an exception this boundary does not specifically know into a
/// typed [Failure], and logs it exactly once at the repository boundary.
///
/// Repositories classify their OWN known exception taxonomy first (specific
/// `on` clauses); everything else falls through to this mapper.
Failure mapExceptionToFailure(
  Object error, {
  StackTrace? stackTrace,
  String tag = 'Repository',
}) {
  AppLogger.error(
    '$tag: unclassified exception',
    tag: tag,
    error: error,
    stackTrace: stackTrace,
  );
  if (error is TimeoutException) {
    return NetworkFailure(error.toString(), error);
  }
  if (error is SocketException || error is HttpException) {
    return NetworkFailure(error.toString(), error);
  }
  if (error is FileSystemException || error is FormatException) {
    return StorageFailure(error.toString(), error);
  }
  return UnknownFailure(error.toString(), error);
}
