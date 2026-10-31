import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:focusbro/models/focus_session.dart';
import 'package:focusbro/models/task.dart';
import 'package:focusbro/models/note.dart';
import 'test_database_helper.dart';

void main() {
  // Initialize FFI for testing
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Database Model Tests', () {
    setUp(() async {
      await TestDatabaseHelper.reset();
    });

    tearDown(() async {
      await TestDatabaseHelper.close();
    });

    test('Database initialization creates tables', () async {
      final db = await TestDatabaseHelper.database;
      expect(db, isNotNull);

      // Check if tables exist by querying them
      final tables = await db
          .rawQuery("SELECT name FROM sqlite_master WHERE type='table'");

      final tableNames = tables.map((table) => table['name']).toList();
      expect(tableNames, contains('focus_sessions'));
      expect(tableNames, contains('tasks'));
      expect(tableNames, contains('notes'));
      expect(tableNames, contains('focus_statistics'));
    });

    test('Focus session model serialization', () async {
      final now = DateTime.now();
      final session = FocusSession(
        sessionDate: now,
        workDuration: 1500, // 25 minutes
        breakDuration: 300, // 5 minutes
        totalDuration: 1800, // 30 minutes
        sessionType: 'work',
        completed: true,
        createdAt: now,
        updatedAt: now,
      );

      // Test toMap
      final map = session.toMap();
      expect(map['work_duration'], equals(1500));
      expect(map['break_duration'], equals(300));
      expect(map['total_duration'], equals(1800));
      expect(map['session_type'], equals('work'));
      expect(map['completed'], equals(1));

      // Test fromMap
      final recreatedSession = FocusSession.fromMap(map);
      expect(recreatedSession.workDuration, equals(session.workDuration));
      expect(recreatedSession.breakDuration, equals(session.breakDuration));
      expect(recreatedSession.totalDuration, equals(session.totalDuration));
      expect(recreatedSession.sessionType, equals(session.sessionType));
      expect(recreatedSession.completed, equals(session.completed));
    });

    test('Task model serialization', () async {
      final now = DateTime.now();
      final task = Task(
        id: 'test-task-1',
        title: 'Test Task',
        description: 'This is a test task',
        category: 'Work',
        priority: TaskPriority.high,
        dueDate: now.add(const Duration(days: 1)),
        isCompleted: false,
        isFavorite: false,
        createdAt: now,
        updatedAt: now,
      );

      // Test toMap
      final map = task.toMap();
      expect(map['id'], equals('test-task-1'));
      expect(map['title'], equals('Test Task'));
      expect(map['category'], equals('Work'));
      expect(map['priority'], equals(TaskPriority.high.index));
      expect(map['is_completed'], equals(0));
      expect(map['is_favorite'], equals(0));

      // Test fromMap
      final recreatedTask = Task.fromMap(map);
      expect(recreatedTask.id, equals(task.id));
      expect(recreatedTask.title, equals(task.title));
      expect(recreatedTask.category, equals(task.category));
      expect(recreatedTask.priority, equals(task.priority));
      expect(recreatedTask.isCompleted, equals(task.isCompleted));
      expect(recreatedTask.isFavorite, equals(task.isFavorite));
    });

    test('Note model serialization', () async {
      final now = DateTime.now();
      final note = Note(
        id: 'test-note-1',
        title: 'Test Note',
        content: 'This is a test note content',
        category: 'Personal',
        isFavorite: false,
        createdAt: now,
        updatedAt: now,
      );

      // Test toMap
      final map = note.toMap();
      expect(map['id'], equals('test-note-1'));
      expect(map['title'], equals('Test Note'));
      expect(map['content'], equals('This is a test note content'));
      expect(map['category'], equals('Personal'));
      expect(map['is_favorite'], equals(0));

      // Test fromMap
      final recreatedNote = Note.fromMap(map);
      expect(recreatedNote.id, equals(note.id));
      expect(recreatedNote.title, equals(note.title));
      expect(recreatedNote.content, equals(note.content));
      expect(recreatedNote.category, equals(note.category));
      expect(recreatedNote.isFavorite, equals(note.isFavorite));
    });
  });
}
