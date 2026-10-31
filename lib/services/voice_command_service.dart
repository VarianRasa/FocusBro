import 'dart:async';
// Temporarily disabled for compatibility
// import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Voice command service for hands-free timer control
class VoiceCommandService {
  static final VoiceCommandService _instance = VoiceCommandService._internal();
  factory VoiceCommandService() => _instance;
  VoiceCommandService._internal();

  // Temporarily disabled for compatibility
  // final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();
  SharedPreferences? _prefs;

  bool _isInitialized = false;
  bool _isListening = false;
  bool _isAvailable = false;
  bool _voiceCommandsEnabled = true;
  bool _voiceFeedbackEnabled = true;
  String _currentLanguage = 'en-US';
  double _speechRate = 0.5;
  double _speechPitch = 1.0;
  double _speechVolume = 0.8;

  // Voice command callbacks
  Function()? _onStartTimer;
  Function()? _onPauseTimer;
  Function()? _onResetTimer;
  Function()? _onSkipSession;
  Function(int)? _onSetWorkDuration;
  Function(int)? _onSetBreakDuration;
  Function()? _onShowStats;
  Function()? _onShowSettings;

  // Command patterns
  final Map<String, List<String>> _commandPatterns = {
    'start': [
      'start timer',
      'begin timer',
      'start focus',
      'begin focus',
      'start session',
      'begin session',
      'go',
      'play',
    ],
    'pause': [
      'pause timer',
      'stop timer',
      'pause focus',
      'stop focus',
      'pause session',
      'stop session',
      'pause',
      'stop',
    ],
    'reset': [
      'reset timer',
      'restart timer',
      'reset focus',
      'restart focus',
      'reset session',
      'restart session',
      'reset',
      'restart',
    ],
    'skip': [
      'skip session',
      'skip timer',
      'next session',
      'skip this',
      'skip',
      'next',
    ],
    'stats': [
      'show stats',
      'show statistics',
      'show analytics',
      'my stats',
      'my progress',
      'statistics',
      'analytics',
    ],
    'settings': [
      'show settings',
      'open settings',
      'settings',
      'preferences',
      'options',
    ],
  };

  /// Initialize voice command service
  Future<void> initialize() async {
    if (_isInitialized) return;

    _prefs = await SharedPreferences.getInstance();
    await _loadSettings();

    // Speech recognition temporarily disabled for compatibility
    _isAvailable = false; // Will be true when speech_to_text is re-enabled
    // _isAvailable = await _speech.initialize(
    //   onStatus: _onSpeechStatus,
    //   onError: _onSpeechError,
    // );

    // Initialize text-to-speech
    await _initializeTTS();

    _isInitialized = true;
  }

  /// Initialize text-to-speech
  Future<void> _initializeTTS() async {
    await _tts.setLanguage(_currentLanguage.split('-')[0]);
    await _tts.setSpeechRate(_speechRate);
    await _tts.setPitch(_speechPitch);
    await _tts.setVolume(_speechVolume);
  }

  /// Load voice settings from preferences
  Future<void> _loadSettings() async {
    _voiceCommandsEnabled = _prefs?.getBool('voice_commands_enabled') ?? true;
    _voiceFeedbackEnabled = _prefs?.getBool('voice_feedback_enabled') ?? true;
    _currentLanguage = _prefs?.getString('voice_language') ?? 'en-US';
    _speechRate = _prefs?.getDouble('speech_rate') ?? 0.5;
    _speechPitch = _prefs?.getDouble('speech_pitch') ?? 1.0;
    _speechVolume = _prefs?.getDouble('speech_volume') ?? 0.8;
  }

