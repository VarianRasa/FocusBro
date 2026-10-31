import 'dart:async';
import 'dart:convert';

import '../models/sync_operation.dart';
import '../repositories/firebase_auth_repository.dart';
import '../repositories/firebase_sync_repository.dart';
import '../repositories/sync_metadata_repository.dart';
import '../repositories/sync_outbox_repository.dart';
import '../repositories/task_repository.dart';
import 'task_service.dart';

abstract interface class SyncEntityStore {
  String get entityType;

  Future<List<Map<String, dynamic>>> loadLocalRecords();

  Future<Set<String>> applyRemoteRecords(
    Iterable<Map<String, dynamic>> records,
  );
}

class CanonicalTaskSyncStore implements SyncEntityStore {
  CanonicalTaskSyncStore({
    CanonicalTaskRepository? repository,
    TaskService? taskService,
  })  : _repository = repository ?? CanonicalTaskRepository(),
        _taskService = taskService ?? TaskService();

  final CanonicalTaskRepository _repository;
  final TaskService _taskService;

  @override
  String get entityType => 'tasks';

  @override
  Future<List<Map<String, dynamic>>> loadLocalRecords() {
    return _repository.loadAllTaskPayloads();
  }

  @override
  Future<Set<String>> applyRemoteRecords(
    Iterable<Map<String, dynamic>> records,
  ) {
    return _taskService.applyRemoteTaskPayloads(records);
  }
}

enum SyncCoordinatorPhase {
  idle,
  syncing,
  partiallySynced,
  synced,
  failed,
  signedOut,
  unavailable,
}

class SyncSnapshot {
  const SyncSnapshot({
    required this.phase,
    required this.totalRecords,
    required this.completedRecords,
    required this.failedRecords,
    required this.conflictCount,
    required this.message,
    this.lastSuccessfulSync,
  });

  const SyncSnapshot.initial()
      : phase = SyncCoordinatorPhase.idle,
        totalRecords = 0,
        completedRecords = 0,
        failedRecords = 0,
        conflictCount = 0,
        message = 'Ready to sync',
        lastSuccessfulSync = null;

  final SyncCoordinatorPhase phase;
  final int totalRecords;
  final int completedRecords;
  final int failedRecords;
  final int conflictCount;
  final String message;
  final DateTime? lastSuccessfulSync;

  bool get isSyncing => phase == SyncCoordinatorPhase.syncing;

  double? get progress => totalRecords == 0
      ? null
      : (completedRecords / totalRecords).clamp(0.0, 1.0).toDouble();
}

abstract interface class SyncRunner {
  SyncSnapshot get currentSnapshot;

  Stream<SyncSnapshot> get progressStream;

  Future<void> initialize();

  Future<SyncSnapshot> syncNow({DateTime? now});

  Future<SyncSnapshot> retry({DateTime? now});

  Future<List<SyncConflict>> getConflicts(String accountUid);

  void dispose();
}

class SyncCoordinator implements SyncRunner {
  SyncCoordinator({
    AuthRepository? authRepository,
    SyncOutboxRepository? outboxRepository,
    FirebaseSyncRepository? firestoreRepository,
    SyncStateRepository? stateRepository,
    SyncConflictRepository? conflictRepository,
    Iterable<SyncEntityStore>? entityStores,
    DateTime Function()? clock,
  })  : _authRepository = authRepository ?? const FirebaseAuthRepository(),
        _outboxRepository = outboxRepository ?? SyncOutboxRepository(),
        _firestoreRepository = firestoreRepository ??
            FirebaseSyncRepository(
              authRepository: authRepository ?? const FirebaseAuthRepository(),
            ),
        _stateRepository = stateRepository ?? SyncStateRepository(),
        _conflictRepository = conflictRepository ?? SyncConflictRepository(),
        _entityStores = {
          for (final store in entityStores ?? [CanonicalTaskSyncStore()])
            store.entityType: store,
        },
        _clock = clock ?? DateTime.now;

