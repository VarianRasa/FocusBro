import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/voice_recording_service.dart';
import '../services/voice_notes_service.dart';
import '../models/voice_note.dart';

/// Enhanced voice note recorder widget with recording and transcription
class VoiceNoteRecorder extends StatefulWidget {
  final Function(VoiceNote voiceNote)? onVoiceNoteSaved;
  final Function(String transcription)? onTranscriptionComplete;
  final bool enableTranscription;
  final bool showSaveDialog;
  final String? initialTitle;

  const VoiceNoteRecorder({
    super.key,
    this.onVoiceNoteSaved,
    this.onTranscriptionComplete,
    this.enableTranscription = true,
    this.showSaveDialog = true,
    this.initialTitle,
  });

  @override
  State<VoiceNoteRecorder> createState() => _VoiceNoteRecorderState();
}

class _VoiceNoteRecorderState extends State<VoiceNoteRecorder>
    with TickerProviderStateMixin {
  late VoiceRecordingService _recordingService;
  late VoiceNotesService _voiceNotesService;
  late AnimationController _pulseController;
  late AnimationController _waveController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _waveAnimation;

  String? _currentRecordingPath;
  String _transcription = '';
  bool _isTranscribing = false;
  String? _errorMessage;
  final TextEditingController _titleController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _recordingService = VoiceRecordingService();
    _voiceNotesService = VoiceNotesService();

    // Initialize title
    _titleController.text = widget.initialTitle ??
        'Voice Note ${DateTime.now().day}/${DateTime.now().month}';

    // Setup animations
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _waveController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _waveAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _waveController, curve: Curves.linear),
    );

    _initializeServices();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _waveController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _initializeServices() async {
    await _recordingService.initialize();
    await _voiceNotesService.initialize();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ChangeNotifierProvider.value(
      value: _recordingService,
      child: Consumer<VoiceRecordingService>(
        builder: (context, service, child) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colorScheme.outline.withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                _buildHeader(theme, colorScheme),
                const SizedBox(height: 20),

                // Recording Controls
                _buildRecordingControls(theme, colorScheme, service),
                const SizedBox(height: 20),

                // Recording Status
                if (service.isRecording || _currentRecordingPath != null)
                  _buildRecordingStatus(theme, colorScheme, service),

                // Transcription Section
                if (widget.enableTranscription && _transcription.isNotEmpty)
                  _buildTranscriptionSection(theme, colorScheme),

                // Error Message
                if (_errorMessage != null)
                  _buildErrorMessage(theme, colorScheme),

                // Action Buttons
                if (_currentRecordingPath != null)
                  _buildActionButtons(theme, colorScheme, service),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, ColorScheme colorScheme) {
    return Row(
      children: [
        Icon(
          Icons.mic,
          color: colorScheme.primary,
          size: 24,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'Voice Note Recorder',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecordingControls(
    ThemeData theme,
    ColorScheme colorScheme,
    VoiceRecordingService service,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Record/Stop Button
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: service.isRecording ? _pulseAnimation.value : 1.0,
              child: FloatingActionButton(
                onPressed:
                    service.isRecording ? _stopRecording : _startRecording,
                backgroundColor:
                    service.isRecording ? Colors.red : colorScheme.primary,
                child: Icon(
                  service.isRecording ? Icons.stop : Icons.mic,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            );
          },
        ),

        // Play/Pause Button
        if (_currentRecordingPath != null)
          FloatingActionButton(
            onPressed: service.isPlaying
                ? (service.isPaused ? _resumePlayback : _pausePlayback)
                : _playRecording,
            backgroundColor: colorScheme.secondary,
            child: Icon(
              service.isPlaying && !service.isPaused
                  ? Icons.pause
                  : Icons.play_arrow,
              color: Colors.white,
              size: 28,
            ),
          ),

        // Delete Button
        if (_currentRecordingPath != null)
          FloatingActionButton(
            onPressed: _deleteRecording,
            backgroundColor: Colors.red.withValues(alpha: 0.8),
            child: const Icon(
              Icons.delete,
              color: Colors.white,
              size: 28,
            ),
          ),
      ],
    );
  }

  Widget _buildRecordingStatus(
    ThemeData theme,
    ColorScheme colorScheme,
    VoiceRecordingService service,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Duration Display
          Text(
            service.isRecording
                ? _formatDuration(service.recordingDuration)
                : _formatDuration(service.totalDuration),
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: service.isRecording ? Colors.red : colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),

          // Status Text
          Text(
            service.isRecording
                ? 'Recording...'
                : service.isPlaying
                    ? 'Playing...'
                    : 'Ready to play',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),

          // Progress Bar for Playback
          if (service.isPlaying || service.isPaused) ...[
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: service.totalDuration.inMilliseconds > 0
                  ? service.playbackPosition.inMilliseconds /
                      service.totalDuration.inMilliseconds
                  : 0.0,
              backgroundColor: colorScheme.outline.withValues(alpha: 0.2),
              valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDuration(service.playbackPosition),
                  style: theme.textTheme.labelSmall,
                ),
                Text(
                  _formatDuration(service.totalDuration),
                  style: theme.textTheme.labelSmall,
                ),
              ],
            ),
          ],

          // Recording Wave Animation
          if (service.isRecording) ...[
            const SizedBox(height: 12),
            AnimatedBuilder(
              animation: _waveAnimation,
              builder: (context, child) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    final delay = index * 0.2;
                    final animValue = (_waveAnimation.value + delay) % 1.0;
                    final height = 4 +
                        (20 *
                            (0.5 +
                                0.5 *
                                    (animValue < 0.5
                                        ? animValue * 2
                                        : (1 - animValue) * 2)));

                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      width: 4,
                      height: height,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    );
                  }),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTranscriptionSection(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
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
                'Transcription',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (_isTranscribing)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(colorScheme.primary),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _transcription.isEmpty
                ? 'No transcription available'
                : _transcription,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: _transcription.isEmpty
                  ? colorScheme.onSurfaceVariant
                  : colorScheme.onSurface,
            ),
          ),
          if (_transcription.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: _copyTranscription,
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('Copy'),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: _useTranscription,
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('Use Text'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorMessage(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error, color: Colors.red, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage!,
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(
    ThemeData theme,
    ColorScheme colorScheme,
    VoiceRecordingService service,
  ) {
    return Container(
      margin: const EdgeInsets.only(top: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Transcribe Button
          if (widget.enableTranscription)
            ElevatedButton.icon(
              onPressed: _isTranscribing ? null : _transcribeAudio,
              icon: _isTranscribing
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          colorScheme.onPrimary,
                        ),
                      ),
                    )
                  : const Icon(Icons.transcribe),
              label: Text(_isTranscribing ? 'Transcribing...' : 'Transcribe'),
            ),

          // Save Button
          if (widget.showSaveDialog)
            FilledButton.icon(
              onPressed: _saveVoiceNote,
              icon: const Icon(Icons.save),
              label: const Text('Save Note'),
            ),
        ],
      ),
    );
  }

  // Action Methods
  Future<void> _startRecording() async {
    setState(() {
      _errorMessage = null;
    });

    final success = await _recordingService.startRecording();
    if (success) {
      _pulseController.repeat(reverse: true);
      _waveController.repeat();
    } else {
      setState(() {
        _errorMessage =
            'Failed to start recording. Please check microphone permissions.';
      });
    }
  }

  Future<void> _stopRecording() async {
    final path = await _recordingService.stopRecording();
    _pulseController.stop();
    _waveController.stop();

    if (path != null) {
      setState(() {
        _currentRecordingPath = path;
      });
    }
  }

  Future<void> _playRecording() async {
    if (_currentRecordingPath != null) {
      await _recordingService.playAudio(_currentRecordingPath!);
    }
  }

  Future<void> _pausePlayback() async {
    await _recordingService.pausePlayback();
  }

  Future<void> _resumePlayback() async {
    await _recordingService.resumePlayback();
  }

  Future<void> _deleteRecording() async {
    if (_currentRecordingPath != null) {
      await _recordingService.deleteAudioFile(_currentRecordingPath!);
      setState(() {
        _currentRecordingPath = null;
        _transcription = '';
      });
    }
  }

  Future<void> _transcribeAudio() async {
    if (_currentRecordingPath == null) return;

    setState(() {
      _isTranscribing = true;
      _errorMessage = null;
    });

    try {
      // Use the enhanced VoiceNotesService for real transcription
      final transcriptionResult =
          await _voiceNotesService.transcribeAudioFile(_currentRecordingPath!);

      setState(() {
        if (transcriptionResult != null && transcriptionResult.isNotEmpty) {
          _transcription = transcriptionResult;
        } else {
          _transcription =
              'No speech detected in the recording. Please try recording again with clearer speech.';
        }
        _isTranscribing = false;
      });

      widget.onTranscriptionComplete?.call(_transcription);
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to transcribe audio: ${e.toString()}';
        _isTranscribing = false;
      });
    }
  }

  void _copyTranscription() {
    // Copy transcription to clipboard
    // Implementation would use Clipboard.setData()
  }

  void _useTranscription() {
    widget.onTranscriptionComplete?.call(_transcription);
  }

  Future<void> _saveVoiceNote() async {
    if (_currentRecordingPath == null) return;

    try {
      final duration =
          await _recordingService.getAudioDuration(_currentRecordingPath!);

      final voiceNote = VoiceNote(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: _titleController.text.trim(),
        transcription: _transcription.isEmpty ? null : _transcription,
        audioFilePath: _currentRecordingPath!,
        duration: duration ?? Duration.zero,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Save to VoiceNotesService
      final saved = await _voiceNotesService.saveVoiceNote(voiceNote);

      if (saved) {
        widget.onVoiceNoteSaved?.call(voiceNote);

        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('Voice note "${voiceNote.title}" saved successfully!'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        throw Exception('Failed to save voice note to storage');
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

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
