import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:focusbro/models/task_model.dart';
import 'package:focusbro/services/task_active_focus_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('validateAgainstTasks clears invalid active focus task', () async {
    final store = TaskActiveFocusStore();
    await store.save('missing-task');

    final validated = store.validateAgainstTasks(
      'missing-task',
      [
        _task(id: 'other', title: 'Other'),
      ],
    );

    expect(validated, isNull);
    expect(await store.load(), isNull);
  });

  test('save and load round-trip active focus task id', () async {
    final store = TaskActiveFocusStore();
    await store.save('task-1');

    expect(await store.load(), 'task-1');
    await store.clear();
    expect(await store.load(), isNull);
  });
}

Task _task({required String id, required String title}) {
  final createdAt = DateTime(2026, 5, 1);
  return Task(
    id: id,
    title: title,
    createdAt: createdAt,
    updatedAt: createdAt,
  );
}
