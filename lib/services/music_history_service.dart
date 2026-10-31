import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/music_track.dart';

/// Music listening history entry
class MusicHistoryEntry {
  final String trackId;
  final String trackTitle;
  final String trackArtist;
  final DateTime timestamp;
  final Duration listenDuration;
  final String sessionType; // 'work', 'break', 'manual'
  final bool completedTrack;

  const MusicHistoryEntry({
    required this.trackId,
    required this.trackTitle,
    required this.trackArtist,
    required this.timestamp,
    required this.listenDuration,
    required this.sessionType,
    required this.completedTrack,
  });

  Map<String, dynamic> toJson() => {
        'trackId': trackId,
        'trackTitle': trackTitle,
        'trackArtist': trackArtist,
        'timestamp': timestamp.millisecondsSinceEpoch,
        'listenDuration': listenDuration.inMilliseconds,
        'sessionType': sessionType,
        'completedTrack': completedTrack,
      };

  factory MusicHistoryEntry.fromJson(Map<String, dynamic> json) =>
      MusicHistoryEntry(
        trackId: json['trackId'] ?? '',
        trackTitle: json['trackTitle'] ?? '',
        trackArtist: json['trackArtist'] ?? '',
        timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] ?? 0),
        listenDuration: Duration(milliseconds: json['listenDuration'] ?? 0),
        sessionType: json['sessionType'] ?? 'manual',
        completedTrack: json['completedTrack'] ?? false,
      );
}

/// Music listening statistics
class MusicStats {
  final int totalListenTime; // in minutes
  final int totalTracks;
  final int totalSessions;
  final Map<String, int> categoryStats;
  final Map<String, int> sessionTypeStats;
  final List<String> topTracks;
  final List<String> topArtists;
  final Map<String, int> dailyListening; // day -> minutes

  const MusicStats({
    required this.totalListenTime,
    required this.totalTracks,
    required this.totalSessions,
    required this.categoryStats,
    required this.sessionTypeStats,
    required this.topTracks,
    required this.topArtists,
    required this.dailyListening,
  });
}

/// Service for tracking music listening history and analytics
class MusicHistoryService extends ChangeNotifier {
  static final MusicHistoryService _instance = MusicHistoryService._internal();
  factory MusicHistoryService() => _instance;
  MusicHistoryService._internal();

  SharedPreferences? _prefs;

  List<MusicHistoryEntry> _history = [];
  final int _maxHistoryEntries = 1000; // Limit history size

  // Current listening session tracking
  String? _currentTrackId;
  DateTime? _sessionStartTime;
  String _currentSessionType = 'manual';

  // Getters
  List<MusicHistoryEntry> get history => List.from(_history);
  List<MusicHistoryEntry> get recentlyPlayed => _getRecentlyPlayed();

  /// Initialize the history service
  Future<void> initialize() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      await _loadHistory();

