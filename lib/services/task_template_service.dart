import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task_template.dart';
import '../models/task_model.dart';
import '../utils/error_handler.dart';
import '../utils/cache_manager.dart';

/// Service for managing task templates
class TaskTemplateService {
  static const String _templatesKey = 'task_templates';

  SharedPreferences? _prefs;
  final CacheManager _cache = CacheManager();
  final StreamController<List<TaskTemplate>> _templatesController =
      StreamController<List<TaskTemplate>>.broadcast();

  List<TaskTemplate> _templates = [];

  /// Stream of template updates
  Stream<List<TaskTemplate>> get templatesStream => _templatesController.stream;

  /// Get all templates
  List<TaskTemplate> get templates => List.unmodifiable(_templates);

  /// Get built-in templates
  List<TaskTemplate> get builtInTemplates =>
      _templates.where((t) => t.isBuiltIn).toList();

  /// Get custom templates
  List<TaskTemplate> get customTemplates =>
      _templates.where((t) => !t.isBuiltIn).toList();

  /// Initialize the service
  Future<void> initialize() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      await _loadTemplates();

      // Add built-in templates if not already present
      await _ensureBuiltInTemplates();

      // Emit initial templates
      _templatesController.add(List.from(_templates));
    } catch (e) {
      ErrorHandler.logError('Failed to initialize TaskTemplateService', e);
      throw Exception('Failed to initialize task templates');
    }
  }

  /// Load templates from storage
  Future<void> _loadTemplates() async {
    try {
      // Try cache first
      final cachedData = await _cache.getMemoryCache(_templatesKey);
      if (cachedData != null) {
        _templates = (cachedData as List)
            .map((json) => TaskTemplate.fromJson(json))
            .toList();
        return;
      }

      // Load from SharedPreferences
      final templatesJson = _prefs?.getStringList(_templatesKey) ?? [];
      _templates = templatesJson
          .map((jsonStr) => TaskTemplate.fromJson(jsonDecode(jsonStr)))
          .toList();
    } catch (e) {
      ErrorHandler.logError('Failed to load templates', e);
      _templates = [];
    }
  }

  /// Ensure built-in templates are present
  Future<void> _ensureBuiltInTemplates() async {
    final existingBuiltInIds =
        _templates.where((t) => t.isBuiltIn).map((t) => t.id).toSet();

    final missingTemplates = BuiltInTaskTemplates.templates
        .where((t) => !existingBuiltInIds.contains(t.id))
        .toList();

    if (missingTemplates.isNotEmpty) {
      _templates.addAll(missingTemplates);
      await _saveTemplates();
    }
  }

  /// Save templates to storage
  Future<void> _saveTemplates() async {
    try {
      final templatesJson =
          _templates.map((template) => template.toJson()).toList();
      await _prefs?.setStringList(
        _templatesKey,
        templatesJson.map((json) => jsonEncode(json)).toList(),
      );

      // Update cache
      _cache.setMemoryCache(
        _templatesKey,
        templatesJson,
        ttl: const Duration(minutes: 30),
      );

      // Emit stream update
      _templatesController.add(List.from(_templates));
    } catch (e) {
      ErrorHandler.logError('Failed to save templates', e);
      throw Exception('Failed to save templates');
    }
  }

  /// Create a new custom template
  Future<TaskTemplate> createTemplate({
    required String name,
    required String description,
    required TaskPriority priority,
    required TaskCategory category,
    required List<String> tags,
    required int estimatedFocusSessions,
    Duration? estimatedDuration,
    required IconData icon,
    required Color color,
  }) async {
    try {
      final template = TaskTemplate(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        description: description,
        priority: priority,
        category: category,
        tags: tags,
        estimatedFocusSessions: estimatedFocusSessions,
        estimatedDuration: estimatedDuration,
        icon: icon,
        color: color,
        isBuiltIn: false,
        createdAt: DateTime.now(),
      );

      _templates.add(template);
      await _saveTemplates();

      return template;
    } catch (e) {
      ErrorHandler.logError('Failed to create template', e);
      throw Exception('Failed to create template');
    }
  }

  /// Update an existing template
  Future<TaskTemplate> updateTemplate(TaskTemplate updatedTemplate) async {
    try {
      if (updatedTemplate.isBuiltIn) {
        throw Exception('Cannot modify built-in templates');
      }

      final index = _templates.indexWhere((t) => t.id == updatedTemplate.id);
      if (index == -1) {
        throw Exception('Template not found');
      }

      _templates[index] = updatedTemplate;
      await _saveTemplates();

      return updatedTemplate;
    } catch (e) {
      ErrorHandler.logError('Failed to update template', e);
      throw Exception('Failed to update template');
    }
  }

  /// Delete a template
  Future<void> deleteTemplate(String templateId) async {
    try {
      final template = _templates.firstWhere(
        (t) => t.id == templateId,
        orElse: () => throw Exception('Template not found'),
      );

      if (template.isBuiltIn) {
        throw Exception('Cannot delete built-in templates');
      }

      _templates.removeWhere((t) => t.id == templateId);
      await _saveTemplates();
    } catch (e) {
      ErrorHandler.logError('Failed to delete template', e);
      throw Exception('Failed to delete template');
    }
  }

  /// Get template by ID
  TaskTemplate? getTemplate(String templateId) {
    try {
      return _templates.firstWhere((t) => t.id == templateId);
    } catch (e) {
      return null;
    }
  }

  /// Search templates
  List<TaskTemplate> searchTemplates(String query) {
    if (query.isEmpty) return templates;

    final lowercaseQuery = query.toLowerCase();
    return _templates.where((template) {
      return template.name.toLowerCase().contains(lowercaseQuery) ||
          template.description.toLowerCase().contains(lowercaseQuery) ||
          template.tags
              .any((tag) => tag.toLowerCase().contains(lowercaseQuery));
    }).toList();
  }

  /// Get templates by category
  List<TaskTemplate> getTemplatesByCategory(TaskCategory category) {
    return _templates.where((t) => t.category == category).toList();
  }

  /// Dispose resources
  void dispose() {
    _templatesController.close();
  }
}
