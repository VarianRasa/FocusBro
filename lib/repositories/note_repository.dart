import 'package:sqflite/sqflite.dart';
import 'base_repository.dart';
import '../models/note.dart';
import '../services/database_helper.dart';

class NoteRepository extends BaseRepository<Note> {
  @override
  String get tableName => 'notes';

  @override
  String get primaryKey => 'id';

  @override
  Note fromMap(Map<String, dynamic> map) {
    return Note.fromMap(map);
  }

  /// Get notes by category
  Future<List<Note>> getNotesByCategory(String category) async {
    return await findWhere(
      'category = ?',
      [category],
      orderBy: 'updated_at DESC',
    );
  }

  /// Get favorite notes
  Future<List<Note>> getFavoriteNotes() async {
    return await findWhere(
      'is_favorite = ?',
      [1],
      orderBy: 'updated_at DESC',
    );
  }

  /// Search notes by title or content
  Future<List<Note>> searchNotes(String query) async {
    return await findWhere(
      'title LIKE ? OR content LIKE ?',
      ['%$query%', '%$query%'],
      orderBy: 'updated_at DESC',
    );
  }

  /// Get notes sorted by creation date
  Future<List<Note>> getNotesSortedByCreated({bool ascending = false}) async {
    return await findAll(
      orderBy: ascending ? 'created_at ASC' : 'created_at DESC',
    );
  }

  /// Get notes sorted by update date
  Future<List<Note>> getNotesSortedByUpdated({bool ascending = false}) async {
    return await findAll(
      orderBy: ascending ? 'updated_at ASC' : 'updated_at DESC',
    );
  }

  /// Get notes sorted by title
  Future<List<Note>> getNotesSortedByTitle({bool ascending = true}) async {
    return await findAll(
      orderBy: ascending ? 'title ASC' : 'title DESC',
    );
  }

  /// Toggle favorite status
  Future<int> toggleFavorite(String noteId) async {
    final note = await findById(noteId);
    if (note == null) return 0;

    final db = await _database;
    return await db.update(
      tableName,
      {
        'is_favorite': note.isFavorite ? 0 : 1,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [noteId],
    );
  }

  /// Get notes statistics by category
  Future<Map<String, int>> getNoteStatsByCategory() async {
    final result = await rawQuery('''
      SELECT category, COUNT(*) as count
      FROM $tableName 
      GROUP BY category
      ORDER BY count DESC
    ''');

    final stats = <String, int>{};
    for (final row in result) {
      stats[row['category'] as String] = row['count'] as int;
    }
    return stats;
  }

  /// Get recent notes (last N days)
  Future<List<Note>> getRecentNotes(int days) async {
    final cutoffDate = DateTime.now().subtract(Duration(days: days));

    return await findWhere(
      'updated_at >= ?',
      [cutoffDate.toIso8601String()],
      orderBy: 'updated_at DESC',
    );
  }

  /// Get notes with attachments
  Future<List<Note>> getNotesWithAttachments() async {
    final result = await rawQuery('''
      SELECT DISTINCT n.*
      FROM $tableName n
      INNER JOIN note_attachments na ON n.id = na.note_id
      ORDER BY n.updated_at DESC
    ''');

    return result.map((map) => fromMap(map)).toList();
  }

  Future<Database> get _database async => await DatabaseHelper().database;
}

class NoteAttachmentRepository extends BaseRepository<NoteAttachment> {
  @override
  String get tableName => 'note_attachments';

  @override
  NoteAttachment fromMap(Map<String, dynamic> map) {
    return NoteAttachment.fromMap(map);
  }

  /// Get attachments for a specific note
  Future<List<NoteAttachment>> getAttachmentsForNote(String noteId) async {
    return await findWhere(
      'note_id = ?',
      [noteId],
      orderBy: 'created_at ASC',
    );
  }

  /// Delete all attachments for a note
  Future<int> deleteAttachmentsForNote(String noteId) async {
    final db = await _database;
    return await db.delete(
      tableName,
      where: 'note_id = ?',
      whereArgs: [noteId],
    );
  }

  /// Get attachments by file type
  Future<List<NoteAttachment>> getAttachmentsByType(String fileType) async {
    return await findWhere(
      'file_type = ?',
      [fileType],
      orderBy: 'created_at DESC',
    );
  }

  /// Get total size of attachments for a note
  Future<int> getTotalSizeForNote(String noteId) async {
    final result = await rawQuery('''
      SELECT SUM(file_size) as total_size
      FROM $tableName 
      WHERE note_id = ?
    ''', [noteId]);

    return result.isNotEmpty ? (result.first['total_size'] as int? ?? 0) : 0;
  }

  /// Get total size of all attachments
  Future<int> getTotalSize() async {
    final result = await rawQuery('''
      SELECT SUM(file_size) as total_size
      FROM $tableName
    ''');

    return result.isNotEmpty ? (result.first['total_size'] as int? ?? 0) : 0;
  }

  /// Get attachment statistics by file type
  Future<Map<String, Map<String, dynamic>>> getAttachmentStatsByType() async {
    final result = await rawQuery('''
      SELECT 
        file_type,
        COUNT(*) as count,
        SUM(file_size) as total_size,
        AVG(file_size) as avg_size
      FROM $tableName 
      WHERE file_type IS NOT NULL
      GROUP BY file_type
    ''');

    final stats = <String, Map<String, dynamic>>{};
    for (final row in result) {
      stats[row['file_type'] as String] = {
        'count': row['count'] as int,
        'total_size': row['total_size'] as int? ?? 0,
        'avg_size': row['avg_size'] as double? ?? 0.0,
      };
    }
    return stats;
  }

  Future<Database> get _database async => await DatabaseHelper().database;
}