  static const Duration _initialRetryDelay = Duration(seconds: 5);
  static const Duration _maximumRetryDelay = Duration(hours: 1);

  final AuthRepository _authRepository;
  final SyncOutboxRepository _outboxRepository;
  final FirebaseSyncRepository _firestoreRepository;
  final SyncStateRepository _stateRepository;
  final SyncConflictRepository _conflictRepository;
  final Map<String, SyncEntityStore> _entityStores;
  final DateTime Function() _clock;
  final StreamController<SyncSnapshot> _progressController =
      StreamController<SyncSnapshot>.broadcast();

  SyncSnapshot _currentSnapshot = const SyncSnapshot.initial();
  Future<SyncSnapshot>? _activeSync;
  String? _activeSyncUid;
  bool _disposed = false;

  @override
  SyncSnapshot get currentSnapshot => _currentSnapshot;

  @override
  Stream<SyncSnapshot> get progressStream => _progressController.stream;

  @override
  Future<void> initialize() async {
    await _outboxRepository.recoverInterruptedOperations(at: _clock());
    final state = await _stateRepository.getState();
    _publish(
      SyncSnapshot(
        phase: SyncCoordinatorPhase.idle,
        totalRecords: 0,
        completedRecords: 0,
        failedRecords: 0,
        conflictCount: 0,
        message: 'Ready to sync',
        lastSuccessfulSync: state.lastSuccessfulSync,
      ),
    );
  }

  @override
  Future<SyncSnapshot> syncNow({DateTime? now}) {
    final activeSync = _activeSync;
    final requestedUid = _authRepository.currentUser?.uid.trim();
    if (activeSync != null) {
      if (_activeSyncUid == requestedUid) return activeSync;
      return activeSync.then((_) => syncNow(now: now));
    }

    _activeSyncUid = requestedUid;
    final run = _runSync(now: (now ?? _clock()).toUtc());
    late final Future<SyncSnapshot> trackedRun;
    trackedRun = run.whenComplete(() {
      if (identical(_activeSync, trackedRun)) {
        _activeSync = null;
        _activeSyncUid = null;
      }
    });
    _activeSync = trackedRun;
    return trackedRun;
  }

  @override
  Future<SyncSnapshot> retry({DateTime? now}) async {
    await _outboxRepository.retryFailedOperations();
    return syncNow(now: now);
  }

  @override
  Future<List<SyncConflict>> getConflicts(String accountUid) {
    return _conflictRepository.getForAccount(accountUid);
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    unawaited(_progressController.close());
  }

