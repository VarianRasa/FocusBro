import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

/// Cache entry with expiration
class CacheEntry {
  final dynamic data;
  final DateTime createdAt;
  final Duration? ttl;

  CacheEntry(this.data, this.createdAt, this.ttl);

  bool get isExpired {
    if (ttl == null) return false;
    return DateTime.now().difference(createdAt) > ttl!;
  }
}

/// Cache manager for optimizing app performance
class CacheManager {
  static final CacheManager _instance = CacheManager._internal();
  factory CacheManager() => _instance;
  CacheManager._internal();

  final Map<String, CacheEntry> _memoryCache = {};
  final Map<String, Timer> _expirationTimers = {};
  SharedPreferences? _prefs;

  /// Initialize the cache manager
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    await _cleanExpiredCache();
  }

  /// Store data in memory cache
  void setMemoryCache(String key, dynamic data, {Duration? ttl}) {
    // Cancel existing timer if any
    _expirationTimers[key]?.cancel();

    _memoryCache[key] = CacheEntry(data, DateTime.now(), ttl);

    // Set expiration timer if TTL is provided
    if (ttl != null) {
      _expirationTimers[key] = Timer(ttl, () {
        _memoryCache.remove(key);
        _expirationTimers.remove(key);
      });
    }
  }

  /// Get data from memory cache
  T? getMemoryCache<T>(String key) {
    final entry = _memoryCache[key];
    if (entry == null || entry.isExpired) {
      _memoryCache.remove(key);
      _expirationTimers[key]?.cancel();
      _expirationTimers.remove(key);
      return null;
    }
    return entry.data as T?;
  }

  /// Store data in persistent cache
  Future<void> setPersistentCache(String key, dynamic data,
      {Duration? ttl}) async {
    _prefs ??= await SharedPreferences.getInstance();

    final cacheData = {
      'data': data,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
      'ttl': ttl?.inMilliseconds,
    };

    await _prefs!.setString('cache_$key', jsonEncode(cacheData));
  }

  /// Get data from persistent cache
  Future<T?> getPersistentCache<T>(String key) async {
    _prefs ??= await SharedPreferences.getInstance();

    final cacheString = _prefs!.getString('cache_$key');
    if (cacheString == null) return null;

    try {
      final cacheData = jsonDecode(cacheString) as Map<String, dynamic>;
      final createdAt =
          DateTime.fromMillisecondsSinceEpoch(cacheData['createdAt'] as int);
      final ttlMs = cacheData['ttl'] as int?;

      // Check if expired
      if (ttlMs != null) {
        final ttl = Duration(milliseconds: ttlMs);
        if (DateTime.now().difference(createdAt) > ttl) {
          await _prefs!.remove('cache_$key');
          return null;
        }
      }

      return cacheData['data'] as T?;
    } catch (e) {
      // Remove corrupted cache entry
      await _prefs!.remove('cache_$key');
      return null;
    }
  }

  /// Clear specific cache entry
  Future<void> clearCache(String key) async {
    _memoryCache.remove(key);
    _expirationTimers[key]?.cancel();
    _expirationTimers.remove(key);

    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.remove('cache_$key');
  }

  /// Clear all cache
  Future<void> clearAllCache() async {
    _memoryCache.clear();
    for (final timer in _expirationTimers.values) {
      timer.cancel();
    }
    _expirationTimers.clear();

    _prefs ??= await SharedPreferences.getInstance();
    final keys = _prefs!.getKeys().where((key) => key.startsWith('cache_'));
    for (final key in keys) {
      await _prefs!.remove(key);
    }
  }

  /// Clean expired cache entries
  Future<void> _cleanExpiredCache() async {
    _prefs ??= await SharedPreferences.getInstance();
    final keys = _prefs!.getKeys().where((key) => key.startsWith('cache_'));

    for (final key in keys) {
      final cacheString = _prefs!.getString(key);
      if (cacheString == null) continue;

      try {
        final cacheData = jsonDecode(cacheString) as Map<String, dynamic>;
        final createdAt =
            DateTime.fromMillisecondsSinceEpoch(cacheData['createdAt'] as int);
        final ttlMs = cacheData['ttl'] as int?;

        if (ttlMs != null) {
          final ttl = Duration(milliseconds: ttlMs);
          if (DateTime.now().difference(createdAt) > ttl) {
            await _prefs!.remove(key);
          }
        }
      } catch (e) {
        // Remove corrupted cache entry
        await _prefs!.remove(key);
      }
    }
  }

  /// Get cache size information
  Map<String, int> getCacheInfo() {
    return {
      'memoryEntries': _memoryCache.length,
      'persistentEntries':
          _prefs?.getKeys().where((key) => key.startsWith('cache_')).length ??
              0,
    };
  }

  /// Cache keys for common data
  static const String timerPresets = 'timer_presets';
  static const String sessionHistory = 'session_history';
  static const String achievements = 'achievements';
  static const String rewards = 'rewards';
  static const String userSettings = 'user_settings';
  static const String musicSettings = 'music_settings';
  static const String focusModeSettings = 'focus_mode_settings';
  static const String notificationSettings = 'notification_settings';
  static const String themeSettings = 'theme_settings';
  static const String notes = 'notes';
  static const String tasks = 'tasks';
  static const String statistics = 'statistics';

  /// Preload commonly used data
  Future<void> preloadCommonData() async {
    final futures = <Future>[];

    // Preload timer presets
    futures.add(_preloadTimerPresets());

    // Preload user settings
    futures.add(_preloadUserSettings());

    // Preload theme settings
    futures.add(_preloadThemeSettings());

    await Future.wait(futures);
  }

  Future<void> _preloadTimerPresets() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      final savedTimersJson = _prefs!.getStringList('savedTimers') ?? [];
      setMemoryCache(timerPresets, savedTimersJson,
          ttl: const Duration(hours: 1));
    } catch (e) {
      // Ignore preload errors
    }
  }

  Future<void> _preloadUserSettings() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      final settings = {
        'workDuration': _prefs!.getInt('workDuration') ?? 1500,
        'breakDuration': _prefs!.getInt('breakDuration') ?? 300,
        'sessionsUntilLongBreak': _prefs!.getInt('sessionsUntilLongBreak') ?? 4,
        'showFocusNotification':
            _prefs!.getBool('showFocusNotification') ?? true,
        'selectedNotificationSound':
            _prefs!.getString('selectedNotificationSound') ?? 'default',
      };
      setMemoryCache(userSettings, settings, ttl: const Duration(hours: 1));
    } catch (e) {
      // Ignore preload errors
    }
  }

  Future<void> _preloadThemeSettings() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      final themeMode = _prefs!.getString('themeMode') ?? 'system';
      setMemoryCache(themeSettings, themeMode, ttl: const Duration(hours: 1));
    } catch (e) {
      // Ignore preload errors
    }
  }

  /// Invalidate cache when data changes
  void invalidateCache(String key) {
    _memoryCache.remove(key);
    _expirationTimers[key]?.cancel();
    _expirationTimers.remove(key);
  }

  /// Batch cache operations
  Future<void> batchSet(Map<String, dynamic> data, {Duration? ttl}) async {
    final futures = <Future>[];
    for (final entry in data.entries) {
      futures.add(setPersistentCache(entry.key, entry.value, ttl: ttl));
    }
    await Future.wait(futures);
  }

  /// Get multiple cache entries
  Future<Map<String, T?>> batchGet<T>(List<String> keys) async {
    final futures = keys.map((key) => getPersistentCache<T>(key));
    final results = await Future.wait(futures);

    final map = <String, T?>{};
    for (int i = 0; i < keys.length; i++) {
      map[keys[i]] = results[i];
    }
    return map;
  }
}
