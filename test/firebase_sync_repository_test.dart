import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusbro/models/sync_operation.dart';
import 'package:focusbro/repositories/firebase_auth_repository.dart';
import 'package:focusbro/repositories/firebase_sync_repository.dart';

void main() {
  group('FirebaseSyncRepository', () {
    late _FakeFirebaseSyncGateway gateway;
    late _FakeAuthRepository authRepository;
    late FirebaseSyncRepository repository;

    setUp(() {
      gateway = _FakeFirebaseSyncGateway();
      authRepository = _FakeAuthRepository(
        account: const AuthAccount(uid: 'owner-uid'),
      );
      repository = FirebaseSyncRepository(
        authRepository: authRepository,
        gateway: gateway,
      );
    });

    test('writes a versioned record beneath the authenticated UID', () async {
      final operation = SyncOperation.create(
        entityType: 'tasks',
        entityId: 'task-1',
        kind: SyncOperationKind.upsert,
        schemaVersion: 1,
        payload: const {'id': 'task-1', 'title': 'Owner task'},
        createdAt: DateTime.utc(2026, 1, 1),
      );

      await repository.applyOperation(operation);

      expect(
        gateway.documents.keys,
        ['users/owner-uid/sync/v1/tasks/task-1'],
      );
      expect(gateway.documents.values.single, {
        'entityId': 'task-1',
        'schemaVersion': 1,
        'updatedAt': DateTime.utc(2026, 1, 1),
        'deletedAt': null,
        'payload': {'id': 'task-1', 'title': 'Owner task'},
      });
    });

    test('writes deletes as tombstones instead of hard deletes', () async {
      final deletedAt = DateTime.utc(2026, 2, 1);
      final operation = SyncOperation.create(
        entityType: 'tasks',
        entityId: 'task-1',
        kind: SyncOperationKind.delete,
        schemaVersion: 1,
        deletedAt: deletedAt,
      );

      await repository.applyOperation(operation);

      final record = gateway.documents.values.single;
      expect(record['deletedAt'], deletedAt);
      expect(record['payload'], isNull);
      expect(gateway.hardDeleteCount, 0);
    });

    test('reads and lists typed records only from the authenticated path',
        () async {
      final operation = SyncOperation.create(
        entityType: 'tasks',
        entityId: 'task-2',
        kind: SyncOperationKind.upsert,
        schemaVersion: 1,
        payload: const {'id': 'task-2', 'title': 'Read task'},
        createdAt: DateTime.utc(2026, 3, 1),
      );
      await repository.applyOperation(operation);

      final record = await repository.getRecord(
        entityType: 'tasks',
        entityId: 'task-2',
      );
      final records = await repository.getRecords(entityType: 'tasks');

      expect(record?.entityId, 'task-2');
      expect(record?.payload?['title'], 'Read task');
      expect(records.map((item) => item.entityId), ['task-2']);
      expect(gateway.requestedPaths, contains('users/owner-uid/sync/v1/tasks'));
    });

    test('requires available Firebase and an authenticated account', () async {
      authRepository.isAvailable = false;
      await expectLater(
        repository.getRecords(entityType: 'tasks'),
        throwsA(
          isA<FirebaseSyncRepositoryException>().having(
            (error) => error.code,
            'code',
            'firebase_unavailable',
          ),
        ),
      );

      authRepository
        ..isAvailable = true
        ..account = null;
      await expectLater(
        repository.getRecords(entityType: 'tasks'),
        throwsA(
          isA<FirebaseSyncRepositoryException>().having(
            (error) => error.code,
            'code',
            'unauthenticated',
          ),
        ),
      );
      expect(gateway.requestedPaths, isEmpty);
    });

    test('rejects a changed UID before using the expected account path',
        () async {
      await expectLater(
        repository.getRecords(entityType: 'tasks', expectedUid: 'other-uid'),
        throwsA(
          isA<FirebaseSyncRepositoryException>().having(
            (error) => error.code,
            'code',
            'account-changed',
          ),
        ),
      );
      expect(gateway.requestedPaths, isEmpty);
    });

    test('rejects unsupported collections and unsafe document IDs', () async {
      final unsupportedOperation = SyncOperation.create(
        entityType: 'files',
        entityId: 'file-1',
        kind: SyncOperationKind.upsert,
        schemaVersion: 1,
        payload: const {'id': 'file-1'},
      );
      await expectLater(
        repository.applyOperation(unsupportedOperation),
        throwsArgumentError,
      );
      await expectLater(
        repository.getRecord(entityType: 'tasks', entityId: 'bad/id'),
        throwsArgumentError,
      );
      expect(gateway.documents, isEmpty);
    });

    test('sanitizes Firebase exceptions', () async {
      gateway.failure = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
        message: 'Internal permission detail',
      );

      await expectLater(
        repository.getRecords(entityType: 'tasks'),
        throwsA(
          isA<FirebaseSyncRepositoryException>().having(
            (error) => error.code,
            'code',
            'permission-denied',
          ),
        ),
      );
    });
  });
}

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.account});

  AuthAccount? account;

  @override
  bool isAvailable = true;

  @override
  AuthAccount? get currentUser => account;

  @override
  Stream<AuthAccount?> get authStateChanges => Stream.value(account);

  @override
  Future<AuthAccount> register(String email, String password) =>
      throw UnimplementedError();

  @override
  Future<void> signOut() async {
    account = null;
  }

  @override
  Future<AuthAccount> signIn(String email, String password) =>
      throw UnimplementedError();
}

class _FakeFirebaseSyncGateway implements FirebaseSyncGateway {
  final Map<String, Map<String, Object?>> documents = {};
  final List<String> requestedPaths = [];
  Object? failure;
  int hardDeleteCount = 0;

  @override
  Future<FirebaseSyncDocument?> getDocument(String path) async {
    _recordPath(path);
    _throwIfConfigured();
    final data = documents[path];
    if (data == null) return null;
    final id = path.split('/').last;
    return FirebaseSyncDocument(id: id, data: data);
  }

  @override
  Future<List<FirebaseSyncDocument>> getCollection(String path) async {
    _recordPath(path);
    _throwIfConfigured();
    final prefix = '$path/';
    return documents.entries
        .where((entry) => entry.key.startsWith(prefix))
        .map(
          (entry) => FirebaseSyncDocument(
            id: entry.key.substring(prefix.length),
            data: entry.value,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<void> setDocument(String path, Map<String, Object?> data) async {
    _recordPath(path);
    _throwIfConfigured();
    documents[path] = Map<String, Object?>.from(data);
  }

  void _recordPath(String path) => requestedPaths.add(path);

  void _throwIfConfigured() {
    final error = failure;
    if (error != null) throw error;
  }
}
