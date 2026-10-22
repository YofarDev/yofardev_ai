
      final Either<Failure, {{FEATURE_PASCAL}}> result = await repository.getData();

      verify(() => mockDataSource.getData()).called(1);
      result.fold(
        (_) => fail('Expected Right({{FEATURE_PASCAL}})'),
        ({{FEATURE_PASCAL}} data) {
          expect(data.id, '1');
          expect(data.name, 'Test');
        },
      );
    });

    test('translates an unexpected exception into Failure.unexpected', () async {
      when(() => mockDataSource.getData()).thenThrow(StateError('boom'));

      final Either<Failure, {{FEATURE_PASCAL}}> result = await repository.getData();

      result.fold(
        (Failure failure) => expect(failure, const Failure.unexpected()),
        (_) => fail('Expected Left(Failure.unexpected)'),
      );
    });

    test('translates a timeout into Failure.networkError', () async {
      when(() => mockDataSource.getData())
          .thenThrow(TimeoutException('timed out'));

      final Either<Failure, {{FEATURE_PASCAL}}> result = await repository.getData();

      result.fold(
        (Failure failure) => expect(failure, const Failure.networkError()),
        (_) => fail('Expected Left(Failure.networkError)'),
      );
    });
  });
}
