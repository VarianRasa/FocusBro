import 'dart:async';
import 'package:flutter/material.dart';
import '../models/note.dart';
import '../services/note_service.dart';
import '../utils/error_handler.dart';

/// Note Provider for state management with robust initialization and real-time updates
class NoteProvider extends ChangeNotifier {
  final NoteService _noteService = NoteService();

  List<Note> _notes = [];
  Map<String, dynamic> _noteStats = {};
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _error;

  // Filters and sorting
  String _sortBy = 'updated';
  String _selectedCategory = 'All';
  String _searchQuery = '';
  bool _favoritesOnly = false;
  bool _pinnedOnly = false;
  bool _isGridView = false;

  // Stream subscription
  StreamSubscription<List<Note>>? _notesSubscription;

  // Retry mechanism
  int _initRetryCount = 0;
  static const int _maxRetries = 3;
  Timer? _retryTimer;

  // Getters
  List<Note> get notes => List.unmodifiable(_notes);
  List<Note> get filteredNotes => _getFilteredNotes();
  Map<String, dynamic> get noteStats => Map.unmodifiable(_noteStats);
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  String? get error => _error;
  String get sortBy => _sortBy;
  String get selectedCategory => _selectedCategory;
  String get searchQuery => _searchQuery;
  bool get favoritesOnly => _favoritesOnly;
  bool get pinnedOnly => _pinnedOnly;
  bool get isGridView => _isGridView;
  List<String> get categories => _noteService.getCategories();

  /// Initialize the provider
  Future<void> initialize() async {
    if (_isInitialized && _error == null) return;

    _setLoading(true);
    _clearError();

    try {
      debugPrint(
          'NoteProvider: Starting initialization (attempt ${_initRetryCount + 1})...');

      // Initialize service
      await _noteService.initialize();

      // Load data
      await _loadAllData();

      // Set up real-time subscriptions
      await _setupSubscriptions();

      // Mark as successfully initialized
      _isInitialized = true;
      _initRetryCount = 0;
      _retryTimer?.cancel();

      debugPrint('NoteProvider: Initialization completed successfully');
      debugPrint('NoteProvider: Loaded ${_notes.length} notes');
    } catch (e) {
      debugPrint('NoteProvider: Initialization failed: $e');
      await _handleInitializationFailure(e);
    } finally {
      _setLoading(false);
    }
  }

  /// Handle initialization failure with retry mechanism
  Future<void> _handleInitializationFailure(dynamic error) async {
    _setError('Failed to initialize notes: ${error.toString()}');

    if (_initRetryCount < _maxRetries) {
      _initRetryCount++;
      debugPrint(
          'NoteProvider: Scheduling retry $_initRetryCount/$_maxRetries in 2 seconds...');

      _retryTimer = Timer(const Duration(seconds: 2), () {
        debugPrint('NoteProvider: Retrying initialization...');
        initialize();
      });
    } else {
      debugPrint(
          'NoteProvider: Max retries reached, initialization failed permanently');
      ErrorHandler.logError(
          'NoteProvider initialization failed after $_maxRetries attempts',
          error);
    }
  }

  /// Load all data
  Future<void> _loadAllData() async {
    await Future.wait([
      _loadNotes(),
      _loadNoteStats(),
    ]);
  }

  /// Set up real-time subscriptions
  Future<void> _setupSubscriptions() async {
    debugPrint('NoteProvider: Setting up real-time subscriptions...');

    try {
      _subscribeToNoteUpdates();
    } catch (e) {
      debugPrint('NoteProvider: Warning - Failed to set up subscriptions: $e');
      // Don't fail initialization if subscriptions fail, but log the error
    }
  }

  /// Subscribe to note updates
  void _subscribeToNoteUpdates() {
    _notesSubscription?.cancel();

    _notesSubscription = _noteService.notesStream.listen(
      (notes) async {
        try {
          debugPrint(
              'NoteProvider: Received note update - ${notes.length} notes');

          // Update notes with proper state management
          _notes = List.from(notes);

          // Refresh statistics
          await _loadNoteStats();

          // Notify UI of changes
          notifyListeners();

          debugPrint('NoteProvider: Note update processed successfully');
        } catch (e) {
          debugPrint('NoteProvider: Error processing note update: $e');
          _setError('Failed to process note update: ${e.toString()}');
        }
      },
      onError: (error) {
        debugPrint('NoteProvider: Note stream error: $error');
        _setError('Note stream error: ${error.toString()}');
      },
    );
  }

