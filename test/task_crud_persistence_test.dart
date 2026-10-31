import 'package:flutter_test/flutter_test.dart';
import 'package:focusbro/models/task_model.dart';
import 'package:focusbro/providers/task_provider.dart';
import 'package:focusbro/services/task_service.dart';
import 'package:focusbro/utils/cache_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TaskProvider provider;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await CacheManager().clearAllCache();
    await TaskService().resetForTests();
    provider = TaskProvider();
    await provider.initialize();
  });

  tearDown(() async {
    await TaskService().resetForTests();
    provider.dispose();
  });

  test('task CRUD and Agenda state survive provider reinitialization',
      () async {
    final now = DateTime.now();
    final created = await provider.createTask(
      title: 'Wave 1 task',
      description: 'Initial description',
      priority: TaskPriority.high,
      category: TaskCategory.work,
      dueDate: DateTime(now.year, now.month, now.day, 12),
    );

    expect(created, isNotNull);
    expect(provider.tasksDueToday.single.id, created!.id);

    final updated = await provider.updateTask(
      created.copyWith(
        title: 'Wave 1 task edited',
        description: 'Edited description',
        dueDate: null,
      ),
    );
    expect(updated?.title, 'Wave 1 task edited');
    expect(updated?.dueDate, isNull);

    expect(await provider.completeTask(created.id), isTrue);
    expect(provider.completedTasks.single.completedAt, isNotNull);

    expect(await provider.toggleTaskCompletion(created.id), isTrue);
    expect(provider.tasks.single.status, TaskStatus.todo);
    expect(provider.tasks.single.completedAt, isNull);

    await provider.forceReinitialize();
    expect(provider.tasks.single.title, 'Wave 1 task edited');
    expect(provider.tasks.single.status, TaskStatus.todo);
    expect(provider.tasks.single.completedAt, isNull);
    expect(provider.tasks.single.dueDate, isNull);

    expect(await provider.deleteTask(created.id), isTrue);
    await provider.forceReinitialize();
    expect(provider.tasks, isEmpty);
  });
}
