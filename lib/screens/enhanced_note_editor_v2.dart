import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import '../models/note.dart';
import '../models/voice_note.dart';
import '../providers/note_provider.dart';
import '../widgets/voice_note_recorder.dart';
import '../widgets/voice_note_player.dart';
import '../widgets/rich_text_editor.dart';
import '../services/voice_notes_service.dart';
import '../services/voice_recording_service.dart';

/// Enhanced Note Editor with Priority 2 features:
/// - File attachments
/// - Note templates
/// - Rich editing capabilities
/// - Voice notes (placeholder)
class EnhancedNoteEditorV2 extends StatefulWidget {
  final Note? note;
  final NoteTemplate? template;

  const EnhancedNoteEditorV2({
    super.key,
    this.note,
    this.template,
  });

  @override
  State<EnhancedNoteEditorV2> createState() => _EnhancedNoteEditorV2State();
}

class _EnhancedNoteEditorV2State extends State<EnhancedNoteEditorV2> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();

  String _selectedCategory = 'Personal';
  bool _isFavorite = false;
  bool _isLoading = false;
  List<NoteAttachment> _attachments = [];

  final List<String> _categories = [
    'Personal',
    'Work',
    'Study',
    'Project',
    'Meeting',
    'Ideas',
    'Quick Note',
  ];

  @override
  void initState() {
    super.initState();
    _initializeEditor();
  }

  void _initializeEditor() {
    if (widget.note != null) {
      // Editing existing note
      _titleController.text = widget.note!.title;
      _contentController.text = widget.note!.content;
      _selectedCategory = widget.note!.category;
      _isFavorite = widget.note!.isFavorite;
      _loadAttachments();
    } else if (widget.template != null) {
      // Creating from template
      _titleController.text = widget.template!.title;
      _contentController.text = widget.template!.content;
      _selectedCategory = widget.template!.category;
    }
  }

  Future<void> _loadAttachments() async {
    if (widget.note != null) {
      final noteProvider = Provider.of<NoteProvider>(context, listen: false);
      final attachments =
          await noteProvider.getAttachmentsForNote(widget.note!.id);
      setState(() {
        _attachments = attachments;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: _buildAppBar(theme),
      body: _buildBody(theme),
      bottomNavigationBar: _buildBottomBar(theme),
    );
  }

  PreferredSizeWidget _buildAppBar(ThemeData theme) {
    return AppBar(
      title: Text(widget.note != null ? 'Edit Note' : 'New Note'),
      backgroundColor: theme.colorScheme.surface,
      foregroundColor: theme.colorScheme.onSurface,
      elevation: 0,
      actions: [
        // Template selector
        if (widget.note == null)
          IconButton(
            icon: const Icon(Icons.library_books),
            onPressed: _showTemplateSelector,
            tooltip: 'Choose Template',
          ),

        // Voice note button
        IconButton(
          icon: const Icon(Icons.mic),
          onPressed: _startVoiceNote,
          tooltip: 'Voice Note',
        ),

        // Attachment button
        IconButton(
          icon: const Icon(Icons.attach_file),
          onPressed: _showAttachmentOptions,
          tooltip: 'Add Attachment',
        ),

        // Save button
        IconButton(
          icon: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save),
          onPressed: _isLoading ? null : _saveNote,
          tooltip: 'Save Note',
        ),
      ],
    );
  }

  Widget _buildBody(ThemeData theme) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          // Note metadata section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border(
                bottom: BorderSide(
                  color: theme.colorScheme.outline.withValues(alpha: 0.2),
                ),
              ),
            ),
            child: Column(
              children: [
                // Title field
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Note Title',
                    hintText: 'Enter note title...',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a title';
                    }
                    return null;
                  },
                  textInputAction: TextInputAction.next,
                ),

                const SizedBox(height: 16),

                // Category and favorite row
                Row(
                  children: [
                    // Category dropdown
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedCategory,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          border: OutlineInputBorder(),
                        ),
                        items: _categories.map((category) {
                          return DropdownMenuItem(
                            value: category,
                            child: Text(category),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedCategory = value!;
                          });
                        },
                      ),
                    ),

                    const SizedBox(width: 16),

                    // Favorite toggle
                    Column(
                      children: [
                        IconButton(
                          icon: Icon(
                            _isFavorite
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color: _isFavorite ? Colors.red : null,
                          ),
                          onPressed: () {
                            setState(() {
                              _isFavorite = !_isFavorite;
                            });
                          },
                          tooltip: _isFavorite
                              ? 'Remove from favorites'
                              : 'Add to favorites',
                        ),
                        Text(
                          'Favorite',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Attachments section
          if (_attachments.isNotEmpty) _buildAttachmentsSection(theme),

          // Rich Text Content Editor
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
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
        ],
      ),
    );
  }

  Widget _buildAttachmentsSection(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.attach_file,
                size: 16,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 8),
              Text(
                'Attachments (${_attachments.length})',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildAttachmentsList(theme),
        ],
      ),
    );
  }

  Widget _buildAttachmentsList(ThemeData theme) {
    final imageAttachments = _attachments
        .where((a) => a.fileType?.startsWith('image/') == true)
        .toList();
    final voiceAttachments = _attachments
        .where((a) => a.fileType?.startsWith('audio/') == true)
        .toList();
    final otherAttachments = _attachments
        .where((a) =>
            !(a.fileType?.startsWith('image/') == true) &&
            !(a.fileType?.startsWith('audio/') == true))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Image Attachments Grid
        if (imageAttachments.isNotEmpty) ...[
          Text(
            'Images (${imageAttachments.length})',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1,
            ),
            itemCount: imageAttachments.length,
            itemBuilder: (context, index) {
              return _buildImageAttachmentChip(imageAttachments[index], theme);
            },
          ),
          const SizedBox(height: 16),
        ],

        // Voice Attachments
        if (voiceAttachments.isNotEmpty) ...[
          Text(
            'Voice Notes (${voiceAttachments.length})',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: voiceAttachments.map((attachment) {
              return _buildVoiceAttachmentChip(attachment, theme);
            }).toList(),
          ),
          const SizedBox(height: 16),
        ],

        // Other Attachments
        if (otherAttachments.isNotEmpty) ...[
          Text(
            'Files (${otherAttachments.length})',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: otherAttachments.map((attachment) {
              return _buildFileAttachmentChip(attachment, theme);
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildFileAttachmentChip(NoteAttachment attachment, ThemeData theme) {
    return Chip(
      avatar: Icon(
        _getFileIcon(attachment.fileType),
        size: 16,
      ),
      label: Text(
        attachment.fileName,
        style: const TextStyle(fontSize: 12),
      ),
      deleteIcon: const Icon(Icons.close, size: 16),
      onDeleted: () => _deleteAttachment(attachment),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _buildVoiceAttachmentChip(NoteAttachment attachment, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.mic,
            size: 16,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Text(
            attachment.fileName.replaceAll('.aac', ''),
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () => _playVoiceAttachment(attachment),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.play_circle_outline,
                size: 18,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () => _deleteAttachment(attachment),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: theme.colorScheme.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.close,
                size: 16,
                color: theme.colorScheme.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageAttachmentChip(NoteAttachment attachment, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(right: 8, bottom: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.3),
        ),
      ),
      child: Stack(
        children: [
          // Image Preview
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
              ),
              child: _buildImagePreview(attachment, theme),
            ),
          ),

          // Delete Button
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: () => _deleteAttachment(attachment),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.error,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.close,
                  size: 14,
                  color: Colors.white,
                ),
              ),
            ),
          ),

          // Tap to View Overlay
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _viewImageAttachment(attachment),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.3),
                      ],
                    ),
                  ),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Text(
                        _getShortFileName(attachment.fileName),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          shadows: [
                            Shadow(
                              color: Colors.black,
                              blurRadius: 2,
                            ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePreview(NoteAttachment attachment, ThemeData theme) {
    final file = File(attachment.filePath);

    if (!file.existsSync()) {
      return Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          Icons.broken_image,
          color: theme.colorScheme.onErrorContainer,
          size: 32,
        ),
      );
    }

    return Image.file(
      file,
      width: 80,
      height: 80,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: theme.colorScheme.errorContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.broken_image,
            color: theme.colorScheme.onErrorContainer,
            size: 32,
          ),
        );
      },
    );
  }

  String _getShortFileName(String fileName) {
    if (fileName.length <= 12) return fileName;
    final extension = fileName.split('.').last;
    final nameWithoutExt = fileName.substring(0, fileName.lastIndexOf('.'));
    if (nameWithoutExt.length <= 8) {
      return fileName;
    }
    return '${nameWithoutExt.substring(0, 8)}...$extension';
  }

  Future<void> _viewImageAttachment(NoteAttachment attachment) async {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          children: [
            // Image Viewer
            Center(
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.9,
                  maxHeight: MediaQuery.of(context).size.height * 0.8,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.file(
                    File(attachment.filePath),
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.broken_image,
                              size: 64,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onErrorContainer,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Failed to load image',
                              style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onErrorContainer,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),

            // Close Button
            Positioned(
              top: 40,
              right: 20,
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),

            // File Name
            Positioned(
              bottom: 40,
              left: 20,
              right: 20,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  attachment.fileName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          // Word count
          Text(
            '${_contentController.text.split(' ').where((word) => word.isNotEmpty).length} words',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),

          const Spacer(),

          // Action buttons
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),

          const SizedBox(width: 8),

          ElevatedButton(
            onPressed: _isLoading ? null : _saveNote,
            child: _isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(widget.note != null ? 'Update' : 'Save'),
          ),
        ],
      ),
    );
  }

  // Helper methods and actions will be added in the next part...

  IconData _getFileIcon(String? fileType) {
    if (fileType == null) return Icons.insert_drive_file;

    if (fileType.startsWith('image/')) return Icons.image;
    if (fileType.startsWith('video/')) return Icons.video_file;
    if (fileType.startsWith('audio/')) return Icons.audio_file;
    if (fileType.contains('pdf')) return Icons.picture_as_pdf;
    if (fileType.contains('doc')) return Icons.description;
    if (fileType.contains('sheet') || fileType.contains('excel')) {
      return Icons.table_chart;
    }

    return Icons.insert_drive_file;
  }

  void _showTemplateSelector() {
    final noteProvider = Provider.of<NoteProvider>(context, listen: false);
    final templates = noteProvider.getNoteTemplates();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildTemplateSelector(templates),
    );
  }

  Widget _buildTemplateSelector(List<NoteTemplate> templates) {
    final theme = Theme.of(context);

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text(
                  'Choose Template',
                  style: theme.textTheme.headlineSmall,
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Templates list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: templates.length,
              itemBuilder: (context, index) {
                final template = templates[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          theme.colorScheme.primary.withValues(alpha: 0.1),
                      child: Icon(
                        _getCategoryIcon(template.category),
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    title: Text(template.name),
                    subtitle: Text(template.category),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      Navigator.pop(context);
                      _applyTemplate(template);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _applyTemplate(NoteTemplate template) {
    setState(() {
      _titleController.text = template.title;
      _contentController.text = template.content;
      _selectedCategory = template.category;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Applied template: ${template.name}')),
    );
  }

  void _startVoiceNote() {
    showDialog(
      context: context,
      builder: (context) => _buildEnhancedVoiceNoteDialog(),
    );
  }

  Widget _buildEnhancedVoiceNoteDialog() {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      elevation: 16,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.95,
        height: MediaQuery.of(context).size.height * 0.8,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
          minHeight: 500,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
        child: _buildVoiceNoteContent(),
      ),
    );
  }

  Widget _buildVoiceNoteContent() {
    return VoiceNoteRecorder(
      onVoiceNoteSaved: _handleVoiceNoteSaved,
      onTranscriptionComplete: _handleTranscriptionComplete,
      enableTranscription: true,
      showSaveDialog: true,
    );
  }

  void _handleVoiceNoteSaved(VoiceNote voiceNote) async {
    try {
      // Save audio file as attachment
      await _addVoiceNoteAsAttachment(voiceNote);

      // Add transcription to note content if available
      if (voiceNote.transcription != null &&
          voiceNote.transcription!.isNotEmpty) {
        _addTranscriptionToContent(voiceNote.transcription!);
      }

      if (mounted) {
        Navigator.of(context).pop(); // Close dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Voice note "${voiceNote.title}" saved as attachment!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save voice note: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _handleTranscriptionComplete(String transcription) {
    // This is called when transcription is complete but before saving
    // We can show a preview or allow editing before final save
  }

  Future<void> _addVoiceNoteAsAttachment(VoiceNote voiceNote) async {
    final file = File(voiceNote.audioFilePath);
    if (!await file.exists()) {
      throw Exception('Voice note audio file not found');
    }

    if (widget.note == null) {
      // For new notes, store temporarily until note is saved
      final attachment = NoteAttachment(
        noteId: 'temp',
        fileName: '${voiceNote.title}.aac',
        filePath: voiceNote.audioFilePath,
        fileSize: await file.length(),
        fileType: 'audio/aac',
        createdAt: voiceNote.createdAt,
      );

      setState(() {
        _attachments.add(attachment);
      });
    } else {
      // For existing notes, save directly to provider
      if (mounted) {
        final noteProvider = Provider.of<NoteProvider>(context, listen: false);
        final attachment = await noteProvider.addAttachment(
          noteId: widget.note!.id,
          filePath: voiceNote.audioFilePath,
          fileName: '${voiceNote.title}.aac',
          fileType: 'audio/aac',
          fileSize: await file.length(),
        );

        if (attachment != null) {
          setState(() {
            _attachments.add(attachment);
          });
        }
      }
    }
  }

  void _addTranscriptionToContent(String transcription) {
    final currentText = _contentController.text;
    final newText = currentText.isEmpty
        ? transcription
        : '$currentText\n\n--- Voice Note Transcription ---\n$transcription';

    setState(() {
      _contentController.text = newText;
    });
  }

  Future<void> _playVoiceAttachment(NoteAttachment attachment) async {
    try {
      final voiceRecordingService = VoiceRecordingService();
      await voiceRecordingService.initialize();

      // Play the voice attachment
      await voiceRecordingService.playAudio(attachment.filePath);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Playing "${attachment.fileName}"'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to play voice note: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => _buildAttachmentOptions(),
    );
  }

  Widget _buildAttachmentOptions() {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Add Attachment',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.photo_camera),
            title: const Text('Take Photo'),
            onTap: () {
              Navigator.pop(context);
              _pickImage(ImageSource.camera);
            },
          ),
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: const Text('Choose from Gallery'),
            onTap: () {
              Navigator.pop(context);
              _pickImage(ImageSource.gallery);
            },
          ),
          ListTile(
            leading: const Icon(Icons.attach_file),
            title: const Text('Choose File'),
            onTap: () {
              Navigator.pop(context);
              _pickFile();
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: source);

      if (pickedFile != null) {
        await _addAttachment(
          filePath: pickedFile.path,
          fileName: pickedFile.name,
          fileType: 'image/${pickedFile.path.split('.').last}',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e')),
        );
      }
    }
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles();

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        await _addAttachment(
          filePath: file.path!,
          fileName: file.name,
          fileType:
              file.extension != null ? 'application/${file.extension}' : null,
          fileSize: file.size,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick file: $e')),
        );
      }
    }
  }

  Future<void> _addAttachment({
    required String filePath,
    required String fileName,
    String? fileType,
    int? fileSize,
  }) async {
    if (widget.note == null) {
      // For new notes, store temporarily until note is saved
      setState(() {
        _attachments.add(NoteAttachment(
          noteId: 'temp',
          filePath: filePath,
          fileName: fileName,
          fileType: fileType,
          fileSize: fileSize,
          createdAt: DateTime.now(),
        ));
      });
      return;
    }

    final noteProvider = Provider.of<NoteProvider>(context, listen: false);
    final attachment = await noteProvider.addAttachment(
      noteId: widget.note!.id,
      filePath: filePath,
      fileName: fileName,
      fileType: fileType,
      fileSize: fileSize,
    );

    if (attachment != null) {
      setState(() {
        _attachments.add(attachment);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Attachment added successfully')),
        );
      }
    }
  }

  Future<void> _deleteAttachment(NoteAttachment attachment) async {
    if (attachment.id == null) {
      // Remove from temporary list
      setState(() {
        _attachments.remove(attachment);
      });
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Attachment'),
        content:
            Text('Are you sure you want to delete "${attachment.fileName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final noteProvider = Provider.of<NoteProvider>(context, listen: false);
      final success = await noteProvider.deleteAttachment(attachment.id!);

      if (success && mounted) {
        setState(() {
          _attachments.remove(attachment);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Attachment deleted')),
        );
      }
    }
  }

  Future<void> _saveNote() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final noteProvider = Provider.of<NoteProvider>(context, listen: false);

      if (widget.note != null) {
        // Update existing note
        final updatedNote = widget.note!.copyWith(
          title: _titleController.text.trim(),
          content: _contentController.text.trim(),
          category: _selectedCategory,
          isFavorite: _isFavorite,
        );

        await noteProvider.updateNote(updatedNote);
      } else {
        // Create new note
        final newNote = await noteProvider.createNote(
          title: _titleController.text.trim(),
          content: _contentController.text.trim(),
          category: _selectedCategory,
          isFavorite: _isFavorite,
        );

        // Add any temporary attachments to the new note
        if (newNote != null && _attachments.isNotEmpty) {
          for (final attachment in _attachments) {
            if (attachment.noteId == 'temp') {
              await noteProvider.addAttachment(
                noteId: newNote.id,
                filePath: attachment.filePath,
                fileName: attachment.fileName,
                fileType: attachment.fileType,
                fileSize: attachment.fileSize,
              );
            }
          }
        }
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save note: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Work':
        return Icons.work;
      case 'Personal':
        return Icons.person;
      case 'Study':
        return Icons.school;
      case 'Project':
        return Icons.folder;
      case 'Meeting':
        return Icons.meeting_room;
      case 'Ideas':
        return Icons.lightbulb;
      case 'Quick Note':
        return Icons.note;
      default:
        return Icons.note;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }
}
