import 'failure.dart';

/// First-party result type. Repositories and services return this instead of
/// throwing or leaking exceptions. Never use fpdart/dartz.
sealed class Result<T> {
  const Result();

  const factory Result.ok(T value) = Ok<T>;
  const factory Result.err(Failure failure) = Err<T>;

  bool get isOk => this is Ok<T>;

  T? get getOrNull => switch (this) {
        Ok<T>(:final T value) => value,
        Err<T>() => null,
      };

  R when<R>({
    required R Function(Failure failure) err,
    required R Function(T value) ok,
  }) => switch (this) {
        Ok<T>(:final T value) => ok(value),
        Err<T>(:final Failure failure) => err(failure),
      };
}

final class Ok<T> extends Result<T> {
  const Ok(this.value);
  final T value;
}

final class Err<T> extends Result<T> {
  const Err(this.failure);
  final Failure failure;
}
