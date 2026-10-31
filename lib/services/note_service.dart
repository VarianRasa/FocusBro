import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import '../models/note.dart';
import '../repositories/note_repository.dart';
import '../utils/error_handler.dart';
import '../utils/cache_manager.dart';
import 'analytics_service.dart';

/// Note management service with advanced features following FocusBro patterns
class NoteService {
  static final NoteService _instance = NoteService._internal();
  factory NoteService() => _instance;
  NoteService._internal();

  final NoteRepository _repository = NoteRepository();
  final NoteAttachmentRepository _attachmentRepository =
      NoteAttachmentRepository();
  final CacheManager _cache = CacheManager();
  final AnalyticsService _analytics = AnalyticsService();
  SharedPreferences? _prefs;

  List<Note> _notes = [];
  final StreamController<List<Note>> _notesController =
      StreamController<List<Note>>.broadcast();

  // Cache keys
  static const String _notesKey = 'notes_cache';
  static const String _noteStatsKey = 'note_stats_cache';

  bool _isInitialized = false;

  /// Initialize note service with robust error handling
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      debugPrint('NoteService: Starting initialization...');

      _prefs = await SharedPreferences.getInstance();
      debugPrint('NoteService: SharedPreferences initialized');

      await _loadNotes();
      debugPrint(
          'NoteService: Notes loaded successfully, count: ${_notes.length}');

      // Emit initial notes to stream
      _notesController.add(List.from(_notes));
      debugPrint('NoteService: Initial note stream emitted');

