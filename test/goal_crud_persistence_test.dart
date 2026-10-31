import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusbro/models/goal.dart';
import 'package:focusbro/providers/goal_provider.dart';
import 'package:focusbro/services/database_helper.dart';
import 'package:focusbro/services/goal_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
  final databaseDirectory =
      Directory('${Directory.systemTemp.path}/focusbro_goal_crud_test');

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await databaseDirectory.create(recursive: true);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (call) async {
      if (call.method == 'getApplicationDocumentsDirectory') {
        return databaseDirectory.path;
      }
      return null;
    });
    await DatabaseHelper().deleteDatabase();
  });

  tearDownAll(() async {
    await DatabaseHelper().close();
    final databaseFile = File('${databaseDirectory.path}/focusbro.db');
    if (await databaseFile.exists()) {
      await databaseFile.delete();
    }
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
  });

  test('goal CRUD, progress, reopen, and provider restart persist', () async {
    final service = GoalService();
    await service.initialize();
    final initialCount = service.goals.length;

    final created = await service.createGoal(
      title: 'Complete Wave 1',
      type: GoalType.custom,
      targetValue: 5,
      customUnit: 'flows',
    );
    expect(service.goals.length, initialCount + 1);

    final completed = await service.updateGoalProgress(created.id, 5);
    expect(completed.status, GoalStatus.completed);
    expect(completed.completedAt, isNotNull);

    final reopened = await service.updateGoalProgress(created.id, 2);
    expect(reopened.status, GoalStatus.active);
    expect(reopened.completedAt, isNull);

    final edited = await service.updateGoal(
      reopened.copyWith(
        title: 'Complete Android Wave 1',
        endDate: DateTime(2026, 7, 1),
      ),
    );
    expect(edited.title, 'Complete Android Wave 1');

    final restartedProvider = GoalProvider(goalService: service);
    await restartedProvider.initialize();
    expect(restartedProvider.getGoalById(created.id)?.title,
        'Complete Android Wave 1');
    expect(restartedProvider.getGoalById(created.id)?.currentValue, 2);

    expect(await restartedProvider.deleteGoal(created.id), isTrue);
    expect(restartedProvider.getGoalById(created.id), isNull);

    restartedProvider.dispose();
  });
}
