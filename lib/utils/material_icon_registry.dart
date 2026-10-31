import 'package:flutter/material.dart';

class MaterialIconRegistry {
  static const String taskFallbackKey = 'task';
  static const String achievementFallbackKey = 'emoji_events';

  static const Map<String, IconData> iconsByKey = {
    taskFallbackKey: Icons.task,
    achievementFallbackKey: Icons.emoji_events,
    'groups': Icons.groups,
    'code': Icons.code,
    'fitness_center': Icons.fitness_center,
    'school': Icons.school,
    'email': Icons.email,
    'restaurant': Icons.restaurant,
    'work': Icons.work,
    'person': Icons.person,
    'favorite': Icons.favorite,
    'shopping_cart': Icons.shopping_cart,
    'category': Icons.category,
    'timer': Icons.timer,
    'star': Icons.star,
    'flag': Icons.flag,
    'local_fire_department': Icons.local_fire_department,
    'workspace_premium': Icons.workspace_premium,
  };

  static final Map<int, String> _keysByCodePoint = {
    for (final entry in iconsByKey.entries) entry.value.codePoint: entry.key,
  };

  static IconData byKey(String? key, {String fallbackKey = taskFallbackKey}) {
    return iconsByKey[key] ?? iconsByKey[fallbackKey] ?? Icons.task;
  }

  static IconData byCodePoint(
    Object? codePoint, {
    String fallbackKey = taskFallbackKey,
  }) {
    final parsedCodePoint = _readInt(codePoint);
    return byKey(_keysByCodePoint[parsedCodePoint], fallbackKey: fallbackKey);
  }

  static IconData fromJson(
    Map<String, dynamic> json, {
    String fallbackKey = taskFallbackKey,
  }) {
    final key = json['iconKey'];
    if (key is String && iconsByKey.containsKey(key)) {
      return iconsByKey[key]!;
    }

    return byCodePoint(json['iconCodePoint'], fallbackKey: fallbackKey);
  }

  static String keyFor(
    IconData icon, {
    String fallbackKey = taskFallbackKey,
  }) {
    for (final entry in iconsByKey.entries) {
      if (entry.value.codePoint == icon.codePoint &&
          entry.value.fontFamily == icon.fontFamily &&
          entry.value.fontPackage == icon.fontPackage) {
        return entry.key;
      }
    }

    return fallbackKey;
  }

  static int? _readInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}