      _isInitialized = true;
    } catch (e) {
      debugPrint('NoteService: Initialization failed: $e');
      ErrorHandler.logError('NoteService initialization failed', e);
      throw Exception('Failed to initialize NoteService: ${e.toString()}');
    }
  }

  /// Get notes stream
  Stream<List<Note>> get notesStream => _notesController.stream;

  /// Get all notes
  List<Note> get notes => List.unmodifiable(_notes);

  /// Load notes from database
  Future<void> _loadNotes() async {
    try {
      // Try to load from cache first
      final cachedNotes = _cache.getMemoryCache(_notesKey);
      if (cachedNotes != null) {
        _notes =
            (cachedNotes as List).map((json) => Note.fromMap(json)).toList();
        _notes.sort(
            (a, b) => b.updatedAt.compareTo(a.updatedAt)); // Most recent first
        _notesController.add(List.from(_notes));
        return;
      }

      // Load from database
      _notes = await _repository.findAll(orderBy: 'updated_at DESC');

      // Cache the loaded notes
      _cache.setMemoryCache(
        _notesKey,
        _notes.map((note) => note.toMap()).toList(),
        ttl: const Duration(minutes: 30),
      );

      _notesController.add(List.from(_notes));
    } catch (e) {
      ErrorHandler.logError('Failed to load notes', e);
      _notes = [];
      _notesController.add(_notes);
    }
  }

  /// Create a new note
  Future<Note> createNote({
    required String title,
    required String content,
    required String category,
    bool isFavorite = false,
    bool isPinned = false,
    List<String> tags = const [],
  }) async {
    try {
      debugPrint('NoteService: Creating note with title: "$title"');

      final now = DateTime.now();
      final note = Note(
        id: now.millisecondsSinceEpoch.toString(),
        title: title,
        content: content,
        category: category,
        isFavorite: isFavorite,
        isPinned: isPinned,
        tags: tags,
        createdAt: now,
        updatedAt: now,
      );

      // Save to database
      await _repository.insert(note);
      debugPrint('NoteService: Note saved to database');

      // Add to local list
      _notes.insert(0, note); // Add at beginning for newest-first order
      debugPrint(
          'NoteService: Note added to list, total notes: ${_notes.length}');

      // Invalidate cache
      _cache.invalidateCache(_notesKey);
      _cache.invalidateCache(_noteStatsKey);

      // Emit stream update
      _notesController.add(List.from(_notes));
      debugPrint('NoteService: Stream update emitted');

      // Track analytics
      await _analytics.trackFeatureUsage('note_created', metadata: {
        'category': category,
        'content_length': content.length,
        'tags_count': tags.length,
        'is_favorite': isFavorite,
        'is_pinned': isPinned,
        'title_length': title.length,
      });

      return note;
    } catch (e) {
      debugPrint('NoteService: Failed to create note: $e');
      ErrorHandler.logError('Failed to create note', e);
      throw Exception('Failed to create note: ${e.toString()}');
    }
  }

  /// Update an existing note
  Future<Note> updateNote(Note updatedNote) async {
    try {
      final index = _notes.indexWhere((note) => note.id == updatedNote.id);
      if (index == -1) {
        throw Exception('Note not found');
      }

      // Update timestamp
      final noteWithTimestamp = updatedNote.copyWith(updatedAt: DateTime.now());

      // Save to database
      await _repository.update(noteWithTimestamp);

      // Update local list
      _notes[index] = noteWithTimestamp;

      // Re-sort to maintain newest-first order
      _notes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

      // Invalidate cache
      _cache.invalidateCache(_notesKey);
      _cache.invalidateCache(_noteStatsKey);

      // Emit stream update
      _notesController.add(List.from(_notes));

      // Track analytics
      await _analytics.trackFeatureUsage('note_updated', metadata: {
        'category': noteWithTimestamp.category,
        'content_length': noteWithTimestamp.content.length,
        'tags_count': noteWithTimestamp.tags.length,
        'is_favorite': noteWithTimestamp.isFavorite,
        'is_pinned': noteWithTimestamp.isPinned,
        'title_length': noteWithTimestamp.title.length,
      });

      return noteWithTimestamp;
    } catch (e) {
      ErrorHandler.logError('Failed to update note', e);
      throw Exception('Failed to update note: ${e.toString()}');
    }
  }

  /// Delete a note
  Future<void> deleteNote(String noteId) async {
    try {
      // Get note info before deletion for analytics
      final noteToDelete = _notes.firstWhere((note) => note.id == noteId);

      // Delete from database
      await _repository.delete(noteId);

      // Remove from local list
      _notes.removeWhere((note) => note.id == noteId);

      // Invalidate cache
      _cache.invalidateCache(_notesKey);
      _cache.invalidateCache(_noteStatsKey);

      // Emit stream update
      _notesController.add(List.from(_notes));

      // Track analytics
      await _analytics.trackFeatureUsage('note_deleted', metadata: {
        'category': noteToDelete.category,
        'content_length': noteToDelete.content.length,
        'tags_count': noteToDelete.tags.length,
        'was_favorite': noteToDelete.isFavorite,
        'was_pinned': noteToDelete.isPinned,
      });
    } catch (e) {
      ErrorHandler.logError('Failed to delete note', e);
      throw Exception('Failed to delete note: ${e.toString()}');
    }
  }

  /// Toggle favorite status
  Future<Note> toggleFavorite(String noteId) async {
    try {
      final note = _notes.firstWhere((n) => n.id == noteId);
      final updatedNote = note.copyWith(isFavorite: !note.isFavorite);
      return await updateNote(updatedNote);
    } catch (e) {
      ErrorHandler.logError('Failed to toggle favorite', e);
      throw Exception('Failed to toggle favorite: ${e.toString()}');
    }
  }

  /// Toggle pinned status
  Future<Note> togglePinned(String noteId) async {
    try {
      final note = _notes.firstWhere((n) => n.id == noteId);
      final updatedNote = note.copyWith(isPinned: !note.isPinned);
      return await updateNote(updatedNote);
    } catch (e) {
      ErrorHandler.logError('Failed to toggle pinned', e);
      throw Exception('Failed to toggle pinned: ${e.toString()}');
    }
  }

  /// Add tag to note
  Future<Note> addTagToNote(String noteId, String tag) async {
    try {
      final note = _notes.firstWhere((n) => n.id == noteId);
      final cleanTag = tag.trim().toLowerCase();

      if (cleanTag.isEmpty || note.tags.contains(cleanTag)) {
        return note; // Tag already exists or is empty
      }

      final updatedTags = List<String>.from(note.tags)..add(cleanTag);
      final updatedNote = note.copyWith(tags: updatedTags);
      return await updateNote(updatedNote);
    } catch (e) {
      ErrorHandler.logError('Failed to add tag', e);
      throw Exception('Failed to add tag: ${e.toString()}');
    }
  }

  /// Remove tag from note
  Future<Note> removeTagFromNote(String noteId, String tag) async {
    try {
      final note = _notes.firstWhere((n) => n.id == noteId);
      final cleanTag = tag.trim().toLowerCase();

      final updatedTags = List<String>.from(note.tags)..remove(cleanTag);
      final updatedNote = note.copyWith(tags: updatedTags);
      return await updateNote(updatedNote);
    } catch (e) {
      ErrorHandler.logError('Failed to remove tag', e);
      throw Exception('Failed to remove tag: ${e.toString()}');
    }
  }

  /// Update note tags
  Future<Note> updateNoteTags(String noteId, List<String> tags) async {
    try {
      final note = _notes.firstWhere((n) => n.id == noteId);
      final cleanTags = tags
          .map((tag) => tag.trim().toLowerCase())
          .where((tag) => tag.isNotEmpty)
          .toSet()
          .toList();

      final updatedNote = note.copyWith(tags: cleanTags);
      return await updateNote(updatedNote);
    } catch (e) {
      ErrorHandler.logError('Failed to update tags', e);
      throw Exception('Failed to update tags: ${e.toString()}');
    }
  }

  /// Search notes by title or content
  Future<List<Note>> searchNotes(String query) async {
    try {
      if (query.trim().isEmpty) {
        return List.from(_notes);
      }

      final results = await _repository.searchNotes(query.trim());

      // Track analytics
      await _analytics.trackFeatureUsage('note_search', metadata: {
        'query_length': query.trim().length,
        'results_count': results.length,
        'has_results': results.isNotEmpty,
      });

      return results;
    } catch (e) {
      ErrorHandler.logError('Failed to search notes', e);
      return [];
    }
  }

  /// Get notes by category
  Future<List<Note>> getNotesByCategory(String category) async {
    try {
      if (category == 'All') {
        return List.from(_notes);
      }
      return await _repository.getNotesByCategory(category);
    } catch (e) {
      ErrorHandler.logError('Failed to get notes by category', e);
      return [];
    }
  }

  /// Get favorite notes
  Future<List<Note>> getFavoriteNotes() async {
    try {
      return await _repository.getFavoriteNotes();
    } catch (e) {
      ErrorHandler.logError('Failed to get favorite notes', e);
      return [];
    }
  }

  /// Get note statistics
  Future<Map<String, dynamic>> getNoteStatistics() async {
    try {
      // Try cache first
      final cachedStats = _cache.getMemoryCache(_noteStatsKey);
      if (cachedStats != null) {
        return Map<String, dynamic>.from(cachedStats);
      }

      final categoryStats = await _repository.getNoteStatsByCategory();
      final recentNotes = await _repository.getRecentNotes(7);
      final favoriteCount = _notes.where((n) => n.isFavorite).length;

      final stats = {
        'total': _notes.length,
        'favorites': favoriteCount,
        'categories': categoryStats,
        'recentCount': recentNotes.length,
        'lastUpdated': DateTime.now().toIso8601String(),
      };

      // Cache stats
      _cache.setMemoryCache(
        _noteStatsKey,
        stats,
        ttl: const Duration(minutes: 15),
      );

      return stats;
    } catch (e) {
      ErrorHandler.logError('Failed to get note statistics', e);
      return {
        'total': 0,
        'favorites': 0,
        'categories': <String, int>{},
        'recentCount': 0,
        'lastUpdated': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Get comprehensive note analytics for Analytics Dashboard
  Future<Map<String, dynamic>> getNoteAnalytics() async {
    try {
      final basicStats = await getNoteStatistics();

      // Calculate additional analytics
      final totalWords = _notes.fold<int>(
          0, (sum, note) => sum + note.content.split(' ').length);
      final averageContentLength = _notes.isNotEmpty
          ? _notes.fold<int>(0, (sum, note) => sum + note.content.length) /
              _notes.length
          : 0.0;

      // Category distribution
      final categoryDistribution = <String, int>{};
      for (final note in _notes) {
        categoryDistribution[note.category] =
            (categoryDistribution[note.category] ?? 0) + 1;
      }

      // Tag usage analytics
      final allTags = <String>[];
      for (final note in _notes) {
        allTags.addAll(note.tags);
      }
      final tagFrequency = <String, int>{};
      for (final tag in allTags) {
        tagFrequency[tag] = (tagFrequency[tag] ?? 0) + 1;
      }

      // Recent activity (last 7 days)
      final weekAgo = DateTime.now().subtract(const Duration(days: 7));
      final recentNotes = _notes
          .where((note) =>
              note.createdAt.isAfter(weekAgo) ||
              note.updatedAt.isAfter(weekAgo))
          .length;

      return {
        ...basicStats,
        'totalWords': totalWords,
        'averageContentLength': averageContentLength.round(),
        'categoryDistribution': categoryDistribution,
        'topTags': _getTopTags(tagFrequency, 5),
        'recentActivity': recentNotes,
        'pinnedCount': _notes.where((n) => n.isPinned).length,
        'averageTagsPerNote':
            _notes.isNotEmpty ? allTags.length / _notes.length : 0.0,
        'longestNote': _notes.isNotEmpty
            ? _notes
                .map((n) => n.content.length)
                .reduce((a, b) => a > b ? a : b)
            : 0,
        'shortestNote': _notes.isNotEmpty
            ? _notes
                .map((n) => n.content.length)
                .reduce((a, b) => a < b ? a : b)
            : 0,
      };
    } catch (e) {
      ErrorHandler.logError('Failed to get note analytics', e);
      return await getNoteStatistics(); // Fallback to basic stats
    }
  }

  /// Get top tags by frequency
  List<Map<String, dynamic>> _getTopTags(
      Map<String, int> tagFrequency, int limit) {
    final sortedTags = tagFrequency.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sortedTags
        .take(limit)
        .map((entry) => {
              'tag': entry.key,
              'count': entry.value,
            })
        .toList();
  }

  /// Refresh notes from database
  Future<void> refreshNotes() async {
    try {
      _cache.invalidateCache(_notesKey);
      await _loadNotes();
    } catch (e) {
      ErrorHandler.logError('Failed to refresh notes', e);
    }
  }

  /// Duplicate a note
  Future<Note> duplicateNote(String noteId) async {
    try {
      final originalNote = _notes.firstWhere((n) => n.id == noteId);
      return await createNote(
        title: '${originalNote.title} (Copy)',
        content: originalNote.content,
        category: originalNote.category,
        isFavorite: false,
      );
    } catch (e) {
      ErrorHandler.logError('Failed to duplicate note', e);
      throw Exception('Failed to duplicate note: ${e.toString()}');
    }
  }

  /// Export notes to JSON
  Future<String> exportNotes({List<String>? noteIds}) async {
    try {
      List<Note> notesToExport;
      if (noteIds != null && noteIds.isNotEmpty) {
        notesToExport = _notes.where((n) => noteIds.contains(n.id)).toList();
      } else {
        notesToExport = List.from(_notes);
      }

      final exportData = {
        'version': '1.0',
        'exportDate': DateTime.now().toIso8601String(),
        'notes': notesToExport.map((note) => note.toMap()).toList(),
      };

      return jsonEncode(exportData);
    } catch (e) {
      ErrorHandler.logError('Failed to export notes', e);
      throw Exception('Failed to export notes: ${e.toString()}');
    }
  }

  /// Import notes from JSON
  Future<int> importNotes(String jsonData) async {
    try {
      final data = jsonDecode(jsonData);
      final importedNotes =
          (data['notes'] as List).map((json) => Note.fromMap(json)).toList();

      int importedCount = 0;
      for (final note in importedNotes) {
        // Check if note already exists
        final exists = _notes.any((n) => n.id == note.id);
        if (!exists) {
          await _repository.insert(note);
          _notes.insert(0, note);
          importedCount++;
        }
      }

      if (importedCount > 0) {
        // Re-sort notes
        _notes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

        // Invalidate cache
        _cache.invalidateCache(_notesKey);
        _cache.invalidateCache(_noteStatsKey);

        // Emit stream update
        _notesController.add(List.from(_notes));
      }

      return importedCount;
    } catch (e) {
      ErrorHandler.logError('Failed to import notes', e);
      throw Exception('Failed to import notes: ${e.toString()}');
    }
  }

  /// Get filtered and sorted notes with smart pinned priority
  List<Note> getFilteredNotes({
    String? category,
    String? searchQuery,
    String sortBy = 'updated',
    bool favoritesOnly = false,
    bool pinnedOnly = false,
  }) {
    List<Note> filtered = List.from(_notes);

    // Apply category filter
    if (category != null && category != 'All') {
      filtered = filtered.where((note) => note.category == category).toList();
    }

    // Apply favorites filter
    if (favoritesOnly) {
      filtered = filtered.where((note) => note.isFavorite).toList();
    }

    // Apply pinned filter
    if (pinnedOnly) {
      filtered = filtered.where((note) => note.isPinned).toList();
    }

    // Apply search filter
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final query = searchQuery.toLowerCase();
      filtered = filtered.where((note) {
        return note.title.toLowerCase().contains(query) ||
            note.content.toLowerCase().contains(query) ||
            note.tags.any((tag) => tag.toLowerCase().contains(query));
      }).toList();
    }

    // Apply smart sorting with pinned priority
    return _applySortingWithPinnedPriority(filtered, sortBy);
  }

  /// Apply sorting with pinned notes always at the top
  List<Note> _applySortingWithPinnedPriority(List<Note> notes, String sortBy) {
    // Separate pinned and unpinned notes
    final pinnedNotes = notes.where((note) => note.isPinned).toList();
    final unpinnedNotes = notes.where((note) => !note.isPinned).toList();

    // Sort each group according to the specified criteria
    _sortNotesList(pinnedNotes, sortBy);
    _sortNotesList(unpinnedNotes, sortBy);

    // Return pinned notes first, then unpinned notes
    return [...pinnedNotes, ...unpinnedNotes];
  }

  /// Sort a list of notes according to the specified criteria
  void _sortNotesList(List<Note> notes, String sortBy) {
    switch (sortBy) {
      case 'title':
        notes.sort((a, b) => a.title.compareTo(b.title));
        break;
      case 'created':
        notes
            .sort((a, b) => b.createdAt.compareTo(a.createdAt)); // Newest first
        break;
      case 'category':
        notes.sort((a, b) {
          final categoryComparison = a.category.compareTo(b.category);
          if (categoryComparison != 0) return categoryComparison;
          // If same category, sort by updated date (newest first)
          return b.updatedAt.compareTo(a.updatedAt);
        });
        break;
      case 'updated':
      default:
        notes
            .sort((a, b) => b.updatedAt.compareTo(a.updatedAt)); // Newest first
        break;
    }
  }

  /// Get available categories
  List<String> getCategories() {
    final categories = <String>{'All'};
    for (final note in _notes) {
      categories.add(note.category);
    }
    return categories.toList()..sort();
  }

  /// Clear all notes (for testing/reset purposes)
  Future<void> clearAllNotes() async {
    try {
      // Delete all from database
      for (final note in _notes) {
        await _repository.delete(note.id);
      }

      // Clear local list
      _notes.clear();

      // Invalidate cache
      _cache.invalidateCache(_notesKey);
      _cache.invalidateCache(_noteStatsKey);

      // Emit stream update
      _notesController.add(List.from(_notes));
    } catch (e) {
      ErrorHandler.logError('Failed to clear all notes', e);
      throw Exception('Failed to clear all notes: ${e.toString()}');
    }
  }

  // ============================================================================
  // ATTACHMENT MANAGEMENT
  // ============================================================================

  /// Get attachments for a note
  Future<List<NoteAttachment>> getAttachmentsForNote(String noteId) async {
    try {
      return await _attachmentRepository.getAttachmentsForNote(noteId);
    } catch (e) {
      ErrorHandler.logError('Failed to get attachments for note', e);
      return [];
    }
  }

  /// Add attachment to a note
  Future<NoteAttachment> addAttachment({
    required String noteId,
    required String filePath,
    required String fileName,
    String? fileType,
    int? fileSize,
  }) async {
    try {
      final attachment = NoteAttachment(
        noteId: noteId,
        filePath: filePath,
        fileName: fileName,
        fileType: fileType,
        fileSize: fileSize,
        createdAt: DateTime.now(),
      );

      await _attachmentRepository.insert(attachment);
      return attachment;
    } catch (e) {
      ErrorHandler.logError('Failed to add attachment', e);
      throw Exception('Failed to add attachment: ${e.toString()}');
    }
  }

  /// Delete an attachment
  Future<void> deleteAttachment(int attachmentId) async {
    try {
      await _attachmentRepository.delete(attachmentId.toString());
    } catch (e) {
      ErrorHandler.logError('Failed to delete attachment', e);
      throw Exception('Failed to delete attachment: ${e.toString()}');
    }
  }

  /// Delete all attachments for a note
  Future<void> deleteAttachmentsForNote(String noteId) async {
    try {
      await _attachmentRepository.deleteAttachmentsForNote(noteId);
    } catch (e) {
      ErrorHandler.logError('Failed to delete attachments for note', e);
      throw Exception('Failed to delete attachments for note: ${e.toString()}');
    }
  }

  /// Get attachment statistics
  Future<Map<String, dynamic>> getAttachmentStatistics() async {
    try {
      final totalSize = await _attachmentRepository.getTotalSize();
      final statsByType =
          await _attachmentRepository.getAttachmentStatsByType();

      return {
        'totalSize': totalSize,
        'statsByType': statsByType,
        'lastUpdated': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      ErrorHandler.logError('Failed to get attachment statistics', e);
      return {
        'totalSize': 0,
        'statsByType': <String, Map<String, dynamic>>{},
        'lastUpdated': DateTime.now().toIso8601String(),
      };
    }
  }

  // ============================================================================
  // NOTE TEMPLATES
  // ============================================================================

  /// Get predefined note templates
  List<NoteTemplate> getNoteTemplates() {
    final now = DateTime.now();
    return [
      NoteTemplate(
        id: 'builtin_meeting',
        name: 'Meeting Notes',
        title: 'Meeting - [Date]',
        content: '''**Attendees:**
-

**Agenda:**
1.

**Discussion Points:**
-

**Action Items:**
- [ ]

**Next Steps:**
-
''',
        category: 'Meeting',
        description: 'Template for meeting notes with agenda and action items',
        tags: ['meeting', 'work', 'agenda'],
        isBuiltIn: true,
        createdAt: now,
        updatedAt: now,
      ),
      NoteTemplate(
        id: 'builtin_project',
        name: 'Project Planning',
        title: 'Project: [Name]',
        content: '''**Project Overview:**


**Goals:**
-

**Timeline:**
- Start Date:
- End Date:

**Resources Needed:**
-

**Milestones:**
- [ ]

**Risks & Mitigation:**
-
''',
        category: 'Project',
        description: 'Template for project planning and management',
        tags: ['project', 'planning', 'work'],
        isBuiltIn: true,
        createdAt: now,
        updatedAt: now,
      ),
      NoteTemplate(
        id: 'builtin_journal',
        name: 'Daily Journal',
        title: 'Journal - [Date]',
        content: '''**Today's Highlights:**
-

**Accomplishments:**
-

**Challenges:**
-

**Tomorrow's Goals:**
-

**Reflections:**

''',
        category: 'Personal',
        description: 'Template for daily journaling and reflection',
        tags: ['journal', 'personal', 'daily'],
        isBuiltIn: true,
        createdAt: now,
        updatedAt: now,
      ),
      NoteTemplate(
        id: 'builtin_study',
        name: 'Study Notes',
        title: 'Study: [Subject]',
        content: '''**Topic:**

**Key Concepts:**
-

**Important Points:**
1.

**Questions:**
-

**Summary:**

**Review Date:**
''',
        category: 'Study',
        description: 'Template for study notes and learning materials',
        tags: ['study', 'learning', 'education'],
        isBuiltIn: true,
        createdAt: now,
        updatedAt: now,
      ),
      NoteTemplate(
        id: 'builtin_quick',
        name: 'Quick Note',
        title: 'Quick Note',
        content: '',
        category: 'Quick Note',
        description: 'Simple template for quick notes',
        tags: ['quick', 'simple'],
        isBuiltIn: true,
        createdAt: now,
        updatedAt: now,
      ),
    ];
  }

  /// Create note from template
  Future<Note> createNoteFromTemplate(NoteTemplate template) async {
    try {
      final now = DateTime.now();
      final title = template.title
          .replaceAll('[Date]', '${now.day}/${now.month}/${now.year}');

      return await createNote(
        title: title,
        content: template.content,
        category: template.category,
      );
    } catch (e) {
      ErrorHandler.logError('Failed to create note from template', e);
      throw Exception('Failed to create note from template: ${e.toString()}');
    }
  }

  // ============================================================================
  // ADVANCED SEARCH & FILTERING
  // ============================================================================

  /// Advanced search with multiple criteria
  Future<List<Note>> advancedSearch({
    String? query,
    List<String>? categories,
    bool? favoritesOnly,
    DateTime? createdAfter,
    DateTime? createdBefore,
    DateTime? updatedAfter,
    DateTime? updatedBefore,
    bool? hasAttachments,
  }) async {
    try {
      List<Note> results = List.from(_notes);

      // Text search
      if (query != null && query.trim().isNotEmpty) {
        final searchQuery = query.toLowerCase();
        results = results.where((note) {
          return note.title.toLowerCase().contains(searchQuery) ||
              note.content.toLowerCase().contains(searchQuery);
        }).toList();
      }

      // Category filter
      if (categories != null && categories.isNotEmpty) {
        results = results
            .where((note) => categories.contains(note.category))
            .toList();
      }

      // Favorites filter
      if (favoritesOnly == true) {
        results = results.where((note) => note.isFavorite).toList();
      }

      // Date filters
      if (createdAfter != null) {
        results = results
            .where((note) => note.createdAt.isAfter(createdAfter))
            .toList();
      }
      if (createdBefore != null) {
        results = results
            .where((note) => note.createdAt.isBefore(createdBefore))
            .toList();
      }
      if (updatedAfter != null) {
        results = results
            .where((note) => note.updatedAt.isAfter(updatedAfter))
            .toList();
      }
      if (updatedBefore != null) {
        results = results
            .where((note) => note.updatedAt.isBefore(updatedBefore))
            .toList();
      }

      // Attachment filter
      if (hasAttachments != null) {
        final notesWithAttachments =
            await _repository.getNotesWithAttachments();
        final noteIdsWithAttachments =
            notesWithAttachments.map((n) => n.id).toSet();

        if (hasAttachments) {
          results = results
              .where((note) => noteIdsWithAttachments.contains(note.id))
              .toList();
        } else {
          results = results
              .where((note) => !noteIdsWithAttachments.contains(note.id))
              .toList();
        }
      }

      return results;
    } catch (e) {
      ErrorHandler.logError('Failed to perform advanced search', e);
      return [];
    }
  }

  /// Get notes with specific tags
  Future<List<Note>> getNotesWithTags(List<String> tags) async {
    try {
      if (tags.isEmpty) return List.from(_notes);

      final cleanTags = tags.map((tag) => tag.trim().toLowerCase()).toList();

      return _notes.where((note) {
        return cleanTags.any((tag) => note.tags.contains(tag));
      }).toList();
    } catch (e) {
      ErrorHandler.logError('Failed to get notes with tags', e);
      return [];
    }
  }

  /// Get all unique tags from all notes
  List<String> getAllTags() {
    try {
      final allTags = <String>{};
      for (final note in _notes) {
        allTags.addAll(note.tags);
      }
      return allTags.toList()..sort();
    } catch (e) {
      ErrorHandler.logError('Failed to get all tags', e);
      return [];
    }
  }

  /// Get pinned notes
  List<Note> getPinnedNotes() {
    try {
      return _notes.where((note) => note.isPinned).toList();
    } catch (e) {
      ErrorHandler.logError('Failed to get pinned notes', e);
      return [];
    }
  }

  /// Get notes sorted with pinned notes first
  List<Note> getNotesWithPinnedFirst() {
    try {
      final pinnedNotes = _notes.where((note) => note.isPinned).toList();
      final unpinnedNotes = _notes.where((note) => !note.isPinned).toList();

      // Sort each group by updated date
      pinnedNotes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      unpinnedNotes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

      return [...pinnedNotes, ...unpinnedNotes];
    } catch (e) {
      ErrorHandler.logError('Failed to get notes with pinned first', e);
      return List.from(_notes);
    }
  }

  /// Search notes by title, content, or tags
  Future<List<Note>> searchNotesAdvanced(String query,
      {List<String>? filterTags}) async {
    try {
      if (query.trim().isEmpty && (filterTags == null || filterTags.isEmpty)) {
        return getNotesWithPinnedFirst();
      }

      List<Note> results = List.from(_notes);

      // Filter by tags if provided
      if (filterTags != null && filterTags.isNotEmpty) {
        results = await getNotesWithTags(filterTags);
      }

      // Filter by search query if provided
      if (query.trim().isNotEmpty) {
        final searchQuery = query.trim().toLowerCase();
        results = results.where((note) {
          return note.title.toLowerCase().contains(searchQuery) ||
              note.content.toLowerCase().contains(searchQuery) ||
              note.category.toLowerCase().contains(searchQuery) ||
              note.tags.any((tag) => tag.toLowerCase().contains(searchQuery));
        }).toList();
      }

      return results;
    } catch (e) {
      ErrorHandler.logError('Failed to search notes', e);
      return [];
    }
  }

  /// Dispose resources
  void dispose() {
    _notesController.close();
  }
}
