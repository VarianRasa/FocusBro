import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusbro/models/achievement.dart';

void main() {
  group('Achievement icon serialization', () {
    test('resolves stored Material icon metadata to a constant icon', () {
      final achievement = Achievement.fromMap({
        'id': 'first_session',
        'title': 'First Session',
        'description': 'Complete one focus session',
        'icon_code_point': Icons.emoji_events.codePoint,
        'icon_font_family': 'MaterialIcons',
        'achievement_type': 'focus_sessions',
        'target_value': 1,
        'created_at': DateTime(2026, 1, 1).toIso8601String(),
      });

      expect(achievement.icon, same(Icons.emoji_events));
    });

    test('falls back to trophy icon for unknown icon metadata', () {
      final achievement = Achievement.fromMap({
        'id': 'unknown_icon',
        'title': 'Unknown Icon',
        'description': 'Uses unknown icon metadata',
        'icon_code_point': 123456,
        'icon_font_family': 'MaterialIcons',
        'achievement_type': 'focus_sessions',
        'target_value': 1,
        'created_at': DateTime(2026, 1, 1).toIso8601String(),
      });

      expect(achievement.icon, same(Icons.emoji_events));
    });
  });
}
