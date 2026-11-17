
      final Result<{{FEATURE_PASCAL}}> result = await repository.getData();

      verify(() => mockDataSource.getData()).called(1);
      result.when(
        err: (Failure failure) => fail('Expected Result.ok, got $failure'),
        ok: ({{FEATURE_PASCAL}} data) {
          expect(data.id, '1');
          expect(data.name, 'Test');
        },
      );
    });

    test('translates an unexpected exception into UnknownFailure', () async {
      when(() => mockDataSource.getData()).thenThrow(StateError('boom'));

      final Result<{{FEATURE_PASCAL}}> result = await repository.getData();

      result.when(
        ok: ({{FEATURE_PASCAL}} _) => fail('Expected an UnknownFailure'),
        err: (Failure failure) => expect(failure, isA<UnknownFailure>()),
      );
    });

    test('translates a timeout into NetworkFailure', () async {
      when(() => mockDataSource.getData())
          .thenThrow(TimeoutException('timed out'));

      final Result<{{FEATURE_PASCAL}}> result = await repository.getData();

      result.when(
        ok: ({{FEATURE_PASCAL}} _) => fail('Expected a NetworkFailure'),
        err: (Failure failure) => expect(failure, isA<NetworkFailure>()),
      );
    });
  });
}
