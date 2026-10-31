import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/note.dart';
import '../utils/error_handler.dart';
import '../utils/cache_manager.dart';

/// Service for managing note templates (both built-in and custom)
class NoteTemplateService {
  static const String _customTemplatesKey = 'custom_note_templates';
  static const String _favoriteTemplatesKey = 'favorite_note_templates';

  SharedPreferences? _prefs;
  final CacheManager _cache = CacheManager();

  List<NoteTemplate> _customTemplates = [];
  Set<String> _favoriteTemplateIds = {};

  // Stream controllers
  final StreamController<List<NoteTemplate>> _templatesController =
      StreamController<List<NoteTemplate>>.broadcast();
  final StreamController<Set<String>> _favoritesController =
      StreamController<Set<String>>.broadcast();

  // Getters
  List<NoteTemplate> get customTemplates => List.unmodifiable(_customTemplates);
  Set<String> get favoriteTemplateIds => Set.unmodifiable(_favoriteTemplateIds);
  Stream<List<NoteTemplate>> get templatesStream => _templatesController.stream;
  Stream<Set<String>> get favoritesStream => _favoritesController.stream;

  /// Initialize the service
  Future<void> initialize() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      await _loadCustomTemplates();
      await _loadFavoriteTemplates();

      print('NoteTemplateService: Initialization completed successfully');
    } catch (e) {
      ErrorHandler.logError('Failed to initialize NoteTemplateService', e);
      throw Exception('Failed to initialize template service');
    }
  }

  /// Load custom templates from storage
  Future<void> _loadCustomTemplates() async {
    try {
      // Try cache first
      final cached = _cache.getMemoryCache(_customTemplatesKey);
      if (cached != null) {
        _customTemplates = (cached as List)
            .map((json) => NoteTemplate.fromJson(json))
            .toList();
        _templatesController.add(List.from(_customTemplates));
        return;
      }

      // Load from SharedPreferences
      final templatesJson = _prefs?.getStringList(_customTemplatesKey) ?? [];
      _customTemplates = templatesJson
          .map((jsonStr) => NoteTemplate.fromJson(jsonDecode(jsonStr)))
          .toList();

      // Update cache
      _cache.setMemoryCache(
        _customTemplatesKey,
        _customTemplates.map((t) => t.toJson()).toList(),
        ttl: const Duration(minutes: 30),
      );

      // Emit stream update
      _templatesController.add(List.from(_customTemplates));

      print(
          'NoteTemplateService: Loaded ${_customTemplates.length} custom templates');
    } catch (e) {
      ErrorHandler.logError('Failed to load custom templates', e);
      _customTemplates = [];
    }
  }

  /// Load favorite templates from storage
  Future<void> _loadFavoriteTemplates() async {
    try {
      final favoriteIds = _prefs?.getStringList(_favoriteTemplatesKey) ?? [];
      _favoriteTemplateIds = favoriteIds.toSet();

      // Emit stream update
      _favoritesController.add(Set.from(_favoriteTemplateIds));

      print(
          'NoteTemplateService: Loaded ${_favoriteTemplateIds.length} favorite templates');
    } catch (e) {
      ErrorHandler.logError('Failed to load favorite templates', e);
      _favoriteTemplateIds = {};
    }
  }

  /// Save custom templates to storage
  Future<void> _saveCustomTemplates() async {
    try {
      final templatesJson = _customTemplates
          .map((template) => jsonEncode(template.toJson()))
          .toList();
      await _prefs?.setStringList(_customTemplatesKey, templatesJson);

      // Update cache
      _cache.setMemoryCache(
        _customTemplatesKey,
        _customTemplates.map((t) => t.toJson()).toList(),
        ttl: const Duration(minutes: 30),
      );

      // Emit stream update
      _templatesController.add(List.from(_customTemplates));
    } catch (e) {
      ErrorHandler.logError('Failed to save custom templates', e);
      throw Exception('Failed to save templates');
    }
  }

  /// Save favorite templates to storage
  Future<void> _saveFavoriteTemplates() async {
    try {
      await _prefs?.setStringList(
          _favoriteTemplatesKey, _favoriteTemplateIds.toList());

      // Emit stream update
      _favoritesController.add(Set.from(_favoriteTemplateIds));
    } catch (e) {
      ErrorHandler.logError('Failed to save favorite templates', e);
      throw Exception('Failed to save favorites');
    }
  }

  /// Create a new custom template
  Future<NoteTemplate> createTemplate({
    required String name,
    required String title,
    required String content,
    required String category,
    String? description,
    List<String>? tags,
  }) async {
    try {
      final now = DateTime.now();
      final template = NoteTemplate(
        id: 'custom_${now.millisecondsSinceEpoch}',
        name: name,
        title: title,
        content: content,
        category: category,
        description: description ?? '',
        tags: tags ?? [],
        isBuiltIn: false,
        isFavorite: false,
        createdAt: now,
        updatedAt: now,
        createdBy: 'user',
      );

      _customTemplates.add(template);
      await _saveCustomTemplates();

      print('NoteTemplateService: Created template "${template.name}"');
      return template;
    } catch (e) {
      ErrorHandler.logError('Failed to create template', e);
      throw Exception('Failed to create template: ${e.toString()}');
    }
  }

  /// Update an existing custom template
  Future<NoteTemplate> updateTemplate({
    required String templateId,
    String? name,
    String? title,
    String? content,
    String? category,
    String? description,
    List<String>? tags,
  }) async {
    try {
      final index = _customTemplates.indexWhere((t) => t.id == templateId);
      if (index == -1) {
        throw Exception('Template not found');
      }

      final existingTemplate = _customTemplates[index];
      if (existingTemplate.isBuiltIn) {
        throw Exception('Cannot edit built-in templates');
      }

      final updatedTemplate = existingTemplate.copyWith(
        name: name,
        title: title,
        content: content,
        category: category,
        description: description,
        tags: tags,
        updatedAt: DateTime.now(),
      );

      _customTemplates[index] = updatedTemplate;
      await _saveCustomTemplates();

      print('NoteTemplateService: Updated template "${updatedTemplate.name}"');
      return updatedTemplate;
    } catch (e) {
      ErrorHandler.logError('Failed to update template', e);
      throw Exception('Failed to update template: ${e.toString()}');
    }
  }

  /// Delete a custom template
  Future<void> deleteTemplate(String templateId) async {
    try {
      final template = _customTemplates.firstWhere((t) => t.id == templateId);
      if (template.isBuiltIn) {
        throw Exception('Cannot delete built-in templates');
      }

      _customTemplates.removeWhere((t) => t.id == templateId);
      _favoriteTemplateIds.remove(templateId);

      await _saveCustomTemplates();
      await _saveFavoriteTemplates();

      print('NoteTemplateService: Deleted template "${template.name}"');
    } catch (e) {
      ErrorHandler.logError('Failed to delete template', e);
      throw Exception('Failed to delete template: ${e.toString()}');
    }
  }

  /// Create template from existing note
  Future<NoteTemplate> createTemplateFromNote({
    required Note note,
    required String templateName,
    String? description,
    List<String>? tags,
  }) async {
    try {
      return await createTemplate(
        name: templateName,
        title: note.title,
        content: note.content,
        category: note.category,
        description: description ?? 'Template created from note: ${note.title}',
        tags: tags ?? note.tags,
      );
    } catch (e) {
      ErrorHandler.logError('Failed to create template from note', e);
      throw Exception('Failed to create template from note: ${e.toString()}');
    }
  }

  /// Toggle template favorite status
  Future<void> toggleTemplateFavorite(String templateId) async {
    try {
      if (_favoriteTemplateIds.contains(templateId)) {
        _favoriteTemplateIds.remove(templateId);
      } else {
        _favoriteTemplateIds.add(templateId);
      }

      await _saveFavoriteTemplates();
      print('NoteTemplateService: Toggled favorite for template $templateId');
    } catch (e) {
      ErrorHandler.logError('Failed to toggle template favorite', e);
      throw Exception('Failed to toggle favorite: ${e.toString()}');
    }
  }

  /// Get all templates (built-in + custom)
  List<NoteTemplate> getAllTemplates(List<NoteTemplate> builtInTemplates) {
    final allTemplates = <NoteTemplate>[];

    // Add built-in templates with favorite status
    for (final template in builtInTemplates) {
      final isFavorite = _favoriteTemplateIds.contains(template.id);
      allTemplates.add(template.copyWith(isFavorite: isFavorite));
    }

    // Add custom templates with favorite status
    for (final template in _customTemplates) {
      final isFavorite = _favoriteTemplateIds.contains(template.id);
      allTemplates.add(template.copyWith(isFavorite: isFavorite));
    }

    return allTemplates;
  }

  /// Search templates
  List<NoteTemplate> searchTemplates(
    List<NoteTemplate> allTemplates,
    String query, {
    String? categoryFilter,
    bool favoritesOnly = false,
  }) {
    var results = allTemplates;

    // Filter by search query
    if (query.trim().isNotEmpty) {
      final searchQuery = query.toLowerCase();
      results = results.where((template) {
        return template.name.toLowerCase().contains(searchQuery) ||
            template.description.toLowerCase().contains(searchQuery) ||
            template.category.toLowerCase().contains(searchQuery) ||
            template.tags.any((tag) => tag.toLowerCase().contains(searchQuery));
      }).toList();
    }

    // Filter by category
    if (categoryFilter != null && categoryFilter != 'All') {
      results = results
          .where((template) => template.category == categoryFilter)
          .toList();
    }

    // Filter favorites only
    if (favoritesOnly) {
      results = results.where((template) => template.isFavorite).toList();
    }

    return results;
  }

  /// Get template categories
  List<String> getTemplateCategories(List<NoteTemplate> allTemplates) {
    final categories = allTemplates.map((t) => t.category).toSet().toList();
    categories.sort();
    return ['All', ...categories];
  }

  /// Dispose resources
  void dispose() {
    _templatesController.close();
    _favoritesController.close();
  }
}
