import 'dart:async';
import 'dart:convert';

import 'dart:math';
import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/music_track.dart';
import 'audio_equalizer_service.dart';
import 'music_history_service.dart';

/// Comprehensive music service for background music management
class MusicService extends ChangeNotifier {
  static int _playlistIdSequence = 0;
  static final MusicService _instance = MusicService._internal();
  factory MusicService() => _instance;
  MusicService._internal();

  // Audio player for background music
  final ap.AudioPlayer _musicPlayer = ap.AudioPlayer();

  // Advanced services
  final AudioEqualizerService _equalizerService = AudioEqualizerService();
  final MusicHistoryService _historyService = MusicHistoryService();

  // State management
  PlayerState _playerState = PlayerState.stopped;
  MusicTrack? _currentTrack;
  MusicPlaylist? _currentPlaylist;
  List<MusicTrack> _allTracks = [];
  List<MusicPlaylist> _allPlaylists = [];

  // Playback settings
  PlaybackMode _playbackMode = PlaybackMode.normal;
  double _musicVolume = 0.5;
  bool _isMusicEnabled = false;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;

  // Auto-play settings
  String? _workPlaylistId;
  String? _breakPlaylistId;
  bool _autoPlayEnabled = true;
  bool _fadeTransitions = true;

  // Internal state
  SharedPreferences? _prefs;
  bool _isInitialized = false;
  Timer? _positionTimer;
  List<String> _shuffleOrder = [];
  int _currentShuffleIndex = 0;

  // Getters
  PlayerState get playerState => _playerState;
  MusicTrack? get currentTrack => _currentTrack;
  MusicPlaylist? get currentPlaylist => _currentPlaylist;
  List<MusicTrack> get allTracks => List.unmodifiable(_allTracks);
  List<MusicPlaylist> get allPlaylists => List.unmodifiable(_allPlaylists);
  PlaybackMode get playbackMode => _playbackMode;
  double get musicVolume => _musicVolume;
  bool get isMusicEnabled => _isMusicEnabled;
  Duration get currentPosition => _currentPosition;
  Duration get totalDuration => _totalDuration;
  bool get autoPlayEnabled => _autoPlayEnabled;
  bool get fadeTransitions => _fadeTransitions;
  String? get workPlaylistId => _workPlaylistId;
  String? get breakPlaylistId => _breakPlaylistId;

  // Advanced services getters
  AudioEqualizerService get equalizerService => _equalizerService;
  MusicHistoryService get historyService => _historyService;

  bool get isPlaying => _playerState == PlayerState.playing;
  bool get isPaused => _playerState == PlayerState.paused;
  bool get isLoading => _playerState == PlayerState.loading;
  bool get hasError => _playerState == PlayerState.error;

  double get progress {
    if (_totalDuration.inMilliseconds == 0) return 0.0;
    return _currentPosition.inMilliseconds / _totalDuration.inMilliseconds;
  }

  /// Initialize the music service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _prefs = await SharedPreferences.getInstance();
      await _loadSettings();
      await _loadBuiltInTracks();
      await _loadUserTracks();
      await _loadPlaylists();

      // Setup audio player listeners
      _setupAudioPlayerListeners();

      // Set initial volume
      await _musicPlayer.setVolume(_musicVolume);

      // Initialize advanced services
      await _equalizerService.initialize();
      await _historyService.initialize();

      _isInitialized = true;

