import 'package:sqflite/sqflite.dart';

import '../models/sync_operation.dart';
import '../services/database_helper.dart';

typedef SyncOutboxDatabaseProvider = Future<Database> Function();

class SyncOutboxRepository {
  SyncOutboxRepository({SyncOutboxDatabaseProvider? databaseProvider})
      : _databaseProvider =
            databaseProvider ?? (() => DatabaseHelper().database);

  static const String tableName = 'sync_outbox';

  final SyncOutboxDatabaseProvider _databaseProvider;

  Future<SyncOperation> enqueue(SyncOperation operation) async {
    final database = await _databaseProvider();
    await _insertOperation(database, operation);
    final existing = await getByIdempotencyKey(operation.idempotencyKey);
    if (existing == null) {
      throw StateError('Could not persist the sync operation.');
    }
    return existing;
  }

  Future<void> mutateAndEnqueue({
    required Future<void> Function(Transaction transaction) localMutation,
    required SyncOperation operation,
  }) async {
    final database = await _databaseProvider();
    await database.transaction((transaction) async {
      final existing = await transaction.query(
        tableName,
        columns: const ['operation_id'],
        where: 'idempotency_key = ?',
        whereArgs: [operation.idempotencyKey],
        limit: 1,
      );
      if (existing.isNotEmpty) return;

      await localMutation(transaction);
      await _insertOperation(transaction, operation);
    });
  }

  Future<void> enqueueInTransaction(
    DatabaseExecutor executor,
    SyncOperation operation,
  ) async {
    final existing = await executor.query(
      tableName,
      columns: const ['operation_id'],
      where: 'idempotency_key = ?',
      whereArgs: [operation.idempotencyKey],
      limit: 1,
    );
    if (existing.isNotEmpty) return;
    await _insertOperation(executor, operation);
  }

  Future<SyncOperation?> getByOperationId(String operationId) async {
    final database = await _databaseProvider();
    final rows = await database.query(
      tableName,
      where: 'operation_id = ?',
      whereArgs: [operationId],
      limit: 1,
    );
    return rows.isEmpty ? null : SyncOperation.fromDatabaseRow(rows.single);
  }

  Future<SyncOperation?> getByIdempotencyKey(String idempotencyKey) async {
    final database = await _databaseProvider();
    final rows = await database.query(
      tableName,
      where: 'idempotency_key = ?',
      whereArgs: [idempotencyKey],
      limit: 1,
    );
    return rows.isEmpty ? null : SyncOperation.fromDatabaseRow(rows.single);
  }

  Future<List<SyncOperation>> getPendingOperations({DateTime? now}) async {
    final database = await _databaseProvider();
    final timestamp = (now ?? DateTime.now()).toUtc().toIso8601String();
    final rows = await database.query(
      tableName,
      where: 'status IN (?, ?) AND '
          '(next_attempt_at IS NULL OR next_attempt_at <= ?)',
      whereArgs: [
        SyncOperationState.pending.name,
        SyncOperationState.failed.name,
        timestamp,
      ],
      orderBy: 'rowid ASC',
    );
    return rows.map(SyncOperation.fromDatabaseRow).toList();
  }

  Future<List<SyncOperation>> getOutstandingOperations() async {
    final database = await _databaseProvider();
    final rows = await database.query(
      tableName,
      where: 'status IN (?, ?, ?)',
      whereArgs: [
        SyncOperationState.pending.name,
        SyncOperationState.inProgress.name,
        SyncOperationState.failed.name,
      ],
      orderBy: 'rowid ASC',
    );
    return rows.map(SyncOperation.fromDatabaseRow).toList();
  }

  Future<int> retryFailedOperations() async {
    final database = await _databaseProvider();
    return database.update(
      tableName,
      {
        'status': SyncOperationState.pending.name,
        'next_attempt_at': null,
        'error_code': null,
      },
      where: 'status = ?',
      whereArgs: [SyncOperationState.failed.name],
    );
  }

