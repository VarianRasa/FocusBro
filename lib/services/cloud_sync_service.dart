import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../repositories/firebase_auth_repository.dart';
import '../repositories/sync_metadata_repository.dart';
import 'sync_coordinator.dart';

class CloudSyncService extends WidgetsBindingObserver {
  static final CloudSyncService _instance = CloudSyncService._internal();

  factory CloudSyncService() => _instance;

  CloudSyncService._internal()
      : _authRepository = const FirebaseAuthRepository(),
        _syncRunner = SyncCoordinator(
          authRepository: const FirebaseAuthRepository(),
        ),
        _connectivityChanges = null,
        _enableAutomaticTriggers = true;

  @visibleForTesting
  CloudSyncService.forTesting({
    required AuthRepository authRepository,
    SyncRunner? syncRunner,
    Stream<ConnectivityResult>? connectivityChanges,
    bool enableAutomaticTriggers = false,
  })  : _authRepository = authRepository,
        _syncRunner = syncRunner ?? _UnavailableSyncRunner(),
        _connectivityChanges = connectivityChanges,
        _enableAutomaticTriggers = enableAutomaticTriggers;

  final AuthRepository _authRepository;
  final SyncRunner _syncRunner;
  final Stream<ConnectivityResult>? _connectivityChanges;
  final bool _enableAutomaticTriggers;
  final StreamController<SyncStatus> _syncStatusController =
      StreamController<SyncStatus>.broadcast();

  StreamSubscription<AuthAccount?>? _authStateSubscription;
  StreamSubscription<SyncSnapshot>? _coordinatorSubscription;
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  AuthAccount? _currentUser;
  SyncStatus _currentStatus = SyncStatus.idle;
  String? _lastErrorMessage;
  String? _currentStatusMessage;
  bool _initialized = false;
  bool _isSyncing = false;
  bool _disposed = false;
  bool _observingLifecycle = false;
  int _authGeneration = 0;

  Future<void> initialize() async {
    if (_initialized &&
        (_authStateSubscription != null || !_authRepository.isAvailable)) {
      return;
    }
    _initialized = true;

    if (!_authRepository.isAvailable) {
      _currentUser = null;
      _updateSyncStatus(
        SyncStatus.error,
        'Authentication is unavailable. Local features remain available.',
      );
      return;
    }

    try {
      _coordinatorSubscription = _syncRunner.progressStream.listen(
        _handleCoordinatorSnapshot,
        onError: (Object error, StackTrace stackTrace) {
          _updateSyncStatus(
            SyncStatus.error,
            'Sync status is unavailable. Local changes remain available.',
          );
        },
      );
      var syncQueueAvailable = true;
      try {
        await _syncRunner.initialize();
      } catch (_) {
        syncQueueAvailable = false;
      }
      _currentUser = _authRepository.currentUser;
      _authStateSubscription = _authRepository.authStateChanges.listen(
        _handleAuthStateChange,
        onError: (Object error, StackTrace stackTrace) {
          _handleAuthStateError();
        },
      );
      if (_enableAutomaticTriggers) _startAutomaticTriggers();
      if (syncQueueAvailable) {
        _updateSyncStatus(
          _currentUser == null
              ? SyncStatus.signedOut
              : SyncStatus.authenticated,
        );
      } else {
        _updateSyncStatus(
          SyncStatus.error,
          'The local sync queue is unavailable. Account state is unchanged.',
        );
      }
      if (_currentUser != null &&
          _enableAutomaticTriggers &&
          syncQueueAvailable) {
        unawaited(syncAll());
      }
    } catch (_) {
      _currentUser = null;
      _updateSyncStatus(
        SyncStatus.error,
        'Authentication is unavailable. Local features remain available.',
      );
    }
  }

  Stream<SyncStatus> get syncStatusStream => _syncStatusController.stream;

  Stream<AuthAccount?> get authStateChanges => _authRepository.authStateChanges;

  AuthAccount? get currentUser => _currentUser;

  String? get currentUserUid => _currentUser?.uid;

  String? get currentUserEmail => _currentUser?.email;

  bool get isAuthAvailable => _authRepository.isAvailable;

  bool get isAuthenticated => _currentUser != null;

  DateTime? get lastSyncTime => _syncRunner.currentSnapshot.lastSuccessfulSync;

  bool get isSyncing => _isSyncing;

