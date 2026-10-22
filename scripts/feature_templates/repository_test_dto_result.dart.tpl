      when(() => mockDataSource.getData()).thenAnswer(
        (_) async => const {{FEATURE_PASCAL}}Dto(id: '1', name: 'Test'),
      );