  Future<SyncSnapshot> _runSync({required DateTime now}) async {
    _publish(
      SyncSnapshot(
        phase: SyncCoordinatorPhase.syncing,
        totalRecords: 0,
        completedRecords: 0,
        failedRecords: 0,
        conflictCount: 0,
        message: 'Checking local and cloud records...',
        lastSuccessfulSync: _currentSnapshot.lastSuccessfulSync,
      ),
    );

    if (!_authRepository.isAvailable) {
      return _finish(
        phase: SyncCoordinatorPhase.failed,
        message:
            'Cloud access is unavailable. Local changes remain on this device.',
      );
    }
    final uid = _authRepository.currentUser?.uid.trim();
    if (uid == null || uid.isEmpty) {
      return _finish(
        phase: SyncCoordinatorPhase.signedOut,
        message: 'Sign in before synchronizing records.',
      );
    }

    var completed = 0;
    var failed = 0;
    final workEntities = <(String, String)>{};
    final completedEntities = <(String, String)>{};
    final failedEntities = <(String, String)>{};
    final blockedEntities = <(String, String)>{};
    try {
      await _stateRepository.claimAccount(uid);
      await _outboxRepository.recoverInterruptedOperations(at: now);
      var outstanding = await _outboxRepository.getOutstandingOperations();
      workEntities.addAll(_operationEntityKeys(outstanding));
      _publish(
        SyncSnapshot(
          phase: SyncCoordinatorPhase.syncing,
          totalRecords: workEntities.length,
          completedRecords: 0,
          failedRecords: 0,
          conflictCount: 0,
          message: 'Reconciling local and cloud records...',
          lastSuccessfulSync: _currentSnapshot.lastSuccessfulSync,
        ),
      );

      for (final store in _entityStores.values) {
        final result = await _reconcileEntityStore(
          store: store,
          accountUid: uid,
          operations: outstanding,
          now: now,
        );
        workEntities
          ..addAll(result.completedEntities)
          ..addAll(result.importedEntities);
        completedEntities
          ..addAll(result.completedEntities)
          ..addAll(result.importedEntities);
        completed = completedEntities.length;
        blockedEntities.addAll(result.blockedEntities);
        outstanding = await _outboxRepository.getOutstandingOperations();
        workEntities.addAll(_operationEntityKeys(outstanding));
        _publish(
          SyncSnapshot(
            phase: SyncCoordinatorPhase.syncing,
            totalRecords: workEntities.length,
            completedRecords: completedEntities.length,
            failedRecords: failedEntities.length,
            conflictCount: result.conflictCount,
            message: 'Reconciling ${store.entityType}...',
            lastSuccessfulSync: _currentSnapshot.lastSuccessfulSync,
          ),
        );
      }

      final sendResult = await _sendReadyOperations(
        accountUid: uid,
        operations: outstanding,
        blockedEntities: blockedEntities,
        now: now,
        workEntities: workEntities,
        completedEntities: completedEntities,
        failedEntities: failedEntities,
      );
      completed = completedEntities.length;
      failed += sendResult.failed;

      final remaining = await _outboxRepository.getOutstandingOperations();
      final conflicts = await _conflictRepository.getForAccount(uid);
      _assertCurrentAccount(uid);
      final remainingEntityKeys = _operationEntityKeys(remaining);
      workEntities.addAll(remainingEntityKeys);
      completedEntities.removeAll(remainingEntityKeys);
      completed = completedEntities.length;
      if (remaining.isEmpty && conflicts.isEmpty && failed == 0) {
        await _stateRepository.markAccountReconciled(
          uid,
          lastSuccessfulSync: now,
        );
      } else {
        await _stateRepository.markAccountReconciled(uid);
      }
      final accountState = await _stateRepository.getState();
      final remainingFailures = remaining
          .where((operation) => operation.state == SyncOperationState.failed)
          .map((operation) => (operation.entityType, operation.entityId))
          .toSet()
          .length;
      final hasUnintegratedTypes =
          !_entityStores.keys.toSet().containsAll(firebaseSyncEntityTypes);
      final failedRecordKeys = <(String, String)>{
        ...failedEntities,
        ...remaining
            .where((operation) => operation.state == SyncOperationState.failed)
            .map((operation) => (operation.entityType, operation.entityId)),
      };
      final hasFailures = failed > 0 || failedRecordKeys.isNotEmpty;
      final hasConflicts = conflicts.isNotEmpty;
      final isComplete = !hasUnintegratedTypes &&
          remaining.isEmpty &&
          !hasConflicts &&
          !hasFailures;

      final message = switch ((hasFailures, hasConflicts, isComplete)) {
        (true, _, _) =>
          'Some changes could not sync. They remain queued for retry.',
        (false, true, _) =>
          'Conflicting versions were retained for review; neither was overwritten.',
        (false, false, true) => 'All supported records are up to date.',
        _ =>
          'Task records and queued changes were processed. Other categories are not yet fully synchronized.',
      };
      return _finish(
        phase: isComplete
            ? SyncCoordinatorPhase.synced
            : hasFailures
                ? SyncCoordinatorPhase.failed
                : SyncCoordinatorPhase.partiallySynced,
        message: message,
        totalRecords: workEntities.length,
        completedRecords: completedEntities.length,
        failedRecords: failedRecordKeys.length,
        conflictCount: conflicts.length,
        lastSuccessfulSync: accountState.lastSuccessfulSync,
      );
    } on SyncAccountMismatchException catch (error) {
      return _finish(
        phase: SyncCoordinatorPhase.failed,
        message: error.toString(),
      );
    } on FirebaseSyncRepositoryException catch (error) {
      return _finish(
        phase: SyncCoordinatorPhase.failed,
        message: error.message,
        failedRecords: failed + 1,
        completedRecords: completed,
      );
    } catch (_) {
      return _finish(
        phase: SyncCoordinatorPhase.failed,
        message:
            'Sync could not complete. Local changes remain available for retry.',
        failedRecords: failed + 1,
        completedRecords: completed,
      );
    }
  }