  Future<int> markOperationsCompleted(
    Iterable<String> operationIds, {
    DateTime? at,
  }) async {
    final ids = operationIds.toSet();
    if (ids.isEmpty) return 0;

    final database = await _databaseProvider();
    final timestamp = (at ?? DateTime.now()).toUtc().toIso8601String();
    return database.transaction((transaction) async {
      var completedCount = 0;
      for (final operationId in ids) {
        completedCount += await transaction.update(
          tableName,
          {
            'status': SyncOperationState.completed.name,
            'error_code': null,
            'next_attempt_at': null,
            'completed_at': timestamp,
            'updated_at': timestamp,
          },
          where: 'operation_id = ? AND status != ?',
          whereArgs: [
            operationId,
            SyncOperationState.completed.name,
          ],
        );
      }
      return completedCount;
    });
  }

  Future<void> markAttemptStarted(String operationId, {DateTime? at}) async {
    final database = await _databaseProvider();
    final timestamp = (at ?? DateTime.now()).toUtc().toIso8601String();
    final rowsUpdated = await database.rawUpdate(
      '''
      UPDATE $tableName
      SET status = ?,
          attempt_count = attempt_count + 1,
          last_attempt_at = ?,
          next_attempt_at = NULL,
          error_code = NULL,
          updated_at = ?
      WHERE operation_id = ? AND status IN (?, ?)
      ''',
      [
        SyncOperationState.inProgress.name,
        timestamp,
        timestamp,
        operationId,
        SyncOperationState.pending.name,
        SyncOperationState.failed.name,
      ],
    );
    if (rowsUpdated == 0) {
      throw StateError('The sync operation is missing or cannot be started.');
    }
  }

  Future<void> markFailed(
    String operationId, {
    required String errorCode,
    DateTime? nextAttemptAt,
    DateTime? at,
  }) async {
    final database = await _databaseProvider();
    final timestamp = (at ?? DateTime.now()).toUtc();
    final rowsUpdated = await database.update(
      tableName,
      {
        'status': SyncOperationState.failed.name,
        'error_code': SyncOperation.sanitizeErrorCode(errorCode) ?? 'unknown',
        'next_attempt_at': nextAttemptAt?.toUtc().toIso8601String(),
        'updated_at': timestamp.toIso8601String(),
      },
      where: 'operation_id = ? AND status != ?',
      whereArgs: [operationId, SyncOperationState.completed.name],
    );
    if (rowsUpdated == 0) {
      throw StateError('The sync operation is missing or already completed.');
    }
  }

  Future<void> markCompleted(String operationId, {DateTime? at}) async {
    final database = await _databaseProvider();
    final timestamp = (at ?? DateTime.now()).toUtc();
    final rowsUpdated = await database.update(
      tableName,
      {
        'status': SyncOperationState.completed.name,
        'error_code': null,
        'next_attempt_at': null,
        'completed_at': timestamp.toIso8601String(),
        'updated_at': timestamp.toIso8601String(),
      },
      where: 'operation_id = ? AND status != ?',
      whereArgs: [operationId, SyncOperationState.completed.name],
    );
    if (rowsUpdated == 0) {
      throw StateError('The sync operation is missing or already completed.');
    }
  }

  Future<int> recoverInterruptedOperations({DateTime? at}) async {
    final database = await _databaseProvider();
    final timestamp = (at ?? DateTime.now()).toUtc().toIso8601String();
    return database.update(
      tableName,
      {
        'status': SyncOperationState.pending.name,
        'updated_at': timestamp,
      },
      where: 'status = ?',
      whereArgs: [SyncOperationState.inProgress.name],
    );
  }

  Future<void> _insertOperation(
    DatabaseExecutor executor,
    SyncOperation operation,
  ) async {
    await executor.insert(
      tableName,
      operation.toDatabaseRow(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }
}
