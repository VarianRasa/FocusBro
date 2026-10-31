import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../services/database_helper.dart';

typedef SyncMetadataDatabaseProvider = Future<Database> Function();

class SyncAccountState {
  const SyncAccountState({
    this.accountUid,
    this.pendingAccountUid,
    this.lastSuccessfulSync,
  });

  final String? accountUid;
  final String? pendingAccountUid;
  final DateTime? lastSuccessfulSync;

  factory SyncAccountState.fromRow(Map<String, Object?> row) {
    final timestamp = row['last_successful_sync'] as String?;
    return SyncAccountState(
      accountUid: row['account_uid'] as String?,
      pendingAccountUid: row['pending_account_uid'] as String?,
      lastSuccessfulSync:
          timestamp == null ? null : DateTime.parse(timestamp).toUtc(),
    );
  }
}

class SyncStateRepository {
  SyncStateRepository({SyncMetadataDatabaseProvider? databaseProvider})
      : _databaseProvider =
            databaseProvider ?? (() => DatabaseHelper().database);

  final SyncMetadataDatabaseProvider _databaseProvider;

  Future<SyncAccountState> getState() async {
    final database = await _databaseProvider();
    final rows = await database.query(
      'sync_state',
      where: 'singleton_id = 1',
      limit: 1,
    );
    if (rows.isEmpty) return const SyncAccountState();
    return SyncAccountState.fromRow(rows.single);
  }

  Future<SyncAccountState> claimAccount(String uid) async {
    final accountUid = uid.trim();
    if (accountUid.isEmpty) {
      throw ArgumentError.value(uid, 'uid', 'Account UID must not be empty.');
    }

    final database = await _databaseProvider();
    return database.transaction((transaction) async {
      final rows = await transaction.query(
        'sync_state',
        where: 'singleton_id = 1',
        limit: 1,
      );
      if (rows.isEmpty) {
        await transaction.insert('sync_state', {'singleton_id': 1});
      }
      final state = rows.isEmpty
          ? const SyncAccountState()
          : SyncAccountState.fromRow(rows.single);

      if ((state.accountUid != null && state.accountUid != accountUid) ||
          (state.pendingAccountUid != null &&
              state.pendingAccountUid != accountUid)) {
        throw const SyncAccountMismatchException();
      }

      if (state.accountUid == null && state.pendingAccountUid == null) {
        await transaction.update(
          'sync_state',
          {'pending_account_uid': accountUid},
          where: 'singleton_id = 1',
        );
        return SyncAccountState(
          pendingAccountUid: accountUid,
          lastSuccessfulSync: state.lastSuccessfulSync,
        );
      }
      return state;
    });
  }

  Future<void> markSuccessfulSync(String uid, {DateTime? at}) async {
    await markAccountReconciled(
      uid,
      lastSuccessfulSync: (at ?? DateTime.now()).toUtc(),
    );
  }

  Future<void> markAccountReconciled(
    String uid, {
    DateTime? lastSuccessfulSync,
  }) async {
    final accountUid = uid.trim();
    if (accountUid.isEmpty) {
      throw ArgumentError.value(uid, 'uid', 'Account UID must not be empty.');
    }

    final database = await _databaseProvider();
    await database.transaction((transaction) async {
      final rows = await transaction.query(
        'sync_state',
        where: 'singleton_id = 1',
        limit: 1,
      );
      if (rows.isEmpty) {
        await transaction.insert('sync_state', {'singleton_id': 1});
      } else {
        final state = SyncAccountState.fromRow(rows.single);
        if ((state.accountUid != null && state.accountUid != accountUid) ||
            (state.pendingAccountUid != null &&
                state.pendingAccountUid != accountUid)) {
          throw const SyncAccountMismatchException();
        }
      }

      final values = <String, Object?>{
        'account_uid': accountUid,
        'pending_account_uid': null,
      };
      if (lastSuccessfulSync != null) {
        values['last_successful_sync'] =
            lastSuccessfulSync.toUtc().toIso8601String();
      }
      await transaction.update(
        'sync_state',
        values,
        where: 'singleton_id = 1',
      );
    });
  }
}

class SyncAccountMismatchException implements Exception {
  const SyncAccountMismatchException();

  @override
  String toString() =>
      'Local sync data is associated with a different account.';
}

class SyncConflict {
  const SyncConflict({
    required this.id,
    required this.accountUid,
    required this.entityType,
    required this.entityId,
    required this.localVersion,
    required this.remoteVersion,
    required this.detectedAt,
  });

  final int id;
  final String accountUid;
  final String entityType;
  final String entityId;
  final Map<String, dynamic> localVersion;
  final Map<String, dynamic> remoteVersion;
  final DateTime detectedAt;

  factory SyncConflict.fromRow(Map<String, Object?> row) {
    final local = jsonDecode(row['local_version_json']! as String);
    final remote = jsonDecode(row['remote_version_json']! as String);
    if (local is! Map || remote is! Map) {
      throw const FormatException('Sync conflict versions must be objects.');
    }
    return SyncConflict(
      id: row['id'] as int,
      accountUid: row['account_uid'] as String,
      entityType: row['entity_type'] as String,
      entityId: row['entity_id'] as String,
      localVersion: Map<String, dynamic>.from(local),
      remoteVersion: Map<String, dynamic>.from(remote),
      detectedAt: DateTime.parse(row['detected_at'] as String).toUtc(),
    );
  }
}

class SyncConflictRepository {
  SyncConflictRepository({SyncMetadataDatabaseProvider? databaseProvider})
      : _databaseProvider =
            databaseProvider ?? (() => DatabaseHelper().database);

  final SyncMetadataDatabaseProvider _databaseProvider;

  Future<void> retain({
    required String accountUid,
    required String entityType,
    required String entityId,
    required Map<String, dynamic> localVersion,
    required Map<String, dynamic> remoteVersion,
    DateTime? detectedAt,
  }) async {
    final database = await _databaseProvider();
    await database.insert(
      'sync_conflicts',
      {
        'account_uid': accountUid,
        'entity_type': entityType,
        'entity_id': entityId,
        'local_version_json': jsonEncode(localVersion),
        'remote_version_json': jsonEncode(remoteVersion),
        'detected_at': (detectedAt ?? DateTime.now()).toUtc().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<SyncConflict>> getForAccount(String accountUid) async {
    final database = await _databaseProvider();
    final rows = await database.query(
      'sync_conflicts',
      where: 'account_uid = ?',
      whereArgs: [accountUid],
      orderBy: 'detected_at ASC, id ASC',
    );
    return rows.map(SyncConflict.fromRow).toList(growable: false);
  }

  Future<void> removeForEntity({
    required String accountUid,
    required String entityType,
    required String entityId,
  }) async {
    final database = await _databaseProvider();
    await database.delete(
      'sync_conflicts',
      where: 'account_uid = ? AND entity_type = ? AND entity_id = ?',
      whereArgs: [accountUid, entityType, entityId],
    );
  }
}
