import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:focusbro/models/goal.dart';
import 'package:focusbro/models/note.dart';
import 'package:focusbro/services/cloud_sync_service.dart';
import 'package:focusbro/services/database_helper.dart';
import 'package:focusbro/services/goal_service.dart';
import 'package:focusbro/services/note_service.dart';
import 'package:focusbro/services/task_service.dart';
import 'package:focusbro/utils/cache_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    CacheManager.disableExpirationTimers = true;
    await CloudSyncService().resetForTesting();
    await DatabaseHelper().deleteDatabase();
    await TaskService().resetForTests();
    await NoteService().clearAllNotes();
    final database = await DatabaseHelper().database;
    await database.delete('goals');
    await GoalService().refreshGoals();
    await CacheManager().clearAllCache();
  });

  tearDown(() async {
    await CloudSyncService().signOut();
    await TaskService().resetForTests();
    await NoteService().clearAllNotes();
    final database = await DatabaseHelper().database;
    await database.delete('goals');
    await DatabaseHelper().close();
    CacheManager().cancelAllExpirationTimers();
    CacheManager.disableExpirationTimers = false;
  });

  test('remote note deletion refreshes NoteService runtime state', () async {
    final noteService = NoteService();
    await noteService.initialize();
    final note = Note(
      id: 'remote-note-delete',
      title: 'Remote note',
      content: 'Delete this remotely',
      category: 'Work',
      createdAt: DateTime(2026, 1, 2, 12),
      updatedAt: DateTime(2026, 1, 2, 12),
    );
    final cloudSync = await _authenticatedLocalCloudSync();

    await _seedCloud('cloud_notes_snapshot_v1', [note.toMap()]);
    expect(await cloudSync.forceSyncNow(), isTrue);
    expect(noteService.notes.map((item) => item.id), contains(note.id));

    await _seedCloud('cloud_notes_snapshot_v1', const []);
    expect(await cloudSync.forceSyncNow(), isTrue);

    expect(noteService.notes.map((item) => item.id), isNot(contains(note.id)));
    expect(
      (await DatabaseHelper().getAllNotes()).map((item) => item['id']),
      isNot(contains(note.id)),
    );
  });

  test('remote goal deletion refreshes GoalService runtime state', () async {
    final goalService = GoalService();
    await goalService.initialize();
    final goal = Goal(
      id: 'remote-goal-delete',
      title: 'Remote goal',
      type: GoalType.custom,
      targetValue: 1,
      createdAt: DateTime(2026, 1, 2, 12),
      updatedAt: DateTime(2026, 1, 2, 12),
    );
    final cloudSync = await _authenticatedLocalCloudSync();

    await _seedCloud('cloud_goals_snapshot_v1', [goal.toMap()]);
    expect(await cloudSync.forceSyncNow(), isTrue);
    expect(goalService.goals.map((item) => item.id), contains(goal.id));

    await _seedCloud('cloud_goals_snapshot_v1', const []);
    expect(await cloudSync.forceSyncNow(), isTrue);

    expect(goalService.goals.map((item) => item.id), isNot(contains(goal.id)));
    expect(
      (await DatabaseHelper().getAllGoals()).map((item) => item['id']),
      isNot(contains(goal.id)),
    );
  });
}

Future<CloudSyncService> _authenticatedLocalCloudSync() async {
  final preferences = await SharedPreferences.getInstance();
  await preferences.setString('user_id', 'local-runtime-refresh-user');
  await preferences.setString(
    'cloud_sync_backend_provider',
    CloudSyncBackendProvider.localSnapshot.name,
  );
  final cloudSync = CloudSyncService();
  await cloudSync.initialize();
  return cloudSync;
}

Future<void> _seedCloud(
  String key,
  List<Map<String, dynamic>> items,
) async {
  final preferences = await SharedPreferences.getInstance();
  await preferences.setString(
    key,
    jsonEncode({
      'updatedAt': DateTime(2026, 1, 3).toIso8601String(),
      'userId': 'local-runtime-refresh-user',
      'items': items,
    }),
  );
}
