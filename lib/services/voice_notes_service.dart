import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import '../models/voice_note.dart';
import '../utils/error_handler.dart';

/// Enhanced Voice Notes Service with transcription and storage
class VoiceNotesService {
  static final VoiceNotesService _instance = VoiceNotesService._internal();
  factory VoiceNotesService() => _instance;
  VoiceNotesService._internal();

  final SpeechToText _speechToText = SpeechToText();
  SharedPreferences? _prefs;
  List<VoiceNote> _voiceNotes = [];

  bool _isInitialized = false;
  bool _isListening = false;
  String _recognizedText = '';
  double _confidenceLevel = 0.0;

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isListening => _isListening;
  String get recognizedText => _recognizedText;
  double get confidenceLevel => _confidenceLevel;
  List<VoiceNote> get voiceNotes => List.unmodifiable(_voiceNotes);

  /// Initialize the voice notes service
  Future<bool> initialize() async {
    try {
      debugPrint('VoiceNotesService: Starting initialization...');

      // Initialize SharedPreferences
      _prefs = await SharedPreferences.getInstance();

      // Load saved voice notes
      await _loadVoiceNotes();

      // Check and request permissions
      final micPermission = await Permission.microphone.request();
      if (micPermission != PermissionStatus.granted) {
        debugPrint('VoiceNotesService: Microphone permission denied');
        return false;
      }

      // Initialize speech to text
      final speechAvailable = await _speechToText.initialize(
        onError: (error) {
          debugPrint('VoiceNotesService: Speech recognition error: $error');
          _isListening = false;
        },
        onStatus: (status) {
          debugPrint('VoiceNotesService: Speech recognition status: $status');
          _isListening = status == 'listening';
        },
      );

      if (!speechAvailable) {
        debugPrint('VoiceNotesService: Speech recognition not available');
        return false;
      }

      _isInitialized = true;
      debugPrint('VoiceNotesService: Initialization completed successfully');
      return true;
    } catch (e) {
      debugPrint('VoiceNotesService: Initialization failed: $e');
      return false;
    }
  }

