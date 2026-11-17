
class {{FEATURE_PASCAL}}RepositoryImpl implements {{FEATURE_PASCAL}}Repository {
  final {{FEATURE_PASCAL}}RemoteDataSource _dataSource;

  {{FEATURE_PASCAL}}RepositoryImpl(this._dataSource);

  @override
  Future<Result<{{FEATURE_PASCAL}}>> getData() async {
    try {
{{REPO_BODY_LINES}}
      return Result<{{FEATURE_PASCAL}}>.ok(data);
    } catch (e, st) {
      // Logs the error and stack trace once, at the mapping boundary.
      return Result<{{FEATURE_PASCAL}}>.err(
        mapExceptionToFailure(e, stackTrace: st, tag: '{{FEATURE_PASCAL}}RepositoryImpl'),
      );
    }
  }
}