  SyncStatus get currentStatus => _currentStatus;

  String get currentStatusMessage =>
      _currentStatusMessage ?? _lastErrorMessage ?? _currentStatus.message;

  SyncSnapshot get currentProgress => _syncRunner.currentSnapshot;

  String? get lastErrorMessage => _lastErrorMessage;

  Future<List<SyncConflict>> getSyncConflicts() {
    final uid = _currentUser?.uid;
    return uid == null
        ? Future.value(const <SyncConflict>[])
        : _syncRunner.getConflicts(uid);
  }

  Future<bool> register(String email, String password) {
    return _authenticate(() => _authRepository.register(email, password));
  }

  Future<bool> signIn(String email, String password) {
    return _authenticate(() => _authRepository.signIn(email, password));
  }

  Future<bool> _authenticate(
    Future<AuthAccount> Function() authenticate,
  ) async {
    if (!_initialized) await initialize();
    if (!_authRepository.isAvailable) {
      _updateSyncStatus(
        SyncStatus.error,
        'Authentication is unavailable. Local features remain available.',
      );
      return false;
    }

    _updateSyncStatus(SyncStatus.authenticating);
    try {
      final account = await authenticate();
      _handleAuthStateChange(account);
      if (_currentStatus == SyncStatus.authenticating ||
          _currentStatus == SyncStatus.error) {
        _updateSyncStatus(SyncStatus.authenticated);
      }
      return true;
    } on FirebaseAuthRepositoryException catch (error) {
      _updateSyncStatus(SyncStatus.error, error.message);
      return false;
    } catch (_) {
      _updateSyncStatus(
        SyncStatus.error,
        'Authentication failed. Check your details and try again.',
      );
      return false;
    }
  }

  Future<bool> signOut() async {
    if (!_initialized) await initialize();
    if (!isAuthenticated) {
      _updateSyncStatus(SyncStatus.signedOut);
      return true;
    }

    try {
      await _authRepository.signOut();
      _handleAuthStateChange(null);
      return true;
    } on FirebaseAuthRepositoryException catch (error) {
      _updateSyncStatus(SyncStatus.error, error.message);
      return false;
    } catch (_) {
      _updateSyncStatus(
        SyncStatus.error,
        'Could not sign out. Please try again.',
      );
      return false;
    }
  }

  Future<bool> syncAll() => _runSync(retry: false);

  Future<bool> forceSyncNow() => _runSync(retry: true);

  Future<bool> _runSync({required bool retry}) async {
    if (!_initialized) await initialize();
    if (!isAuthenticated) {
      _updateSyncStatus(SyncStatus.signedOut);
      return false;
    }

    final authGeneration = _authGeneration;
    _isSyncing = true;
    _updateSyncStatus(SyncStatus.syncing);
    try {
      final snapshot =
          retry ? await _syncRunner.retry() : await _syncRunner.syncNow();
      if (authGeneration != _authGeneration) return false;
      _isSyncing = snapshot.isSyncing;
      _handleCoordinatorSnapshot(snapshot);
      return snapshot.phase == SyncCoordinatorPhase.synced;
    } catch (_) {
      if (authGeneration == _authGeneration) {
        _isSyncing = false;
        _updateSyncStatus(
          SyncStatus.error,
          'Sync could not complete. Local changes remain available for retry.',
        );
      }
      return false;
    } finally {
      if (authGeneration == _authGeneration &&
          !_syncRunner.currentSnapshot.isSyncing) {
        _isSyncing = false;
      }
    }
  }

  void _handleAuthStateChange(AuthAccount? account) {
    if (_sameAccount(_currentUser, account)) return;
    _authGeneration++;
    _currentUser = account;
    if (account == null) {
      _isSyncing = false;
      _updateSyncStatus(SyncStatus.signedOut);
    } else {
      _updateSyncStatus(SyncStatus.authenticated);
      if (_enableAutomaticTriggers) unawaited(syncAll());
    }
  }