  /// Start listening for speech-to-text
  Future<bool> startListening({
    Function(String)? onResult,
    Function(String)? onError,
  }) async {
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) {
        onError?.call('Failed to initialize voice recognition');
        return false;
      }
    }

    try {
      await _speechToText.listen(
        onResult: (result) {
          _recognizedText = result.recognizedWords;
          _confidenceLevel = result.confidence;
          onResult?.call(_recognizedText);
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        partialResults: true,
        localeId: 'en_US', // Can be made configurable
        cancelOnError: true,
      );

      _isListening = true;
      return true;
    } catch (e) {
      debugPrint('VoiceNotesService: Failed to start listening: $e');
      onError?.call('Failed to start voice recognition: $e');
      return false;
    }
  }

  /// Stop listening for speech-to-text
  Future<void> stopListening() async {
    try {
      await _speechToText.stop();
      _isListening = false;
    } catch (e) {
      debugPrint('VoiceNotesService: Failed to stop listening: $e');
    }
  }

  /// Cancel current listening session
  Future<void> cancelListening() async {
    try {
      await _speechToText.cancel();
      _isListening = false;
      _recognizedText = '';
      _confidenceLevel = 0.0;
    } catch (e) {
      debugPrint('VoiceNotesService: Failed to cancel listening: $e');
    }
  }

  /// Get available locales for speech recognition
  Future<List<LocaleName>> getAvailableLocales() async {
    if (!_isInitialized) {
      await initialize();
    }
    return _speechToText.locales();
  }

  /// Check if speech recognition is available on this device
  Future<bool> isAvailable() async {
    try {
      return await _speechToText.initialize();
    } catch (e) {
      return false;
    }
  }

  /// Get current error message if any
  String? getLastError() {
    return _speechToText.lastError?.errorMsg;
  }

  /// Reset the service state
  void reset() {
    _recognizedText = '';
    _confidenceLevel = 0.0;
    _isListening = false;
  }

  /// Transcribe audio file to text
  Future<String?> transcribeAudioFile(String audioFilePath) async {
    try {
      debugPrint(
          'VoiceNotesService: Starting transcription for $audioFilePath');

      if (!_isInitialized) {
        await initialize();
      }

      // For now, we'll use a simulated transcription
      // In a real implementation, you would:
      // 1. Convert audio to the required format
      // 2. Send to a speech-to-text API (Google Cloud Speech, Azure, AWS, etc.)
      // 3. Return the transcribed text

      // Simulate processing time
      await Future.delayed(const Duration(seconds: 2));

      // Check if file exists
      final file = File(audioFilePath);
      if (!await file.exists()) {
        throw Exception('Audio file not found: $audioFilePath');
      }

      // Simulate transcription based on file duration/size
      final fileSize = await file.length();
      if (fileSize < 1024) {
        return 'Audio file too short for transcription.';
      }

      // Return a realistic placeholder transcription
      final timestamp = DateTime.now();
      return 'Voice note recorded on ${timestamp.day}/${timestamp.month}/${timestamp.year} at ${timestamp.hour}:${timestamp.minute}. This is a simulated transcription. In a production app, this would contain the actual speech-to-text conversion of your audio recording.';
    } catch (e) {
      ErrorHandler.logError('Failed to transcribe audio file', e);
      return null;
    }
  }

  Future<void> _ensureStorageReady() async {
    if (_prefs != null) return;
    _prefs = await SharedPreferences.getInstance();
    await _loadVoiceNotes();
  }

  /// Save voice note to storage
  Future<bool> saveVoiceNote(VoiceNote voiceNote) async {
    try {
      await _ensureStorageReady();
      final index = _voiceNotes.indexWhere((note) => note.id == voiceNote.id);
      if (index == -1) {
        _voiceNotes.add(voiceNote);
      } else {
        _voiceNotes[index] = voiceNote;
      }
      await _saveVoiceNotes();
      debugPrint('VoiceNotesService: Voice note saved: ${voiceNote.id}');
      return true;
    } catch (e) {
      ErrorHandler.logError('Failed to save voice note', e);
      return false;
    }
  }

  /// Update voice note metadata while preserving its recording.
  Future<bool> updateVoiceNote(VoiceNote voiceNote) async {
    try {
      await _ensureStorageReady();
      final index = _voiceNotes.indexWhere((note) => note.id == voiceNote.id);
      if (index == -1) return false;
      _voiceNotes[index] = voiceNote.copyWith(updatedAt: DateTime.now());
      await _saveVoiceNotes();
      return true;
    } catch (e) {
      ErrorHandler.logError('Failed to update voice note', e);
      return false;
    }
  }

  /// Delete voice note
  Future<bool> deleteVoiceNote(String voiceNoteId) async {
    try {
      await _ensureStorageReady();
      final index = _voiceNotes.indexWhere((note) => note.id == voiceNoteId);
      if (index != -1) {
        final voiceNote = _voiceNotes[index];

        // Delete audio file
        final audioFile = File(voiceNote.audioFilePath);
        if (await audioFile.exists()) {
          await audioFile.delete();
        }

        // Remove from list
        _voiceNotes.removeAt(index);
        await _saveVoiceNotes();

        debugPrint('VoiceNotesService: Voice note deleted: $voiceNoteId');
        return true;
      }
      return false;
    } catch (e) {
      ErrorHandler.logError('Failed to delete voice note', e);
      return false;
    }
  }

  /// Get voice note by ID
  VoiceNote? getVoiceNote(String id) {
    try {
      return _voiceNotes.firstWhere((note) => note.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Load voice notes from storage
  Future<void> _loadVoiceNotes() async {
    try {
      final voiceNotesJson = _prefs?.getStringList('voice_notes') ?? [];
      _voiceNotes = voiceNotesJson
          .map((json) => VoiceNote.fromJson(jsonDecode(json)))
          .toList();

      // Verify audio files still exist
      final validNotes = <VoiceNote>[];
      for (final note in _voiceNotes) {
        if (await File(note.audioFilePath).exists()) {
          validNotes.add(note);
        }
      }

      if (validNotes.length != _voiceNotes.length) {
        _voiceNotes = validNotes;
        await _saveVoiceNotes();
      }

      debugPrint('VoiceNotesService: Loaded ${_voiceNotes.length} voice notes');
    } catch (e) {
      ErrorHandler.logError('Failed to load voice notes', e);
      _voiceNotes = [];
    }
  }

  /// Save voice notes to storage
  Future<void> _saveVoiceNotes() async {
    try {
      final voiceNotesJson =
          _voiceNotes.map((note) => jsonEncode(note.toJson())).toList();
      await _prefs?.setStringList('voice_notes', voiceNotesJson);
    } catch (e) {
      ErrorHandler.logError('Failed to save voice notes', e);
    }
  }

  /// Get voice notes directory
  Future<Directory> getVoiceNotesDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final voiceNotesDir = Directory('${appDir.path}/voice_notes');

    if (!await voiceNotesDir.exists()) {
      await voiceNotesDir.create(recursive: true);
    }

    return voiceNotesDir;
  }

  /// Dispose of resources
  void dispose() {
    if (_isListening) {
      stopListening();
    }
  }
}

/// Voice notes dialog widget
class VoiceNotesDialog extends StatefulWidget {
  final Function(String) onTextRecognized;
  final String? initialText;

  const VoiceNotesDialog({
    super.key,
    required this.onTextRecognized,
    this.initialText,
  });

  @override
  State<VoiceNotesDialog> createState() => _VoiceNotesDialogState();
}

class _VoiceNotesDialogState extends State<VoiceNotesDialog>
    with TickerProviderStateMixin {
  final VoiceNotesService _voiceService = VoiceNotesService();
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  String _recognizedText = '';
  bool _isListening = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _recognizedText = widget.initialText ?? '';

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _initializeVoiceService();
  }

  Future<void> _initializeVoiceService() async {
    final initialized = await _voiceService.initialize();
    if (!initialized && mounted) {
      setState(() {
        _errorMessage = 'Voice recognition not available on this device';
      });
    }
  }

  Future<void> _startListening() async {
    setState(() {
      _errorMessage = null;
    });

    final success = await _voiceService.startListening(
      onResult: (text) {
        if (mounted) {
          setState(() {
            _recognizedText = text;
          });
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() {
            _errorMessage = error;
            _isListening = false;
          });
          _animationController.stop();
        }
      },
    );

    if (success && mounted) {
      setState(() {
        _isListening = true;
      });
      _animationController.repeat(reverse: true);
    }
  }

  Future<void> _stopListening() async {
    await _voiceService.stopListening();
    if (mounted) {
      setState(() {
        _isListening = false;
      });
      _animationController.stop();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _voiceService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.mic, color: colorScheme.primary),
          const SizedBox(width: 8),
          const Text('Voice Note'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Microphone animation
          AnimatedBuilder(
            animation: _scaleAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _isListening ? _scaleAnimation.value : 1.0,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isListening
                        ? colorScheme.primary.withValues(alpha: 0.2)
                        : colorScheme.surfaceContainerHighest,
                  ),
                  child: Icon(
                    _isListening ? Icons.mic : Icons.mic_none,
                    size: 40,
                    color: _isListening
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 16),

          // Status text
          Text(
            _isListening
                ? 'Listening...'
                : _errorMessage ?? 'Tap microphone to start',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: _errorMessage != null ? colorScheme.error : null,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 16),

          // Recognized text
          if (_recognizedText.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _recognizedText,
                style: theme.textTheme.bodyMedium,
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        if (_isListening)
          TextButton(
            onPressed: _stopListening,
            child: const Text('Stop'),
          )
        else
          TextButton(
            onPressed: _voiceService.isInitialized ? _startListening : null,
            child: const Text('Start'),
          ),
        if (_recognizedText.isNotEmpty)
          FilledButton(
            onPressed: () {
              widget.onTextRecognized(_recognizedText);
              Navigator.pop(context);
            },
            child: const Text('Use Text'),
          ),
      ],
    );
  }
}
