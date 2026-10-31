import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingService {
  static const String _hasSeenOnboardingKey = 'has_seen_onboarding';
  static const String _showOnboardingKey = 'show_onboarding';
  static const String _tipSeenPrefix = 'tip_seen_';

  static OnboardingService? _instance;
  static OnboardingService get instance => _instance ??= OnboardingService._();

  OnboardingService._();

  SharedPreferences? _prefs;

  /// Initialize the service
  Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Check if user has seen onboarding
  Future<bool> hasSeenOnboarding() async {
    await initialize();
    return _prefs?.getBool(_hasSeenOnboardingKey) ?? false;
  }

  /// Mark onboarding as completed
  Future<void> completeOnboarding() async {
    await initialize();
    await _prefs?.setBool(_hasSeenOnboardingKey, true);
  }

  /// Check if onboarding/help tips are enabled
  Future<bool> isOnboardingEnabled() async {
    await initialize();
    return _prefs?.getBool(_showOnboardingKey) ?? true;
  }

  /// Enable or disable onboarding/help tips
  Future<void> setOnboardingEnabled(bool enabled) async {
    await initialize();
    await _prefs?.setBool(_showOnboardingKey, enabled);
  }

  /// Check if a specific tip has been seen
  Future<bool> hasTipBeenSeen(String tipId) async {
    await initialize();
    return _prefs?.getBool('$_tipSeenPrefix$tipId') ?? false;
  }

  /// Mark a specific tip as seen
  Future<void> markTipAsSeen(String tipId) async {
    await initialize();
    await _prefs?.setBool('$_tipSeenPrefix$tipId', true);
  }

  /// Reset all tips (mark as unseen)
  Future<void> resetAllTips() async {
    await initialize();
    if (_prefs == null) return;

    final keys = _prefs!.getKeys();
    for (final key in keys) {
      if (key.startsWith(_tipSeenPrefix)) {
        await _prefs!.remove(key);
      }
    }
  }

  /// Reset onboarding (mark as not seen)
  Future<void> resetOnboarding() async {
    await initialize();
    await _prefs?.setBool(_hasSeenOnboardingKey, false);
    await resetAllTips();
  }

  /// Get onboarding status summary
  Future<Map<String, dynamic>> getOnboardingStatus() async {
    await initialize();

    final hasSeenOnboarding = await this.hasSeenOnboarding();
    final isEnabled = await isOnboardingEnabled();

    // Count seen tips
    final keys = _prefs?.getKeys() ?? <String>{};
    final seenTips = keys.where((key) => key.startsWith(_tipSeenPrefix)).length;

    return {
      'hasSeenOnboarding': hasSeenOnboarding,
      'isEnabled': isEnabled,
      'seenTipsCount': seenTips,
    };
  }

  /// Show onboarding if needed
  static Future<bool> shouldShowOnboarding() async {
    final service = OnboardingService.instance;
    final hasSeenOnboarding = await service.hasSeenOnboarding();
    final isEnabled = await service.isOnboardingEnabled();

    return !hasSeenOnboarding && isEnabled;
  }

  /// Navigate to onboarding screen if needed
  static Future<void> showOnboardingIfNeeded(BuildContext context) async {
    if (await shouldShowOnboarding()) {
      if (context.mounted) {
        Navigator.pushReplacementNamed(context, '/onboarding');
      }
    }
  }

  /// Predefined help tips for different screens
  static const Map<String, Map<String, String>> predefinedTips = {
    // Enhanced Focus Screen tips
    'focus_timer_start': {
      'title': 'Start Your Focus Session',
      'description':
          'Tap the play button to begin your Pomodoro session. The timer will automatically switch between work and break periods.',
    },
    'focus_presets': {
      'title': 'Timer Presets',
      'description':
          'Use preset buttons for quick timer setup, or create custom presets for your specific needs.',
    },
    'focus_voice_commands': {
      'title': 'Voice Commands',
      'description':
          'Enable voice commands to control your timer hands-free. Say "start timer" or "pause timer" to control your session.',
    },
    'focus_music': {
      'title': 'Background Music',
      'description':
          'Add background music to enhance your focus. Choose from ambient sounds or import your own music.',
    },

    // Enhanced Agenda Screen tips
    'agenda_create_task': {
      'title': 'Create New Task',
      'description':
          'Tap the + button to create a new task. You can set priorities, categories, and due dates.',
    },
    'agenda_filters': {
      'title': 'Filter Tasks',
      'description':
          'Use the filter options to view tasks by status, priority, or category to stay organized.',
    },
    'agenda_task_actions': {
      'title': 'Task Actions',
      'description':
          'Long press on any task to access quick actions like edit, delete, or change status.',
    },

    // Enhanced Notes Screen tips
    'notes_create': {
      'title': 'Create Notes',
      'description':
          'Tap the + button to create a new note. You can add rich formatting, tags, and voice recordings.',
    },
    'notes_search': {
      'title': 'Search Notes',
      'description':
          'Use the search bar to find notes by title, content, or tags. Advanced search options are available.',
    },
    'notes_tags': {
      'title': 'Organize with Tags',
      'description':
          'Add tags to your notes for better organization and quick filtering.',
    },

    // Enhanced PDF Reader tips
    'pdf_navigation': {
      'title': 'Navigate Pages',
      'description':
          'Swipe or use the navigation controls to move between pages. Pinch to zoom in and out.',
    },
    'pdf_annotations': {
      'title': 'Add Annotations',
      'description':
          'Use the annotation tools to highlight text, add notes, and mark important sections.',
    },
    'pdf_search': {
      'title': 'Search in PDF',
      'description':
          'Use the search function to find specific text within your PDF documents.',
    },

    // Enhanced Settings Screen tips
    'settings_customization': {
      'title': 'Customize Your Experience',
      'description':
          'Adjust themes, fonts, and preferences to make FocusBro work perfectly for you.',
    },
    'settings_backup': {
      'title': 'Backup Your Data',
      'description':
          'Enable cloud sync to backup your tasks, notes, and settings across devices.',
    },
  };

  /// Get a predefined tip
  static Map<String, String>? getPredefinedTip(String tipId) {
    return predefinedTips[tipId];
  }

  /// Get all available tip IDs for a screen
  static List<String> getTipIdsForScreen(String screenName) {
    return predefinedTips.keys
        .where((key) => key.startsWith(screenName.toLowerCase()))
        .toList();
  }
}
