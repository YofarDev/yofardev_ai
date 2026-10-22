      when(() => mockDataSource.getData()).thenAnswer(
        (_) async => const {{FEATURE_PASCAL}}(id: '1', name: 'Test'),
      );
