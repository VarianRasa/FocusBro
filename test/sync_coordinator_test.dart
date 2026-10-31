import 'dart:io';
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:focusbro/models/sync_operation.dart';
import 'package:focusbro/repositories/firebase_auth_repository.dart';
import 'package:focusbro/repositories/firebase_sync_repository.dart';
import 'package:focusbro/repositories/sync_metadata_repository.dart';
import 'package:focusbro/repositories/sync_outbox_repository.dart';
import 'package:focusbro/services/database_helper.dart';
import 'package:focusbro/services/sync_coordinator.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory temporaryDirectory;
  late Database database;
  late SyncOutboxRepository outboxRepository;
  late SyncStateRepository stateRepository;
  late SyncConflictRepository conflictRepository;
  late _FakeAuthRepository authRepository;
  late _FakeFirebaseSyncGateway gateway;
  late _MemoryTaskStore taskStore;
  late SyncCoordinator coordinator;

  final now = DateTime.utc(2026, 1, 1, 12);

  setUp(() async {
    temporaryDirectory =
        await Directory.systemTemp.createTemp('focusbro-sync-coordinator-');
    final databasePath = p.join(temporaryDirectory.path, 'sync.db');
    final legacyDatabase = await openDatabase(
      databasePath,
      version: 6,
      onCreate: (db, _) => DatabaseHelper.upgradeForTesting(db, 5, 6),
    );
    await legacyDatabase.close();

    database = await openDatabase(
      databasePath,
      version: 8,
      onUpgrade: DatabaseHelper.upgradeForTesting,
    );
    outboxRepository = SyncOutboxRepository(
      databaseProvider: () async => database,
    );
    stateRepository = SyncStateRepository(
      databaseProvider: () async => database,
    );
    conflictRepository = SyncConflictRepository(
      databaseProvider: () async => database,
    );
    authRepository = _FakeAuthRepository();
    gateway = _FakeFirebaseSyncGateway();
    taskStore = _MemoryTaskStore();
    coordinator = SyncCoordinator(
      authRepository: authRepository,
      outboxRepository: outboxRepository,
      firestoreRepository: FirebaseSyncRepository(
        authRepository: authRepository,
        gateway: gateway,
      ),
      stateRepository: stateRepository,
      conflictRepository: conflictRepository,
      entityStores: [taskStore],
      clock: () => now,
    );
    await coordinator.initialize();
  });

  tearDown(() async {
    coordinator.dispose();
    await database.close();
    await temporaryDirectory.delete(recursive: true);
  });

  test('schema migration adds coordinator tables and preserves the outbox',
      () async {
    final tables = await database.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    );
    final tableNames = tables.map((row) => row['name']).toSet();

    expect(
      tableNames,
      containsAll(['sync_outbox', 'sync_state', 'sync_conflicts']),
    );
    expect(await stateRepository.getState(), isA<SyncAccountState>());
  });

  test('does not access Firestore while signed out', () async {
    authRepository.account = null;

    final snapshot = await coordinator.syncNow(now: now);

    expect(snapshot.phase, SyncCoordinatorPhase.signedOut);
    expect(gateway.collectionReadCount, 0);
    expect(await stateRepository.getState(), isA<SyncAccountState>());
  });

  test('uploads local task records and binds sync to the first account',
      () async {
    taskStore.records = [
      {'id': 'task-1', 'title': 'Local task'},
    ];

    final snapshot = await coordinator.syncNow(now: now);

    expect(snapshot.phase, SyncCoordinatorPhase.partiallySynced);
    expect(snapshot.completedRecords, 1);
    expect(snapshot.lastSuccessfulSync, now);
    expect(
      gateway.documents.keys,
      contains('users/user-1/sync/v1/tasks/task-1'),
    );
    expect(await outboxRepository.getOutstandingOperations(), isEmpty);
    final accountState = await stateRepository.getState();
    expect(accountState.accountUid, 'user-1');
    expect(accountState.pendingAccountUid, isNull);
  });

  test('imports remote-only task records without enqueueing an upload',
      () async {
    gateway.documents['users/user-1/sync/v1/tasks/task-remote'] =
        _record('task-remote', 'Remote task');

    final snapshot = await coordinator.syncNow(now: now);

    expect(snapshot.phase, SyncCoordinatorPhase.partiallySynced);
    expect(taskStore.records, [
      {'id': 'task-remote', 'title': 'Remote task'},
    ]);
    expect(gateway.writeCount, 0);
    expect(await outboxRepository.getOutstandingOperations(), isEmpty);
  });

  test('uses outbox insertion order for equal-timestamp task changes',
      () async {
    await outboxRepository.enqueue(
      SyncOperation.create(
        operationId: 'z-earlier-op',
        idempotencyKey: 'z-earlier-key',
        entityType: 'notes',
        entityId: 'note-1',
        kind: SyncOperationKind.upsert,
        schemaVersion: 1,
        payload: const {'id': 'note-1', 'title': 'Earlier'},
        createdAt: now,
      ),
    );
    await outboxRepository.enqueue(
      SyncOperation.create(
        operationId: 'a-later-op',
        idempotencyKey: 'a-later-key',
        entityType: 'notes',
        entityId: 'note-1',
        kind: SyncOperationKind.upsert,
        schemaVersion: 1,
        payload: const {'id': 'note-1', 'title': 'Later'},
        createdAt: now,
      ),
    );

    final snapshot = await coordinator.syncNow(now: now);
    final cloudRecord = gateway.documents['users/user-1/sync/v1/notes/note-1'];
    final cloudPayload = cloudRecord?['payload'] as Map<String, Object?>?;

    expect(snapshot.totalRecords, 1);
    expect(snapshot.completedRecords, 1);
    expect(cloudPayload?['title'], 'Later');
    expect(await outboxRepository.getOutstandingOperations(), isEmpty);
  });

  test('keeps a mutation queued during upload and reports record progress',
      () async {
    await outboxRepository.enqueue(
      SyncOperation.create(
        operationId: 'z-first-op',
        idempotencyKey: 'z-first-key',
        entityType: 'notes',
        entityId: 'note-1',
        kind: SyncOperationKind.upsert,
        schemaVersion: 1,
        payload: const {'id': 'note-1', 'title': 'Captured mutation'},
        createdAt: now,
      ),
    );
    gateway.documents['users/user-1/sync/v1/tasks/task-remote'] =
        _record('task-remote', 'Remote task');
    gateway.beforeDocumentWrite = () async {
      gateway.beforeDocumentWrite = null;
      await outboxRepository.enqueue(
        SyncOperation.create(
          operationId: 'a-concurrent-op',
          idempotencyKey: 'a-concurrent-key',
          entityType: 'notes',
          entityId: 'note-1',
          kind: SyncOperationKind.upsert,
          schemaVersion: 1,
          payload: const {'id': 'note-1', 'title': 'Newer mutation'},
          createdAt: now,
        ),
      );
    };
    final snapshots = <SyncSnapshot>[];
    final subscription = coordinator.progressStream.listen(snapshots.add);

    final snapshot = await coordinator.syncNow(now: now);

    await subscription.cancel();
    final queued = await outboxRepository.getByOperationId('a-concurrent-op');
    expect(snapshot.phase, SyncCoordinatorPhase.partiallySynced);
    expect(snapshot.totalRecords, 2);
    expect(snapshot.completedRecords, 1);
    expect(queued?.state, SyncOperationState.pending);
    expect(
      snapshots.every(
        (progress) => progress.completedRecords <= progress.totalRecords,
      ),
      isTrue,
    );
  });

  test('does not overwrite local task changes made during reconciliation',
      () async {
    final readStarted = Completer<void>();
    final continueRead = Completer<void>();
    taskStore.records = [
      {'id': 'task-local', 'title': 'Original local task'},
    ];
    gateway.beforeCollectionRead = () async {
      if (!readStarted.isCompleted) readStarted.complete();
      await continueRead.future;
    };
    gateway.documents['users/user-1/sync/v1/tasks/task-remote'] =
        _record('task-remote', 'Remote task');

    final sync = coordinator.syncNow(now: now);
    await readStarted.future;
    taskStore.records = [
      {'id': 'task-local', 'title': 'Edited while syncing'},
    ];
    continueRead.complete();

    await sync;

    expect(
      taskStore.records.map((record) => record['title']),
      containsAll(['Edited while syncing', 'Remote task']),
    );
  });

  test('retains divergent local and remote versions without overwriting',
      () async {
    taskStore.records = [
      {'id': 'task-1', 'title': 'Local version'},
    ];
    gateway.documents['users/user-1/sync/v1/tasks/task-1'] =
        _record('task-1', 'Cloud version');

    final snapshot = await coordinator.syncNow(now: now);
    final conflicts = await coordinator.getConflicts('user-1');

    expect(snapshot.phase, SyncCoordinatorPhase.partiallySynced);
    expect(snapshot.conflictCount, 1);
    expect(gateway.writeCount, 0);
    expect(taskStore.records.single['title'], 'Local version');
    expect(conflicts.single.localVersion['payload']['title'], 'Local version');
    expect(
      conflicts.single.remoteVersion['payload']['title'],
      'Cloud version',
    );
  });

  test('manual retry bypasses backoff and completes a failed operation',
      () async {
    await outboxRepository.enqueue(
      SyncOperation.create(
        operationId: 'note-op',
        idempotencyKey: 'note-key',
        entityType: 'notes',
        entityId: 'note-1',
        kind: SyncOperationKind.upsert,
        schemaVersion: 1,
        payload: const {'id': 'note-1', 'title': 'Queued note'},
        createdAt: now,
      ),
    );
    gateway.failWrites = true;

    final failedSnapshot = await coordinator.syncNow(now: now);
    final failedOperation = await outboxRepository.getByOperationId('note-op');
    expect(failedSnapshot.phase, SyncCoordinatorPhase.failed);
    expect(failedOperation?.state, SyncOperationState.failed);
    expect(failedOperation?.attemptCount, 1);
    expect(
      failedOperation?.nextAttemptAt,
      now.add(const Duration(seconds: 5)),
    );

    gateway.failWrites = false;
    final retriedSnapshot = await coordinator.retry(
      now: now.add(const Duration(seconds: 1)),
    );

    expect(retriedSnapshot.phase, SyncCoordinatorPhase.partiallySynced);
    expect(await outboxRepository.getOutstandingOperations(), isEmpty);
    expect(gateway.writeCount, 1);
  });

  test('blocks another account from using locally bound sync data', () async {
    await coordinator.syncNow(now: now);
    final remoteReadsBeforeAccountChange = gateway.collectionReadCount;
    authRepository.account = const AuthAccount(uid: 'user-2');

    final snapshot = await coordinator.syncNow(now: now);

    expect(snapshot.phase, SyncCoordinatorPhase.failed);
    expect(snapshot.message, contains('different account'));
    expect(gateway.collectionReadCount, remoteReadsBeforeAccountChange);
    expect(
      gateway.documents.keys.every((path) => path.startsWith('users/user-1/')),
      isTrue,
    );
  });

  test('a changed account stops the active sync and queues a fresh run',
      () async {
    await outboxRepository.enqueue(
      SyncOperation.create(
        operationId: 'note-op',
        idempotencyKey: 'note-key',
        entityType: 'notes',
        entityId: 'note-1',
        kind: SyncOperationKind.upsert,
        schemaVersion: 1,
        payload: const {'id': 'note-1', 'title': 'Queued note'},
        createdAt: now,
      ),
    );
    final readStarted = Completer<void>();
    final continueRead = Completer<void>();
    gateway.beforeCollectionRead = () async {
      if (!readStarted.isCompleted) readStarted.complete();
      await continueRead.future;
    };

    final firstRun = coordinator.syncNow(now: now);
    await readStarted.future;
    authRepository.account = const AuthAccount(uid: 'user-2');
    final secondRun = coordinator.syncNow(now: now);
    continueRead.complete();

    final firstSnapshot = await firstRun;
    final secondSnapshot = await secondRun;

    expect(firstSnapshot.phase, SyncCoordinatorPhase.failed);
    expect(firstSnapshot.message, contains('account changed'));
    expect(secondSnapshot.phase, SyncCoordinatorPhase.failed);
    expect(secondSnapshot.message, contains('different account'));
    expect(gateway.collectionReadCount, 1);
    expect(gateway.writeCount, 0);
    expect(
      (await outboxRepository.getByOperationId('note-op'))?.state,
      SyncOperationState.pending,
    );
  });

  test('recovers an interrupted operation during coordinator initialization',
      () async {
    await outboxRepository.enqueue(
      SyncOperation.create(
        operationId: 'interrupted-op',
        idempotencyKey: 'interrupted-key',
        entityType: 'notes',
        entityId: 'note-1',
        kind: SyncOperationKind.upsert,
        schemaVersion: 1,
        payload: const {'id': 'note-1', 'title': 'Queued note'},
        createdAt: now,
      ),
    );
    await outboxRepository.markAttemptStarted('interrupted-op', at: now);

    await coordinator.initialize();

    expect(
      (await outboxRepository.getByOperationId('interrupted-op'))?.state,
      SyncOperationState.pending,
    );
  });

  test('repeated sync does not create duplicate remote writes', () async {
    taskStore.records = [
      {'id': 'task-1', 'title': 'Local task'},
    ];
    await coordinator.syncNow(now: now);
    final writeCount = gateway.writeCount;

    await coordinator.syncNow(now: now.add(const Duration(minutes: 1)));

    expect(gateway.writeCount, writeCount);
    expect(await outboxRepository.getOutstandingOperations(), isEmpty);
  });
}