  Future<_EntityReconcileResult> _reconcileEntityStore({
    required SyncEntityStore store,
    required String accountUid,
    required List<SyncOperation> operations,
    required DateTime now,
  }) async {
    _assertCurrentAccount(accountUid);
    final localRecords = await store.loadLocalRecords();
    final localById = <String, Map<String, dynamic>>{
      for (final record in localRecords)
        if (record['id'] is String) record['id'] as String: record,
    };
    final remoteRecords = await _firestoreRepository.getRecords(
      entityType: store.entityType,
      expectedUid: accountUid,
    );
    final remoteById = {
      for (final record in remoteRecords) record.entityId: record,
    };
    _assertCurrentAccount(accountUid);
    final latestOperations = _latestOperationsByEntity(
      operations.where((operation) => operation.entityType == store.entityType),
    );
    final operationsById = {
      for (final entry in latestOperations.entries) entry.key.$2: entry.value,
    };
    final allIds = <String>{
      ...localById.keys,
      ...remoteById.keys,
      ...operationsById.keys,
    };
    final remoteImports = <Map<String, dynamic>>[];
    final completedEntities = <(String, String)>{};
    final importedEntities = <(String, String)>{};
    final blocked = <(String, String)>{};

    for (final entityId in allIds) {
      final localPayload = localById[entityId];
      final localOperation = operationsById[entityId];
      final remoteRecord = remoteById[entityId];

      if (localPayload == null && localOperation == null) {
        if (remoteRecord != null && !remoteRecord.isTombstone) {
          final payload = remoteRecord.payload;
          if (payload == null || payload['id'] != entityId) {
            throw const FormatException(
              'A remote task payload has an invalid stable ID.',
            );
          }
          remoteImports.add(payload);
          await _conflictRepository.removeForEntity(
            accountUid: accountUid,
            entityType: store.entityType,
            entityId: entityId,
          );
        }
        continue;
      }

      final effectiveLocal = localPayload ??
          (localOperation?.kind == SyncOperationKind.upsert
              ? localOperation?.payload
              : null);
      final localIsDeleted =
          effectiveLocal == null && localOperation?.isTombstone == true;

      if (remoteRecord != null &&
          _matchesRemote(
            localPayload: effectiveLocal,
            localIsDeleted: localIsDeleted,
            remoteRecord: remoteRecord,
          )) {
        if (localOperation != null) {
          final acknowledged = await _completeCapturedOperations(
            operations,
            localOperation,
            now,
          );
          if (acknowledged > 0) {
            completedEntities.add((store.entityType, entityId));
          }
        }
        await _conflictRepository.removeForEntity(
          accountUid: accountUid,
          entityType: store.entityType,
          entityId: entityId,
        );
        continue;
      }

      if (remoteRecord != null && effectiveLocal != null ||
          remoteRecord != null && localIsDeleted) {
        await _retainConflict(
          accountUid: accountUid,
          entityType: store.entityType,
          entityId: entityId,
          localVersion: _localVersion(
            entityId: entityId,
            payload: effectiveLocal,
            operation: localOperation,
            isDeleted: localIsDeleted,
            at: now,
          ),
          remoteRecord: remoteRecord,
          detectedAt: now,
        );
        blocked.add((store.entityType, entityId));
        continue;
      }

      if (effectiveLocal == null) {
        // A local tombstone with no remote record still needs to be sent so
        // another offline device cannot recreate the deleted record.
        continue;
      }

      if (remoteRecord == null) {
        final alreadyQueued =
            localOperation?.kind == SyncOperationKind.upsert &&
                _payloadsEqual(localOperation?.payload, effectiveLocal);
        if (!alreadyQueued) {
          final createdAt = localOperation == null ||
                  now.isAfter(localOperation.createdAt)
              ? now
              : localOperation.createdAt.add(const Duration(microseconds: 1));
          await _outboxRepository.enqueue(
            SyncOperation.create(
              entityType: store.entityType,
              entityId: entityId,
              kind: SyncOperationKind.upsert,
              schemaVersion: 1,
              payload: effectiveLocal,
              createdAt: createdAt,
            ),
          );
        }
      }
    }

    if (remoteImports.isNotEmpty) {
      _assertCurrentAccount(accountUid);
      final importedIds = await store.applyRemoteRecords(remoteImports);
      importedEntities.addAll(
        importedIds.map((id) => (store.entityType, id)),
      );
    }

    return _EntityReconcileResult(
      completedEntities: completedEntities,
      importedEntities: importedEntities,
      blockedEntities: blocked,
      conflictCount:
          (await _conflictRepository.getForAccount(accountUid)).length,
    );
  }

