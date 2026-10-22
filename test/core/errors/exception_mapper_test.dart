import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/errors/exception_mapper.dart';
import 'package:yofardev_ai/core/models/failure.dart';

void main() {
  test('TimeoutException maps to NetworkFailure', () {
    expect(
      mapExceptionToFailure(TimeoutException('t', const Duration(seconds: 1))),
      isA<NetworkFailure>(),
    );
  });

  test('SocketException maps to NetworkFailure', () {
    expect(
      mapExceptionToFailure(const SocketException('down')),
      isA<NetworkFailure>(),
    );
  });

  test('FileSystemException and FormatException map to StorageFailure', () {
    expect(
      mapExceptionToFailure(const FileSystemException('disk')),
      isA<StorageFailure>(),
    );
    expect(
      mapExceptionToFailure(const FormatException('bad')),
      isA<StorageFailure>(),
    );
  });

  test('anything else maps to UnknownFailure and keeps the cause', () {
    final Object error = StateError('boom');
    final Failure failure = mapExceptionToFailure(error, tag: 'Test');
    expect(failure, isA<UnknownFailure>());
    expect(failure.cause, same(error));
  });
}