  void _handleCoordinatorSnapshot(SyncSnapshot snapshot) {
    _isSyncing = snapshot.isSyncing;
    final status = switch (snapshot.phase) {
      SyncCoordinatorPhase.idle =>
        _currentUser == null ? SyncStatus.signedOut : SyncStatus.authenticated,
      SyncCoordinatorPhase.syncing => SyncStatus.syncing,
      SyncCoordinatorPhase.partiallySynced => SyncStatus.partial,
      SyncCoordinatorPhase.synced => SyncStatus.synced,
      SyncCoordinatorPhase.failed => SyncStatus.error,
      SyncCoordinatorPhase.signedOut => SyncStatus.signedOut,
      SyncCoordinatorPhase.unavailable => SyncStatus.unavailable,
    };
    _updateSyncStatus(status, snapshot.message);
  }

  void _startAutomaticTriggers() {
    if (!_observingLifecycle) {
      WidgetsBinding.instance.addObserver(this);
      _observingLifecycle = true;
    }
    try {
      final connectivityChanges =
          _connectivityChanges ?? Connectivity().onConnectivityChanged;
      _connectivitySubscription ??= connectivityChanges.listen(
        (result) {
          if (result != ConnectivityResult.none && isAuthenticated) {
            unawaited(syncAll());
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          // Manual and lifecycle triggers remain available.
        },
      );
    } catch (_) {
      // Manual and lifecycle triggers remain available.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && isAuthenticated) {
      unawaited(syncAll());
    }
  }

  bool _sameAccount(AuthAccount? left, AuthAccount? right) {
    return left?.uid == right?.uid && left?.email == right?.email;
  }

  void _handleAuthStateError() {
    _authGeneration++;
    _currentUser = null;
    _isSyncing = false;
    _updateSyncStatus(
      SyncStatus.error,
      'Authentication state is unavailable. Sign in again.',
    );
  }

  void _updateSyncStatus(SyncStatus status, [String? message]) {
    _currentStatus = status;
    _currentStatusMessage = message;
    _lastErrorMessage =
        status == SyncStatus.error || status == SyncStatus.unavailable
            ? message
            : null;
    if (!_disposed) _syncStatusController.add(status);
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    if (_observingLifecycle) {
      WidgetsBinding.instance.removeObserver(this);
      _observingLifecycle = false;
    }
    final authStateSubscription = _authStateSubscription;
    if (authStateSubscription != null) {
      unawaited(authStateSubscription.cancel());
    }
    unawaited(_coordinatorSubscription?.cancel());
    unawaited(_connectivitySubscription?.cancel());
    _syncRunner.dispose();
    unawaited(_syncStatusController.close());
  }
}

enum SyncStatus {
  idle,
  authenticating,
  authenticated,
  syncing,
  partial,
  synced,
  unavailable,
  error,
  signedOut,
  offline,
}

extension SyncStatusExtension on SyncStatus {
  String get message {
    switch (this) {
      case SyncStatus.idle:
        return 'Ready to sync';
      case SyncStatus.authenticating:
        return 'Signing in...';
      case SyncStatus.authenticated:
        return 'Account signed in. Sync is ready.';
      case SyncStatus.syncing:
        return 'Syncing structured data...';
      case SyncStatus.partial:
        return 'Some data categories are not yet synchronized.';
      case SyncStatus.synced:
        return 'Data synced successfully';
      case SyncStatus.unavailable:
        return 'Cloud sync is not available yet';
      case SyncStatus.error:
        return 'Authentication failed';
      case SyncStatus.signedOut:
        return 'Signed out';
      case SyncStatus.offline:
        return 'Offline - will sync when online';
    }
  }

  bool get isError => this == SyncStatus.error;

  bool get isSuccess => this == SyncStatus.synced;

  bool get isLoading =>
      this == SyncStatus.authenticating || this == SyncStatus.syncing;
}

class _UnavailableSyncRunner implements SyncRunner {
  @override
  SyncSnapshot get currentSnapshot => const SyncSnapshot(
        phase: SyncCoordinatorPhase.unavailable,
        totalRecords: 0,
        completedRecords: 0,
        failedRecords: 0,
        conflictCount: 0,
        message:
            'Cloud sync is not available yet. Your data remains on this device.',
      );

  @override
  Stream<SyncSnapshot> get progressStream => const Stream.empty();

  @override
  Future<void> initialize() async {}

  @override
  Future<SyncSnapshot> syncNow({DateTime? now}) async => currentSnapshot;

  @override
  Future<SyncSnapshot> retry({DateTime? now}) async => currentSnapshot;

  @override
  Future<List<SyncConflict>> getConflicts(String accountUid) async => const [];

  @override
  void dispose() {}
}