      if (kDebugMode) {
        print(
            'MusicHistoryService initialized with ${_history.length} entries');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing MusicHistoryService: $e');
      }
    }
  }

  /// Load history from storage
  Future<void> _loadHistory() async {
    try {
      final historyJson = _prefs?.getString('music_history');
      if (historyJson != null) {
        final List<dynamic> historyData = jsonDecode(historyJson);
        _history = historyData
            .map((entry) => MusicHistoryEntry.fromJson(entry))
            .toList();

        // Sort by timestamp (newest first)
        _history.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading music history: $e');
      }
      _history = [];
    }
  }

  /// Save history to storage
  Future<void> _saveHistory() async {
    try {
      // Limit history size
      if (_history.length > _maxHistoryEntries) {
        _history = _history.take(_maxHistoryEntries).toList();
      }

      final historyJson =
          jsonEncode(_history.map((entry) => entry.toJson()).toList());
      await _prefs?.setString('music_history', historyJson);
    } catch (e) {
      if (kDebugMode) {
        print('Error saving music history: $e');
      }
    }
  }

  /// Start tracking a listening session
  void startListeningSession(MusicTrack track, String sessionType) {
    _currentTrackId = track.id;
    _sessionStartTime = DateTime.now();
    _currentSessionType = sessionType;

    if (kDebugMode) {
      print('Started listening session: ${track.title} ($sessionType)');
    }
  }

  /// End tracking a listening session
  Future<void> endListeningSession({bool completed = false}) async {
    if (_currentTrackId == null || _sessionStartTime == null) return;

    try {
      final endTime = DateTime.now();
      final listenDuration = endTime.difference(_sessionStartTime!);

      // Only record if listened for at least 5 seconds
      if (listenDuration.inSeconds >= 5) {
        // Find track info (this would typically come from the music service)
        final entry = MusicHistoryEntry(
          trackId: _currentTrackId!,
          trackTitle: 'Unknown Track', // Would be populated from track data
          trackArtist: 'Unknown Artist', // Would be populated from track data
          timestamp: _sessionStartTime!,
          listenDuration: listenDuration,
          sessionType: _currentSessionType,
          completedTrack: completed,
        );

        await addHistoryEntry(entry);
      }

      _currentTrackId = null;
      _sessionStartTime = null;
      _currentSessionType = 'manual';
    } catch (e) {
      if (kDebugMode) {
        print('Error ending listening session: $e');
      }
    }
  }

  /// Add a history entry
  Future<void> addHistoryEntry(MusicHistoryEntry entry) async {
    _history.insert(0, entry); // Add to beginning (newest first)
    await _saveHistory();
    notifyListeners();

    if (kDebugMode) {
      print(
          'Added history entry: ${entry.trackTitle} (${entry.listenDuration.inMinutes}m)');
    }
  }

  /// Record track play with track info
  Future<void> recordTrackPlay(MusicTrack track, String sessionType,
      {Duration? duration}) async {
    final entry = MusicHistoryEntry(
      trackId: track.id,
      trackTitle: track.title,
      trackArtist: track.artist,
      timestamp: DateTime.now(),
      listenDuration:
          duration ?? const Duration(seconds: 30), // Default minimum
      sessionType: sessionType,
      completedTrack: duration != null && track.duration != null
          ? duration.inSeconds >=
              (track.duration!.inSeconds * 0.8) // 80% completion
          : false,
    );

    await addHistoryEntry(entry);
  }

  /// Get recently played tracks (last 50, deduplicated)
  List<MusicHistoryEntry> _getRecentlyPlayed() {
    final seen = <String>{};
    return _history.where((entry) => seen.add(entry.trackId)).take(50).toList();
  }

  /// Get listening statistics
  MusicStats getStatistics({DateTime? since}) {
    final filteredHistory = since != null
        ? _history.where((entry) => entry.timestamp.isAfter(since)).toList()
        : _history;

    // Calculate total listening time
    final totalListenTime = filteredHistory.fold<int>(
        0, (sum, entry) => sum + entry.listenDuration.inMinutes);

    // Count unique tracks
    final uniqueTracks = filteredHistory.map((e) => e.trackId).toSet();

    // Session type statistics
    final sessionTypeStats = <String, int>{};
    for (final entry in filteredHistory) {
      sessionTypeStats[entry.sessionType] =
          (sessionTypeStats[entry.sessionType] ?? 0) + 1;
    }

    // Top tracks by play count
    final trackPlayCounts = <String, int>{};
    for (final entry in filteredHistory) {
      trackPlayCounts[entry.trackId] =
          (trackPlayCounts[entry.trackId] ?? 0) + 1;
    }
    final topTracks = trackPlayCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value))
      ..take(10);

    // Top artists by play count
    final artistPlayCounts = <String, int>{};
    for (final entry in filteredHistory) {
      artistPlayCounts[entry.trackArtist] =
          (artistPlayCounts[entry.trackArtist] ?? 0) + 1;
    }
    final topArtists = artistPlayCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value))
      ..take(10);

    // Daily listening statistics (last 30 days)
    final dailyListening = <String, int>{};
    final now = DateTime.now();
    for (int i = 0; i < 30; i++) {
      final date = now.subtract(Duration(days: i));
      final dateKey =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

      final dayEntries = filteredHistory.where((entry) {
        final entryDate = entry.timestamp;
        return entryDate.year == date.year &&
            entryDate.month == date.month &&
            entryDate.day == date.day;
      });

      dailyListening[dateKey] = dayEntries.fold<int>(
          0, (sum, entry) => sum + entry.listenDuration.inMinutes);
    }

    return MusicStats(
      totalListenTime: totalListenTime,
      totalTracks: uniqueTracks.length,
      totalSessions: filteredHistory.length,
      categoryStats: {}, // Would be populated with category analysis
      sessionTypeStats: sessionTypeStats,
      topTracks: topTracks.map((e) => e.key).toList(),
      topArtists: topArtists.map((e) => e.key).toList(),
      dailyListening: dailyListening,
    );
  }

  /// Get recommendations based on listening history
  List<String> getRecommendations({String? sessionType, int limit = 10}) {
    if (_history.isEmpty) return [];

    // Filter by session type if specified
    final relevantHistory = sessionType != null
        ? _history.where((entry) => entry.sessionType == sessionType).toList()
        : _history;

    if (relevantHistory.isEmpty) return [];

    // Count track plays and completion rates
    final trackStats = <String, Map<String, dynamic>>{};

    for (final entry in relevantHistory) {
      if (!trackStats.containsKey(entry.trackId)) {
        trackStats[entry.trackId] = {
          'playCount': 0,
          'completions': 0,
          'totalDuration': Duration.zero,
          'lastPlayed': entry.timestamp,
        };
      }

      final stats = trackStats[entry.trackId]!;
      stats['playCount'] = stats['playCount'] + 1;
      if (entry.completedTrack) {
        stats['completions'] = stats['completions'] + 1;
      }
      stats['totalDuration'] = stats['totalDuration'] + entry.listenDuration;

      // Update last played if this entry is more recent
      if (entry.timestamp.isAfter(stats['lastPlayed'])) {
        stats['lastPlayed'] = entry.timestamp;
      }
    }

    // Score tracks based on play count, completion rate, and recency
    final scoredTracks = trackStats.entries.map((entry) {
      final stats = entry.value;
      final playCount = stats['playCount'] as int;
      final completions = stats['completions'] as int;
      final lastPlayed = stats['lastPlayed'] as DateTime;

      final completionRate = playCount > 0 ? completions / playCount : 0.0;
      final daysSinceLastPlayed = DateTime.now().difference(lastPlayed).inDays;
      final recencyScore = 1.0 / (1.0 + daysSinceLastPlayed * 0.1);

      final score = playCount * 0.4 + completionRate * 0.4 + recencyScore * 0.2;

      return MapEntry(entry.key, score);
    }).toList();

    // Sort by score and return top recommendations
    scoredTracks.sort((a, b) => b.value.compareTo(a.value));

    return scoredTracks.take(limit).map((entry) => entry.key).toList();
  }

  /// Clear all history
  Future<void> clearHistory() async {
    _history.clear();
    await _saveHistory();
    notifyListeners();

    if (kDebugMode) {
      print('Music history cleared');
    }
  }

  /// Export history data
  Map<String, dynamic> exportHistory() {
    return {
      'exportDate': DateTime.now().toIso8601String(),
      'totalEntries': _history.length,
      'history': _history.map((entry) => entry.toJson()).toList(),
      'statistics': getStatistics(),
    };
  }
}