      if (kDebugMode) {
        print('MusicService initialized successfully');
        print(
            'Loaded ${_allTracks.length} tracks and ${_allPlaylists.length} playlists');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing MusicService: $e');
      }
    }
  }

  /// Setup audio player event listeners
  void _setupAudioPlayerListeners() {
    _musicPlayer.onPlayerStateChanged.listen((state) {
      switch (state) {
        case ap.PlayerState.playing:
          _playerState = PlayerState.playing;
          _startPositionTimer();
          break;
        case ap.PlayerState.paused:
          _playerState = PlayerState.paused;
          _stopPositionTimer();
          break;
        case ap.PlayerState.stopped:
          _playerState = PlayerState.stopped;
          _stopPositionTimer();
          _currentPosition = Duration.zero;
          break;
        case ap.PlayerState.completed:
          _onTrackCompleted();
          break;
        case ap.PlayerState.disposed:
          _playerState = PlayerState.stopped;
          _stopPositionTimer();
          break;
      }
      notifyListeners();
    });

    _musicPlayer.onDurationChanged.listen((duration) {
      _totalDuration = duration;
      notifyListeners();
    });

    _musicPlayer.onPositionChanged.listen((position) {
      _currentPosition = position;
      notifyListeners();
    });
  }

  /// Start position tracking timer
  void _startPositionTimer() {
    _stopPositionTimer();
    _positionTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      // Position is updated via listener, this is just for backup
    });
  }

  /// Stop position tracking timer
  void _stopPositionTimer() {
    _positionTimer?.cancel();
    _positionTimer = null;
  }

  /// Handle track completion
  void _onTrackCompleted() {
    // Record track completion in history
    _historyService.endListeningSession(completed: true);

    switch (_playbackMode) {
      case PlaybackMode.normal:
        playNext();
        break;
      case PlaybackMode.repeat:
        replay();
        break;
      case PlaybackMode.repeatAll:
        playNext();
        break;
      case PlaybackMode.shuffle:
        playNext();
        break;
    }
  }

  /// Load settings from SharedPreferences
  Future<void> _loadSettings() async {
    _musicVolume = _prefs?.getDouble('music_volume') ?? 0.5;
    _isMusicEnabled = _prefs?.getBool('music_enabled') ?? false;
    _autoPlayEnabled = _prefs?.getBool('auto_play_enabled') ?? true;
    _fadeTransitions = _prefs?.getBool('fade_transitions') ?? true;
    _workPlaylistId = _prefs?.getString('work_playlist_id');
    _breakPlaylistId = _prefs?.getString('break_playlist_id');

    final playbackModeIndex = _prefs?.getInt('playback_mode') ?? 0;
    _playbackMode = PlaybackMode
        .values[playbackModeIndex.clamp(0, PlaybackMode.values.length - 1)];
  }

  /// Save settings to SharedPreferences
  Future<void> _saveSettings() async {
    await _prefs?.setDouble('music_volume', _musicVolume);
    await _prefs?.setBool('music_enabled', _isMusicEnabled);
    await _prefs?.setBool('auto_play_enabled', _autoPlayEnabled);
    await _prefs?.setBool('fade_transitions', _fadeTransitions);
    await _prefs?.setString('work_playlist_id', _workPlaylistId ?? '');
    await _prefs?.setString('break_playlist_id', _breakPlaylistId ?? '');
    await _prefs?.setInt('playback_mode', _playbackMode.index);
  }

  /// Load built-in music tracks
  Future<void> _loadBuiltInTracks() async {
    _allTracks.addAll([
      // Nature Sounds
      const MusicTrack(
        id: 'nature_rain',
        title: 'Gentle Rain',
        artist: 'Nature Sounds',
        description: 'Soft rainfall for deep concentration',
        filePath: 'sounds/nature_rain.mp3',
        category: MusicCategory.nature,
        source: MusicSource.asset,
        isBuiltIn: true,
      ),
      const MusicTrack(
        id: 'nature_forest',
        title: 'Forest Ambience',
        artist: 'Nature Sounds',
        description: 'Birds chirping in a peaceful forest',
        filePath: 'sounds/nature_forest.mp3',
        category: MusicCategory.nature,
        source: MusicSource.asset,
        isBuiltIn: true,
      ),
      const MusicTrack(
        id: 'nature_ocean',
        title: 'Ocean Waves',
        artist: 'Nature Sounds',
        description: 'Calming ocean waves on the shore',
        filePath: 'sounds/nature_ocean.mp3',
        category: MusicCategory.nature,
        source: MusicSource.asset,
        isBuiltIn: true,
      ),

      // White Noise
      const MusicTrack(
        id: 'white_noise',
        title: 'White Noise',
        artist: 'Focus Sounds',
        description: 'Pure white noise for concentration',
        filePath: 'sounds/white_noise.mp3',
        category: MusicCategory.whiteNoise,
        source: MusicSource.asset,
        isBuiltIn: true,
      ),
      const MusicTrack(
        id: 'pink_noise',
        title: 'Pink Noise',
        artist: 'Focus Sounds',
        description: 'Balanced pink noise for relaxation',
        filePath: 'sounds/pink_noise.mp3',
        category: MusicCategory.whiteNoise,
        source: MusicSource.asset,
        isBuiltIn: true,
      ),
      const MusicTrack(
        id: 'brown_noise',
        title: 'Brown Noise',
        artist: 'Focus Sounds',
        description: 'Deep brown noise for deep focus',
        filePath: 'sounds/brown_noise.mp3',
        category: MusicCategory.whiteNoise,
        source: MusicSource.asset,
        isBuiltIn: true,
      ),

      // Instrumental/Ambient
      const MusicTrack(
        id: 'ambient_space',
        title: 'Space Ambient',
        artist: 'Ambient Collective',
        description: 'Ethereal space-like ambient sounds',
        filePath: 'sounds/ambient_space.mp3',
        category: MusicCategory.ambient,
        source: MusicSource.asset,
        isBuiltIn: true,
      ),
      const MusicTrack(
        id: 'lofi_study',
        title: 'Lo-Fi Study Beats',
        artist: 'Chill Beats',
        description: 'Relaxing lo-fi hip-hop for studying',
        filePath: 'sounds/lofi_study.mp3',
        category: MusicCategory.lofi,
        source: MusicSource.asset,
        isBuiltIn: true,
      ),
      const MusicTrack(
        id: 'classical_piano',
        title: 'Classical Piano',
        artist: 'Classical Collection',
        description: 'Peaceful classical piano pieces',
        filePath: 'sounds/classical_piano.mp3',
        category: MusicCategory.classical,
        source: MusicSource.asset,
        isBuiltIn: true,
      ),

      // Binaural Beats
      const MusicTrack(
        id: 'binaural_focus',
        title: 'Focus Frequency',
        artist: 'Binaural Beats',
        description: '40Hz gamma waves for enhanced focus',
        filePath: 'sounds/binaural_focus.mp3',
        category: MusicCategory.binaural,
        source: MusicSource.asset,
        isBuiltIn: true,
      ),
      const MusicTrack(
        id: 'binaural_calm',
        title: 'Calm Frequency',
        artist: 'Binaural Beats',
        description: '10Hz alpha waves for relaxation',
        filePath: 'sounds/binaural_calm.mp3',
        category: MusicCategory.binaural,
        source: MusicSource.asset,
        isBuiltIn: true,
      ),
    ]);
  }

  /// Load user-added tracks from storage
  Future<void> _loadUserTracks() async {
    try {
      final tracksJson = _prefs?.getString('user_tracks') ?? '[]';
      final tracksList = jsonDecode(tracksJson) as List;

      for (final trackData in tracksList) {
        try {
          final track = MusicTrack.fromJson(trackData as Map<String, dynamic>);
          _allTracks.add(track);
        } catch (e) {
          if (kDebugMode) {
            print('Error loading user track: $e');
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading user tracks: $e');
      }
    }
  }

  /// Save user tracks to storage
  Future<void> _saveUserTracks() async {
    try {
      final userTracks = _allTracks.where((track) => !track.isBuiltIn).toList();
      final tracksJson =
          jsonEncode(userTracks.map((track) => track.toJson()).toList());
      await _prefs?.setString('user_tracks', tracksJson);
    } catch (e) {
      if (kDebugMode) {
        print('Error saving user tracks: $e');
      }
    }
  }

  /// Load playlists from storage
  Future<void> _loadPlaylists() async {
    try {
      // Load built-in playlists
      await _loadBuiltInPlaylists();

      // Load user playlists
      final playlistsJson = _prefs?.getString('user_playlists') ?? '[]';
      final playlistsList = jsonDecode(playlistsJson) as List;

      for (final playlistData in playlistsList) {
        try {
          final playlist =
              MusicPlaylist.fromJson(playlistData as Map<String, dynamic>);
          _allPlaylists.add(playlist);
        } catch (e) {
          if (kDebugMode) {
            print('Error loading user playlist: $e');
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading playlists: $e');
      }
    }
  }

  /// Load built-in playlists
  Future<void> _loadBuiltInPlaylists() async {
    final now = DateTime.now();

    _allPlaylists.addAll([
      MusicPlaylist(
        id: 'nature_focus',
        name: 'Nature Focus',
        description: 'Natural sounds for deep concentration',
        trackIds: ['nature_rain', 'nature_forest', 'nature_ocean'],
        category: MusicCategory.nature,
        createdAt: now,
        updatedAt: now,
        isBuiltIn: true,
      ),
      MusicPlaylist(
        id: 'white_noise_collection',
        name: 'White Noise Collection',
        description: 'Various noise types for focus',
        trackIds: ['white_noise', 'pink_noise', 'brown_noise'],
        category: MusicCategory.whiteNoise,
        createdAt: now,
        updatedAt: now,
        isBuiltIn: true,
      ),
      MusicPlaylist(
        id: 'work_productivity',
        name: 'Work Productivity',
        description: 'Optimized for work sessions',
        trackIds: ['binaural_focus', 'ambient_space', 'white_noise'],
        category: MusicCategory.work,
        createdAt: now,
        updatedAt: now,
        isBuiltIn: true,
      ),
      MusicPlaylist(
        id: 'study_session',
        name: 'Study Session',
        description: 'Perfect for studying and learning',
        trackIds: ['lofi_study', 'classical_piano', 'nature_rain'],
        category: MusicCategory.study,
        createdAt: now,
        updatedAt: now,
        isBuiltIn: true,
      ),
      MusicPlaylist(
        id: 'break_relaxation',
        name: 'Break Relaxation',
        description: 'Calming music for breaks',
        trackIds: ['binaural_calm', 'nature_ocean', 'ambient_space'],
        category: MusicCategory.break_,
        createdAt: now,
        updatedAt: now,
        isBuiltIn: true,
      ),
    ]);
  }

  /// Save user playlists to storage
  Future<void> _saveUserPlaylists() async {
    try {
      final userPlaylists =
          _allPlaylists.where((playlist) => !playlist.isBuiltIn).toList();
      final playlistsJson = jsonEncode(
          userPlaylists.map((playlist) => playlist.toJson()).toList());
      await _prefs?.setString('user_playlists', playlistsJson);
    } catch (e) {
      if (kDebugMode) {
        print('Error saving user playlists: $e');
      }
    }
  }

  // ============================================================================
  // MUSIC PLAYER CONTROLS
  // ============================================================================

  /// Play a specific track
  Future<void> playTrack(MusicTrack track, {MusicPlaylist? playlist}) async {
    if (!_isMusicEnabled) return;

    try {
      _playerState = PlayerState.loading;
      notifyListeners();

      // Stop current playback
      await _musicPlayer.stop();

      // End previous listening session if any
      await _historyService.endListeningSession(completed: false);

      // Set new track
      _currentTrack = track;
      _currentPlaylist = playlist;

      // Start new listening session
      _historyService.startListeningSession(track, 'manual');

      // Setup shuffle order if needed
      if (_playbackMode == PlaybackMode.shuffle && playlist != null) {
        _setupShuffleOrder(playlist);
      }

      // Play the track
      if (track.source == MusicSource.asset) {
        await _musicPlayer.play(ap.AssetSource(track.filePath));
      } else {
        await _musicPlayer.play(ap.DeviceFileSource(track.filePath));
      }

      if (kDebugMode) {
        print('Playing track: ${track.title} by ${track.artist}');
      }
    } catch (e) {
      _playerState = PlayerState.error;
      if (kDebugMode) {
        print('Error playing track: $e');
      }
    }
    notifyListeners();
  }

  /// Play a playlist
  Future<void> playPlaylist(MusicPlaylist playlist,
      {int startIndex = 0}) async {
    if (!_isMusicEnabled || playlist.trackIds.isEmpty) return;

    final tracks = getTracksFromPlaylist(playlist);
    if (tracks.isEmpty) return;

    final trackIndex = startIndex.clamp(0, tracks.length - 1);
    await playTrack(tracks[trackIndex], playlist: playlist);
  }

  /// Resume playback
  Future<void> resume() async {
    if (_playerState == PlayerState.paused) {
      await _musicPlayer.resume();
    }
  }

  /// Pause playback
  Future<void> pause() async {
    if (_playerState == PlayerState.playing) {
      await _musicPlayer.pause();
    }
  }

  /// Stop playback
  Future<void> stop() async {
    await _musicPlayer.stop();
    _currentTrack = null;
    _currentPlaylist = null;
    _currentPosition = Duration.zero;
    _totalDuration = Duration.zero;
    notifyListeners();
  }

  /// Play next track
  Future<void> playNext() async {
    if (_currentPlaylist == null) return;

    final tracks = getTracksFromPlaylist(_currentPlaylist!);
    if (tracks.isEmpty) return;

    int nextIndex;

    if (_playbackMode == PlaybackMode.shuffle) {
      nextIndex = _getNextShuffleIndex();
    } else {
      final currentIndex =
          tracks.indexWhere((track) => track.id == _currentTrack?.id);
      nextIndex = (currentIndex + 1) % tracks.length;

      // If we've reached the end and not in repeat all mode, stop
      if (nextIndex == 0 && _playbackMode != PlaybackMode.repeatAll) {
        await stop();
        return;
      }
    }

    await playTrack(tracks[nextIndex], playlist: _currentPlaylist);
  }

  /// Play previous track
  Future<void> playPrevious() async {
    if (_currentPlaylist == null) return;

    final tracks = getTracksFromPlaylist(_currentPlaylist!);
    if (tracks.isEmpty) return;

    int previousIndex;

    if (_playbackMode == PlaybackMode.shuffle) {
      previousIndex = _getPreviousShuffleIndex();
    } else {
      final currentIndex =
          tracks.indexWhere((track) => track.id == _currentTrack?.id);
      previousIndex = (currentIndex - 1 + tracks.length) % tracks.length;
    }

    await playTrack(tracks[previousIndex], playlist: _currentPlaylist);
  }

  /// Replay current track
  Future<void> replay() async {
    if (_currentTrack != null) {
      await playTrack(_currentTrack!, playlist: _currentPlaylist);
    }
  }

  /// Seek to position
  Future<void> seekTo(Duration position) async {
    await _musicPlayer.seek(position);
  }

  /// Set music volume
  Future<void> setMusicVolume(double volume) async {
    _musicVolume = volume.clamp(0.0, 1.0);
    await _musicPlayer.setVolume(_musicVolume);
    await _saveSettings();
    notifyListeners();
  }

  /// Toggle music enabled state
  Future<void> toggleMusic() async {
    _isMusicEnabled = !_isMusicEnabled;

    if (!_isMusicEnabled) {
      await stop();
    }

    await _saveSettings();
    notifyListeners();
  }

  /// Set playback mode
  Future<void> setPlaybackMode(PlaybackMode mode) async {
    _playbackMode = mode;

    // Setup shuffle if needed
    if (mode == PlaybackMode.shuffle && _currentPlaylist != null) {
      _setupShuffleOrder(_currentPlaylist!);
    }

    await _saveSettings();
    notifyListeners();
  }

  /// Setup shuffle order for playlist
  void _setupShuffleOrder(MusicPlaylist playlist) {
    _shuffleOrder = List.from(playlist.trackIds);
    _shuffleOrder.shuffle(Random());

    // Move current track to beginning if it exists
    if (_currentTrack != null) {
      final currentIndex = _shuffleOrder.indexOf(_currentTrack!.id);
      if (currentIndex != -1) {
        _shuffleOrder.removeAt(currentIndex);
        _shuffleOrder.insert(0, _currentTrack!.id);
        _currentShuffleIndex = 0;
      }
    }
  }

  /// Get next shuffle index
  int _getNextShuffleIndex() {
    _currentShuffleIndex = (_currentShuffleIndex + 1) % _shuffleOrder.length;
    return _currentShuffleIndex;
  }

  /// Get previous shuffle index
  int _getPreviousShuffleIndex() {
    _currentShuffleIndex = (_currentShuffleIndex - 1 + _shuffleOrder.length) %
        _shuffleOrder.length;
    return _currentShuffleIndex;
  }

  /// Get tracks from playlist
  List<MusicTrack> getTracksFromPlaylist(MusicPlaylist playlist) {
    final tracks = <MusicTrack>[];
    for (final id in playlist.trackIds) {
      try {
        final track = _allTracks.firstWhere((track) => track.id == id);
        tracks.add(track);
      } catch (e) {
        if (kDebugMode) {
          print('Track not found: $id');
        }
      }
    }
    return tracks;
  }

  // ============================================================================
  // SMART MUSIC FEATURES
  // ============================================================================

  /// Auto-play music based on session type
  Future<void> autoPlayForSession({required bool isWorkTime}) async {
    if (!_autoPlayEnabled || !_isMusicEnabled) return;

    final playlistId = isWorkTime ? _workPlaylistId : _breakPlaylistId;
    if (playlistId == null) return;

    final playlist = _allPlaylists.firstWhere(
      (p) => p.id == playlistId,
      orElse: () => _allPlaylists.first,
    );

    await playPlaylist(playlist);
  }

  /// Set work session playlist
  Future<void> setWorkPlaylist(String? playlistId) async {
    _workPlaylistId = playlistId;
    await _saveSettings();
    notifyListeners();
  }

  /// Set break session playlist
  Future<void> setBreakPlaylist(String? playlistId) async {
    _breakPlaylistId = playlistId;
    await _saveSettings();
    notifyListeners();
  }

  /// Toggle auto-play feature
  Future<void> toggleAutoPlay() async {
    _autoPlayEnabled = !_autoPlayEnabled;
    await _saveSettings();
    notifyListeners();
  }

  /// Toggle fade transitions
  Future<void> toggleFadeTransitions() async {
    _fadeTransitions = !_fadeTransitions;
    await _saveSettings();
    notifyListeners();
  }

  /// Fade out current track
  Future<void> fadeOut({Duration duration = const Duration(seconds: 2)}) async {
    if (!_fadeTransitions || !isPlaying) return;

    final steps = 20;
    final stepDuration = duration.inMilliseconds ~/ steps;
    final volumeStep = _musicVolume / steps;

    for (int i = 0; i < steps; i++) {
      final newVolume = _musicVolume - (volumeStep * (i + 1));
      await _musicPlayer.setVolume(newVolume.clamp(0.0, 1.0));
      await Future.delayed(Duration(milliseconds: stepDuration));
    }

    await pause();
    await _musicPlayer.setVolume(_musicVolume); // Restore original volume
  }

  /// Fade in current track
  Future<void> fadeIn({Duration duration = const Duration(seconds: 2)}) async {
    if (!_fadeTransitions) return;

    await _musicPlayer.setVolume(0.0);
    await resume();

    final steps = 20;
    final stepDuration = duration.inMilliseconds ~/ steps;
    final volumeStep = _musicVolume / steps;

    for (int i = 0; i < steps; i++) {
      final newVolume = volumeStep * (i + 1);
      await _musicPlayer.setVolume(newVolume.clamp(0.0, _musicVolume));
      await Future.delayed(Duration(milliseconds: stepDuration));
    }
  }

  // ============================================================================
  // PLAYLIST MANAGEMENT
  // ============================================================================

  /// Create a new playlist
  Future<MusicPlaylist> createPlaylist({
    required String name,
    String? description,
    List<String> trackIds = const [],
    MusicCategory? category,
  }) async {
    final now = DateTime.now();
    final playlist = MusicPlaylist(
      id: 'playlist_${now.microsecondsSinceEpoch}_${_playlistIdSequence++}',
      name: name,
      description: description,
      trackIds: trackIds,
      category: category,
      createdAt: now,
      updatedAt: now,
      isBuiltIn: false,
    );

    _allPlaylists.add(playlist);
    await _saveUserPlaylists();
    notifyListeners();

    return playlist;
  }

  /// Update an existing playlist
  Future<void> updatePlaylist(MusicPlaylist playlist) async {
    final index = _allPlaylists.indexWhere((p) => p.id == playlist.id);
    if (index != -1) {
      _allPlaylists[index] = playlist.copyWith(updatedAt: DateTime.now());
      await _saveUserPlaylists();
      notifyListeners();
    }
  }

  /// Delete a playlist
  Future<void> deletePlaylist(String playlistId) async {
    _allPlaylists.removeWhere((p) => p.id == playlistId && !p.isBuiltIn);
    await _saveUserPlaylists();
    notifyListeners();
  }

  // ============================================================================
  // ADVANCED PLAYLIST MANAGEMENT
  // ============================================================================

  /// Reorder tracks in a playlist
  Future<void> reorderPlaylistTracks(
      String playlistId, int oldIndex, int newIndex) async {
    try {
      final playlist = _allPlaylists.firstWhere((p) => p.id == playlistId);
      if (playlist.isBuiltIn) return; // Can't modify built-in playlists

      final trackIds = List<String>.from(playlist.trackIds);
      if (oldIndex < trackIds.length && newIndex < trackIds.length) {
        final item = trackIds.removeAt(oldIndex);
        trackIds.insert(newIndex, item);

        final updatedPlaylist = playlist.copyWith(
          trackIds: trackIds,
          updatedAt: DateTime.now(),
        );

        await updatePlaylist(updatedPlaylist);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error reordering playlist tracks: $e');
      }
    }
  }

  /// Bulk add tracks to playlist
  Future<bool> bulkAddTracksToPlaylist(
      String playlistId, List<String> trackIds) async {
    try {
      final playlist = _allPlaylists.firstWhere((p) => p.id == playlistId);
      if (playlist.isBuiltIn) return false;

      final newTrackIds = <String>[];
      for (final trackId in trackIds) {
        if (!playlist.trackIds.contains(trackId)) {
          newTrackIds.add(trackId);
        }
      }

      if (newTrackIds.isNotEmpty) {
        final updatedPlaylist = playlist.copyWith(
          trackIds: [...playlist.trackIds, ...newTrackIds],
          updatedAt: DateTime.now(),
        );

        await updatePlaylist(updatedPlaylist);
        return true;
      }

      return false;
    } catch (e) {
      if (kDebugMode) {
        print('Error bulk adding tracks to playlist: $e');
      }
      return false;
    }
  }

  /// Bulk remove tracks from playlist
  Future<bool> bulkRemoveTracksFromPlaylist(
      String playlistId, List<String> trackIds) async {
    try {
      final playlist = _allPlaylists.firstWhere((p) => p.id == playlistId);
      if (playlist.isBuiltIn) return false;

      final updatedTrackIds =
          playlist.trackIds.where((id) => !trackIds.contains(id)).toList();

      if (updatedTrackIds.length != playlist.trackIds.length) {
        final updatedPlaylist = playlist.copyWith(
          trackIds: updatedTrackIds,
          updatedAt: DateTime.now(),
        );

        await updatePlaylist(updatedPlaylist);
        return true;
      }

      return false;
    } catch (e) {
      if (kDebugMode) {
        print('Error bulk removing tracks from playlist: $e');
      }
      return false;
    }
  }

  /// Duplicate playlist
  Future<MusicPlaylist?> duplicatePlaylist(
      String playlistId, String newName) async {
    try {
      final originalPlaylist =
          _allPlaylists.firstWhere((p) => p.id == playlistId);

      final duplicatedPlaylist = await createPlaylist(
        name: newName,
        description: '${originalPlaylist.description} (Copy)',
        trackIds: List.from(originalPlaylist.trackIds),
        category: originalPlaylist.category,
      );

      return duplicatedPlaylist;
    } catch (e) {
      if (kDebugMode) {
        print('Error duplicating playlist: $e');
      }
      return null;
    }
  }

  /// Merge playlists
  Future<MusicPlaylist?> mergePlaylists(
      List<String> playlistIds, String newName, String description) async {
    try {
      final allTrackIds = <String>[];
      final categories = <MusicCategory>{};

      for (final playlistId in playlistIds) {
        final playlist = _allPlaylists.firstWhere((p) => p.id == playlistId);
        allTrackIds.addAll(playlist.trackIds);
        if (playlist.category != null) {
          categories.add(playlist.category!);
        }
      }

      // Remove duplicates while preserving order
      final uniqueTrackIds = <String>[];
      for (final trackId in allTrackIds) {
        if (!uniqueTrackIds.contains(trackId)) {
          uniqueTrackIds.add(trackId);
        }
      }

      // Use the most common category or default to custom
      final category =
          categories.length == 1 ? categories.first : MusicCategory.custom;

      final mergedPlaylist = await createPlaylist(
        name: newName,
        description: description,
        trackIds: uniqueTrackIds,
        category: category,
      );

      return mergedPlaylist;
    } catch (e) {
      if (kDebugMode) {
        print('Error merging playlists: $e');
      }
      return null;
    }
  }

  /// Get playlist statistics
  Map<String, dynamic> getPlaylistStats(String playlistId) {
    try {
      final playlist = _allPlaylists.firstWhere((p) => p.id == playlistId);
      final tracks = playlist.trackIds
          .map((id) => _allTracks.firstWhere((t) => t.id == id))
          .toList();

      final totalDuration = tracks
          .where((track) => track.duration != null)
          .fold<Duration>(Duration.zero, (sum, track) => sum + track.duration!);

      final categories = <MusicCategory, int>{};
      final artists = <String, int>{};

      for (final track in tracks) {
        categories[track.category] = (categories[track.category] ?? 0) + 1;
        artists[track.artist] = (artists[track.artist] ?? 0) + 1;
      }

      return {
        'totalTracks': tracks.length,
        'totalDuration': totalDuration,
        'categories': categories,
        'artists': artists,
        'averageTrackDuration': tracks.isNotEmpty && totalDuration.inSeconds > 0
            ? Duration(seconds: totalDuration.inSeconds ~/ tracks.length)
            : Duration.zero,
        'createdAt': playlist.createdAt,
        'updatedAt': playlist.updatedAt,
      };
    } catch (e) {
      if (kDebugMode) {
        print('Error getting playlist stats: $e');
      }
      return {};
    }
  }

  // ============================================================================
  // MUSIC RECOMMENDATIONS
  // ============================================================================

  /// Get music recommendations based on session type and history
  List<MusicTrack> getRecommendations({String? sessionType, int limit = 10}) {
    try {
      // Get recommendations from history service
      final recommendedTrackIds = _historyService.getRecommendations(
        sessionType: sessionType,
        limit: limit * 2, // Get more to filter
      );

      // Convert track IDs to tracks
      final recommendedTracks = <MusicTrack>[];
      for (final trackId in recommendedTrackIds) {
        try {
          final track = _allTracks.firstWhere((t) => t.id == trackId);
          recommendedTracks.add(track);
        } catch (e) {
          // Track not found, skip
        }
      }

      // If we don't have enough recommendations from history, add popular tracks
      if (recommendedTracks.length < limit) {
        final popularTracks = _getPopularTracksForSession(sessionType);
        for (final track in popularTracks) {
          if (!recommendedTracks.any((t) => t.id == track.id) &&
              recommendedTracks.length < limit) {
            recommendedTracks.add(track);
          }
        }
      }

      return recommendedTracks.take(limit).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting recommendations: $e');
      }
      return [];
    }
  }

  /// Get popular tracks for a specific session type
  List<MusicTrack> _getPopularTracksForSession(String? sessionType) {
    switch (sessionType) {
      case 'work':
        return _allTracks
            .where((track) =>
                track.category == MusicCategory.binaural ||
                track.category == MusicCategory.ambient ||
                track.category == MusicCategory.whiteNoise)
            .toList();
      case 'break':
        return _allTracks
            .where((track) =>
                track.category == MusicCategory.nature ||
                track.category == MusicCategory.meditation ||
                track.category == MusicCategory.classical)
            .toList();
      case 'study':
        return _allTracks
            .where((track) =>
                track.category == MusicCategory.lofi ||
                track.category == MusicCategory.classical ||
                track.category == MusicCategory.instrumental)
            .toList();
      default:
        return _allTracks.where((track) => track.isBuiltIn).toList();
    }
  }

  /// Get recommended playlists for session type
  List<MusicPlaylist> getRecommendedPlaylists(
      {String? sessionType, int limit = 5}) {
    try {
      final playlists = <MusicPlaylist>[];

      // Filter playlists by session type
      switch (sessionType) {
        case 'work':
          playlists.addAll(_allPlaylists.where((p) =>
              p.category == MusicCategory.work ||
              p.category == MusicCategory.binaural ||
              p.category == MusicCategory.whiteNoise));
          break;
        case 'break':
          playlists.addAll(_allPlaylists.where((p) =>
              p.category == MusicCategory.break_ ||
              p.category == MusicCategory.nature ||
              p.category == MusicCategory.meditation));
          break;
        case 'study':
          playlists.addAll(_allPlaylists.where((p) =>
              p.category == MusicCategory.study ||
              p.category == MusicCategory.lofi ||
              p.category == MusicCategory.classical));
          break;
        default:
          playlists.addAll(_allPlaylists);
      }

      // Sort by creation date (newest first) and built-in status
      playlists.sort((a, b) {
        if (a.isBuiltIn && !b.isBuiltIn) return -1;
        if (!a.isBuiltIn && b.isBuiltIn) return 1;
        return b.createdAt.compareTo(a.createdAt);
      });

      return playlists.take(limit).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting recommended playlists: $e');
      }
      return [];
    }
  }

  /// Add a user-imported track to the library
  Future<bool> addUserTrack(MusicTrack track) async {
    try {
      // Check if track already exists
      if (_allTracks.any((t) => t.id == track.id)) {
        if (kDebugMode) {
          print('Track ${track.id} already exists in library');
        }
        return false;
      }

      // Add track to library
      _allTracks.add(track);

      // Save tracks to persistent storage
      await _saveUserTracks();

      // Notify listeners
      notifyListeners();

      if (kDebugMode) {
        print('Added user track: ${track.title}');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error adding user track: $e');
      }
      return false;
    }
  }

  /// Remove a user track from the library
  Future<bool> removeUserTrack(String trackId) async {
    try {
      // Find the track
      final track = _allTracks.firstWhere(
        (t) => t.id == trackId,
        orElse: () => throw Exception('Track not found'),
      );

      // Don't allow deletion of built-in tracks
      if (track.isBuiltIn) {
        if (kDebugMode) {
          print('Cannot delete built-in track: ${track.title}');
        }
        return false;
      }

      // Remove track from all playlists first
      final playlistsWithTrack =
          _allPlaylists.where((p) => p.trackIds.contains(trackId)).toList();

      for (final playlist in playlistsWithTrack) {
        await removeTrackFromPlaylist(playlist.id, trackId);
      }

      // Remove track from library
      _allTracks.removeWhere((t) => t.id == trackId);

      // Save tracks to persistent storage
      await _saveUserTracks();

      // Notify listeners
      notifyListeners();

      if (kDebugMode) {
        print('Removed user track: ${track.title}');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error removing user track: $e');
      }
      return false;
    }
  }

  /// Add track to playlist
  Future<void> addTrackToPlaylist(String playlistId, String trackId) async {
    final playlist = _allPlaylists.firstWhere((p) => p.id == playlistId);
    if (!playlist.trackIds.contains(trackId)) {
      final updatedPlaylist = playlist.copyWith(
        trackIds: [...playlist.trackIds, trackId],
        updatedAt: DateTime.now(),
      );
      await updatePlaylist(updatedPlaylist);
    }
  }

  /// Remove track from playlist
  Future<void> removeTrackFromPlaylist(
      String playlistId, String trackId) async {
    final playlist = _allPlaylists.firstWhere((p) => p.id == playlistId);
    final updatedTrackIds =
        playlist.trackIds.where((id) => id != trackId).toList();
    final updatedPlaylist = playlist.copyWith(
      trackIds: updatedTrackIds,
      updatedAt: DateTime.now(),
    );
    await updatePlaylist(updatedPlaylist);
  }

  /// Get playlists by category
  List<MusicPlaylist> getPlaylistsByCategory(MusicCategory category) {
    return _allPlaylists.where((p) => p.category == category).toList();
  }

  /// Get tracks by category
  List<MusicTrack> getTracksByCategory(MusicCategory category) {
    return _allTracks.where((t) => t.category == category).toList();
  }

  // ============================================================================
  // UTILITY METHODS
  // ============================================================================

  /// Dispose resources
  @override
  void dispose() {
    _stopPositionTimer();
    _musicPlayer.dispose();
    super.dispose();
  }

  /// Format duration for display
  String formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Get current track index in playlist
  int getCurrentTrackIndex() {
    if (_currentPlaylist == null || _currentTrack == null) return -1;
    final tracks = getTracksFromPlaylist(_currentPlaylist!);
    return tracks.indexWhere((track) => track.id == _currentTrack!.id);
  }

  /// Check if track is in current playlist
  bool isTrackInCurrentPlaylist(String trackId) {
    if (_currentPlaylist == null) return false;
    return _currentPlaylist!.trackIds.contains(trackId);
  }
}
