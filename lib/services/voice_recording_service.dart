import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/voice_note.dart';
import '../utils/error_handler.dart';

/// Enhanced voice recording service for FocusBro
class VoiceRecordingService extends ChangeNotifier {
  static final VoiceRecordingService _instance =
      VoiceRecordingService._internal();
  factory VoiceRecordingService() => _instance;
  VoiceRecordingService._internal();

  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();
  SharedPreferences? _prefs;

  // Recording state
  bool _isRecording = false;
  bool _isPlaying = false;
  bool _isPaused = false;
  String? _currentRecordingPath;
  Duration _recordingDuration = Duration.zero;
  Duration _playbackPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  Timer? _recordingTimer;
  StreamSubscription? _playerSubscription;

  // Settings
  String _audioFormat = 'aac';
  int _sampleRate = 44100;
  int _bitRate = 128000;
  bool _enableNoiseReduction = true;
  double _recordingVolume = 1.0;

  // Getters
  bool get isRecording => _isRecording;
  bool get isPlaying => _isPlaying;
  bool get isPaused => _isPaused;
  String? get currentRecordingPath => _currentRecordingPath;
  Duration get recordingDuration => _recordingDuration;
  Duration get playbackPosition => _playbackPosition;
  Duration get totalDuration => _totalDuration;
  String get audioFormat => _audioFormat;
  int get sampleRate => _sampleRate;
  int get bitRate => _bitRate;
  bool get enableNoiseReduction => _enableNoiseReduction;
  double get recordingVolume => _recordingVolume;

  /// Initialize the voice recording service
  Future<bool> initialize() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      await _loadSettings();

      // Setup player listeners
      _setupPlayerListeners();