  /// Load notes from service
  Future<void> _loadNotes() async {
    try {
      _notes = _noteService.notes;
    } catch (e) {
      ErrorHandler.logError('Failed to load notes in provider', e);
      _setError('Failed to load notes: ${e.toString()}');
    }
  }

  /// Load note statistics
  Future<void> _loadNoteStats() async {
    try {
      _noteStats = await _noteService.getNoteStatistics();
    } catch (e) {
      ErrorHandler.logError('Failed to load note statistics', e);
      _noteStats = {};
    }
  }

  /// Create a new note
  Future<Note?> createNote({
    required String title,
    required String content,
    required String category,
    bool isFavorite = false,
    bool isPinned = false,
    List<String> tags = const [],
  }) async {
    try {
      _clearError();
      final note = await _noteService.createNote(
        title: title,
        content: content,
        category: category,
        isFavorite: isFavorite,
        isPinned: isPinned,
        tags: tags,
      );

      // Note: Stream subscription will handle UI updates
      return note;
    } catch (e) {
      _setError('Failed to create note: ${e.toString()}');
      return null;
    }
  }

  /// Update an existing note
  Future<Note?> updateNote(Note note) async {
    try {
      _clearError();
      final updatedNote = await _noteService.updateNote(note);

      // Note: Stream subscription will handle UI updates
      return updatedNote;
    } catch (e) {
      _setError('Failed to update note: ${e.toString()}');
      return null;
    }
  }

  /// Delete a note
  Future<bool> deleteNote(String noteId) async {
    try {
      _clearError();
      await _noteService.deleteNote(noteId);

      // Note: Stream subscription will handle UI updates
      return true;
    } catch (e) {
      _setError('Failed to delete note: ${e.toString()}');
      return false;
    }
  }

  /// Toggle favorite status
  Future<bool> toggleFavorite(String noteId) async {
    try {
      _clearError();
      await _noteService.toggleFavorite(noteId);

      // Note: Stream subscription will handle UI updates
      return true;
    } catch (e) {
      _setError('Failed to toggle favorite: ${e.toString()}');
      return false;
    }
  }

  /// Toggle pinned status
  Future<bool> togglePinned(String noteId) async {
    try {
      _clearError();
      await _noteService.togglePinned(noteId);

      // Note: Stream subscription will handle UI updates
      return true;
    } catch (e) {
      _setError('Failed to toggle pinned: ${e.toString()}');
      return false;
    }
  }

  /// Add tag to note
  Future<bool> addTagToNote(String noteId, String tag) async {
    try {
      _clearError();
      await _noteService.addTagToNote(noteId, tag);

      // Note: Stream subscription will handle UI updates
      return true;
    } catch (e) {
      _setError('Failed to add tag: ${e.toString()}');
      return false;
    }
  }

  /// Remove tag from note
  Future<bool> removeTagFromNote(String noteId, String tag) async {
    try {
      _clearError();
      await _noteService.removeTagFromNote(noteId, tag);

      // Note: Stream subscription will handle UI updates
      return true;
    } catch (e) {
      _setError('Failed to remove tag: ${e.toString()}');
      return false;
    }
  }

  /// Update note tags
  Future<bool> updateNoteTags(String noteId, List<String> tags) async {
    try {
      _clearError();
      await _noteService.updateNoteTags(noteId, tags);

      // Note: Stream subscription will handle UI updates
      return true;
    } catch (e) {
      _setError('Failed to update tags: ${e.toString()}');
      return false;
    }
  }

