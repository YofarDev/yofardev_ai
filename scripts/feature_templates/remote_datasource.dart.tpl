{{DATA_SOURCE_IMPORTS}}

abstract class I{{FEATURE_PASCAL}}RemoteDataSource {
  Future<{{DATA_SOURCE_RETURN_TYPE}}> getData();
}

class {{FEATURE_PASCAL}}RemoteDataSource implements I{{FEATURE_PASCAL}}RemoteDataSource {
  @override
  Future<{{DATA_SOURCE_RETURN_TYPE}}> getData() async {
    {{DATA_SOURCE_RETURN_DOC}}
    // TODO: Implement the real remote call.
    return {{DATA_SOURCE_CONSTRUCTION}};
  }
}
