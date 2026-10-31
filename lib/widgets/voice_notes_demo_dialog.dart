import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../widgets/voice_note_recorder.dart';
import '../widgets/voice_note_player.dart';
import '../models/voice_note.dart';
import '../services/voice_notes_service.dart';

/// Demo dialog to showcase voice notes functionality
class VoiceNotesDemoDialog extends StatefulWidget {
  final Function(String transcription)? onTranscriptionComplete;

  const VoiceNotesDemoDialog({
    super.key,
    this.onTranscriptionComplete,
  });

  @override
  State<VoiceNotesDemoDialog> createState() => _VoiceNotesDemoDialogState();
}

class _VoiceNotesDemoDialogState extends State<VoiceNotesDemoDialog>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final VoiceNotesService _voiceNotesService = VoiceNotesService();
  List<VoiceNote> _savedVoiceNotes = [];
  String _lastTranscription = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadVoiceNotes();
  }

  Future<void> _loadVoiceNotes() async {
    await _voiceNotesService.initialize();
    setState(() {
      _savedVoiceNotes = _voiceNotesService.voiceNotes;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      elevation: 16,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.95,
        height: MediaQuery.of(context).size.height * 0.88,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
          minHeight: 600,
        ),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: colorScheme.outline.withValues(alpha: 0.2),
          ),
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withValues(alpha: 0.1),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Column(
            children: [
              // Header
              _buildHeader(theme, colorScheme),
              const SizedBox(height: 24),

              // Tab Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildTabBar(theme, colorScheme),
              ),
              const SizedBox(height: 24),

              // Tab Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildRecorderTab(),
                      _buildLibraryTab(),
                    ],
                  ),
                ),
              ),

              // Action Buttons
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: _buildActionButtons(theme, colorScheme),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primaryContainer.withValues(alpha: 0.8),
            colorScheme.primaryContainer.withValues(alpha: 0.4),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.primary,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.primary.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              Icons.mic_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Voice Notes',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Record, transcribe, and manage voice notes',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color:
                        colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: colorScheme.surface.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: Icon(
                Icons.close_rounded,
                color: colorScheme.onSurface,
              ),
              tooltip: 'Close',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: colorScheme.primary,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: colorScheme.primary.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        labelColor: Colors.white,
        unselectedLabelColor: colorScheme.onSurfaceVariant,
        dividerColor: Colors.transparent,
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
        tabs: [
          Tab(
            height: 48,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.mic_rounded,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text('Record'),
              ],
            ),
          ),
          Tab(
            height: 48,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.library_music_rounded,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text('Library'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecorderTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Voice Note Recorder
          VoiceNoteRecorder(
            onVoiceNoteSaved: _onVoiceNoteSaved,
            onTranscriptionComplete: _onTranscriptionComplete,
            enableTranscription: true,
            showSaveDialog: false,
          ),

          // Last Transcription Display
          if (_lastTranscription.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildTranscriptionPreview(),
          ],

          // Demo Features Info
          const SizedBox(height: 16),
          _buildDemoInfo(),

          // Extra bottom padding to prevent overflow
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildLibraryTab() {
    if (_savedVoiceNotes.isEmpty) {
      return _buildEmptyLibrary();
    }

    return Column(
      children: [
        // Library Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            children: [
              Icon(
                Icons.library_music_rounded,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Your Voice Notes (${_savedVoiceNotes.length})',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Voice Notes List
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.only(bottom: 16),
            itemCount: _savedVoiceNotes.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final voiceNote = _savedVoiceNotes[index];
              return VoiceNotePlayer(
                voiceNote: voiceNote,
                onDelete: _deleteVoiceNote,
                onEdit: _editVoiceNote,
                onShare: _shareVoiceNote,
                compact: true,
                showControls: true,
                showTranscription: true,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTranscriptionPreview() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.transcribe,
                color: colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Latest Transcription',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _lastTranscription,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: _useTranscription,
                icon: const Icon(Icons.check, size: 16),
                label: const Text('Use in Note'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDemoInfo() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                color: colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Voice Notes Features',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildFeatureItem(
            icon: Icons.mic,
            title: 'High-Quality Recording',
            description: 'Record audio with configurable quality settings',
          ),
          _buildFeatureItem(
            icon: Icons.transcribe,
            title: 'Speech-to-Text',
            description: 'Convert voice recordings to text automatically',
          ),
          _buildFeatureItem(
            icon: Icons.play_circle,
            title: 'Advanced Playback',
            description: 'Play with speed control, seek, and progress tracking',
          ),
          _buildFeatureItem(
            icon: Icons.folder,
            title: 'Voice Library',
            description: 'Organize and manage all your voice notes',
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyLibrary() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animated Icon Container
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colorScheme.primaryContainer.withValues(alpha: 0.3),
                  colorScheme.secondaryContainer.withValues(alpha: 0.3),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: colorScheme.outline.withValues(alpha: 0.2),
              ),
            ),
            child: Icon(
              Icons.library_music_rounded,
              size: 64,
              color: colorScheme.primary.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 20),

          Text(
            'No Voice Notes Yet',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),

          Text(
            'Record your first voice note to get started.\nYour recordings will appear here.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // Enhanced Start Recording Button
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.primary.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: FilledButton.icon(
              onPressed: () => _tabController.animateTo(0),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: const Icon(
                Icons.mic_rounded,
                size: 20,
              ),
              label: const Text(
                'Start Recording',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Quick Tips
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colorScheme.outline.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.lightbulb_outline_rounded,
                  color: colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Tip: Voice notes are automatically transcribed to text',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (_lastTranscription.isNotEmpty) ...[
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.primary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: FilledButton.icon(
                onPressed: _useTranscription,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(
                  Icons.check_rounded,
                  size: 18,
                ),
                label: const Text(
                  'Use Transcription',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              side: BorderSide(
                color: colorScheme.outline.withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  'Close',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Event Handlers
  void _onVoiceNoteSaved(VoiceNote voiceNote) {
    // Reload voice notes from service
    _loadVoiceNotes();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Voice note "${voiceNote.title}" saved!'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );

    // Switch to library tab to show the saved note
    _tabController.animateTo(1);
  }

  void _onTranscriptionComplete(String transcription) {
    setState(() {
      _lastTranscription = transcription;
    });
  }

  void _useTranscription() {
    widget.onTranscriptionComplete?.call(_lastTranscription);
    Navigator.of(context).pop();
  }

  void _deleteVoiceNote(VoiceNote voiceNote) async {
    final deleted = await _voiceNotesService.deleteVoiceNote(voiceNote.id);

    if (!mounted) return;

    if (deleted) {
      // Reload voice notes from service
      _loadVoiceNotes();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Voice note "${voiceNote.title}" deleted'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete voice note "${voiceNote.title}"'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _editVoiceNote(VoiceNote voiceNote) async {
    var title = voiceNote.title;
    var transcription = voiceNote.transcription ?? '';
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit voice note'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                initialValue: title,
                onChanged: (value) => title = value,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter a title'
                    : null,
              ),
              TextFormField(
                initialValue: transcription,
                onChanged: (value) => transcription = value,
                decoration: const InputDecoration(labelText: 'Transcription'),
                minLines: 3,
                maxLines: 6,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(dialogContext, true);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != true || !mounted) return;
    final updated = voiceNote.copyWith(
      title: title.trim(),
      transcription: transcription.trim(),
      updatedAt: DateTime.now(),
    );
    final success = await _voiceNotesService.updateVoiceNote(updated);
    if (!mounted) return;
    if (success) await _loadVoiceNotes();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            success ? 'Voice note updated' : 'Could not update voice note'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _shareVoiceNote(String audioPath) async {
    try {
      final note = _savedVoiceNotes.firstWhere(
        (voiceNote) => voiceNote.audioFilePath == audioPath,
      );
      if (note.audioFileExists) {
        await Share.shareXFiles(
          [XFile(audioPath)],
          text: '${note.title}\n${note.transcription ?? ''}'.trim(),
        );
      } else {
        await Share.share(
          '${note.title}\n${note.transcription ?? ''}'.trim(),
          subject: note.title,
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not share voice note: $error')),
        );
      }
    }
  }
}
