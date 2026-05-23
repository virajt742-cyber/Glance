/// Stub for sqflite package on web.
/// This file is only imported when compiling for web (dart.library.html).

Future<String> getDatabasesPath() async => '';

Future<Database> openDatabase(
  String path, {
  int? version,
  Function? onCreate,
  Function? onUpgrade,
  Function? onDowngrade,
  Function? onOpen,
  Function? onConfigure,
  bool readOnly = false,
  bool singleInstance = true,
}) async {
  return Database._();
}

class Database {
  Database._();

  Future<int> insert(String table, Map<String, dynamic> values) async => 0;

  Future<List<Map<String, dynamic>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) async =>
      [];

  Future<int> delete(String table,
          {String? where, List<Object?>? whereArgs}) async =>
      0;

  Future<int> rawUpdate(String sql, [List<Object?>? arguments]) async => 0;

  Future<void> execute(String sql, [List<Object?>? arguments]) async {}

  Future<void> close() async {}
}