  Future<_OperationSendResult> _sendReadyOperations({
    required String accountUid,
    required List<SyncOperation> operations,
    required Set<(String, String)> blockedEntities,
    required DateTime now,
    required Set<(String, String)> workEntities,
    required Set<(String, String)> completedEntities,
    required Set<(String, String)> failedEntities,
  }) async {
    final ready = await _outboxRepository.getPendingOperations(now: now);
    final readyIds = ready.map((operation) => operation.operationId).toSet();
    final latestByEntity = _latestOperationsByEntity(operations);
    var failed = 0;

    for (final entry in latestByEntity.entries) {
      final key = entry.key;
      final operation = entry.value;
      workEntities.add(key);
      if (blockedEntities.contains(key) ||
          !readyIds.contains(operation.operationId)) {
        continue;
      }

      try {
        _assertCurrentAccount(accountUid);
        final remoteRecord = await _firestoreRepository.getRecord(
          entityType: operation.entityType,
          entityId: operation.entityId,
          expectedUid: accountUid,
        );
        final localPayload = operation.kind == SyncOperationKind.upsert
            ? operation.payload
            : null;
        if (_matchesRemote(
          localPayload: localPayload,
          localIsDeleted: operation.isTombstone,
          remoteRecord: remoteRecord,
        )) {
          final acknowledged = await _completeCapturedOperations(
            operations,
            operation,
            now,
          );
          if (acknowledged > 0) completedEntities.add(key);
          failedEntities.remove(key);
          await _conflictRepository.removeForEntity(
            accountUid: accountUid,
            entityType: operation.entityType,
            entityId: operation.entityId,
          );
          _publishProgress(
            completedEntities.length,
            workEntities.length,
            failedEntities.length,
          );
          continue;
        }

        if (remoteRecord != null) {
          await _retainConflict(
            accountUid: accountUid,
            entityType: operation.entityType,
            entityId: operation.entityId,
            localVersion: _localVersion(
              entityId: operation.entityId,
              payload: localPayload,
              operation: operation,
              isDeleted: operation.isTombstone,
              at: now,
            ),
            remoteRecord: remoteRecord,
            detectedAt: now,
          );
          _publishProgress(
            completedEntities.length,
            workEntities.length,
            failedEntities.length,
          );
          continue;
        }

        _assertCurrentAccount(accountUid);
        await _outboxRepository.markAttemptStarted(
          operation.operationId,
          at: now,
        );
        await _firestoreRepository.applyOperation(
          operation,
          expectedUid: accountUid,
        );
        final acknowledged = await _completeCapturedOperations(
          operations,
          operation,
          now,
        );
        if (acknowledged > 0) completedEntities.add(key);
        failedEntities.remove(key);
        await _conflictRepository.removeForEntity(
          accountUid: accountUid,
          entityType: operation.entityType,
          entityId: operation.entityId,
        );
      } on FirebaseSyncRepositoryException catch (error) {
        if (error.code == 'account-changed') {
          await _outboxRepository.recoverInterruptedOperations(at: now);
          rethrow;
        }
        failed++;
        failedEntities.add(key);
        final currentOperation =
            await _outboxRepository.getByOperationId(operation.operationId);
        final attempts = currentOperation?.attemptCount ?? 1;
        await _outboxRepository.markFailed(
          operation.operationId,
          errorCode: error.code,
          nextAttemptAt: now.add(_retryDelay(attempts)),
          at: now,
        );
        _publishProgress(
          completedEntities.length,
          workEntities.length,
          failedEntities.length,
        );
      } catch (error) {
        failed++;
        failedEntities.add(key);
        final currentOperation =
            await _outboxRepository.getByOperationId(operation.operationId);
        final attempts = currentOperation?.attemptCount ?? 1;
        await _outboxRepository.markFailed(
          operation.operationId,
          errorCode:
              error is FirebaseSyncRepositoryException ? error.code : 'unknown',
          nextAttemptAt: now.add(_retryDelay(attempts)),
          at: now,
        );
        _publishProgress(
          completedEntities.length,
          workEntities.length,
          failedEntities.length,
        );
      }

      _publishProgress(
        completedEntities.length,
        workEntities.length,
        failedEntities.length,
      );
    }

    return _OperationSendResult(failed: failed);
  }

