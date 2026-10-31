import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusbro/repositories/firebase_auth_repository.dart';

void main() {
  group('FirebaseAuthRepository', () {
    late _FakeFirebaseAuthGateway gateway;
    late FirebaseAuthRepository repository;

    setUp(() {
      gateway = _FakeFirebaseAuthGateway();
      repository = FirebaseAuthRepository(gateway: gateway);
    });

    tearDown(() => gateway.close());

    test('default gateway stays closed until Firebase bootstrap succeeds',
        () async {
      const defaultRepository = FirebaseAuthRepository();

      expect(defaultRepository.isAvailable, isFalse);
      expect(defaultRepository.currentUser, isNull);
      expect(await defaultRepository.authStateChanges.first, isNull);
      await expectLater(
        defaultRepository.signIn('user@example.com', 'password'),
        throwsA(isA<FirebaseAuthRepositoryException>()),
      );
    });

    test('signs in with trimmed email and an unchanged password', () async {
      final account = await repository.signIn(' user@example.com ', ' pass ');

      expect(account.uid, 'firebase-user-1');
      expect(gateway.lastOperation, 'signIn');
      expect(gateway.lastEmail, 'user@example.com');
      expect(gateway.lastPassword, ' pass ');
    });

    test('registers an account through the Firebase auth gateway', () async {
      final account =
          await repository.register('new@example.com', 'a-strong-password');

      expect(account.uid, 'firebase-user-1');
      expect(gateway.lastOperation, 'register');
    });

    test('converts authentication errors to safe user messages', () async {
      gateway.failure = FirebaseAuthException(
        code: 'wrong-password',
        message: 'Sensitive provider detail',
      );

      await expectLater(
        repository.signIn('user@example.com', 'wrong'),
        throwsA(
          isA<FirebaseAuthRepositoryException>().having(
            (error) => error.message,
            'message',
            'Email or password is incorrect.',
          ),
        ),
      );
    });

    test('does not call Firebase when bootstrap is unavailable', () async {
      gateway.isAvailable = false;

      await expectLater(
        repository.signIn('user@example.com', 'password'),
        throwsA(
          isA<FirebaseAuthRepositoryException>().having(
            (error) => error.message,
            'message',
            'Authentication is unavailable. Local features remain available.',
          ),
        ),
      );
      expect(gateway.lastOperation, isNull);
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
  String? lastEmail;
  String? lastOperation;
  String? lastPassword;

  @override
  AuthAccount? get currentUser => _currentUser;

  @override
  Stream<AuthAccount?> get authStateChanges => _authStateController.stream;

  @override
  Future<AuthAccount> register(String email, String password) {
    return _authenticate('register', email, password);
  }

  @override
  Future<AuthAccount> signIn(String email, String password) {
    return _authenticate('signIn', email, password);
  }

  Future<AuthAccount> _authenticate(
    String operation,
    String email,
    String password,
  ) async {
    lastOperation = operation;
    lastEmail = email;
    lastPassword = password;
    if (failure case final error?) throw error;

    _currentUser = const AuthAccount(
      uid: 'firebase-user-1',
      email: 'user@example.com',
    );
    _authStateController.add(_currentUser);
    return _currentUser!;
  }

  @override
  Future<void> signOut() async {
    _currentUser = null;
    _authStateController.add(null);
  }

  Future<void> close() => _authStateController.close();
}
