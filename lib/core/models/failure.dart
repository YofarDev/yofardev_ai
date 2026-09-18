/// Typed failure. UI shows [message]; [cause] carries the original error for logs.
abstract class Failure {
  const Failure(this.message, [this.cause]);

  final String message;
  final Object? cause;

  static Failure fromException(Object error, {StackTrace? stackTrace}) {
    // Log the details; callers may also route specific exceptions to
    // narrower variants before falling back here.
    return UnknownFailure(error.toString(), error);
  }

  @override
  String toString() => '$runtimeType($message)';
}

final class StorageFailure extends Failure {
  const StorageFailure(super.message, [super.cause]);
}

final class NetworkFailure extends Failure {
  const NetworkFailure(super.message, [super.cause]);
}

final class TtsFailure extends Failure {
  const TtsFailure(super.message, [super.cause]);
}

final class ConfigFailure extends Failure {
  const ConfigFailure(super.message, [super.cause]);
}

final class UnknownFailure extends Failure {
  const UnknownFailure(super.message, [super.cause]);
}
