import 'package:flutter_test/flutter_test.dart';
import 'package:focusbro/services/startup_initialization_service.dart';

void main() {
  group('StartupInitializationService', () {
    const service = StartupInitializationService();

    test('continues when non-critical step fails', () async {
      final executed = <String>[];

      await service.runSteps([
        StartupInitializationStep(
          name: 'step-1',
          timeout: const Duration(milliseconds: 200),
          action: () async {
            executed.add('step-1');
          },
        ),
        StartupInitializationStep(
          name: 'step-2',
          timeout: const Duration(milliseconds: 200),
          isCritical: false,
          action: () async {
            executed.add('step-2');
            throw Exception('non-critical failure');
          },
        ),
        StartupInitializationStep(
          name: 'step-3',
          timeout: const Duration(milliseconds: 200),
          action: () async {
            executed.add('step-3');
          },
        ),
      ]);

      expect(executed, ['step-1', 'step-2', 'step-3']);
    });

    test('throws when critical step fails', () async {
      final executed = <String>[];

      await expectLater(
        () => service.runSteps([
          StartupInitializationStep(
            name: 'step-1',
            timeout: const Duration(milliseconds: 200),
            action: () async {
              executed.add('step-1');
            },
          ),
          StartupInitializationStep(
            name: 'step-2',
            timeout: const Duration(milliseconds: 200),
            action: () async {
              executed.add('step-2');
              throw Exception('critical failure');
            },
          ),
          StartupInitializationStep(
            name: 'step-3',
            timeout: const Duration(milliseconds: 200),
            action: () async {
              executed.add('step-3');
            },
          ),
        ]),
        throwsException,
      );

      expect(executed, ['step-1', 'step-2']);
    });

    test('treats timeout as failure and continues for non-critical step',
        () async {
      final executed = <String>[];

      await service.runSteps([
        StartupInitializationStep(
          name: 'slow-step',
          timeout: const Duration(milliseconds: 20),
          isCritical: false,
          action: () async {
            executed.add('slow-step');
            await Future<void>.delayed(const Duration(milliseconds: 100));
          },
        ),
        StartupInitializationStep(
          name: 'next-step',
          timeout: const Duration(milliseconds: 200),
          action: () async {
            executed.add('next-step');
          },
        ),
      ]);

      expect(executed, ['slow-step', 'next-step']);
    });
  });
}
