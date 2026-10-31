/// Base model interface for database entities
abstract class BaseModel {
  /// Convert model to Map for database storage
  Map<String, dynamic> toMap();

  /// Get the table name for this model
  String get tableName;

  /// Get the primary key field name
  String get primaryKey => 'id';
}

/// Base model with common fields
abstract class BaseModelWithTimestamps extends BaseModel {
  final DateTime createdAt;
  final DateTime updatedAt;

  BaseModelWithTimestamps({
    required this.createdAt,
    required this.updatedAt,
  });

  /// Helper method to include timestamps in toMap
  Map<String, dynamic> baseToMap() {
    return {
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
