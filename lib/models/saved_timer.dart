import 'base_model.dart';

class SavedTimer extends BaseModelWithTimestamps {
  final int? id;
  final String name;
  final int workDuration;
  final int breakDuration;
  final int sessionsUntilLongBreak;
  final int? longBreakDuration;
  final bool isDefault;

  SavedTimer({
    this.id,
    required this.name,
    required this.workDuration,
    required this.breakDuration,
    this.sessionsUntilLongBreak = 3,
    this.longBreakDuration,
    this.isDefault = false,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) : super(createdAt: createdAt, updatedAt: updatedAt);

  @override
  String get tableName => 'saved_timers';

  @override
  Map<String, dynamic> toMap() {
    final map = {
      'name': name,
      'work_duration': workDuration,
      'break_duration': breakDuration,
      'sessions_until_long_break': sessionsUntilLongBreak,
      'long_break_duration': longBreakDuration,
      'is_default': isDefault ? 1 : 0,
      ...baseToMap(),
    };

    if (id != null) {
      map['id'] = id;
    }

    return map;
  }

  factory SavedTimer.fromMap(Map<String, dynamic> map) {
    return SavedTimer(
      id: map['id'],
      name: map['name'],
      workDuration: map['work_duration'],
      breakDuration: map['break_duration'],
      sessionsUntilLongBreak: map['sessions_until_long_break'] ?? 3,
      longBreakDuration: map['long_break_duration'],
      isDefault: map['is_default'] == 1,
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
    );
  }

  SavedTimer copyWith({
    int? id,
    String? name,
    int? workDuration,
    int? breakDuration,
    int? sessionsUntilLongBreak,
    int? longBreakDuration,
    bool? isDefault,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SavedTimer(
      id: id ?? this.id,
      name: name ?? this.name,
      workDuration: workDuration ?? this.workDuration,
      breakDuration: breakDuration ?? this.breakDuration,
      sessionsUntilLongBreak:
          sessionsUntilLongBreak ?? this.sessionsUntilLongBreak,
      longBreakDuration: longBreakDuration ?? this.longBreakDuration,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class UserSetting extends BaseModel {
  final String key;
  final String value;
  final String dataType;
  final DateTime updatedAt;

  UserSetting({
    required this.key,
    required this.value,
    required this.dataType,
    required this.updatedAt,
  });

  @override
  String get tableName => 'user_settings';

  @override
  String get primaryKey => 'key';

  @override
  Map<String, dynamic> toMap() {
    return {
      'key': key,
      'value': value,
      'data_type': dataType,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory UserSetting.fromMap(Map<String, dynamic> map) {
    return UserSetting(
      key: map['key'],
      value: map['value'],
      dataType: map['data_type'],
      updatedAt: DateTime.parse(map['updated_at']),
    );
  }

  UserSetting copyWith({
    String? key,
    String? value,
    String? dataType,
    DateTime? updatedAt,
  }) {
    return UserSetting(
      key: key ?? this.key,
      value: value ?? this.value,
      dataType: dataType ?? this.dataType,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Helper methods for type conversion
  bool get boolValue => value.toLowerCase() == 'true';
  int get intValue => int.parse(value);
  double get doubleValue => double.parse(value);
  String get stringValue => value;

  static UserSetting fromBool(String key, bool value) {
    return UserSetting(
      key: key,
      value: value.toString(),
      dataType: 'bool',
      updatedAt: DateTime.now(),
    );
  }

  static UserSetting fromInt(String key, int value) {
    return UserSetting(
      key: key,
      value: value.toString(),
      dataType: 'int',
      updatedAt: DateTime.now(),
    );
  }

  static UserSetting fromDouble(String key, double value) {
    return UserSetting(
      key: key,
      value: value.toString(),
      dataType: 'double',
      updatedAt: DateTime.now(),
    );
  }

  static UserSetting fromString(String key, String value) {
    return UserSetting(
      key: key,
      value: value,
      dataType: 'string',
      updatedAt: DateTime.now(),
    );
  }
}