Map<String, Object?> _record(String entityId, String title) {
  return FirebaseSyncRecord(
    entityId: entityId,
    schemaVersion: 1,
    updatedAt: DateTime.utc(2026, 1, 1),
    payload: {'id': entityId, 'title': title},
  ).toFirestore();
}

class _MemoryTaskStore implements SyncEntityStore {
  List<Map<String, dynamic>> records = [];

  @override
  String get entityType => 'tasks';

  @override
  Future<List<Map<String, dynamic>>> loadLocalRecords() async =>
      records.map((record) => Map<String, dynamic>.from(record)).toList();

  @override
  Future<Set<String>> applyRemoteRecords(
    Iterable<Map<String, dynamic>> records,
  ) async {
    final byId = {
      for (final record in this.records) record['id']: record,
    };
    final importedIds = <String>{};
    for (final record in records) {
      final id = record['id'] as String;
      if (byId.containsKey(id)) continue;
      byId[id] = Map<String, dynamic>.from(record);
      importedIds.add(id);
    }
    this.records = byId.values.toList(growable: false);
    return importedIds;
  }
}

class _FakeFirebaseSyncGateway implements FirebaseSyncGateway {
  final Map<String, Map<String, Object?>> documents = {};
  bool failWrites = false;
  Future<void> Function()? beforeCollectionRead;
  Future<void> Function()? beforeDocumentWrite;
  int writeCount = 0;
  int collectionReadCount = 0;

