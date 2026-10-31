import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AudioFeedbackService {
  static final AudioFeedbackService _instance =
      AudioFeedbackService._internal();
  factory AudioFeedbackService() => _instance;
  AudioFeedbackService._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();
  SharedPreferences? _prefs;

  // Audio settings
  bool _soundEffectsEnabled = true;
  bool _notificationSoundsEnabled = true;
  double _volume = 0.7;

  // Audio file paths
  static const String _notificationSound = 'sounds/notification.mp3';
  static const String _applauseSound = 'sounds/applause.mp3';

  // Getters
  bool get soundEffectsEnabled => _soundEffectsEnabled;
  bool get notificationSoundsEnabled => _notificationSoundsEnabled;
  double get volume => _volume;

  /// Initialize the audio feedback service
  Future<void> initialize() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      await _loadSettings();

      // Set initial volume
      await _audioPlayer.setVolume(_volume);

      if (kDebugMode) {
        print('AudioFeedbackService initialized successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing AudioFeedbackService: $e');
      }
    }
  }

  /// Load audio settings from shared preferences
  Future<void> _loadSettings() async {
    _soundEffectsEnabled = _prefs?.getBool('sound_effects_enabled') ?? true;
    _notificationSoundsEnabled =
        _prefs?.getBool('notification_sounds_enabled') ?? true;
    _volume = _prefs?.getDouble('audio_volume') ?? 0.7;
  }

  /// Save audio settings to shared preferences
  Future<void> _saveSettings() async {
    await _prefs?.setBool('sound_effects_enabled', _soundEffectsEnabled);
    await _prefs?.setBool(
        'notification_sounds_enabled', _notificationSoundsEnabled);
    await _prefs?.setDouble('audio_volume', _volume);
  }

  /// Play notification sound for session transitions
  Future<void> playSessionTransition() async {
    if (!_notificationSoundsEnabled) return;

    try {
      await _audioPlayer.stop(); // Stop any currently playing sound
      await _audioPlayer.play(AssetSource(_notificationSound));

      if (kDebugMode) {
        print('Played session transition sound');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error playing session transition sound: $e');
      }
    }
  }

  /// Play completion sound when all sessions are finished
  Future<void> playSessionCompletion() async {
    if (!_soundEffectsEnabled) return;

    try {
      await _audioPlayer.stop(); // Stop any currently playing sound
      await _audioPlayer.play(AssetSource(_applauseSound));

      if (kDebugMode) {
        print('Played session completion sound');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error playing session completion sound: $e');
      }
    }
  }

  /// Play work session start sound
  Future<void> playWorkSessionStart() async {
    if (!_notificationSoundsEnabled) return;
    await playSessionTransition();
  }

  /// Play break session start sound
  Future<void> playBreakSessionStart() async {
    if (!_notificationSoundsEnabled) return;
    await playSessionTransition();
  }

  /// Play work session complete sound
  Future<void> playWorkSessionComplete() async {
    if (!_notificationSoundsEnabled) return;
    await playSessionTransition();
  }

  /// Play break session complete sound
  Future<void> playBreakSessionComplete() async {
    if (!_notificationSoundsEnabled) return;
    await playSessionTransition();
  }

  /// Enable/disable sound effects
  Future<void> setSoundEffectsEnabled(bool enabled) async {
    _soundEffectsEnabled = enabled;
    await _saveSettings();
  }

  /// Enable/disable notification sounds
  Future<void> setNotificationSoundsEnabled(bool enabled) async {
    _notificationSoundsEnabled = enabled;
    await _saveSettings();
  }

  /// Set audio volume (0.0 to 1.0)
  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    await _audioPlayer.setVolume(_volume);
    await _saveSettings();
  }

  /// Test notification sound
  Future<void> testNotificationSound() async {
    await playSessionTransition();
  }

  /// Test completion sound
  Future<void> testCompletionSound() async {
    await playSessionCompletion();
  }

  /// Stop any currently playing audio
  Future<void> stopAudio() async {
    try {
      await _audioPlayer.stop();
    } catch (e) {
      if (kDebugMode) {
        print('Error stopping audio: $e');
      }
    }
  }

  /// Dispose of resources
  Future<void> dispose() async {
    try {
      await _audioPlayer.dispose();
    } catch (e) {
      if (kDebugMode) {
        print('Error disposing AudioFeedbackService: $e');
      }
    }
  }

  /// Get audio settings as a map for UI display
  Map<String, dynamic> getSettings() {
    return {
      'soundEffectsEnabled': _soundEffectsEnabled,
      'notificationSoundsEnabled': _notificationSoundsEnabled,
      'volume': _volume,
    };
  }

  /// Update multiple settings at once
  Future<void> updateSettings({
    bool? soundEffectsEnabled,
    bool? notificationSoundsEnabled,
    double? volume,
  }) async {
    if (soundEffectsEnabled != null) {
      _soundEffectsEnabled = soundEffectsEnabled;
    }

    if (notificationSoundsEnabled != null) {
      _notificationSoundsEnabled = notificationSoundsEnabled;
    }

    if (volume != null) {
      _volume = volume.clamp(0.0, 1.0);
      await _audioPlayer.setVolume(_volume);
    }

    await _saveSettings();
  }

  /// Check if audio is currently playing
  Future<bool> get isPlaying async {
    try {
      final state = await _audioPlayer.getCurrentPosition();
      return state != null && state.inMilliseconds > 0;
    } catch (e) {
      return false;
    }
  }

  /// Preload audio files for better performance
  Future<void> preloadAudio() async {
    try {
      // Preload notification sound
      await _audioPlayer.setSource(AssetSource(_notificationSound));
      await _audioPlayer.setSource(AssetSource(_applauseSound));

      if (kDebugMode) {
        print('Audio files preloaded successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error preloading audio files: $e');
      }
    }
  }
}