  void _publishProgress(
    int completed,
    int total,
    int failed,
  ) {
    _publish(
      SyncSnapshot(
        phase: SyncCoordinatorPhase.syncing,
        totalRecords: total,
        completedRecords: completed,
        failedRecords: failed,
        conflictCount: 0,
        message: 'Syncing records ($completed of $total)...',
        lastSuccessfulSync: _currentSnapshot.lastSuccessfulSync,
      ),
    );
  }

  Future<int> _completeCapturedOperations(
    List<SyncOperation> capturedOperations,
    SyncOperation processedOperation,
    DateTime now,
  ) {
    final matchingOperations = capturedOperations
        .where(
          (operation) =>
              operation.entityType == processedOperation.entityType &&
              operation.entityId == processedOperation.entityId,
        )
        .toList(growable: false);
    final processedIndex = matchingOperations.indexWhere(
      (operation) => operation.operationId == processedOperation.operationId,
    );
    final operationIds = processedIndex < 0
        ? [processedOperation.operationId]
        : matchingOperations
            .take(processedIndex + 1)
            .map((operation) => operation.operationId)
            .toList(growable: false);
    return _outboxRepository.markOperationsCompleted(operationIds, at: now);
  }

  Set<(String, String)> _operationEntityKeys(
    Iterable<SyncOperation> operations,
  ) {
    return {
      for (final operation in operations)
        (operation.entityType, operation.entityId),
    };
  }

  Future<void> _retainConflict({
    required String accountUid,
    required String entityType,
    required String entityId,
    required Map<String, dynamic> localVersion,
    required FirebaseSyncRecord remoteRecord,
    required DateTime detectedAt,
  }) {
    return _conflictRepository.retain(
      accountUid: accountUid,
      entityType: entityType,
      entityId: entityId,
      localVersion: localVersion,
      remoteVersion: _remoteVersion(remoteRecord),
      detectedAt: detectedAt,
    );
  }

  Map<String, dynamic> _localVersion({
    required String entityId,
    required Map<String, dynamic>? payload,
    required SyncOperation? operation,
    required bool isDeleted,
    required DateTime at,
  }) {
    return {
      'entityId': entityId,
      'schemaVersion': operation?.schemaVersion ?? 1,
      'updatedAt': (operation?.createdAt ?? _payloadUpdatedAt(payload) ?? at)
          .toUtc()
          .toIso8601String(),
      'deletedAt': isDeleted
          ? (operation?.deletedAt ?? at).toUtc().toIso8601String()
          : null,
      'payload': isDeleted ? null : payload,
    };
  }