  /// Set voice command callbacks
  void setCallbacks({
    Function()? onStartTimer,
    Function()? onPauseTimer,
    Function()? onResetTimer,
    Function()? onSkipSession,
    Function(int)? onSetWorkDuration,
    Function(int)? onSetBreakDuration,
    Function()? onShowStats,
    Function()? onShowSettings,
  }) {
    _onStartTimer = onStartTimer;
    _onPauseTimer = onPauseTimer;
    _onResetTimer = onResetTimer;
    _onSkipSession = onSkipSession;
    _onSetWorkDuration = onSetWorkDuration;
    _onSetBreakDuration = onSetBreakDuration;
    _onShowStats = onShowStats;
    _onShowSettings = onShowSettings;
  }

  /// Start listening for voice commands (temporarily disabled)
  Future<void> startListening() async {
    // Speech-to-text temporarily disabled for compatibility
    return;

    // if (!_isInitialized ||
    //     !_isAvailable ||
    //     !_voiceCommandsEnabled ||
    //     _isListening) {
    //   return;
    // }

    // await _speech.listen(
    //   onResult: _onSpeechResult,
    //   listenFor: const Duration(seconds: 10),
    //   pauseFor: const Duration(seconds: 3),
    //   partialResults: false,
    //   localeId: _currentLanguage,
    //   listenMode: stt.ListenMode.confirmation,
    // );

    // _isListening = true;
  }

  /// Stop listening for voice commands (temporarily disabled)
  Future<void> stopListening() async {
    // Speech-to-text temporarily disabled for compatibility
    _isListening = false;

    // if (_isListening) {
    //   await _speech.stop();
    //   _isListening = false;
    // }
  }

  /// Process voice command
  void _processVoiceCommand(String command) {
    // Check for timer control commands
    if (_matchesCommand(command, 'start')) {
      _onStartTimer?.call();
      _speakFeedback('Starting timer');
    } else if (_matchesCommand(command, 'pause')) {
      _onPauseTimer?.call();
      _speakFeedback('Pausing timer');
    } else if (_matchesCommand(command, 'reset')) {
      _onResetTimer?.call();
      _speakFeedback('Resetting timer');
    } else if (_matchesCommand(command, 'skip')) {
      _onSkipSession?.call();
      _speakFeedback('Skipping session');
    } else if (_matchesCommand(command, 'stats')) {
      _onShowStats?.call();
      _speakFeedback('Showing statistics');
    } else if (_matchesCommand(command, 'settings')) {
      _onShowSettings?.call();
      _speakFeedback('Opening settings');
    } else if (_containsTimeCommand(command)) {
      _processTimeCommand(command);
    } else {
      _speakFeedback('Command not recognized');
    }
  }

  /// Check if command matches pattern
  bool _matchesCommand(String command, String commandType) {
    final patterns = _commandPatterns[commandType] ?? [];
    return patterns.any((pattern) => command.contains(pattern));
  }

  /// Check if command contains time setting
  bool _containsTimeCommand(String command) {
    return command.contains('set') &&
        (command.contains('work') ||
            command.contains('break') ||
            command.contains('focus')) &&
        (command.contains('minute') || command.contains('minutes'));
  }

  /// Process time setting commands
  void _processTimeCommand(String command) {
    final words = command.split(' ');
    int? minutes;

    // Extract number from command
    for (int i = 0; i < words.length; i++) {
      final word = words[i];
      final number = int.tryParse(word);
      if (number != null && number > 0 && number <= 120) {
        minutes = number;
        break;
      }
    }

    if (minutes != null) {
      if (command.contains('work') || command.contains('focus')) {
        _onSetWorkDuration?.call(minutes * 60);
        _speakFeedback('Work duration set to $minutes minutes');
      } else if (command.contains('break')) {
        _onSetBreakDuration?.call(minutes * 60);
        _speakFeedback('Break duration set to $minutes minutes');
      }
    } else {
      _speakFeedback('Please specify a valid number of minutes');
    }
  }

  /// Speak feedback to user
  Future<void> _speakFeedback(String message) async {
    if (_voiceFeedbackEnabled) {
      await _tts.speak(message);
    }
  }

