import 'package:flutter_test/flutter_test.dart';
import 'package:focusbro/services/database_schema.dart';

void main() {
  test('goalsTableSchemaIsCurrent accepts the canonical goals schema', () {
    expect(
      DatabaseSchema.goalsTableSchemaIsCurrent(
          DatabaseSchema.goalsTableColumns),
      isTrue,
    );
  });

  test('goalsTableSchemaIsCurrent rejects legacy goals schemas', () {
    expect(
      DatabaseSchema.goalsTableSchemaIsCurrent({'id', 'title', 'is_completed'}),
      isFalse,
    );
  });
}
