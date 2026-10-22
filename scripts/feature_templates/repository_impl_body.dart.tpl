
class {{FEATURE_PASCAL}}Repository implements I{{FEATURE_PASCAL}}Repository {
  final I{{FEATURE_PASCAL}}RemoteDataSource _dataSource;

  {{FEATURE_PASCAL}}Repository(this._dataSource);

  @override
  Future<Either<Failure, {{FEATURE_PASCAL}}>> getData() async {
    try {
{{REPO_BODY_LINES}}
      return Right<Failure, {{FEATURE_PASCAL}}>(data);
    } catch (e, st) {
      // Logs the error and stack trace once, at the mapping boundary.
      return Left<Failure, {{FEATURE_PASCAL}}>(
        mapExceptionToFailure(e, stackTrace: st, tag: '{{FEATURE_PASCAL}}Repository'),
      );
    }
  }
}