  @override
  Future<void> setDocument(String path, Map<String, Object?> data) async {
    await beforeDocumentWrite?.call();
    if (failWrites) {
      throw const FirebaseSyncRepositoryException(
        code: 'unavailable',
        message: 'Cloud access is temporarily unavailable.',
      );
    }
    writeCount++;
    documents[path] = Map<String, Object?>.from(data);
  }

  @override
  Future<FirebaseSyncDocument?> getDocument(String path) async {
    final data = documents[path];
    return data == null
        ? null
        : FirebaseSyncDocument(
            id: path.split('/').last,
            data: Map<String, Object?>.from(data),
          );
  }

  @override
  Future<List<FirebaseSyncDocument>> getCollection(String path) async {
    collectionReadCount++;
    await beforeCollectionRead?.call();
    final prefix = '$path/';
    return documents.entries
        .where((entry) => entry.key.startsWith(prefix))
        .map(
          (entry) => FirebaseSyncDocument(
            id: entry.key.substring(prefix.length),
            data: Map<String, Object?>.from(entry.value),
          ),
        )
        .toList(growable: false);
  }
}

class _FakeAuthRepository implements AuthRepository {
  AuthAccount? account = const AuthAccount(uid: 'user-1');

  @override
  bool get isAvailable => true;

  @override
  AuthAccount? get currentUser => account;

  @override
  Stream<AuthAccount?> get authStateChanges => Stream.value(account);

  @override
  Future<AuthAccount> register(String email, String password) =>
      throw UnimplementedError();

  @override
  Future<AuthAccount> signIn(String email, String password) =>
      throw UnimplementedError();

  @override
  Future<void> signOut() async {
    account = null;
  }
}
