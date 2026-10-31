import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/note.dart';
import '../providers/note_provider.dart';
import '../utils/accessibility_helper.dart';
import 'rich_text_editor.dart';

/// Enhanced Note Editor with rich text editing and Material Design 3
class EnhancedNoteEditor extends StatefulWidget {
  final Note? note;
  final String? initialCategory;

  const EnhancedNoteEditor({
    super.key,
    this.note,
    this.initialCategory,
  });

  @override
  State<EnhancedNoteEditor> createState() => _EnhancedNoteEditorState();
}

class _EnhancedNoteEditorState extends State<EnhancedNoteEditor> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  late String _selectedCategory;
  bool _isFavorite = false;
  bool _hasUnsavedChanges = false;
  bool _isSaving = false;

  final FocusNode _titleFocusNode = FocusNode();
  final FocusNode _contentFocusNode = FocusNode();

  final List<String> _categories = [
    'Work',
    'Personal',
    'Ideas',
    'Meeting',
    'Study',
    'Project',
    'Quick Note',
  ];

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _setupChangeListeners();
  }

  void _initializeControllers() {
    _titleController = TextEditingController(text: widget.note?.title ?? '');
    _contentController =
        TextEditingController(text: widget.note?.content ?? '');
    _selectedCategory =
        widget.note?.category ?? widget.initialCategory ?? _categories.first;
    _isFavorite = widget.note?.isFavorite ?? false;
  }

  void _setupChangeListeners() {
    _titleController.addListener(_onContentChanged);
    _contentController.addListener(_onContentChanged);
  }

  void _onContentChanged() {
    if (!_hasUnsavedChanges) {
      setState(() {
        _hasUnsavedChanges = true;
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _titleFocusNode.dispose();
    _contentFocusNode.dispose();
    super.dispose();
  }

  Future<bool> _onWillPop() async {
    if (!_hasUnsavedChanges) return true;

    final shouldDiscard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unsaved Changes'),
        content: const Text(
            'You have unsaved changes. Do you want to discard them?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Discard'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop(false);
              await _saveNote();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    return shouldDiscard ?? false;
  }

  Future<void> _saveNote() async {
    if (_titleController.text.trim().isEmpty) {
      _showErrorSnackBar('Title cannot be empty');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final noteProvider = Provider.of<NoteProvider>(context, listen: false);

      if (widget.note != null) {
        // Update existing note
        final updatedNote = widget.note!.copyWith(
          title: _titleController.text.trim(),
          content: _contentController.text,
          category: _selectedCategory,
          isFavorite: _isFavorite,
        );

        final result = await noteProvider.updateNote(updatedNote);
        if (result != null) {
          setState(() {
            _hasUnsavedChanges = false;
          });
          _showSuccessSnackBar('Note updated successfully');
          if (mounted) Navigator.of(context).pop(result);
        } else {
          _showErrorSnackBar('Failed to update note');
        }
      } else {
        // Create new note
        final result = await noteProvider.createNote(
          title: _titleController.text.trim(),
          content: _contentController.text,
          category: _selectedCategory,
          isFavorite: _isFavorite,
        );

        if (result != null) {
          setState(() {
            _hasUnsavedChanges = false;
          });
          _showSuccessSnackBar('Note created successfully');
          if (mounted) Navigator.of(context).pop(result);
        } else {
          _showErrorSnackBar('Failed to create note');
        }
      }
    } catch (e) {
      _showErrorSnackBar('Error saving note: $e');
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.note != null;

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: Text(isEditing ? 'Edit Note' : 'New Note'),
          elevation: 0,
          actions: [
            // Favorite toggle
            IconButton(
              onPressed: () {
                setState(() {
                  _isFavorite = !_isFavorite;
                  _hasUnsavedChanges = true;
                });
              },
              icon: Icon(
                _isFavorite ? Icons.favorite : Icons.favorite_border,
                color: _isFavorite ? Colors.red : null,
              ),
              tooltip:
                  _isFavorite ? 'Remove from favorites' : 'Add to favorites',
            ),

            // Save button
            if (_isSaving)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              IconButton(
                onPressed: _saveNote,
                icon: const Icon(Icons.save),
                tooltip: 'Save Note',
              ),
          ],
        ),
        body: Column(
          children: [
            // Category selector
            Container(
              padding: const EdgeInsets.all(16),
              child: DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: InputDecoration(
                  labelText: 'Category',
                  prefixIcon: const Icon(Icons.category),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: _categories.map((category) {
                  return DropdownMenuItem(
                    value: category,
                    child: Text(category),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedCategory = value;
                      _hasUnsavedChanges = true;
                    });
                  }
                },
              ),
            ),

            // Title field
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _titleController,
                focusNode: _titleFocusNode,
                decoration: InputDecoration(
                  labelText: 'Title',
                  hintText: 'Enter note title...',
                  prefixIcon: const Icon(Icons.title),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                style: theme.textTheme.titleLarge,
                textInputAction: TextInputAction.next,
                onSubmitted: (_) {
                  _contentFocusNode.requestFocus();
                },
              ),
            ),

            const SizedBox(height: 16),

            // Rich Text Content Editor
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: RichTextEditor(
                  initialText: _contentController.text,
                  onTextChanged: (text) {
                    _contentController.text = text;
                  },
                  hintText: 'Start writing your note...',
                  expands: true,
                ),
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
