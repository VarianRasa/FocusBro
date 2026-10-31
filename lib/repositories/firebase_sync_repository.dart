import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/sync_operation.dart';
import 'firebase_auth_repository.dart';

const Set<String> firebaseSyncEntityTypes = {
  'tasks',
  'focus_sessions',
  'timer_presets',
  'goals',
  'settings',
  'notes',
  'music_library',
  'playlists',
  'pdf_reading_state',
};

class FirebaseSyncDocument {
  const FirebaseSyncDocument({required this.id, required this.data});

  final String id;
  final Map<String, Object?> data;
}

abstract interface class FirebaseSyncGateway {
  Future<void> setDocument(String path, Map<String, Object?> data);

  Future<FirebaseSyncDocument?> getDocument(String path);

  Future<List<FirebaseSyncDocument>> getCollection(String path);
}

class FirebaseFirestoreSyncGateway implements FirebaseSyncGateway {
  FirebaseFirestoreSyncGateway({FirebaseFirestore? firestore})
      : _firestore = firestore;

  final FirebaseFirestore? _firestore;

  FirebaseFirestore get _database => _firestore ?? FirebaseFirestore.instance;

  @override
  Future<void> setDocument(String path, Map<String, Object?> data) {
    return _database.doc(path).set(Map<String, dynamic>.from(data));
  }

  @override
  Future<FirebaseSyncDocument?> getDocument(String path) async {
    final snapshot = await _database.doc(path).get();
    final data = snapshot.data();
    return data == null
        ? null
        : FirebaseSyncDocument(
            id: snapshot.id,
            data: Map<String, Object?>.from(data),
          );
  }

  @override
  Future<List<FirebaseSyncDocument>> getCollection(String path) async {
    final snapshot = await _database.collection(path).get();
    return snapshot.docs
        .map(
          (document) => FirebaseSyncDocument(
            id: document.id,
            data: Map<String, Object?>.from(document.data()),
          ),
        )
        .toList(growable: false);
  }
}

class FirebaseSyncRecord {
  const FirebaseSyncRecord({
    required this.entityId,
    required this.schemaVersion,
    required this.updatedAt,
    required this.payload,
    this.deletedAt,
  });

  factory FirebaseSyncRecord.fromOperation(SyncOperation operation) {
    if (operation.kind == SyncOperationKind.upsert &&
        operation.payload == null) {
      throw const FormatException('Upsert records require a payload.');
    }
    if (operation.kind == SyncOperationKind.delete &&
        operation.deletedAt == null) {
      throw const FormatException('Delete records require a tombstone date.');
    }

    return FirebaseSyncRecord(
      entityId: operation.entityId,
      schemaVersion: operation.schemaVersion,
      updatedAt: operation.createdAt.toUtc(),
      deletedAt: operation.deletedAt?.toUtc(),
      payload:
          operation.kind == SyncOperationKind.delete ? null : operation.payload,
    );
  }

  factory FirebaseSyncRecord.fromDocument(FirebaseSyncDocument document) {
    final data = document.data;
    final entityId = data['entityId'];
    final schemaVersion = data['schemaVersion'];
    final updatedAt = _readDateTime(data['updatedAt'], 'updatedAt');
    final deletedAtValue = data['deletedAt'];
    final deletedAt = deletedAtValue == null
        ? null
        : _readDateTime(deletedAtValue, 'deletedAt');
    final payloadValue = data['payload'];

    if (entityId is! String || entityId != document.id) {
      throw const FormatException('Record ID does not match its document ID.');
    }
    if (schemaVersion is! int || schemaVersion < 1) {
      throw const FormatException(
          'Record schemaVersion must be a positive int.');
    }
    if ((deletedAt == null && payloadValue is! Map) ||
        (deletedAt != null && payloadValue != null)) {
      throw const FormatException('Record payload does not match its state.');
    }

    return FirebaseSyncRecord(
      entityId: entityId,
      schemaVersion: schemaVersion,
      updatedAt: updatedAt,
      deletedAt: deletedAt,
      payload: payloadValue == null
          ? null
          : Map<String, dynamic>.from(payloadValue as Map),
    );
  }

  final String entityId;
  final int schemaVersion;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final Map<String, dynamic>? payload;

  bool get isTombstone => deletedAt != null;

  Map<String, Object?> toFirestore() {
    return {
      'entityId': entityId,
      'schemaVersion': schemaVersion,
      'updatedAt': updatedAt.toUtc(),
      'deletedAt': deletedAt?.toUtc(),
      'payload': payload,
    };
  }

