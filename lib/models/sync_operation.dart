import 'dart:convert';
import 'dart:math';

enum SyncOperationKind { upsert, delete }

enum SyncOperationState { pending, inProgress, failed, completed }

class SyncOperation {
  const SyncOperation._({
    required this.operationId,
    required this.idempotencyKey,
    required this.entityType,
    required this.entityId,
    required this.kind,
    required this.schemaVersion,
    required this.state,
    required this.attemptCount,
    required this.createdAt,
    required this.updatedAt,
    this.payload,
    this.lastAttemptAt,
    this.nextAttemptAt,
    this.errorCode,
    this.completedAt,
    this.deletedAt,
  });

  factory SyncOperation.create({
    String? operationId,
    String? idempotencyKey,
    required String entityType,
    required String entityId,
    required SyncOperationKind kind,
    required int schemaVersion,
    Map<String, dynamic>? payload,
    DateTime? createdAt,
    DateTime? deletedAt,
  }) {
    final normalizedEntityType = entityType.trim();
    final normalizedEntityId = entityId.trim();
    if (normalizedEntityType.isEmpty || normalizedEntityId.isEmpty) {
      throw ArgumentError('Entity type and entity ID must not be empty.');
    }
    if (schemaVersion < 1) {
      throw ArgumentError.value(schemaVersion, 'schemaVersion');
    }
    if (kind == SyncOperationKind.upsert && payload == null) {
      throw ArgumentError('Upsert operations require a structured payload.');
    }

    final timestamp = (createdAt ?? DateTime.now()).toUtc();
    final generatedId = operationId?.trim() ?? _generateUuid();
    final normalizedIdempotencyKey = idempotencyKey?.trim() ?? generatedId;
    if (generatedId.isEmpty || normalizedIdempotencyKey.isEmpty) {
      throw ArgumentError('Operation and idempotency IDs must not be empty.');
    }
    final frozenPayload = payload == null
        ? null
        : _freezeJsonMap(jsonDecode(jsonEncode(payload)) as Map);
    return SyncOperation._(
      operationId: generatedId,
      idempotencyKey: normalizedIdempotencyKey,
      entityType: normalizedEntityType,
      entityId: normalizedEntityId,
      kind: kind,
      schemaVersion: schemaVersion,
      payload: frozenPayload,
      state: SyncOperationState.pending,
      attemptCount: 0,
      createdAt: timestamp,
      updatedAt: timestamp,
      deletedAt: kind == SyncOperationKind.delete
          ? (deletedAt ?? timestamp).toUtc()
          : null,
    );
  }

  final String operationId;
  final String idempotencyKey;
  final String entityType;
  final String entityId;
  final SyncOperationKind kind;
  final int schemaVersion;
  final Map<String, dynamic>? payload;
  final SyncOperationState state;
  final int attemptCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastAttemptAt;
  final DateTime? nextAttemptAt;
  final String? errorCode;
  final DateTime? completedAt;
  final DateTime? deletedAt;

  bool get isTombstone => kind == SyncOperationKind.delete && deletedAt != null;

  Map<String, Object?> toDatabaseRow() {
    return {
      'operation_id': operationId,
      'idempotency_key': idempotencyKey,
      'entity_type': entityType,
      'entity_id': entityId,
      'operation_kind': kind.name,
      'schema_version': schemaVersion,
      'payload_json': payload == null ? null : jsonEncode(payload),
      'status': state.name,
      'attempt_count': attemptCount,
      'error_code': sanitizeErrorCode(errorCode),
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'last_attempt_at': lastAttemptAt?.toUtc().toIso8601String(),
      'next_attempt_at': nextAttemptAt?.toUtc().toIso8601String(),
      'completed_at': completedAt?.toUtc().toIso8601String(),
      'deleted_at': deletedAt?.toUtc().toIso8601String(),
      // Account association is intentionally deferred until reconciliation.
      'account_uid': null,
    };
  }

  factory SyncOperation.fromDatabaseRow(Map<String, dynamic> row) {
    final payloadJson = row['payload_json'] as String?;
    Map<String, dynamic>? decodedPayload;
    if (payloadJson != null) {
      final decoded = jsonDecode(payloadJson);
      if (decoded is! Map) {
        throw const FormatException('Outbox payload must be a JSON object.');
      }
      decodedPayload = _freezeJsonMap(decoded);
    }

    return SyncOperation._(
      operationId: row['operation_id'] as String,
      idempotencyKey: row['idempotency_key'] as String,
      entityType: row['entity_type'] as String,
      entityId: row['entity_id'] as String,
      kind: SyncOperationKind.values.byName(row['operation_kind'] as String),
      schemaVersion: row['schema_version'] as int,
      payload: decodedPayload,
      state: SyncOperationState.values.byName(row['status'] as String),
      attemptCount: row['attempt_count'] as int,
      createdAt: _parseTimestamp(row['created_at']),
      updatedAt: _parseTimestamp(row['updated_at']),
      lastAttemptAt: _parseOptionalTimestamp(row['last_attempt_at']),
      nextAttemptAt: _parseOptionalTimestamp(row['next_attempt_at']),
      errorCode: sanitizeErrorCode(row['error_code'] as String?),
      completedAt: _parseOptionalTimestamp(row['completed_at']),
      deletedAt: _parseOptionalTimestamp(row['deleted_at']),
    );
  }

  static String? sanitizeErrorCode(String? errorCode) {
    final normalized = errorCode?.trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) return null;
    if (RegExp(r'^[a-z0-9][a-z0-9._-]{0,63}$').hasMatch(normalized)) {
      return normalized;
    }
    return 'unknown';
  }

  static DateTime _parseTimestamp(Object? value) {
    return DateTime.parse(value as String).toUtc();
  }

  static DateTime? _parseOptionalTimestamp(Object? value) {
    return value == null ? null : _parseTimestamp(value);
  }

  static Map<String, dynamic> _freezeJsonMap(Map<dynamic, dynamic> value) {
    final result = <String, dynamic>{};
    for (final entry in value.entries) {
      if (entry.key is! String) {
        throw const FormatException('Outbox payload keys must be strings.');
      }
      result[entry.key as String] = _freezeJsonValue(entry.value);
    }
    return Map<String, dynamic>.unmodifiable(result);
  }

  static Object? _freezeJsonValue(Object? value) {
    if (value is Map) return _freezeJsonMap(value);
    if (value is List) {
      return List<Object?>.unmodifiable(value.map(_freezeJsonValue));
    }
    if (value == null || value is String || value is num || value is bool) {
      return value;
    }
    throw const FormatException('Outbox payload contains a non-JSON value.');
  }

  static String _generateUuid() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex =
        bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }
}
