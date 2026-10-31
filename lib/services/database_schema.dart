/// Canonical SQLite column sets used by [DatabaseHelper] migrations.
abstract final class DatabaseSchema {
  static const Set<String> goalsTableColumns = {
    'id',
    'title',
    'description',
    'type',
    'frequency',
    'status',
    'targetValue',
    'currentValue',
    'customUnit',
    'createdAt',
    'updatedAt',
    'startDate',
    'endDate',
    'completedAt',
    'isArchived',
    'metadata',
  };

  static bool goalsTableSchemaIsCurrent(Set<String> columns) {
    return goalsTableColumns.every(columns.contains);
  }
}
