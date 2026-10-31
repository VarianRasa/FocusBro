import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusbro/services/cloud_sync_service.dart';
import 'package:focusbro/services/database_helper.dart';
import 'package:focusbro/services/task_service.dart';
import 'package:focusbro/firebase_options.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Firebase sync propagates local and remote deletions',
      (tester) async {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }

    await FirebaseAuth.instance.useAuthEmulator('10.0.2.2', 9099);
    FirebaseFirestore.instance.useFirestoreEmulator('10.0.2.2', 8080);
    await FirebaseAuth.instance.signOut();

    await DatabaseHelper().deleteDatabase();
    final taskService = TaskService();
    await taskService.resetForTests();
    await taskService.initialize();

    final cloudSync = CloudSyncService();
    await cloudSync.resetForTesting();
    await cloudSync.initialize();
    await cloudSync.configureBackend(
      provider: CloudSyncBackendProvider.firebase,
    );

    final email =
        'firebase-sync-${DateTime.now().microsecondsSinceEpoch}@example.test';
    final signedIn = await cloudSync.signIn(email, 'FocusBro123!');
    expect(signedIn, isTrue, reason: cloudSync.lastStatusMessage);

    final uid = FirebaseAuth.instance.currentUser!.uid;
    final taskCollection = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('sync')
        .doc('v1')
        .collection('tasks');

    final locallyDeletedTask = await taskService.createTask(
      title: 'Local deletion sync',
    );
    expect(await cloudSync.forceSyncNow(), isTrue);
    expect((await taskCollection.get()).docs, hasLength(1));

    await taskService.deleteTask(locallyDeletedTask.id);
    expect(await cloudSync.forceSyncNow(), isTrue);
    expect((await taskCollection.get()).docs, isEmpty);

    final remotelyDeletedTask = await taskService.createTask(
      title: 'Remote deletion sync',
    );
    expect(await cloudSync.forceSyncNow(), isTrue);
    expect((await taskCollection.get()).docs, hasLength(1));

    final remoteDocuments = await taskCollection.get();
    await remoteDocuments.docs.single.reference.delete();
    expect(await cloudSync.forceSyncNow(), isTrue);
    expect(taskService.tasks.map((task) => task.id),
        isNot(contains(remotelyDeletedTask.id)));
    expect((await DatabaseHelper().getAllTasks()).map((task) => task['id']),
        isNot(contains(remotelyDeletedTask.id)));
  });
}
