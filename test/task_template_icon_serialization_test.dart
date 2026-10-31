import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusbro/models/task_model.dart';
import 'package:focusbro/models/task_template.dart';

void main() {
  group('TaskTemplate icon serialization', () {
    test('reads legacy icon code points as constant Material icons', () {
      final template = TaskTemplate.fromJson({
        'id': 'legacy-code-review',
        'name': 'Code Review',
        'description': 'Review pull requests',
        'priority': TaskPriority.high.name,
        'category': TaskCategory.work.name,
        'tags': <String>['code'],
        'estimatedFocusSessions': 2,
        'estimatedDuration': 45,
        'iconCodePoint': Icons.code.codePoint,
        'colorValue': Colors.green.toARGB32(),
        'isBuiltIn': true,
        'createdAt': DateTime(2026, 1, 1).toIso8601String(),
      });

      expect(template.icon, same(Icons.code));
      expect(template.toJson()['iconKey'], 'code');
    });

    test('falls back to task icon for unknown persisted icons', () {
      final template = TaskTemplate.fromJson({
        'id': 'unknown-icon',
        'name': 'Unknown Icon',
        'description': 'Uses a missing icon',
        'priority': TaskPriority.medium.name,
        'category': TaskCategory.other.name,
        'tags': <String>[],
        'estimatedFocusSessions': 1,
        'iconCodePoint': 123456,
        'colorValue': Colors.blue.toARGB32(),
        'isBuiltIn': false,
        'createdAt': DateTime(2026, 1, 1).toIso8601String(),
      });

      expect(template.icon, same(Icons.task));
      expect(template.toJson()['iconKey'], 'task');
    });
  });
}