      return true;
    } catch (e) {
      ErrorHandler.logError('Failed to initialize VoiceRecordingService', e);
      return false;
    }
  }

  /// Setup audio player listeners
  void _setupPlayerListeners() {
    _playerSubscription = _player.positionStream.listen((position) {
      _playbackPosition = position;
      notifyListeners();
    });

    _player.durationStream.listen((duration) {
      if (duration != null) {
        _totalDuration = duration;
        notifyListeners();
      }
    });

    _player.playerStateStream.listen((state) {
      _isPlaying = state.playing;
      notifyListeners();
    });
  }

  /// Check and request microphone permission
  Future<bool> checkPermissions() async {
    try {
      final status = await Permission.microphone.status;

      if (status.isGranted) {
        return true;
      } else if (status.isDenied) {
        final result = await Permission.microphone.request();
        return result.isGranted;
      } else if (status.isPermanentlyDenied) {
        await openAppSettings();
        return false;
      }

      return false;
    } catch (e) {
      ErrorHandler.logError('Failed to check microphone permissions', e);
      return false;
    }
  }

  /// Start recording audio
  Future<bool> startRecording({String? customPath}) async {
    try {
      // Check permissions
      final hasPermission = await checkPermissions();
      if (!hasPermission) {
        throw Exception('Microphone permission not granted');
      }

      // Stop any current recording or playback
      await stopRecording();
      await stopPlayback();

      // Generate recording path
      final recordingPath = customPath ?? await _generateRecordingPath();

      // Configure recording settings
      const config = RecordConfig(
        encoder: AudioEncoder.aacLc,
        sampleRate: 44100,
        bitRate: 128000,
        numChannels: 1,
      );

      // Start recording
      await _recorder.start(config, path: recordingPath);

      _isRecording = true;
      _currentRecordingPath = recordingPath;
      _recordingDuration = Duration.zero;

      // Start duration timer
      _startRecordingTimer();

      notifyListeners();
      debugPrint('VoiceRecordingService: Recording started at $recordingPath');

      return true;
    } catch (e) {
      ErrorHandler.logError('Failed to start recording', e);
      _isRecording = false;
      notifyListeners();
      return false;
    }
  }

  /// Stop recording audio
  Future<String?> stopRecording() async {
    try {
      if (!_isRecording) return _currentRecordingPath;

      final path = await _recorder.stop();

      _isRecording = false;
      _recordingTimer?.cancel();
      _recordingTimer = null;

      notifyListeners();
      debugPrint('VoiceRecordingService: Recording stopped, saved to $path');

      return path;
    } catch (e) {
      ErrorHandler.logError('Failed to stop recording', e);
      _isRecording = false;
      notifyListeners();
      return null;
    }
  }

  /// Pause recording (if supported)
  Future<void> pauseRecording() async {
    try {
      await _recorder.pause();
      _recordingTimer?.cancel();
      notifyListeners();
    } catch (e) {
      ErrorHandler.logError('Failed to pause recording', e);
    }
  }

  /// Resume recording (if supported)
  Future<void> resumeRecording() async {
    try {
      await _recorder.resume();
      _startRecordingTimer();
      notifyListeners();
    } catch (e) {
      ErrorHandler.logError('Failed to resume recording', e);
    }
  }

  /// Play audio file
  Future<bool> playAudio(String filePath) async {
    try {
      await stopPlayback();

      await _player.setFilePath(filePath);
      await _player.play();

      _isPlaying = true;
      _isPaused = false;

      notifyListeners();
      debugPrint('VoiceRecordingService: Playing audio from $filePath');

      return true;
    } catch (e) {
      ErrorHandler.logError('Failed to play audio', e);
      _isPlaying = false;
      notifyListeners();
      return false;
    }
  }

  /// Pause audio playback
  Future<void> pausePlayback() async {
    try {
      await _player.pause();
      _isPaused = true;
      notifyListeners();
    } catch (e) {
      ErrorHandler.logError('Failed to pause playback', e);
    }
  }

  /// Resume audio playback
  Future<void> resumePlayback() async {
    try {
      await _player.play();
      _isPaused = false;
      notifyListeners();
    } catch (e) {
      ErrorHandler.logError('Failed to resume playback', e);
    }
  }

  /// Stop audio playback
  Future<void> stopPlayback() async {
    try {
      await _player.stop();
      _isPlaying = false;
      _isPaused = false;
      _playbackPosition = Duration.zero;
      notifyListeners();
    } catch (e) {
      ErrorHandler.logError('Failed to stop playback', e);
    }
  }

  /// Seek to position in audio
  Future<void> seekTo(Duration position) async {
    try {
      await _player.seek(position);
      _playbackPosition = position;
      notifyListeners();
    } catch (e) {
      ErrorHandler.logError('Failed to seek audio', e);
    }
  }

  /// Set playback speed
  Future<void> setPlaybackSpeed(double speed) async {
    try {
      await _player.setSpeed(speed);
      notifyListeners();
    } catch (e) {
      ErrorHandler.logError('Failed to set playback speed', e);
    }
  }

  /// Delete audio file
  Future<bool> deleteAudioFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        debugPrint('VoiceRecordingService: Deleted audio file $filePath');
        return true;
      }
      return false;
    } catch (e) {
      ErrorHandler.logError('Failed to delete audio file', e);
      return false;
    }
  }

  /// Get audio file duration
  Future<Duration?> getAudioDuration(String filePath) async {
    try {
      final tempPlayer = AudioPlayer();
      await tempPlayer.setFilePath(filePath);
      final duration = tempPlayer.duration;
      await tempPlayer.dispose();
      return duration;
    } catch (e) {
      ErrorHandler.logError('Failed to get audio duration', e);
      return null;
    }
  }

  /// Generate unique recording file path
  Future<String> _generateRecordingPath() async {
    final directory = await getApplicationDocumentsDirectory();
    final recordingsDir = Directory('${directory.path}/voice_notes');

    if (!await recordingsDir.exists()) {
      await recordingsDir.create(recursive: true);
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '${recordingsDir.path}/recording_$timestamp.$_audioFormat';
  }

  /// Start recording duration timer
  void _startRecordingTimer() {
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _recordingDuration = Duration(seconds: timer.tick);
      notifyListeners();
    });
  }

  /// Load recording settings
  Future<void> _loadSettings() async {
    _audioFormat = _prefs?.getString('voice_audio_format') ?? 'aac';
    _sampleRate = _prefs?.getInt('voice_sample_rate') ?? 44100;
    _bitRate = _prefs?.getInt('voice_bit_rate') ?? 128000;
    _enableNoiseReduction = _prefs?.getBool('voice_noise_reduction') ?? true;
    _recordingVolume = _prefs?.getDouble('voice_recording_volume') ?? 1.0;
  }

  /// Save recording settings
  Future<void> _saveSettings() async {
    await _prefs?.setString('voice_audio_format', _audioFormat);
    await _prefs?.setInt('voice_sample_rate', _sampleRate);
    await _prefs?.setInt('voice_bit_rate', _bitRate);
    await _prefs?.setBool('voice_noise_reduction', _enableNoiseReduction);
    await _prefs?.setDouble('voice_recording_volume', _recordingVolume);
  }

  /// Update recording settings
  Future<void> updateSettings({
    String? audioFormat,
    int? sampleRate,
    int? bitRate,
    bool? enableNoiseReduction,
    double? recordingVolume,
  }) async {
    if (audioFormat != null) _audioFormat = audioFormat;
    if (sampleRate != null) _sampleRate = sampleRate;
    if (bitRate != null) _bitRate = bitRate;
    if (enableNoiseReduction != null)
      _enableNoiseReduction = enableNoiseReduction;
    if (recordingVolume != null)
      _recordingVolume = recordingVolume.clamp(0.0, 1.0);

    await _saveSettings();
    notifyListeners();
  }

  /// Dispose resources
  @override
  void dispose() {
    _recordingTimer?.cancel();
    _playerSubscription?.cancel();
    _recorder.dispose();
    _player.dispose();
    super.dispose();
  }
}