  /// Duplicate a note
  Future<Note?> duplicateNote(String noteId) async {
    try {
      _clearError();
      final duplicatedNote = await _noteService.duplicateNote(noteId);

      // Note: Stream subscription will handle UI updates
      return duplicatedNote;
    } catch (e) {
      _setError('Failed to duplicate note: ${e.toString()}');
      return null;
    }
  }

  /// Search notes
  Future<List<Note>> searchNotes(String query) async {
    try {
      return await _noteService.searchNotes(query);
    } catch (e) {
      _setError('Failed to search notes: ${e.toString()}');
      return [];
    }
  }

  /// Export notes
  Future<String?> exportNotes({List<String>? noteIds}) async {
    try {
      _clearError();
      return await _noteService.exportNotes(noteIds: noteIds);
    } catch (e) {
      _setError('Failed to export notes: ${e.toString()}');
      return null;
    }
  }

  /// Import notes
  Future<int> importNotes(String jsonData) async {
    try {
      _clearError();
      final importedCount = await _noteService.importNotes(jsonData);

      // Note: Stream subscription will handle UI updates
      return importedCount;
    } catch (e) {
      _setError('Failed to import notes: ${e.toString()}');
      return 0;
    }
  }

  /// Refresh notes
  Future<void> refreshNotes() async {
    try {
      _clearError();
      await _noteService.refreshNotes();
      await _loadNoteStats();
      notifyListeners();
    } catch (e) {
      _setError('Failed to refresh notes: ${e.toString()}');
    }
  }

  // Filter and UI state methods

  /// Set search query
  void setSearchQuery(String query) {
    if (_searchQuery != query) {
      _searchQuery = query;
      notifyListeners();
    }
  }

  /// Set category filter
  void setCategory(String category) {
    if (_selectedCategory != category) {
      _selectedCategory = category;
      notifyListeners();
    }
  }

  /// Set sort order
  void setSortBy(String sortBy) {
    if (_sortBy != sortBy) {
      _sortBy = sortBy;
      notifyListeners();
    }
  }

  /// Toggle favorites only filter
  void toggleFavoritesOnly() {
    _favoritesOnly = !_favoritesOnly;
    notifyListeners();
  }

  /// Toggle pinned only filter
  void togglePinnedOnly() {
    _pinnedOnly = !_pinnedOnly;
    notifyListeners();
  }

  /// Toggle grid/list view
  void toggleViewMode() {
    _isGridView = !_isGridView;
    notifyListeners();
  }

  /// Clear all filters
  void clearFilters() {
    _searchQuery = '';
    _selectedCategory = 'All';
    _favoritesOnly = false;
    _pinnedOnly = false;
    notifyListeners();
  }

  /// Get filtered notes based on current filters
  List<Note> _getFilteredNotes() {
    return _noteService.getFilteredNotes(
      category: _selectedCategory,
      searchQuery: _searchQuery,
      sortBy: _sortBy,
      favoritesOnly: _favoritesOnly,
      pinnedOnly: _pinnedOnly,
    );
  }

  /// Get notes by specific category
  Future<List<Note>> getNotesByCategory(String category) async {
    try {
      return await _noteService.getNotesByCategory(category);
    } catch (e) {
      _setError('Failed to get notes by category: ${e.toString()}');
      return [];
    }
  }

  /// Get favorite notes
  Future<List<Note>> getFavoriteNotes() async {
    try {
      return await _noteService.getFavoriteNotes();
    } catch (e) {
      _setError('Failed to get favorite notes: ${e.toString()}');
      return [];
    }
  }

  /// Get pinned notes
  List<Note> getPinnedNotes() {
    return _noteService.getPinnedNotes();
  }

  /// Get notes with pinned first
  List<Note> getNotesWithPinnedFirst() {
    return _noteService.getNotesWithPinnedFirst();
  }

  /// Get all unique tags
  List<String> getAllTags() {
    return _noteService.getAllTags();
  }

  /// Get notes with specific tags
  Future<List<Note>> getNotesWithTags(List<String> tags) async {
    try {
      _clearError();
      return await _noteService.getNotesWithTags(tags);
    } catch (e) {
      _setError('Failed to get notes with tags: ${e.toString()}');
      return [];
    }
  }

