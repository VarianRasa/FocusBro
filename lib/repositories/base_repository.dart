import 'package:sqflite/sqflite.dart';
import '../services/database_helper.dart';
import '../models/base_model.dart';

abstract class BaseRepository<T extends BaseModel> {
  final DatabaseHelper _databaseHelper = DatabaseHelper();

  /// Get the table name for this repository
  String get tableName;

  /// Get the primary key field name
  String get primaryKey => 'id';

  /// Convert a map from database to model
  T fromMap(Map<String, dynamic> map);

  /// Get database instance
  Future<Database> get _database async => await _databaseHelper.database;

  /// Insert a new record
  Future<int> insert(T model) async {
    final db = await _database;
    return await db.insert(tableName, model.toMap());
  }

  /// Insert multiple records in a transaction
  Future<List<int>> insertBatch(List<T> models) async {
    final db = await _database;
    final batch = db.batch();

    for (final model in models) {
      batch.insert(tableName, model.toMap());
    }

    final results = await batch.commit();
    return results.cast<int>();
  }

  /// Update a record
  Future<int> update(T model) async {
    final db = await _database;
    return await db.update(
      tableName,
      model.toMap(),
      where: '${model.primaryKey} = ?',
      whereArgs: [_getPrimaryKeyValue(model)],
    );
  }

  /// Delete a record by primary key
  Future<int> delete(dynamic primaryKeyValue) async {
    final db = await _database;
    return await db.delete(
      tableName,
      where: '${_getPrimaryKeyName()} = ?',
      whereArgs: [primaryKeyValue],
    );
  }

  /// Delete multiple records by primary keys
  Future<int> deleteBatch(List<dynamic> primaryKeyValues) async {
    final db = await _database;
    final placeholders = primaryKeyValues.map((_) => '?').join(',');
    return await db.delete(
      tableName,
      where: '${_getPrimaryKeyName()} IN ($placeholders)',
      whereArgs: primaryKeyValues,
    );
  }

  /// Find a record by primary key
  Future<T?> findById(dynamic primaryKeyValue) async {
    final db = await _database;
    final maps = await db.query(
      tableName,
      where: '${_getPrimaryKeyName()} = ?',
      whereArgs: [primaryKeyValue],
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return fromMap(maps.first);
    }
    return null;
  }

  /// Find all records
  Future<List<T>> findAll({
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    final db = await _database;
    final maps = await db.query(
      tableName,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );

    return maps.map((map) => fromMap(map)).toList();
  }

  /// Find records with custom where clause
  Future<List<T>> findWhere(
    String where,
    List<dynamic> whereArgs, {
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    final db = await _database;
    final maps = await db.query(
      tableName,
      where: where,
      whereArgs: whereArgs,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );

    return maps.map((map) => fromMap(map)).toList();
  }

  /// Count all records
  Future<int> count() async {
    final db = await _database;
    final result =
        await db.rawQuery('SELECT COUNT(*) as count FROM $tableName');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Count records with custom where clause
  Future<int> countWhere(String where, List<dynamic> whereArgs) async {
    final db = await _database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $tableName WHERE $where',
      whereArgs,
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Check if a record exists by primary key
  Future<bool> exists(dynamic primaryKeyValue) async {
    final count = await countWhere(
      '${_getPrimaryKeyName()} = ?',
      [primaryKeyValue],
    );
    return count > 0;
  }

  /// Execute a raw query
  Future<List<Map<String, dynamic>>> rawQuery(
    String sql, [
    List<dynamic>? arguments,
  ]) async {
    final db = await _database;
    return await db.rawQuery(sql, arguments);
  }

  /// Execute a raw insert/update/delete
  Future<int> rawExecute(
    String sql, [
    List<dynamic>? arguments,
  ]) async {
    final db = await _database;
    return await db.rawInsert(sql, arguments);
  }

  /// Get the primary key name (override if different from 'id')
  String _getPrimaryKeyName() => primaryKey;

  /// Get the primary key value from a model
  dynamic _getPrimaryKeyValue(T model) {
    final map = model.toMap();
    return map[model.primaryKey];
  }

  /// Execute operations in a transaction
  Future<R> transaction<R>(Future<R> Function(Transaction txn) action) async {
    final db = await _database;
    return await db.transaction(action);
  }
}
