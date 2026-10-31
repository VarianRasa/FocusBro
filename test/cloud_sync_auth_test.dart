import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusbro/repositories/firebase_auth_repository.dart';
import 'package:focusbro/repositories/sync_metadata_repository.dart';
import 'package:focusbro/services/cloud_sync_service.dart';
import 'package:focusbro/services/sync_coordinator.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CloudSyncService authentication', () {
    late _FakeFirebaseAuthGateway gateway;
    late CloudSyncService service;

    setUp(() async {
      SharedPreferences.setMockInitialValues({
        'user_id': 'legacy-generated-id',
        'last_sync_time': 123456,
      });
      gateway = _FakeFirebaseAuthGateway();
      service = CloudSyncService.forTesting(
        authRepository: FirebaseAuthRepository(gateway: gateway),
      );
    });

    tearDown(() async {
      service.dispose();
      await gateway.close();
    });

    test('does not treat a legacy local ID as an authenticated account',
        () async {
      await service.initialize();

      expect(service.isAuthenticated, isFalse);
      expect(service.currentUserUid, isNull);
      expect(service.currentStatus, SyncStatus.signedOut);
      expect(service.lastSyncTime, isNull);
    });

    test('uses the Firebase UID and listens for auth-state changes', () async {
      await service.initialize();

      expect(await service.signIn('user@example.com', 'password'), isTrue);
      expect(service.currentUserUid, 'firebase-user-1');
      expect(service.currentUserEmail, 'user@example.com');
      expect(service.isAuthenticated, isTrue);

      const updatedAccount = AuthAccount(
        uid: 'firebase-user-2',
        email: 'other@example.com',
      );
      gateway.publish(updatedAccount);
      await Future<void>.delayed(Duration.zero);

      expect(service.currentUserUid, updatedAccount.uid);
      expect(service.currentUserEmail, updatedAccount.email);
    });

    test('registration and sign-out update the account state', () async {
      await service.initialize();

      expect(await service.register('new@example.com', 'password'), isTrue);
      expect(gateway.lastOperation, 'register');
      expect(service.isAuthenticated, isTrue);

      expect(await service.signOut(), isTrue);
      expect(gateway.lastOperation, 'signOut');
      expect(service.isAuthenticated, isFalse);
      expect(service.currentStatus, SyncStatus.signedOut);
    });

    test('sign-out failure preserves the authenticated account state',
        () async {
      await service.initialize();
      expect(await service.signIn('user@example.com', 'password'), isTrue);
      gateway.failure = FirebaseAuthException(code: 'network-request-failed');

      expect(await service.signOut(), isFalse);
      expect(service.isAuthenticated, isTrue);
      expect(service.currentStatus, SyncStatus.error);
      expect(
        service.lastErrorMessage,
        'Could not connect. Check your connection and try again.',
      );
    });

    test('authentication failure never becomes authenticated or synced',
        () async {
      await service.initialize();
      gateway.failure = FirebaseAuthException(
        code: 'wrong-password',
        message: 'Provider detail must not reach the UI',
      );

      expect(await service.signIn('user@example.com', 'wrong'), isFalse);
      expect(service.isAuthenticated, isFalse);
      expect(service.currentStatus, SyncStatus.error);
      expect(service.lastErrorMessage, 'Email or password is incorrect.');
      expect(service.currentStatus, isNot(SyncStatus.synced));
    });

    test('does not claim sync success before the coordinator exists', () async {
      await service.initialize();
      expect(await service.signIn('user@example.com', 'password'), isTrue);

      expect(await service.forceSyncNow(), isFalse);
      expect(service.currentStatus, SyncStatus.unavailable);
      expect(service.currentStatusMessage, contains('not available yet'));
      expect(service.lastSyncTime, isNull);
      expect(service.isSyncing, isFalse);
    });

    test('keeps authentication unavailable when Firebase bootstrap failed',
        () async {
      gateway.isAvailable = false;
      await service.initialize();

      expect(service.isAuthenticated, isFalse);
      expect(service.currentStatus, SyncStatus.error);
      expect(
        service.currentStatusMessage,
        contains('Local features remain available'),
      );
      expect(await service.signIn('user@example.com', 'password'), isFalse);
      expect(gateway.lastOperation, isNull);
    });

    test('syncs on startup, network restoration, and app resume', () async {
      final connectivity =
          StreamController<ConnectivityResult>.broadcast(sync: true);
      final runner = _FakeSyncRunner();
      gateway.publish(
        const AuthAccount(uid: 'firebase-user-1', email: 'user@example.com'),
      );
      service.dispose();
      service = CloudSyncService.forTesting(
        authRepository: FirebaseAuthRepository(gateway: gateway),
        syncRunner: runner,
        connectivityChanges: connectivity.stream,
        enableAutomaticTriggers: true,
      );

      await service.initialize();
      await Future<void>.delayed(Duration.zero);
      expect(runner.syncCount, 1);

      connectivity.add(ConnectivityResult.wifi);
      await Future<void>.delayed(Duration.zero);
      expect(runner.syncCount, 2);

      service.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await Future<void>.delayed(Duration.zero);
      expect(runner.syncCount, 3);
      expect(service.currentStatus, SyncStatus.partial);

      await connectivity.close();
    });

    test('syncs automatically after sign-in', () async {
      final runner = _FakeSyncRunner();
      service.dispose();
      service = CloudSyncService.forTesting(
        authRepository: FirebaseAuthRepository(gateway: gateway),
        syncRunner: runner,
        connectivityChanges: const Stream<ConnectivityResult>.empty(),
        enableAutomaticTriggers: true,
      );

      await service.initialize();
      expect(runner.syncCount, 0);

      expect(await service.signIn('user@example.com', 'password'), isTrue);
      await Future<void>.delayed(Duration.zero);

      expect(runner.syncCount, 1);
      expect(service.currentStatus, SyncStatus.partial);
    });
  });
}

