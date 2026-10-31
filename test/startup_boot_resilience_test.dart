import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:focusbro/services/startup_initialization_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('provider startup continues when a non-critical step fails', () async {
    final executed = <String>[];

    await const StartupInitializationService().runSteps([
      StartupInitializationStep(
        name: 'LanguageProvider',
        timeout: const Duration(milliseconds: 200),
        action: () async {
          executed.add('LanguageProvider');
        },
      ),
      StartupInitializationStep(
        name: 'NoteProvider',
        timeout: const Duration(milliseconds: 200),
        isCritical: false,
        action: () async {
          executed.add('NoteProvider');
          throw Exception('simulated note provider failure');
        },
      ),
      StartupInitializationStep(
        name: 'TaskProvider',
        timeout: const Duration(milliseconds: 200),
        action: () async {
          executed.add('TaskProvider');
        },
      ),
    ]);

    expect(executed, ['LanguageProvider', 'NoteProvider', 'TaskProvider']);
  });
}