  static DateTime _readDateTime(Object? value, String fieldName) {
    return switch (value) {
      Timestamp(:final seconds, :final nanoseconds) =>
        DateTime.fromMillisecondsSinceEpoch(
          seconds * 1000 + nanoseconds ~/ 1000000,
          isUtc: true,
        ),
      DateTime dateTime => dateTime.toUtc(),
      _ => throw FormatException('Record $fieldName must be a timestamp.'),
    };
  }
}

class FirebaseSyncRepository {
  FirebaseSyncRepository({
    AuthRepository? authRepository,
    FirebaseSyncGateway? gateway,
  })  : _authRepository = authRepository ?? const FirebaseAuthRepository(),
        _gateway = gateway ?? FirebaseFirestoreSyncGateway();

  final AuthRepository _authRepository;
  final FirebaseSyncGateway _gateway;

  Future<void> applyOperation(
    SyncOperation operation, {
    String? expectedUid,
  }) async {
    _validateEntityType(operation.entityType);
    _validateEntityId(operation.entityId);
    final record = FirebaseSyncRecord.fromOperation(operation);
    final path = _documentPath(
      _requireAuthenticatedUid(expectedUid: expectedUid),
      operation.entityType,
      operation.entityId,
    );
    await _run(() => _gateway.setDocument(path, record.toFirestore()));
  }

  Future<FirebaseSyncRecord?> getRecord({
    required String entityType,
    required String entityId,
    String? expectedUid,
  }) async {
    _validateEntityType(entityType);
    _validateEntityId(entityId);
    final path = _documentPath(
      _requireAuthenticatedUid(expectedUid: expectedUid),
      entityType,
      entityId,
    );
    final document = await _run(() => _gateway.getDocument(path));
    return document == null ? null : FirebaseSyncRecord.fromDocument(document);
  }

  Future<List<FirebaseSyncRecord>> getRecords({
    required String entityType,
    String? expectedUid,
  }) async {
    _validateEntityType(entityType);
    final path = _collectionPath(
      _requireAuthenticatedUid(expectedUid: expectedUid),
      entityType,
    );
    final documents = await _run(() => _gateway.getCollection(path));
    final records = documents
        .map(FirebaseSyncRecord.fromDocument)
        .toList(growable: true)
      ..sort((left, right) => left.entityId.compareTo(right.entityId));
    return records;
  }

  String _requireAuthenticatedUid({String? expectedUid}) {
    if (!_authRepository.isAvailable) {
      throw const FirebaseSyncRepositoryException(
        code: 'firebase_unavailable',
        message:
            'Cloud access is unavailable. Local features remain available.',
      );
    }
    final uid = _authRepository.currentUser?.uid.trim();
    if (uid == null || uid.isEmpty) {
      throw const FirebaseSyncRepositoryException(
        code: 'unauthenticated',
        message: 'Sign in before accessing cloud records.',
      );
    }
    if (expectedUid != null && uid != expectedUid) {
      throw const FirebaseSyncRepositoryException(
        code: 'account-changed',
        message:
            'The signed-in account changed. Sign in to the local data account.',
      );
    }
    return uid;
  }

  void _validateEntityType(String entityType) {
    if (!firebaseSyncEntityTypes.contains(entityType)) {
      throw ArgumentError.value(entityType, 'entityType', 'Unsupported type.');
    }
  }

  void _validateEntityId(String entityId) {
    if (entityId.trim().isEmpty ||
        entityId != entityId.trim() ||
        entityId == '.' ||
        entityId == '..' ||
        entityId.contains('/') ||
        entityId.length > 1500) {
      throw ArgumentError.value(entityId, 'entityId', 'Invalid record ID.');
    }
  }

  String _collectionPath(String uid, String entityType) {
    return 'users/$uid/sync/v1/$entityType';
  }

  String _documentPath(String uid, String entityType, String entityId) {
    return '${_collectionPath(uid, entityType)}/$entityId';
  }

  Future<T> _run<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on FirebaseException catch (error) {
      final safeCode = SyncOperation.sanitizeErrorCode(error.code) ?? 'unknown';
      throw FirebaseSyncRepositoryException(
        code: safeCode,
        message: switch (safeCode) {
          'permission-denied' =>
            'You do not have permission to access this cloud record.',
          'unavailable' => 'Cloud access is temporarily unavailable.',
          _ => 'The cloud record operation failed.',
        },
      );
    }
  }
}

class FirebaseSyncRepositoryException implements Exception {
  const FirebaseSyncRepositoryException({
    required this.code,
    required this.message,
  });

  final String code;
  final String message;

  @override
  String toString() => message;
}