class _FakeFirebaseAuthGateway implements FirebaseAuthGateway {
  final StreamController<AuthAccount?> _authStateController =
      StreamController<AuthAccount?>.broadcast(sync: true);

  AuthAccount? _currentUser;
  Object? failure;
  @override
  bool isAvailable = true;
  String? lastOperation;

  @override
  AuthAccount? get currentUser => _currentUser;

  @override
  Stream<AuthAccount?> get authStateChanges => _authStateController.stream;

  @override
  Future<AuthAccount> register(String email, String password) {
    return _authenticate('register');
  }

  @override
  Future<AuthAccount> signIn(String email, String password) {
    return _authenticate('signIn');
  }

  Future<AuthAccount> _authenticate(String operation) async {
    lastOperation = operation;
    if (failure case final error?) throw error;

    _currentUser = const AuthAccount(
      uid: 'firebase-user-1',
      email: 'user@example.com',
    );
    _authStateController.add(_currentUser);
    return _currentUser!;
  }

  void publish(AuthAccount? account) {
    _currentUser = account;
    _authStateController.add(account);
  }

  @override
  Future<void> signOut() async {
    lastOperation = 'signOut';
    if (failure case final error?) throw error;
    publish(null);
  }

  Future<void> close() => _authStateController.close();
}

class _FakeSyncRunner implements SyncRunner {
  final StreamController<SyncSnapshot> _progress =
      StreamController<SyncSnapshot>.broadcast(sync: true);

  SyncSnapshot _snapshot = const SyncSnapshot.initial();
  int syncCount = 0;

  @override
  SyncSnapshot get currentSnapshot => _snapshot;

  @override
  Stream<SyncSnapshot> get progressStream => _progress.stream;

  @override
  Future<void> initialize() async {}

  @override
  Future<SyncSnapshot> syncNow({DateTime? now}) async {
    syncCount++;
    _snapshot = const SyncSnapshot(
      phase: SyncCoordinatorPhase.partiallySynced,
      totalRecords: 1,
      completedRecords: 1,
      failedRecords: 0,
      conflictCount: 0,
      message: 'Only integrated categories are synced.',
    );
    _progress.add(_snapshot);
    return _snapshot;
  }

  @override
  Future<SyncSnapshot> retry({DateTime? now}) => syncNow(now: now);

  @override
  Future<List<SyncConflict>> getConflicts(String accountUid) async => const [];

  @override
  void dispose() {
    unawaited(_progress.close());
  }
}
