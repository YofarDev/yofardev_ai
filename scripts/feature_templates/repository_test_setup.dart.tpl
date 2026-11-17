
class Mock{{FEATURE_PASCAL}}RemoteDataSource extends Mock
    implements {{FEATURE_PASCAL}}RemoteDataSource {}

/// Repository tests prove three things: the data source is called, the
/// result is mapped to the domain type, and failures are TRANSLATED to typed
/// [Failure] values instead of escaping as exceptions.
void main() {
  group('{{FEATURE_PASCAL}}RepositoryImpl', () {
    late {{FEATURE_PASCAL}}RepositoryImpl repository;
    late Mock{{FEATURE_PASCAL}}RemoteDataSource mockDataSource;

    setUp(() {
      mockDataSource = Mock{{FEATURE_PASCAL}}RemoteDataSource();
      repository = {{FEATURE_PASCAL}}RepositoryImpl(mockDataSource);
    });

    test('returns the mapped domain data on success', () async {
