import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusbro/repositories/firebase_auth_repository.dart';
import 'package:focusbro/screens/cloud_sync_screen.dart';
import 'package:focusbro/services/cloud_sync_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('offers account registration from the sign-in screen',
      (tester) async {
    final gateway = _FakeFirebaseAuthGateway();
    final service = _createService(gateway);

    await tester.pumpWidget(
      MaterialApp(home: CloudSyncScreen(cloudSync: service)),
    );
    await tester.pump();

    expect(find.text('Sign In to Sync'), findsOneWidget);
    expect(find.text('Create an account'), findsOneWidget);

    await tester.tap(find.text('Create an account'));
    await tester.pump();

    expect(find.text('Create Account'), findsNWidgets(2));
    expect(find.text('Already have an account? Sign in'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    service.dispose();
    await gateway.close();
  });

  testWidgets('shows the incomplete sync scope for an authenticated user',
      (tester) async {
    final gateway = _FakeFirebaseAuthGateway(
      currentUser: const AuthAccount(
        uid: 'firebase-user-1',
        email: 'user@example.com',
      ),
    );
    final service = _createService(gateway);

    await tester.pumpWidget(
      MaterialApp(home: CloudSyncScreen(cloudSync: service)),
    );
    await tester.pump();

    expect(find.text('Signed in as user@example.com.'), findsOneWidget);
    expect(
      find.text(
        'Task records and queued changes can sync. Other data categories '
        'are not yet fully synchronized.',
      ),
      findsOneWidget,
    );
    expect(find.text('Sync Now'), findsOneWidget);
    expect(find.text('Data synced successfully'), findsNothing);
    expect(
      find.textContaining('Account export is unavailable'),
      findsOneWidget,
    );
    expect(find.text('What gets synced:'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    service.dispose();
    await gateway.close();
  });

  testWidgets('updates the screen when Firebase auth state changes',
      (tester) async {
    final gateway = _FakeFirebaseAuthGateway();
    final service = _createService(gateway);

    await tester.pumpWidget(
      MaterialApp(home: CloudSyncScreen(cloudSync: service)),
    );
    await tester.pump();
    expect(find.text('Sign In to Sync'), findsOneWidget);

    gateway.publish(
      const AuthAccount(uid: 'firebase-user-2', email: 'updated@example.com'),
    );
    expect(service.currentUserUid, 'firebase-user-2');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    expect(find.text('Signed in as updated@example.com.'), findsOneWidget);
    expect(find.text('Sign In to Sync'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    service.dispose();
    await gateway.close();
  });
}

CloudSyncService _createService(_FakeFirebaseAuthGateway gateway) {
  return CloudSyncService.forTesting(
    authRepository: FirebaseAuthRepository(gateway: gateway),
  );
}

class _FakeFirebaseAuthGateway implements FirebaseAuthGateway {
  _FakeFirebaseAuthGateway({AuthAccount? currentUser})
      : _currentUser = currentUser;

  final StreamController<AuthAccount?> _authStateController =
      StreamController<AuthAccount?>.broadcast(sync: true);

  AuthAccount? _currentUser;

  @override
  bool get isAvailable => true;

  @override
  AuthAccount? get currentUser => _currentUser;

  @override
  Stream<AuthAccount?> get authStateChanges => _authStateController.stream;

  @override
  Future<AuthAccount> register(String email, String password) async {
    return _setUser();
  }

  @override
  Future<AuthAccount> signIn(String email, String password) async {
    return _setUser();
  }

  AuthAccount _setUser() {
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
    publish(null);
  }

  Future<void> close() => _authStateController.close();
}
