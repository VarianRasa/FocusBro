import 'package:flutter/material.dart';
import 'base_model.dart';

class Achievement extends BaseModel {
  final String id;
  final String title;
  final String description;
  final int iconCodePoint;
  final String? iconFontFamily;
  final String achievementType;
  final int? targetValue;
  final DateTime createdAt;
  bool isUnlocked;

  Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.iconCodePoint,
    this.iconFontFamily,
    required this.achievementType,
    this.targetValue,
    required this.createdAt,
    this.isUnlocked = false,
  });

  @override
  String get tableName => 'achievements';

  @override
  String get primaryKey => 'id';

  @override
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'icon_code_point': iconCodePoint,
      'icon_font_family': iconFontFamily,
      'achievement_type': achievementType,
      'target_value': targetValue,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Achievement.fromMap(Map<String, dynamic> map) {
    return Achievement(
      id: map['id'],
      title: map['title'],
      description: map['description'],
      iconCodePoint: map['icon_code_point'],
      iconFontFamily: map['icon_font_family'],
      achievementType: map['achievement_type'],
      targetValue: map['target_value'],
      createdAt: DateTime.parse(map['created_at']),
      isUnlocked: false, // Will be set by UserAchievement
    );
  }

  IconData get icon {
    return IconData(
      iconCodePoint,
      fontFamily: iconFontFamily,
    );
  }

  Achievement copyWith({
    String? id,
    String? title,
    String? description,
    int? iconCodePoint,
    String? iconFontFamily,
    String? achievementType,
    int? targetValue,
    DateTime? createdAt,
    bool? isUnlocked,
  }) {
    return Achievement(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      iconFontFamily: iconFontFamily ?? this.iconFontFamily,
      achievementType: achievementType ?? this.achievementType,
      targetValue: targetValue ?? this.targetValue,
      createdAt: createdAt ?? this.createdAt,
      isUnlocked: isUnlocked ?? this.isUnlocked,
    );
  }
}

class UserAchievement extends BaseModel {
  final int? id;
  final String achievementId;
  final DateTime unlockedAt;
  final int progress;

  UserAchievement({
    this.id,
    required this.achievementId,
    required this.unlockedAt,
    this.progress = 0,
  });

  @override
  String get tableName => 'user_achievements';

  @override
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'achievement_id': achievementId,
      'unlocked_at': unlockedAt.toIso8601String(),
      'progress': progress,
    };

    if (id != null) {
      map['id'] = id;
    }

    return map;
  }

  factory UserAchievement.fromMap(Map<String, dynamic> map) {
    return UserAchievement(
      id: map['id'],
      achievementId: map['achievement_id'],
      unlockedAt: DateTime.parse(map['unlocked_at']),
      progress: map['progress'] ?? 0,
    );
  }

  UserAchievement copyWith({
    int? id,
    String? achievementId,
    DateTime? unlockedAt,
    int? progress,
  }) {
    return UserAchievement(
      id: id ?? this.id,
      achievementId: achievementId ?? this.achievementId,
      unlockedAt: unlockedAt ?? this.unlockedAt,
      progress: progress ?? this.progress,
    );
  }
}

class Reward extends BaseModel {
  final String id;
  final String title;
  final String description;
  final int requiredStreak;
  final bool isUnlocked;
  final DateTime? unlockedAt;
  final DateTime createdAt;

  Reward({
    required this.id,
    required this.title,
    required this.description,
    required this.requiredStreak,
    this.isUnlocked = false,
    this.unlockedAt,
    required this.createdAt,
  });

  @override
  String get tableName => 'rewards';

  @override
  String get primaryKey => 'id';

  @override
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'required_streak': requiredStreak,
      'is_unlocked': isUnlocked ? 1 : 0,
      'unlocked_at': unlockedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Reward.fromMap(Map<String, dynamic> map) {
    return Reward(
      id: map['id'],
      title: map['title'],
      description: map['description'],
      requiredStreak: map['required_streak'],
      isUnlocked: map['is_unlocked'] == 1,
      unlockedAt: map['unlocked_at'] != null
          ? DateTime.parse(map['unlocked_at'])
          : null,
      createdAt: DateTime.parse(map['created_at']),
    );
  }

  Reward copyWith({
    String? id,
    String? title,
    String? description,
    int? requiredStreak,
    bool? isUnlocked,
    DateTime? unlockedAt,
    DateTime? createdAt,
  }) {
    return Reward(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      requiredStreak: requiredStreak ?? this.requiredStreak,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      unlockedAt: unlockedAt ?? this.unlockedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
