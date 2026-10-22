
class Mock{{FEATURE_PASCAL}}RemoteDataSource extends Mock
    implements I{{FEATURE_PASCAL}}RemoteDataSource {}

/// Repository tests prove three things: the data source is called, the
/// result is mapped to the domain type, and failures are TRANSLATED to typed
/// [Failure] values instead of escaping as exceptions.
void main() {
  group('{{FEATURE_PASCAL}}Repository', () {
    late {{FEATURE_PASCAL}}Repository repository;
    late Mock{{FEATURE_PASCAL}}RemoteDataSource mockDataSource;

    setUp(() {
      mockDataSource = Mock{{FEATURE_PASCAL}}RemoteDataSource();
      repository = {{FEATURE_PASCAL}}Repository(mockDataSource);
    });

    test('returns the mapped domain data on success', () async {
