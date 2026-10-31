import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:focusbro/models/sync_operation.dart';
import 'package:focusbro/repositories/sync_outbox_repository.dart';
import 'package:focusbro/services/database_helper.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory temporaryDirectory;
  late String databasePath;
  late Database database;
  late SyncOutboxRepository repository;

  setUp(() async {
    temporaryDirectory =
        await Directory.systemTemp.createTemp('focusbro-outbox-test-');
    databasePath = p.join(temporaryDirectory.path, 'focusbro-outbox.db');

    final legacyDatabase = await openDatabase(
      databasePath,
      version: 5,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE preserved_records (
            record_id TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');
        await db.insert('preserved_records', {
          'record_id': 'existing-record',
          'value': 'keep',
        });
      },
    );
    await legacyDatabase.close();

    database = await openDatabase(
      databasePath,
      version: 6,
      onUpgrade: DatabaseHelper.upgradeForTesting,
    );
    repository = SyncOutboxRepository(
      databaseProvider: () async => database,
    );
  });

  tearDown(() async {
    await database.close();
    await temporaryDirectory.delete(recursive: true);
  });

  test('migration adds the outbox without changing existing records', () async {
    final existingRecords = await database.query('preserved_records');
    final outboxColumns =
        await database.rawQuery('PRAGMA table_info(sync_outbox)');
    final columnNames =
        outboxColumns.map((column) => column['name'] as String).toSet();

    expect(existingRecords.single['value'], 'keep');
    expect(
      columnNames,
      containsAll([
        'operation_id',
        'idempotency_key',
        'entity_type',
        'entity_id',
        'operation_kind',
        'schema_version',
        'payload_json',
        'status',
        'attempt_count',
        'error_code',
        'next_attempt_at',
        'account_uid',
        'deleted_at',
      ]),
    );
  });

  test('deduplicates by idempotency key and persists tombstones after reopen',
      () async {
    final tombstone = SyncOperation.create(
      operationId: 'delete-op-1',
      idempotencyKey: 'delete-key-1',
      entityType: 'tasks',
      entityId: 'task-1',
      kind: SyncOperationKind.delete,
      schemaVersion: 1,
      createdAt: DateTime.utc(2026, 1, 1),
    );

    final queued = await repository.enqueue(tombstone);
    final duplicate = await repository.enqueue(
      SyncOperation.create(
        operationId: 'delete-op-2',
        idempotencyKey: tombstone.idempotencyKey,
        entityType: 'tasks',
        entityId: 'another-task',
        kind: SyncOperationKind.delete,
        schemaVersion: 1,
      ),
    );

    expect(queued.isTombstone, isTrue);
    expect(duplicate.operationId, tombstone.operationId);
    expect(duplicate.entityId, tombstone.entityId);

    await database.close();
    database = await openDatabase(databasePath, version: 6);
    repository = SyncOutboxRepository(
      databaseProvider: () async => database,
    );

    final restored = await repository.getByOperationId(tombstone.operationId);
    expect(restored, isNotNull);
    expect(restored!.isTombstone, isTrue);
    expect(restored.deletedAt, DateTime.utc(2026, 1, 1));
    expect(await repository.getPendingOperations(), hasLength(1));
    final accountBinding = await database.query(
      SyncOutboxRepository.tableName,
      columns: const ['account_uid'],
    );
    expect(accountBinding.single['account_uid'], isNull);
  });

  test('commits local mutations and outbox rows in the same transaction',
      () async {
    final operation = _upsertOperation(
      operationId: 'atomic-op',
      idempotencyKey: 'atomic-key',
      entityId: 'local-1',
    );

    await repository.mutateAndEnqueue(
      operation: operation,
      localMutation: (transaction) async {
        await transaction.insert('preserved_records', {
          'record_id': 'local-1',
          'value': 'created',
        });
      },
    );

    await repository.mutateAndEnqueue(
      operation: operation,
      localMutation: (transaction) async {
        throw StateError('An idempotent retry must not rerun the mutation.');
      },
    );

    expect(
      await database.query(
        'preserved_records',
        where: 'record_id = ?',
        whereArgs: ['local-1'],
      ),
      hasLength(1),
    );
    expect(await repository.getPendingOperations(), hasLength(1));

    final rollbackOperation = _upsertOperation(
      operationId: 'rollback-op',
      idempotencyKey: 'rollback-key',
      entityId: 'rollback-1',
    );
    await expectLater(
      repository.mutateAndEnqueue(
        operation: rollbackOperation,
        localMutation: (transaction) async {
          await transaction.insert('preserved_records', {
            'record_id': 'rollback-1',
            'value': 'must roll back',
          });
          throw StateError('abort transaction');
        },
      ),
      throwsA(isA<StateError>()),
    );

    expect(
      await database.query(
        'preserved_records',
        where: 'record_id = ?',
        whereArgs: ['rollback-1'],
      ),
      isEmpty,
    );
    expect(
      await repository.getByIdempotencyKey('rollback-key'),
      isNull,
    );
  });

  test('retains retry metadata and sanitizes error codes', () async {
    final operation = _upsertOperation(
      operationId: 'retry-op',
      idempotencyKey: 'retry-key',
      entityId: 'retry-1',
    );
    await repository.enqueue(operation);
    await repository.markAttemptStarted(
      operation.operationId,
      at: DateTime.utc(2026, 2, 1),
    );
    await repository.markFailed(
      operation.operationId,
      errorCode: 'Network.Request-Failed',
      nextAttemptAt: DateTime.utc(2026, 2, 1, 0, 5),
      at: DateTime.utc(2026, 2, 1, 0, 1),
    );

    expect(
      await repository.getPendingOperations(
          now: DateTime.utc(2026, 2, 1, 0, 4)),
      isEmpty,
    );
    final retryable = await repository.getPendingOperations(
      now: DateTime.utc(2026, 2, 1, 0, 5),
    );
    expect(retryable.single.attemptCount, 1);
    expect(retryable.single.errorCode, 'network.request-failed');

    await repository.markAttemptStarted(
      operation.operationId,
      at: DateTime.utc(2026, 2, 1, 0, 5),
    );
    await repository.markFailed(
      operation.operationId,
      errorCode: 'raw message with spaces',
      at: DateTime.utc(2026, 2, 1, 0, 6),
    );
    expect(
      (await repository.getByOperationId(operation.operationId))?.errorCode,
      'unknown',
    );

    await repository.markAttemptStarted(
      operation.operationId,
      at: DateTime.utc(2026, 2, 1, 0, 7),
    );
    expect(await repository.recoverInterruptedOperations(), 1);
    expect(await repository.getPendingOperations(), hasLength(1));
  });

  test('freezes payloads and rejects blank operation identifiers', () async {
    final nested = {'value': 'before'};
    final tags = ['initial'];
    final operation = SyncOperation.create(
      entityType: 'records',
      entityId: 'immutable-1',
      kind: SyncOperationKind.upsert,
      schemaVersion: 1,
      payload: {
        'nested': nested,
        'tags': tags,
      },
    );

    nested['value'] = 'after';
    tags.add('later');
    expect(
      (operation.payload!['nested'] as Map<String, dynamic>)['value'],
      'before',
    );
    expect(operation.payload!['tags'], ['initial']);
    expect(
      () => (operation.payload!['nested'] as Map<String, dynamic>)['value'] =
          'mutated',
      throwsUnsupportedError,
    );
    await repository.enqueue(operation);
    final restored = await repository.getByOperationId(operation.operationId);
    expect(
      () => (restored!.payload!['nested'] as Map<String, dynamic>)['value'] =
          'mutated',
      throwsUnsupportedError,
    );

    expect(
      () => SyncOperation.create(
        operationId: ' ',
        entityType: 'records',
        entityId: 'immutable-2',
        kind: SyncOperationKind.delete,
        schemaVersion: 1,
      ),
      throwsArgumentError,
    );
  });

  test('completed operations are retained but no longer pending', () async {
    final operation = _upsertOperation(
      operationId: 'complete-op',
      idempotencyKey: 'complete-key',
      entityId: 'complete-1',
    );
    await repository.enqueue(operation);
    await repository.markAttemptStarted(operation.operationId);
    await repository.markCompleted(operation.operationId);

    expect(await repository.getPendingOperations(), isEmpty);
    expect(
      (await repository.getByOperationId(operation.operationId))?.state,
      SyncOperationState.completed,
    );
  });

  test('acknowledges captured operation IDs without comparing UUID order',
      () async {
    final earlier = _upsertOperation(
      operationId: 'z-earlier-op',
      idempotencyKey: 'z-earlier-key',
      entityId: 'task-1',
      createdAt: DateTime.utc(2026, 1, 1),
    );
    final processed = _upsertOperation(
      operationId: 'm-processed-op',
      idempotencyKey: 'm-processed-key',
      entityId: 'task-1',
      createdAt: DateTime.utc(2026, 1, 1),
    );
    final concurrent = _upsertOperation(
      operationId: 'a-concurrent-op',
      idempotencyKey: 'a-concurrent-key',
      entityId: 'task-1',
      createdAt: DateTime.utc(2026, 1, 1),
    );
    await repository.enqueue(earlier);
    await repository.enqueue(processed);
    final captured = await repository.getOutstandingOperations();
    await repository.enqueue(concurrent);

    final completed = await repository.markOperationsCompleted(
      captured.map((operation) => operation.operationId),
      at: DateTime.utc(2026, 1, 4),
    );

    expect(completed, 2);
    expect(
      (await repository.getByOperationId('z-earlier-op'))?.state,
      SyncOperationState.completed,
    );
    expect(
      (await repository.getByOperationId('m-processed-op'))?.state,
      SyncOperationState.completed,
    );
    expect(
      (await repository.getByOperationId('a-concurrent-op'))?.state,
      SyncOperationState.pending,
    );
  });
}

SyncOperation _upsertOperation({
  required String operationId,
  required String idempotencyKey,
  required String entityId,
  DateTime? createdAt,
}) {
  return SyncOperation.create(
    operationId: operationId,
    idempotencyKey: idempotencyKey,
    entityType: 'records',
    entityId: entityId,
    kind: SyncOperationKind.upsert,
    schemaVersion: 1,
    payload: {'id': entityId, 'title': 'Structured record'},
    createdAt: createdAt,
  );
}
