import 'package:firebase_auth/firebase_auth.dart';

import '../services/firebase_emulator_config.dart';

class AuthAccount {
  const AuthAccount({required this.uid, this.email});

  final String uid;
  final String? email;
}

abstract interface class AuthRepository {
  bool get isAvailable;
  AuthAccount? get currentUser;
  Stream<AuthAccount?> get authStateChanges;

  Future<AuthAccount> register(String email, String password);
  Future<AuthAccount> signIn(String email, String password);
  Future<void> signOut();
}

abstract interface class FirebaseAuthGateway {
  bool get isAvailable;
  AuthAccount? get currentUser;
  Stream<AuthAccount?> get authStateChanges;

  Future<AuthAccount> register(String email, String password);
  Future<AuthAccount> signIn(String email, String password);
  Future<void> signOut();
}

class FirebaseAuthRepository implements AuthRepository {
  const FirebaseAuthRepository({FirebaseAuthGateway? gateway})
      : _gateway = gateway ?? const FirebaseAuthSdkGateway();

  final FirebaseAuthGateway _gateway;

  @override
  bool get isAvailable => _gateway.isAvailable;

  @override
  AuthAccount? get currentUser => isAvailable ? _gateway.currentUser : null;

  @override
  Stream<AuthAccount?> get authStateChanges => isAvailable
      ? _gateway.authStateChanges
      : Stream<AuthAccount?>.value(null);

  @override
  Future<AuthAccount> register(String email, String password) {
    return _runAuth(() => _gateway.register(email.trim(), password));
  }

  @override
  Future<AuthAccount> signIn(String email, String password) {
    return _runAuth(() => _gateway.signIn(email.trim(), password));
  }

  @override
  Future<void> signOut() async {
    _ensureAvailable();
    try {
      await _gateway.signOut();
    } on FirebaseAuthException catch (error) {
      throw FirebaseAuthRepositoryException(_messageForCode(error.code));
    } on FirebaseException {
      throw const FirebaseAuthRepositoryException(
        'Authentication is unavailable. Local features remain available.',
      );
    }
  }

  Future<AuthAccount> _runAuth(Future<AuthAccount> Function() action) async {
    _ensureAvailable();
    try {
      return await action();
    } on FirebaseAuthException catch (error) {
      throw FirebaseAuthRepositoryException(_messageForCode(error.code));
    } on FirebaseException {
      throw const FirebaseAuthRepositoryException(
        'Authentication is unavailable. Local features remain available.',
      );
    }
  }

  void _ensureAvailable() {
    if (!isAvailable) {
      throw const FirebaseAuthRepositoryException(
        'Authentication is unavailable. Local features remain available.',
      );
    }
  }

  String _messageForCode(String code) {
    return switch (code) {
      'invalid-email' => 'Enter a valid email address.',
      'email-already-in-use' => 'An account already exists for this email.',
      'weak-password' => 'Choose a stronger password.',
      'user-not-found' ||
      'wrong-password' ||
      'invalid-credential' =>
        'Email or password is incorrect.',
      'user-disabled' => 'This account is disabled. Contact support for help.',
      'too-many-requests' => 'Too many attempts. Try again later.',
      'network-request-failed' =>
        'Could not connect. Check your connection and try again.',
      'operation-not-allowed' =>
        'Email and password authentication is not enabled.',
      _ => 'Authentication failed. Check your details and try again.',
    };
  }
}

class FirebaseAuthSdkGateway implements FirebaseAuthGateway {
  const FirebaseAuthSdkGateway();

  @override
  bool get isAvailable => FirebaseEmulatorConfig.isFirebaseReady;

  FirebaseAuth get _auth => FirebaseAuth.instance;

  @override
  AuthAccount? get currentUser {
    if (!isAvailable) return null;
    final user = _auth.currentUser;
    return user == null ? null : _toAccount(user);
  }

  @override
  Stream<AuthAccount?> get authStateChanges {
    if (!isAvailable) return Stream<AuthAccount?>.value(null);
    return _auth.authStateChanges().map(
          (user) => user == null ? null : _toAccount(user),
        );
  }

  @override
  Future<AuthAccount> register(String email, String password) async {
    _ensureAvailable();
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = credential.user;
    if (user == null) {
      throw const FirebaseAuthRepositoryException(
        'Account creation did not return a user.',
      );
    }
    return _toAccount(user);
  }

  @override
  Future<AuthAccount> signIn(String email, String password) async {
    _ensureAvailable();
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = credential.user;
    if (user == null) {
      throw const FirebaseAuthRepositoryException(
        'Sign-in did not return a user.',
      );
    }
    return _toAccount(user);
  }

  @override
  Future<void> signOut() async {
    _ensureAvailable();
    await _auth.signOut();
  }

  void _ensureAvailable() {
    if (!isAvailable) {
      throw const FirebaseAuthRepositoryException(
        'Authentication is unavailable. Local features remain available.',
      );
    }
  }

  AuthAccount _toAccount(User user) => AuthAccount(
        uid: user.uid,
        email: user.email,
      );
}

class FirebaseAuthRepositoryException implements Exception {
  const FirebaseAuthRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}
