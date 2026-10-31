import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:focusbro/screens/cloud_sync_screen.dart';
import 'package:focusbro/services/app_lock_service.dart';
import 'package:focusbro/services/backup_service.dart';
import 'package:focusbro/services/cloud_sync_service.dart';
import 'package:focusbro/services/database_helper.dart';
import 'package:focusbro/services/note_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> waitFor(
    WidgetTester tester,
    Finder finder, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (finder.evaluate().isEmpty && DateTime.now().isBefore(deadline)) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    expect(finder, findsWidgets);
  }

  testWidgets('Android core runtime services stay healthy', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await prefs.setBool('has_seen_onboarding', true);
    await prefs.setBool('show_onboarding', false);

    final db = DatabaseHelper();
    await db.clearAllNotes();

    final noteService = NoteService();
    await noteService.initialize();
    await noteService.clearAllNotes();

    final note = await noteService.createNote(
      title: 'Android core smoke note',
      content: 'Runtime backup and restore smoke content',
      category: 'QA',
      tags: const ['android', 'smoke'],
    );
    expect(
      (await db.getAllNotes()).any((item) => item['id'] == note.id),
      isTrue,
    );

    final backup = await BackupService.instance.createBackup();
    expect(backup.success, isTrue);
    expect(backup.filePath, isNotNull);
    final backupFile = File(backup.filePath!);
    expect(await backupFile.exists(), isTrue);
    expect(await backupFile.length(), greaterThan(0));

    await noteService.deleteNote(note.id);
    expect(
      (await db.getAllNotes()).any((item) => item['id'] == note.id),
      isFalse,
    );

    final restored = await BackupService.instance.restoreFromBackup(
      filePath: backupFile.path,
    );
    expect(restored.success, isTrue);
    expect(
      (await db.getAllNotes()).any((item) => item['id'] == note.id),
      isTrue,
    );

    final appLock = AppLockService.instance;
    await appLock.resetForTesting();
    await appLock.initialize();
    await appLock.disableAppLock();
    expect(await appLock.setPIN('2468'), isTrue);
    expect(await appLock.enableAppLock('pin'), isTrue);
    appLock.lockApp();
    expect(appLock.isLocked, isTrue);
    expect(await appLock.unlockWithPIN('0000'), isFalse);
    expect(appLock.isLocked, isTrue);
    expect(await appLock.unlockWithPIN('2468'), isTrue);
    expect(appLock.isLocked, isFalse);
    await appLock.setLockTimeout(0);
    appLock.checkLockStatus();
    expect(appLock.isLocked, isTrue);
    expect(await appLock.disableAppLock(), isTrue);

    final cloudSync = CloudSyncService();
    await cloudSync.resetForTesting();
    await cloudSync.initialize();
    await cloudSync.configureBackend(
      provider: CloudSyncBackendProvider.localSnapshot,
    );
    await cloudSync.signOut();
    expect(cloudSync.isAuthenticated, isFalse);
    expect(await cloudSync.forceSyncNow(), isFalse);

    await tester.pumpWidget(
      const MaterialApp(
        home: CloudSyncScreen(),
      ),
    );
    await waitFor(tester, find.text('Cloud Sync'));
    await waitFor(tester, find.text('Sign In to Sync'));
    await waitFor(tester, find.text('Local Snapshot setup needed'));

    await db.clearAllNotes();
    if (await backupFile.exists()) {
      await backupFile.delete();
    }
  });
}
