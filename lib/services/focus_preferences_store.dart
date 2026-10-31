import 'package:shared_preferences/shared_preferences.dart';

class FocusPreferences {
  final int totalSessions;
  final int workDuration;
  final int breakDuration;
  final bool isMusicEnabled;
  final bool isVoiceEnabled;
  final bool isFocusModeEnabled;

  const FocusPreferences({
    required this.totalSessions,
    required this.workDuration,
    required this.breakDuration,
    required this.isMusicEnabled,
    required this.isVoiceEnabled,
    required this.isFocusModeEnabled,
  });

  static const FocusPreferences defaults = FocusPreferences(
    totalSessions: 4,
    workDuration: 1500,
    breakDuration: 300,
    isMusicEnabled: false,
    isVoiceEnabled: false,
    isFocusModeEnabled: false,
  );
}

class FocusPreferencesStore {
  FocusPreferencesStore();

  Future<FocusPreferences> load() async {
    final prefs = await SharedPreferences.getInstance();
    return FocusPreferences(
      totalSessions: prefs.getInt('totalSessions') ?? 4,
      workDuration: prefs.getInt('workDuration') ?? 1500,
      breakDuration: prefs.getInt('breakDuration') ?? 300,
      isMusicEnabled: prefs.getBool('isMusicEnabled') ?? false,
      isVoiceEnabled: prefs.getBool('isVoiceEnabled') ?? false,
      isFocusModeEnabled: prefs.getBool('isFocusModeEnabled') ?? false,
    );
  }

  Future<void> save(FocusPreferences preferences) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('totalSessions', preferences.totalSessions);
    await prefs.setInt('workDuration', preferences.workDuration);
    await prefs.setInt('breakDuration', preferences.breakDuration);
    await prefs.setBool('isMusicEnabled', preferences.isMusicEnabled);
    await prefs.setBool('isVoiceEnabled', preferences.isVoiceEnabled);
    await prefs.setBool('isFocusModeEnabled', preferences.isFocusModeEnabled);
  }
}