  DateTime? _payloadUpdatedAt(Map<String, dynamic>? payload) {
    final value = payload?['updatedAt'];
    if (value is DateTime) return value.toUtc();
    if (value is! String) return null;
    return DateTime.tryParse(value)?.toUtc();
  }

  void _assertCurrentAccount(String expectedUid) {
    final currentUid = _authRepository.currentUser?.uid.trim();
    if (!_authRepository.isAvailable ||
        currentUid == null ||
        currentUid.isEmpty ||
        currentUid != expectedUid) {
      throw const FirebaseSyncRepositoryException(
        code: 'account-changed',
        message:
            'The signed-in account changed. Sign in to the local data account.',
      );
    }
  }

  Map<String, dynamic> _remoteVersion(FirebaseSyncRecord record) {
    return {
      'entityId': record.entityId,
      'schemaVersion': record.schemaVersion,
      'updatedAt': record.updatedAt.toUtc().toIso8601String(),
      'deletedAt': record.deletedAt?.toUtc().toIso8601String(),
      'payload': record.payload,
    };
  }

  bool _matchesRemote({
    required Map<String, dynamic>? localPayload,
    required bool localIsDeleted,
    required FirebaseSyncRecord? remoteRecord,
  }) {
    if (remoteRecord == null) return false;
    if (localIsDeleted) return remoteRecord.isTombstone;
    if (localPayload == null || remoteRecord.isTombstone) return false;
    return _payloadsEqual(localPayload, remoteRecord.payload);
  }

  bool _payloadsEqual(
    Map<String, dynamic>? left,
    Map<String, dynamic>? right,
  ) {
    if (left == null || right == null) return left == right;
    return jsonEncode(_canonicalize(left)) == jsonEncode(_canonicalize(right));
  }

  Object? _canonicalize(Object? value) {
    if (value is Map) {
      final keys = value.keys.whereType<String>().toList()..sort();
      return {
        for (final key in keys) key: _canonicalize(value[key]),
      };
    }
    if (value is List) return value.map(_canonicalize).toList(growable: false);
    if (value is DateTime) return value.toUtc().toIso8601String();
    return value;
  }

  Map<(String, String), SyncOperation> _latestOperationsByEntity(
    Iterable<SyncOperation> operations,
  ) {
    final result = <(String, String), SyncOperation>{};
    for (final operation in operations) {
      final key = (operation.entityType, operation.entityId);
      result[key] = operation;
    }
    return result;
  }

  Duration _retryDelay(int attempt) {
    var delay = _initialRetryDelay;
    for (var i = 1; i < attempt && delay < _maximumRetryDelay; i++) {
      delay = Duration(seconds: delay.inSeconds * 2);
    }
    return delay > _maximumRetryDelay ? _maximumRetryDelay : delay;
  }

  SyncSnapshot _finish({
    required SyncCoordinatorPhase phase,
    required String message,
    int totalRecords = 0,
    int completedRecords = 0,
    int failedRecords = 0,
    int conflictCount = 0,
    DateTime? lastSuccessfulSync,
  }) {
    final snapshot = SyncSnapshot(
      phase: phase,
      totalRecords: totalRecords,
      completedRecords: completedRecords,
      failedRecords: failedRecords,
      conflictCount: conflictCount,
      message: message,
      lastSuccessfulSync:
          lastSuccessfulSync ?? _currentSnapshot.lastSuccessfulSync,
    );
    _publish(snapshot);
    return snapshot;
  }

  void _publish(SyncSnapshot snapshot) {
    _currentSnapshot = snapshot;
    if (!_disposed) _progressController.add(snapshot);
  }
}

class _EntityReconcileResult {
  const _EntityReconcileResult({
    required this.completedEntities,
    required this.importedEntities,
    required this.blockedEntities,
    required this.conflictCount,
  });

  final Set<(String, String)> completedEntities;
  final Set<(String, String)> importedEntities;
  final Set<(String, String)> blockedEntities;
  final int conflictCount;
}

class _OperationSendResult {
  const _OperationSendResult({required this.failed});

  final int failed;
}
