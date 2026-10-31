import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:focusbro/services/app_lock_service.dart';
import 'package:focusbro/services/backup_service.dart';
import 'package:focusbro/services/database_helper.dart';
import 'package:focusbro/services/note_service.dart';
import 'package:focusbro/services/notification_blocking_service.dart';
import 'package:focusbro/services/social_media_blocking_service.dart';

Future<bool> waitForCondition(
  Future<bool> Function() condition, {
  Duration timeout = const Duration(seconds: 45),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (await condition()) {
      return true;
    }
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }
  return condition();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Android Wave 3 protected local flows work', (tester) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.clear();

    final notificationBlocking = NotificationBlockingService();
    await notificationBlocking.initialize();
    await notificationBlocking.setDoNotDisturbEnabled(true);
    expect(
      await waitForCondition(notificationBlocking.hasNotificationAccess),
      isTrue,
    );
    expect(await notificationBlocking.enableBlocking(), isTrue);
    expect(notificationBlocking.isBlocking, isTrue);
    expect(await notificationBlocking.disableBlocking(), isTrue);
    expect(notificationBlocking.isBlocking, isFalse);

    final socialBlocking = SocialMediaBlockingService();
    await socialBlocking.initialize();
    await socialBlocking.setAppBlockingEnabled(true);
    await socialBlocking.setWebsiteBlockingEnabled(false);
    await socialBlocking.setOverlayEnabled(false);
    expect(
      await waitForCondition(socialBlocking.hasAccessibilityPermission),
      isTrue,
    );
    expect(await socialBlocking.enableBlocking(), isTrue);
    expect(socialBlocking.isBlocking, isTrue);
    expect(await socialBlocking.disableBlocking(), isTrue);
    expect(socialBlocking.isBlocking, isFalse);

    final appLock = AppLockService.instance;
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

    final noteService = NoteService();
    await noteService.initialize();
    final note = await noteService.createNote(
      title: 'Android Wave 3 backup note',
      content: 'Restored from a local FocusBro backup',
      category: 'Work',
    );

    final backup = await BackupService.instance.createBackup();
    expect(backup.success, isTrue);
    expect(backup.filePath, isNotNull);
    final backupFile = File(backup.filePath!);
    expect(await backupFile.exists(), isTrue);
    expect(await backupFile.length(), greaterThan(0));

    await noteService.deleteNote(note.id);
    expect(
      (await DatabaseHelper().getAllNotes())
          .any((item) => item['id'] == note.id),
      isFalse,
    );

    final restored = await BackupService.instance.restoreFromBackup(
      filePath: backupFile.path,
    );
    expect(restored.success, isTrue);
    expect(
      (await DatabaseHelper().getAllNotes())
          .any((item) => item['id'] == note.id),
      isTrue,
    );

    await DatabaseHelper().clearAllNotes();
    if (await backupFile.exists()) {
      await backupFile.delete();
    }
  });
}