  /// Speak timer status
  Future<void> speakTimerStatus({
    required int timeLeft,
    required bool isWorkTime,
    required bool isRunning,
  }) async {
    if (!_voiceFeedbackEnabled) return;

    final minutes = timeLeft ~/ 60;
    final seconds = timeLeft % 60;
    final sessionType = isWorkTime ? 'work' : 'break';
    final status = isRunning ? 'running' : 'paused';

    String message;
    if (minutes > 0) {
      message =
          '$minutes minutes and $seconds seconds remaining in $sessionType session. Timer is $status.';
    } else {
      message =
          '$seconds seconds remaining in $sessionType session. Timer is $status.';
    }

    await _tts.speak(message);
  }

  /// Speak session completion
  Future<void> speakSessionComplete({
    required bool isWorkTime,
    required int nextDuration,
  }) async {
    if (!_voiceFeedbackEnabled) return;

    final completedType = isWorkTime ? 'work' : 'break';
    final nextType = isWorkTime ? 'break' : 'work';
    final nextMinutes = nextDuration ~/ 60;

    final message =
        '$completedType session complete. Starting $nextMinutes minute $nextType session.';
    await _tts.speak(message);
  }

  /// Enable/disable voice commands
  Future<void> setVoiceCommandsEnabled(bool enabled) async {
    _voiceCommandsEnabled = enabled;
    await _prefs?.setBool('voice_commands_enabled', enabled);

    if (!enabled && _isListening) {
      await stopListening();
    }
  }

  /// Enable/disable voice feedback
  Future<void> setVoiceFeedbackEnabled(bool enabled) async {
    _voiceFeedbackEnabled = enabled;
    await _prefs?.setBool('voice_feedback_enabled', enabled);
  }

  /// Set speech rate
  Future<void> setSpeechRate(double rate) async {
    _speechRate = rate;
    await _tts.setSpeechRate(rate);
    await _prefs?.setDouble('speech_rate', rate);
  }

  /// Set speech pitch
  Future<void> setSpeechPitch(double pitch) async {
    _speechPitch = pitch;
    await _tts.setPitch(pitch);
    await _prefs?.setDouble('speech_pitch', pitch);
  }

  /// Set speech volume
  Future<void> setSpeechVolume(double volume) async {
    _speechVolume = volume;
    await _tts.setVolume(volume);
    await _prefs?.setDouble('speech_volume', volume);
  }

  /// Set voice language
  Future<void> setVoiceLanguage(String language) async {
    _currentLanguage = language;
    await _tts.setLanguage(language.split('-')[0]);
    await _prefs?.setString('voice_language', language);
  }

  /// Get available languages
  Future<List<String>> getAvailableLanguages() async {
    final languages = await _tts.getLanguages;
    return languages?.cast<String>() ?? ['en-US'];
  }

  /// Check if voice commands are available
  bool get isAvailable => _isAvailable && _voiceCommandsEnabled;

  /// Check if currently listening
  bool get isListening => _isListening;

  /// Get voice settings
  Map<String, dynamic> get voiceSettings => {
        'voiceCommandsEnabled': _voiceCommandsEnabled,
        'voiceFeedbackEnabled': _voiceFeedbackEnabled,
        'speechRate': _speechRate,
        'speechPitch': _speechPitch,
        'speechVolume': _speechVolume,
        'currentLanguage': _currentLanguage,
      };

  /// Get supported commands
  List<String> get supportedCommands => [
        'Start timer / Begin focus',
        'Pause timer / Stop focus',
        'Reset timer / Restart focus',
        'Skip session / Next session',
        'Set work 25 minutes',
        'Set break 5 minutes',
        'Show stats / Show analytics',
        'Show settings / Open settings',
      ];

  /// Dispose resources
  void dispose() {
    // _speech.cancel(); // Temporarily disabled
    _tts.stop();
  }
}