  /// Advanced search with tags filter
  Future<List<Note>> searchNotesAdvanced(String query,
      {List<String>? filterTags}) async {
    try {
      _clearError();
      return await _noteService.searchNotesAdvanced(query,
          filterTags: filterTags);
    } catch (e) {
      _setError('Failed to search notes: ${e.toString()}');
      return [];
    }
  }

  // Helper methods

  /// Set loading state
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  /// Set error state
  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  /// Clear error state
  void _clearError() {
    _error = null;
    notifyListeners();
  }

  /// Get note by ID
  Note? getNoteById(String noteId) {
    try {
      return _notes.firstWhere((note) => note.id == noteId);
    } catch (e) {
      return null;
    }
  }

  /// Check if note exists
  bool noteExists(String noteId) {
    return _notes.any((note) => note.id == noteId);
  }

  /// Get notes count by category
  Map<String, int> getNotesCountByCategory() {
    final counts = <String, int>{};
    for (final note in _notes) {
      counts[note.category] = (counts[note.category] ?? 0) + 1;
    }
    return counts;
  }

  /// Get recent notes (last 7 days)
  List<Note> getRecentNotes() {
    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
    return _notes
        .where((note) => note.updatedAt.isAfter(sevenDaysAgo))
        .toList();
  }

  // ============================================================================
  // ENHANCED FEATURES - PRIORITY 2
  // ============================================================================

  /// Get attachments for a note
  Future<List<NoteAttachment>> getAttachmentsForNote(String noteId) async {
    try {
      return await _noteService.getAttachmentsForNote(noteId);
    } catch (e) {
      _setError('Failed to get attachments: ${e.toString()}');
      return [];
    }
  }

  /// Add attachment to a note
  Future<NoteAttachment?> addAttachment({
    required String noteId,
    required String filePath,
    required String fileName,
    String? fileType,
    int? fileSize,
  }) async {
    try {
      _setLoading(true);
      final attachment = await _noteService.addAttachment(
        noteId: noteId,
        filePath: filePath,
        fileName: fileName,
        fileType: fileType,
        fileSize: fileSize,
      );
      _setLoading(false);
      return attachment;
    } catch (e) {
      _setLoading(false);
      _setError('Failed to add attachment: ${e.toString()}');
      return null;
    }
  }

  /// Delete an attachment
  Future<bool> deleteAttachment(int attachmentId) async {
    try {
      _setLoading(true);
      await _noteService.deleteAttachment(attachmentId);
      _setLoading(false);
      return true;
    } catch (e) {
      _setLoading(false);
      _setError('Failed to delete attachment: ${e.toString()}');
      return false;
    }
  }

  /// Get attachment statistics
  Future<Map<String, dynamic>> getAttachmentStatistics() async {
    try {
      return await _noteService.getAttachmentStatistics();
    } catch (e) {
      _setError('Failed to get attachment statistics: ${e.toString()}');
      return {
        'totalSize': 0,
        'statsByType': <String, Map<String, dynamic>>{},
        'lastUpdated': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Get note templates
  List<NoteTemplate> getNoteTemplates() {
    return _noteService.getNoteTemplates();
  }

  /// Create note from template
  Future<Note?> createNoteFromTemplate(NoteTemplate template) async {
    try {
      _setLoading(true);
      final note = await _noteService.createNoteFromTemplate(template);
      _setLoading(false);
      return note;
    } catch (e) {
      _setLoading(false);
      _setError('Failed to create note from template: ${e.toString()}');
      return null;
    }
  }

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
      return await _noteService.advancedSearch(
        query: query,
        categories: categories,
        favoritesOnly: favoritesOnly,
        createdAfter: createdAfter,
        createdBefore: createdBefore,
        updatedAfter: updatedAfter,
        updatedBefore: updatedBefore,
        hasAttachments: hasAttachments,
      );
    } catch (e) {
      _setError('Failed to perform advanced search: ${e.toString()}');
      return [];
    }
  }

  /// Dispose resources
  @override
  void dispose() {
    _notesSubscription?.cancel();
    _retryTimer?.cancel();
    super.dispose();
  }
}
