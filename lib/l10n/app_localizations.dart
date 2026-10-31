import 'package:flutter/material.dart';

/// Localization delegate for FocusBro app
class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const List<Locale> supportedLocales = [
    Locale('en', 'US'), // English
    Locale('id', 'ID'), // Indonesian
    Locale('es', 'ES'), // Spanish
    Locale('fr', 'FR'), // French
    Locale('de', 'DE'), // German
    Locale('it', 'IT'), // Italian
    Locale('pt', 'BR'), // Portuguese (Brazil)
    Locale('ja', 'JP'), // Japanese
    Locale('ko', 'KR'), // Korean
    Locale('zh', 'CN'), // Chinese (Simplified)
    Locale('ar', 'SA'), // Arabic
  ];

  // App Title and Navigation
  String get appTitle =>
      _localizedValues[locale.languageCode]?['app_title'] ?? 'FocusBro';
  String get focus =>
      _localizedValues[locale.languageCode]?['focus'] ?? 'Focus';
  String get agenda =>
      _localizedValues[locale.languageCode]?['agenda'] ?? 'Agenda';
  String get notes =>
      _localizedValues[locale.languageCode]?['notes'] ?? 'Notes';
  String get pdf => _localizedValues[locale.languageCode]?['pdf'] ?? 'PDF';
  String get settings =>
      _localizedValues[locale.languageCode]?['settings'] ?? 'Settings';
  String get analytics =>
      _localizedValues[locale.languageCode]?['analytics'] ?? 'Analytics';

  // Timer Controls
  String get start =>
      _localizedValues[locale.languageCode]?['start'] ?? 'Start';
  String get pause =>
      _localizedValues[locale.languageCode]?['pause'] ?? 'Pause';
  String get reset =>
      _localizedValues[locale.languageCode]?['reset'] ?? 'Reset';
  String get skip => _localizedValues[locale.languageCode]?['skip'] ?? 'Skip';
  String get extend =>
      _localizedValues[locale.languageCode]?['extend'] ?? 'Extend';

  // Session Types
  String get workSession =>
      _localizedValues[locale.languageCode]?['work_session'] ?? 'Work Session';
  String get breakSession =>
      _localizedValues[locale.languageCode]?['break_session'] ??
      'Break Session';
  String get longBreak =>
      _localizedValues[locale.languageCode]?['long_break'] ?? 'Long Break';

  // Time Formats
  String get minutes =>
      _localizedValues[locale.languageCode]?['minutes'] ?? 'minutes';
  String get seconds =>
      _localizedValues[locale.languageCode]?['seconds'] ?? 'seconds';
  String get hours =>
      _localizedValues[locale.languageCode]?['hours'] ?? 'hours';

  // Session Status
  String sessionProgress(int current, int total) {
    final template = _localizedValues[locale.languageCode]
            ?['session_progress'] ??
        'Session {current} of {total}';
    return template
        .replaceAll('{current}', current.toString())
        .replaceAll('{total}', total.toString());
  }

  String timeRemaining(int minutes) {
    final template = _localizedValues[locale.languageCode]?['time_remaining'] ??
        '{minutes} minutes remaining';
    return template.replaceAll('{minutes}', minutes.toString());
  }

  String streakDays(int days) {
    final template = _localizedValues[locale.languageCode]?['streak_days'] ??
        '{days} Day Streak';
    return template.replaceAll('{days}', days.toString());
  }

  // Settings
  String get themeMode =>
      _localizedValues[locale.languageCode]?['theme_mode'] ?? 'Theme Mode';
  String get light =>
      _localizedValues[locale.languageCode]?['light'] ?? 'Light';
  String get dark => _localizedValues[locale.languageCode]?['dark'] ?? 'Dark';
  String get system =>
      _localizedValues[locale.languageCode]?['system'] ?? 'System';
  String get language =>
      _localizedValues[locale.languageCode]?['language'] ?? 'Language';
  String get notifications =>
      _localizedValues[locale.languageCode]?['notifications'] ??
      'Notifications';
  String get cloudSync =>
      _localizedValues[locale.languageCode]?['cloud_sync'] ?? 'Cloud Sync';

  // Analytics
  String get overview =>
      _localizedValues[locale.languageCode]?['overview'] ?? 'Overview';
  String get insights =>
      _localizedValues[locale.languageCode]?['insights'] ?? 'Insights';
  String get trends =>
      _localizedValues[locale.languageCode]?['trends'] ?? 'Trends';
  String get totalSessions =>
      _localizedValues[locale.languageCode]?['total_sessions'] ??
      'Total Sessions';
  String get focusTime =>
      _localizedValues[locale.languageCode]?['focus_time'] ?? 'Focus Time';
  String get currentStreak =>
      _localizedValues[locale.languageCode]?['current_streak'] ??
      'Current Streak';
  String get completionRate =>
      _localizedValues[locale.languageCode]?['completion_rate'] ??
      'Completion Rate';
  String get productivityScore =>
      _localizedValues[locale.languageCode]?['productivity_score'] ??
      'Productivity Score';

  // Common Actions
  String get save => _localizedValues[locale.languageCode]?['save'] ?? 'Save';
  String get cancel =>
      _localizedValues[locale.languageCode]?['cancel'] ?? 'Cancel';
  String get delete =>
      _localizedValues[locale.languageCode]?['delete'] ?? 'Delete';
  String get edit => _localizedValues[locale.languageCode]?['edit'] ?? 'Edit';
  String get add => _localizedValues[locale.languageCode]?['add'] ?? 'Add';
  String get close =>
      _localizedValues[locale.languageCode]?['close'] ?? 'Close';
  String get ok => _localizedValues[locale.languageCode]?['ok'] ?? 'OK';
  String get yes => _localizedValues[locale.languageCode]?['yes'] ?? 'Yes';
  String get no => _localizedValues[locale.languageCode]?['no'] ?? 'No';

  // Error Messages
  String get error =>
      _localizedValues[locale.languageCode]?['error'] ?? 'Error';
  String get success =>
      _localizedValues[locale.languageCode]?['success'] ?? 'Success';
  String get warning =>
      _localizedValues[locale.languageCode]?['warning'] ?? 'Warning';
  String get retry =>
      _localizedValues[locale.languageCode]?['retry'] ?? 'Retry';

  // Cloud Sync
  String get signIn =>
      _localizedValues[locale.languageCode]?['sign_in'] ?? 'Sign In';
  String get signOut =>
      _localizedValues[locale.languageCode]?['sign_out'] ?? 'Sign Out';
  String get email =>
      _localizedValues[locale.languageCode]?['email'] ?? 'Email';
  String get password =>
      _localizedValues[locale.languageCode]?['password'] ?? 'Password';
  String get syncNow =>
      _localizedValues[locale.languageCode]?['sync_now'] ?? 'Sync Now';
  String get autoSync =>
      _localizedValues[locale.languageCode]?['auto_sync'] ?? 'Auto Sync';
  String get lastSync =>
      _localizedValues[locale.languageCode]?['last_sync'] ?? 'Last Sync';

  // Notifications
  String get focusSessionComplete =>
      _localizedValues[locale.languageCode]?['focus_session_complete'] ??
      'Focus Session Complete!';
  String get breakTime =>
      _localizedValues[locale.languageCode]?['break_time'] ?? 'Break Time';
  String get backToWork =>
      _localizedValues[locale.languageCode]?['back_to_work'] ?? 'Back to Work';
  String get achievementUnlocked =>
      _localizedValues[locale.languageCode]?['achievement_unlocked'] ??
      'Achievement Unlocked!';

  // Accessibility
  String get startTimer =>
      _localizedValues[locale.languageCode]?['start_timer'] ?? 'Start timer';
  String get pauseTimer =>
      _localizedValues[locale.languageCode]?['pause_timer'] ?? 'Pause timer';
  String get resetTimer =>
      _localizedValues[locale.languageCode]?['reset_timer'] ?? 'Reset timer';
  String get timerStatus =>
      _localizedValues[locale.languageCode]?['timer_status'] ?? 'Timer status';

  // Validation Messages
  String get fieldRequired =>
      _localizedValues[locale.languageCode]?['field_required'] ??
      'This field is required';
  String get invalidEmail =>
      _localizedValues[locale.languageCode]?['invalid_email'] ??
      'Please enter a valid email address';
  String get passwordTooShort =>
      _localizedValues[locale.languageCode]?['password_too_short'] ??
      'Password must be at least 6 characters';

  // Enhanced Settings Screen getters
  String get systemTheme =>
      _localizedValues[locale.languageCode]?['system_theme'] ?? 'System';
  String get lightTheme =>
      _localizedValues[locale.languageCode]?['light_theme'] ?? 'Light';
  String get darkTheme =>
      _localizedValues[locale.languageCode]?['dark_theme'] ?? 'Dark';
  String get general =>
      _localizedValues[locale.languageCode]?['general'] ?? 'General';
  String get autoSave =>
      _localizedValues[locale.languageCode]?['auto_save'] ?? 'Auto-save';
  String get autoSaveDescription =>
      _localizedValues[locale.languageCode]?['auto_save_description'] ??
      'Automatically save notes and tasks';
  String get fontSize =>
      _localizedValues[locale.languageCode]?['font_size'] ?? 'Font Size';
  String get fontSizeDescription =>
      _localizedValues[locale.languageCode]?['font_size_description'] ??
      'Adjust text size for better readability ({percent}%)';
  String get smallFont =>
      _localizedValues[locale.languageCode]?['small_font'] ?? 'Small (80%)';
  String get normalFont =>
      _localizedValues[locale.languageCode]?['normal_font'] ?? 'Normal (100%)';
  String get largeFont =>
      _localizedValues[locale.languageCode]?['large_font'] ?? 'Large (150%)';
  String get defaultScreen =>
      _localizedValues[locale.languageCode]?['default_screen'] ??
      'Default Screen';
  String get focusScreen =>
      _localizedValues[locale.languageCode]?['focus_screen'] ?? 'Focus';
  String get agendaScreen =>
      _localizedValues[locale.languageCode]?['agenda_screen'] ?? 'Agenda';
  String get notesScreen =>
      _localizedValues[locale.languageCode]?['notes_screen'] ?? 'Notes';
  String get pdfReaderScreen =>
      _localizedValues[locale.languageCode]?['pdf_reader_screen'] ??
      'PDF Reader';

  // Onboarding System getters
  String get welcomeToFocusBro =>
      _localizedValues[locale.languageCode]?['welcome_to_focusbro'] ??
      'Welcome to FocusBro';
  String get onboardingSubtitle =>
      _localizedValues[locale.languageCode]?['onboarding_subtitle'] ??
      'Your productivity companion';
  String get getStarted =>
      _localizedValues[locale.languageCode]?['get_started'] ?? 'Get Started';
  String get next => _localizedValues[locale.languageCode]?['next'] ?? 'Next';
  String get previous =>
      _localizedValues[locale.languageCode]?['previous'] ?? 'Previous';
  String get finish =>
      _localizedValues[locale.languageCode]?['finish'] ?? 'Finish';
  String get onboardingFocusTitle =>
      _localizedValues[locale.languageCode]?['onboarding_focus_title'] ??
      'Focus Timer';
  String get onboardingFocusDescription =>
      _localizedValues[locale.languageCode]?['onboarding_focus_description'] ??
      'Use the Pomodoro technique to boost your productivity with customizable work and break sessions.';
  String get onboardingTasksTitle =>
      _localizedValues[locale.languageCode]?['onboarding_tasks_title'] ??
      'Task Management';
  String get onboardingTasksDescription =>
      _localizedValues[locale.languageCode]?['onboarding_tasks_description'] ??
      'Organize your tasks with priorities, categories, and due dates to stay on top of your work.';
  String get onboardingNotesTitle =>
      _localizedValues[locale.languageCode]?['onboarding_notes_title'] ??
      'Smart Notes';
  String get onboardingNotesDescription =>
      _localizedValues[locale.languageCode]?['onboarding_notes_description'] ??
      'Take notes with rich formatting, tags, and voice recordings to capture your ideas.';
  String get onboardingPdfTitle =>
      _localizedValues[locale.languageCode]?['onboarding_pdf_title'] ??
      'PDF Reader';
  String get onboardingPdfDescription =>
      _localizedValues[locale.languageCode]?['onboarding_pdf_description'] ??
      'Read and annotate PDFs with advanced search, bookmarks, and highlighting features.';
  String get onboardingSettingsTitle =>
      _localizedValues[locale.languageCode]?['onboarding_settings_title'] ??
      'Personalization';
  String get onboardingSettingsDescription =>
      _localizedValues[locale.languageCode]
          ?['onboarding_settings_description'] ??
      'Customize themes, sounds, and preferences to make FocusBro work perfectly for you.';
  String get helpTip =>
      _localizedValues[locale.languageCode]?['help_tip'] ?? 'Tip';
  String get gotIt =>
      _localizedValues[locale.languageCode]?['got_it'] ?? 'Got it';
  String get showHelpTips =>
      _localizedValues[locale.languageCode]?['show_help_tips'] ??
      'Show help tips';
  String get hideHelpTips =>
      _localizedValues[locale.languageCode]?['hide_help_tips'] ??
      'Hide help tips';

  static const Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'app_title': 'FocusBro',
      'focus': 'Focus',
      'agenda': 'Agenda',
      'notes': 'Notes',
      'pdf': 'PDF',
      'settings': 'Settings',
      'analytics': 'Analytics',
      'start': 'Start',
      'pause': 'Pause',
      'reset': 'Reset',
      'skip': 'Skip',
      'extend': 'Extend',
      'work_session': 'Work Session',
      'break_session': 'Break Session',
      'long_break': 'Long Break',
      'minutes': 'minutes',
      'seconds': 'seconds',
      'hours': 'hours',
      'session_progress': 'Session {current} of {total}',
      'time_remaining': '{minutes} minutes remaining',
      'streak_days': '{days} Day Streak',
      'theme_mode': 'Theme Mode',
      'light': 'Light',
      'dark': 'Dark',
      'system': 'System',
      'language': 'Language',
      'notifications': 'Notifications',
      'cloud_sync': 'Cloud Sync',
      'overview': 'Overview',
      'insights': 'Insights',
      'trends': 'Trends',
      'total_sessions': 'Total Sessions',
      'focus_time': 'Focus Time',
      'current_streak': 'Current Streak',
      'completion_rate': 'Completion Rate',
      'productivity_score': 'Productivity Score',
      'save': 'Save',
      'cancel': 'Cancel',
      'delete': 'Delete',
      'edit': 'Edit',
      'add': 'Add',
      'close': 'Close',
      'ok': 'OK',
      'yes': 'Yes',
      'no': 'No',
      'error': 'Error',
      'success': 'Success',
      'warning': 'Warning',
      'retry': 'Retry',
      'sign_in': 'Sign In',
      'sign_out': 'Sign Out',
      'email': 'Email',
      'password': 'Password',
      'sync_now': 'Sync Now',
      'auto_sync': 'Auto Sync',
      'last_sync': 'Last Sync',
      'focus_session_complete': 'Focus Session Complete!',
      'break_time': 'Break Time',
      'back_to_work': 'Back to Work',
      'achievement_unlocked': 'Achievement Unlocked!',
      'start_timer': 'Start timer',
      'pause_timer': 'Pause timer',
      'reset_timer': 'Reset timer',
      'timer_status': 'Timer status',
      'field_required': 'This field is required',
      'invalid_email': 'Please enter a valid email address',
      'password_too_short': 'Password must be at least 6 characters',

      // Onboarding System
      'welcome_to_focusbro': 'Welcome to FocusBro',
      'onboarding_subtitle': 'Your productivity companion',
      'get_started': 'Get Started',
      'onboarding_focus_title': 'Focus Timer',
      'onboarding_focus_description':
          'Use the Pomodoro technique to boost your productivity with customizable work and break sessions.',
      'onboarding_tasks_title': 'Task Management',
      'onboarding_tasks_description':
          'Organize your tasks with priorities, categories, and due dates to stay on top of your work.',
      'onboarding_notes_title': 'Smart Notes',
      'onboarding_notes_description':
          'Take notes with rich formatting, tags, and voice recordings to capture your ideas.',
      'onboarding_pdf_title': 'PDF Reader',
      'onboarding_pdf_description':
          'Read and annotate PDFs with advanced search, bookmarks, and highlighting features.',
      'onboarding_settings_title': 'Personalization',
      'onboarding_settings_description':
          'Customize themes, sounds, and preferences to make FocusBro work perfectly for you.',
      'help_tip': 'Tip',
      'got_it': 'Got it',
      'show_help_tips': 'Show help tips',
      'hide_help_tips': 'Hide help tips',

      // Enhanced Focus Screen
      'work_time': 'Work Time',
      'break_time_session': 'Break Time',
      'session_complete': 'Session Complete',
      'timer_reset': 'Timer reset',
      'session_skipped': 'Session skipped',
      'showing_statistics': 'Showing statistics',
      'opening_settings': 'Opening settings',
      'voice_command_recognized': 'Voice command recognized',
      'voice_commands_enabled':
          'Voice commands enabled - Say "start timer" to begin',
      'focus_mode_enabled': 'Focus mode enabled',
      'focus_mode_disabled': 'Focus mode disabled',
      'no_features_enabled': 'No features enabled - Configure in settings',
      'voice_commands': 'Voice Commands',
      'voice_commands_enabled_status': 'Voice Commands Enabled',
      'voice_commands_disabled_status': 'Voice Commands Disabled',
      'voice_feedback_active': 'Voice feedback and commands are active',
      'voice_feedback_inactive': 'Voice feedback and commands are inactive',
      'supported_commands': 'Supported Commands',
      'enable_voice': 'Enable Voice',
      'disable_voice': 'Disable Voice',
      'focus_mode_settings': 'Focus Mode Settings',
      'focus_mode_active': 'Focus Mode Active',
      'focus_mode_inactive': 'Focus Mode Inactive',
      'focus_features': 'Focus Features',
      'automation': 'Automation',
      'enable_focus_mode': 'Enable Focus Mode',
      'disable_focus_mode': 'Disable Focus Mode',
      'quick_settings': 'Quick Settings',
      'timer_durations': 'Timer Durations',
      'background_music': 'Background Music',
      'sound_effects': 'Sound Effects',
      'notification_sounds': 'Notification Sounds',
      'volume': 'Volume',
      'test_sounds': 'Test Sounds',
      'notification': 'Notification',
      'completion': 'Completion',
      'sound_settings_saved': 'Sound settings saved',
      'quick_stats': 'Quick Stats',
      'view_details': 'View Details',
      'timer_presets': 'Timer Presets',
      'built_in_presets': 'Built-in Presets',
      'custom_presets': 'Custom Presets',
      'no_custom_presets': 'No custom presets yet',
      'create_first_preset': 'Create Your First Custom Preset',
      'create_preset_description':
          'Tap the + button above to create a custom timer preset with your preferred work and break durations.',
      'active': 'ACTIVE',
      'work_break_sessions':
          '{work}min work • {break}min break • {sessions} sessions',
      'duplicate_preset': 'Duplicate Preset',
      'delete_preset': 'Delete Preset',
      'preset_duplicated': 'Preset duplicated as "{name}"',
      'failed_duplicate_preset': 'Failed to duplicate preset: {error}',
      'delete_preset_confirm':
          'Are you sure you want to delete "{name}"? This action cannot be undone.',
      'preset_deleted': 'Deleted "{name}" preset',
      'failed_delete_preset': 'Failed to delete preset: {error}',
      'playing_notification_sound': '🔔 Playing notification sound...',
      'error_playing_notification': 'Error playing notification sound: {error}',
      'playing_completion_sound': '🎉 Playing completion sound...',
      'error_playing_completion': 'Error playing completion sound: {error}',
      'applied_preset': 'Applied {name} preset',
      'failed_apply_preset': 'Failed to apply preset: {error}',
      'unable_open_analytics': 'Unable to open analytics: {error}',

      // Enhanced Settings Screen
      'general': 'General',
      'auto_save': 'Auto-save',
      'auto_save_description': 'Automatically save notes and tasks',
      'font_size': 'Font Size',
      'font_size_description':
          'Adjust text size for better readability ({percent}%)',
      'small_font': 'Small (80%)',
      'normal_font': 'Normal (100%)',
      'large_font': 'Large (150%)',
      'system_theme': 'System',
      'light_theme': 'Light',
      'dark_theme': 'Dark',
      'default_screen': 'Default Screen',
      'focus_screen': 'Focus',
      'agenda_screen': 'Agenda',
      'notes_screen': 'Notes',
      'pdf_reader_screen': 'PDF Reader',
      'app_permissions': 'App Permissions',
      'permissions_coming_soon': 'Permissions management coming soon!',
      'could_not_open_url': 'Could not open URL',
      'error_opening_url': 'Error opening URL: {error}',
      'storage_usage': 'Storage Usage',
      'storage_usage_coming_soon': 'Storage usage information coming soon!',
      'calendar_sync': 'Calendar Sync',
      'calendar_sync_coming_soon': 'Calendar synchronization coming soon!',
      'third_party_apps': 'Third-party Apps',
      'third_party_apps_coming_soon': 'Third-party app management coming soon!',
      'app_information': 'App Information',
      'version': 'Version: 1.0.0',
      'build': 'Build: 100',
      'app_description':
          'A productivity app designed to help you focus and manage your tasks effectively.',
      'help_support': 'Help & Support',
      'help_support_coming_soon': 'Help and support features coming soon!',
      'total_sessions_setting': 'Total Sessions',
      'selected_sessions': 'Selected Sessions',
      'adjust_sessions': 'Adjust Sessions',
      'quick_presets': 'Quick Presets',
      'sessions_range': '1-20 range',
      'total_sessions_set': 'Total sessions set to {sessions}',
      'duration_minutes': 'Set duration in minutes (1-60)',
      'slider_minutes': 'Or use slider: {minutes} minutes',
      'quick_presets_label': 'Quick presets:',
      'enable_sound_effects': 'Enable Sound Effects',
      'sound_effects_description': 'Play sounds for timer events',
      'notification_sounds_description': 'Play sounds for notifications',
      'volume_percentage': 'Volume: {percent}%',
      'enable_focus_mode_description':
          'Block distractions during focus sessions',
      'focus_features_title': 'Focus Features',
      'enable_focus_mode_configure':
          'Enable Focus Mode to configure blocking features',
      'current_theme': 'Current Theme',
      'system_default': 'System Default',
      'system_default_description': 'Use system theme with theme mode settings',
      'available_themes': 'Available Themes',
      'built_in': 'Built-in',
      'create_new': 'Create New',
      'delete_theme': 'Delete Theme',
      'delete_theme_confirm':
          'Are you sure you want to delete this custom theme?',
      'theme_deleted': 'Theme deleted successfully',
      'clear_cache': 'Clear Cache',
      'clear_cache_description':
          'This will clear all cached data and temporary files.',
      'clear_cache_benefits': 'Benefits:',
      'clear_cache_benefits_list':
          '• Free up storage space\n• Resolve potential data corruption\n• Improve app performance',
      'clear_cache_note':
          'Note: The app may be slower temporarily while rebuilding cache.',
      'clearing_cache': 'Clearing cache...',
      'clear_cache_button': 'Clear Cache',
      'cache_cleared': 'Cache cleared successfully! Freed {size}MB of storage.',
      'failed_clear_cache': 'Failed to clear cache: {error}',
      'music_library': 'Music Library',
      'music_status': 'Music Status',
      'background_music_description':
          'Play ambient sounds during focus sessions',
      'library_statistics': 'Library Statistics',
      'tracks': 'Tracks',
      'playlists': 'Playlists',
      'quick_actions': 'Quick Actions',
      'app_lock_settings': 'App Lock Settings',
      'app_security': 'App Security',
      'enable_app_lock': 'Enable App Lock',
      'app_lock_description': 'Require authentication to open app',
      'lock_method': 'Lock Method',
      'pin_code': 'PIN Code',
      'pin_code_description': '4-6 digit PIN',
      'biometric': 'Biometric',
      'biometric_available': 'Fingerprint or Face ID',
      'biometric_not_available': 'Not available on this device',
      'setup_lock_method': '{method} setup feature coming soon!',
      'setup_pin': 'Setup PIN',
      'setup_biometric': 'Setup Biometric',
      'app_lock_saved': 'App lock settings saved',
      'create_custom_theme': 'Create Custom Theme',
      'theme_name': 'Theme Name',
      'theme_name_required': 'Theme name is required',
      'brightness': 'Brightness',
      'light_mode': 'Light',
      'dark_mode': 'Dark',
      'colors': 'Colors',
      'primary_color': 'Primary Color',
      'secondary_color': 'Secondary Color',
      'preview': 'Preview',
      'theme_name_placeholder': 'Theme Name',
      'custom_theme': 'Custom Theme',
      'creating_theme': 'Creating theme...',
      'create': 'Create',
      'select_color': 'Select {type} Color',
      'theme_created': 'Theme "{name}" created successfully!',
      'failed_create_theme': 'Failed to create theme: {error}',
      'backup_restore': 'Backup & Restore',
      'backup_status': 'Backup Status',
      'last_backup': 'Last backup: {date}',
      'backup_ready': 'Your data is backed up and ready for restore.',
      'no_backup_found': 'No backup found',
      'create_first_backup': 'Create your first backup to protect your data.',
      'backup_actions': 'Backup Actions',
      'creating_backup': 'Creating Backup...',
      'create_backup': 'Create Backup',
      'restoring_backup': 'Restoring...',
      'restore_backup': 'Restore Backup',
      'backup_includes': 'What gets backed up:',
      'backup_includes_list':
          '• Focus session data and statistics\n• Tasks and agenda items\n• Notes and content\n• Settings and preferences\n• Custom themes and presets',
      'backup_created': 'Backup created successfully!',
      'failed_create_backup': 'Failed to create backup: {error}',
      'restore_backup_title': 'Restore Backup',
      'restore_backup_confirm':
          'This will replace all current data with the backup data. Are you sure you want to continue?',
      'restore': 'Restore',
      'backup_restored':
          'Backup restored successfully! Please restart the app.',
      'failed_restore_backup': 'Failed to restore backup: {error}',
    },
    'es': {
      'app_title': 'FocusBro',
      'focus': 'Enfoque',
      'agenda': 'Agenda',
      'notes': 'Notas',
      'pdf': 'PDF',
      'settings': 'Configuración',
      'analytics': 'Análisis',
      'start': 'Iniciar',
      'pause': 'Pausar',
      'reset': 'Reiniciar',
      'skip': 'Saltar',
      'extend': 'Extender',
      'work_session': 'Sesión de Trabajo',
      'break_session': 'Sesión de Descanso',
      'long_break': 'Descanso Largo',
      'minutes': 'minutos',
      'seconds': 'segundos',
      'hours': 'horas',
      'session_progress': 'Sesión {current} de {total}',
      'time_remaining': '{minutes} minutos restantes',
      'streak_days': 'Racha de {days} Días',
      'theme_mode': 'Modo de Tema',
      'light': 'Claro',
      'dark': 'Oscuro',
      'system': 'Sistema',
      'language': 'Idioma',
      'notifications': 'Notificaciones',
      'cloud_sync': 'Sincronización en la Nube',
      'overview': 'Resumen',
      'insights': 'Perspectivas',
      'trends': 'Tendencias',
      'total_sessions': 'Sesiones Totales',
      'focus_time': 'Tiempo de Enfoque',
      'current_streak': 'Racha Actual',
      'completion_rate': 'Tasa de Finalización',
      'productivity_score': 'Puntuación de Productividad',
      'save': 'Guardar',
      'cancel': 'Cancelar',
      'delete': 'Eliminar',
      'edit': 'Editar',
      'add': 'Agregar',
      'close': 'Cerrar',
      'ok': 'OK',
      'yes': 'Sí',
      'no': 'No',
      'error': 'Error',
      'success': 'Éxito',
      'warning': 'Advertencia',
      'retry': 'Reintentar',
      'sign_in': 'Iniciar Sesión',
      'sign_out': 'Cerrar Sesión',
      'email': 'Correo Electrónico',
      'password': 'Contraseña',
      'sync_now': 'Sincronizar Ahora',
      'auto_sync': 'Sincronización Automática',
      'last_sync': 'Última Sincronización',
      'focus_session_complete': '¡Sesión de Enfoque Completa!',
      'break_time': 'Hora del Descanso',
      'back_to_work': 'De Vuelta al Trabajo',
      'achievement_unlocked': '¡Logro Desbloqueado!',
      'start_timer': 'Iniciar temporizador',
      'pause_timer': 'Pausar temporizador',
      'reset_timer': 'Reiniciar temporizador',
      'timer_status': 'Estado del temporizador',
      'field_required': 'Este campo es obligatorio',
      'invalid_email': 'Por favor ingrese un correo electrónico válido',
      'password_too_short': 'La contraseña debe tener al menos 6 caracteres',
    },
    'fr': {
      'app_title': 'FocusBro',
      'focus': 'Focus',
      'agenda': 'Agenda',
      'notes': 'Notes',
      'pdf': 'PDF',
      'settings': 'Paramètres',
      'analytics': 'Analyses',
      'start': 'Démarrer',
      'pause': 'Pause',
      'reset': 'Réinitialiser',
      'skip': 'Passer',
      'extend': 'Étendre',
      'work_session': 'Session de Travail',
      'break_session': 'Session de Pause',
      'long_break': 'Pause Longue',
      'minutes': 'minutes',
      'seconds': 'secondes',
      'hours': 'heures',
      'session_progress': 'Session {current} sur {total}',
      'time_remaining': '{minutes} minutes restantes',
      'streak_days': 'Série de {days} Jours',
      'theme_mode': 'Mode de Thème',
      'light': 'Clair',
      'dark': 'Sombre',
      'system': 'Système',
      'language': 'Langue',
      'notifications': 'Notifications',
      'cloud_sync': 'Synchronisation Cloud',
      'overview': 'Aperçu',
      'insights': 'Insights',
      'trends': 'Tendances',
      'total_sessions': 'Sessions Totales',
      'focus_time': 'Temps de Focus',
      'current_streak': 'Série Actuelle',
      'completion_rate': 'Taux de Completion',
      'productivity_score': 'Score de Productivité',
      'save': 'Sauvegarder',
      'cancel': 'Annuler',
      'delete': 'Supprimer',
      'edit': 'Modifier',
      'add': 'Ajouter',
      'close': 'Fermer',
      'ok': 'OK',
      'yes': 'Oui',
      'no': 'Non',
      'error': 'Erreur',
      'success': 'Succès',
      'warning': 'Avertissement',
      'retry': 'Réessayer',
      'sign_in': 'Se Connecter',
      'sign_out': 'Se Déconnecter',
      'email': 'Email',
      'password': 'Mot de Passe',
      'sync_now': 'Synchroniser Maintenant',
      'auto_sync': 'Synchronisation Automatique',
      'last_sync': 'Dernière Synchronisation',
      'focus_session_complete': 'Session de Focus Terminée!',
      'break_time': 'Temps de Pause',
      'back_to_work': 'Retour au Travail',
      'achievement_unlocked': 'Succès Débloqué!',
      'start_timer': 'Démarrer le minuteur',
      'pause_timer': 'Mettre en pause le minuteur',
      'reset_timer': 'Réinitialiser le minuteur',
      'timer_status': 'État du minuteur',
      'field_required': 'Ce champ est obligatoire',
      'invalid_email': 'Veuillez entrer une adresse email valide',
      'password_too_short':
          'Le mot de passe doit contenir au moins 6 caractères',
    },
    'id': {
      'app_title': 'FocusBro',
      'focus': 'Fokus',
      'agenda': 'Agenda',
      'notes': 'Catatan',
      'pdf': 'PDF',
      'settings': 'Pengaturan',
      'analytics': 'Analitik',
      'start': 'Mulai',
      'pause': 'Jeda',
      'reset': 'Reset',
      'skip': 'Lewati',
      'extend': 'Perpanjang',
      'work_session': 'Sesi Kerja',
      'break_session': 'Sesi Istirahat',
      'long_break': 'Istirahat Panjang',
      'minutes': 'menit',
      'seconds': 'detik',
      'hours': 'jam',
      'session_progress': 'Sesi {current} dari {total}',
      'time_remaining': '{minutes} menit tersisa',
      'streak_days': 'Streak {days} Hari',
      'theme_mode': 'Mode Tema',
      'light': 'Terang',
      'dark': 'Gelap',
      'system': 'Sistem',
      'language': 'Bahasa',
      'notifications': 'Notifikasi',
      'cloud_sync': 'Sinkronisasi Cloud',
      'overview': 'Ringkasan',
      'insights': 'Wawasan',
      'trends': 'Tren',
      'total_sessions': 'Total Sesi',
      'focus_time': 'Waktu Fokus',
      'current_streak': 'Streak Saat Ini',
      'completion_rate': 'Tingkat Penyelesaian',
      'productivity_score': 'Skor Produktivitas',
      'save': 'Simpan',
      'cancel': 'Batal',
      'delete': 'Hapus',
      'edit': 'Edit',
      'add': 'Tambah',
      'close': 'Tutup',
      'ok': 'OK',
      'yes': 'Ya',
      'no': 'Tidak',
      'error': 'Error',
      'success': 'Berhasil',
      'warning': 'Peringatan',
      'retry': 'Coba Lagi',
      'sign_in': 'Masuk',
      'sign_out': 'Keluar',
      'email': 'Email',
      'password': 'Kata Sandi',
      'sync_now': 'Sinkronkan Sekarang',
      'auto_sync': 'Sinkronisasi Otomatis',
      'last_sync': 'Sinkronisasi Terakhir',
      'focus_session_complete': 'Sesi Fokus Selesai!',
      'break_time': 'Waktu Istirahat',
      'back_to_work': 'Kembali Bekerja',
      'achievement_unlocked': 'Pencapaian Terbuka!',
      'start_timer': 'Mulai timer',
      'pause_timer': 'Jeda timer',
      'reset_timer': 'Reset timer',
      'timer_status': 'Status timer',
      'field_required': 'Field ini wajib diisi',
      'invalid_email': 'Silakan masukkan email yang valid',
      'password_too_short': 'Kata sandi harus minimal 6 karakter',

      // Onboarding System
      'welcome_to_focusbro': 'Selamat Datang di FocusBro',
      'onboarding_subtitle': 'Teman produktivitas Anda',
      'get_started': 'Mulai',
      'onboarding_focus_title': 'Timer Fokus',
      'onboarding_focus_description':
          'Gunakan teknik Pomodoro untuk meningkatkan produktivitas dengan sesi kerja dan istirahat yang dapat disesuaikan.',
      'onboarding_tasks_title': 'Manajemen Tugas',
      'onboarding_tasks_description':
          'Atur tugas Anda dengan prioritas, kategori, dan tenggat waktu untuk tetap menguasai pekerjaan Anda.',
      'onboarding_notes_title': 'Catatan Pintar',
      'onboarding_notes_description':
          'Buat catatan dengan format kaya, tag, dan rekaman suara untuk menangkap ide Anda.',
      'onboarding_pdf_title': 'Pembaca PDF',
      'onboarding_pdf_description':
          'Baca dan beri anotasi PDF dengan pencarian lanjutan, bookmark, dan fitur penyorotan.',
      'onboarding_settings_title': 'Personalisasi',
      'onboarding_settings_description':
          'Sesuaikan tema, suara, dan preferensi untuk membuat FocusBro bekerja sempurna untuk Anda.',
      'help_tip': 'Tips',
      'got_it': 'Mengerti',
      'show_help_tips': 'Tampilkan tips bantuan',
      'hide_help_tips': 'Sembunyikan tips bantuan',

      // Enhanced Focus Screen
      'work_time': 'Waktu Kerja',
      'break_time_session': 'Waktu Istirahat',
      'session_complete': 'Sesi Selesai',
      'timer_reset': 'Timer direset',
      'session_skipped': 'Sesi dilewati',
      'showing_statistics': 'Menampilkan statistik',
      'opening_settings': 'Membuka pengaturan',
      'voice_command_recognized': 'Perintah suara dikenali',
      'voice_commands_enabled':
          'Perintah suara diaktifkan - Katakan "mulai timer" untuk memulai',
      'focus_mode_enabled': 'Mode fokus diaktifkan',
      'focus_mode_disabled': 'Mode fokus dinonaktifkan',
      'no_features_enabled':
          'Tidak ada fitur yang diaktifkan - Konfigurasi di pengaturan',
      'voice_commands': 'Perintah Suara',
      'voice_commands_enabled_status': 'Perintah Suara Diaktifkan',
      'voice_commands_disabled_status': 'Perintah Suara Dinonaktifkan',
      'voice_feedback_active': 'Umpan balik suara dan perintah aktif',
      'voice_feedback_inactive': 'Umpan balik suara dan perintah tidak aktif',
      'supported_commands': 'Perintah yang Didukung',
      'enable_voice': 'Aktifkan Suara',
      'disable_voice': 'Nonaktifkan Suara',
      'focus_mode_settings': 'Pengaturan Mode Fokus',
      'focus_mode_active': 'Mode Fokus Aktif',
      'focus_mode_inactive': 'Mode Fokus Tidak Aktif',
      'focus_features': 'Fitur Fokus',
      'automation': 'Otomatisasi',
      'enable_focus_mode': 'Aktifkan Mode Fokus',
      'disable_focus_mode': 'Nonaktifkan Mode Fokus',
      'quick_settings': 'Pengaturan Cepat',
      'timer_durations': 'Durasi Timer',
      'background_music': 'Musik Latar',
      'sound_effects': 'Efek Suara',
      'notification_sounds': 'Suara Notifikasi',
      'volume': 'Volume',
      'test_sounds': 'Tes Suara',
      'notification': 'Notifikasi',
      'completion': 'Penyelesaian',
      'sound_settings_saved': 'Pengaturan suara disimpan',
      'quick_stats': 'Statistik Cepat',
      'view_details': 'Lihat Detail',
      'timer_presets': 'Preset Timer',
      'built_in_presets': 'Preset Bawaan',
      'custom_presets': 'Preset Kustom',
      'no_custom_presets': 'Belum ada preset kustom',
      'create_first_preset': 'Buat Preset Kustom Pertama Anda',
      'create_preset_description':
          'Ketuk tombol + di atas untuk membuat preset timer kustom dengan durasi kerja dan istirahat yang Anda inginkan.',
      'active': 'AKTIF',
      'work_break_sessions':
          '{work}mnt kerja • {break}mnt istirahat • {sessions} sesi',
      'duplicate_preset': 'Duplikasi Preset',
      'delete_preset': 'Hapus Preset',
      'preset_duplicated': 'Preset diduplikasi sebagai "{name}"',
      'failed_duplicate_preset': 'Gagal menduplikasi preset: {error}',
      'delete_preset_confirm':
          'Apakah Anda yakin ingin menghapus "{name}"? Tindakan ini tidak dapat dibatalkan.',
      'preset_deleted': 'Preset "{name}" dihapus',
      'failed_delete_preset': 'Gagal menghapus preset: {error}',
      'playing_notification_sound': '🔔 Memutar suara notifikasi...',
      'error_playing_notification': 'Error memutar suara notifikasi: {error}',
      'playing_completion_sound': '🎉 Memutar suara penyelesaian...',
      'error_playing_completion': 'Error memutar suara penyelesaian: {error}',
      'applied_preset': 'Menerapkan preset {name}',
      'failed_apply_preset': 'Gagal menerapkan preset: {error}',
      'unable_open_analytics': 'Tidak dapat membuka analitik: {error}',

      // Enhanced Settings Screen
      'general': 'Umum',
      'auto_save': 'Simpan Otomatis',
      'auto_save_description': 'Otomatis menyimpan catatan dan tugas',
      'font_size': 'Ukuran Font',
      'font_size_description':
          'Sesuaikan ukuran teks untuk keterbacaan yang lebih baik ({percent}%)',
      'small_font': 'Kecil (80%)',
      'normal_font': 'Normal (100%)',
      'large_font': 'Besar (150%)',
      'system_theme': 'Sistem',
      'light_theme': 'Terang',
      'dark_theme': 'Gelap',
      'default_screen': 'Layar Default',
      'focus_screen': 'Fokus',
      'agenda_screen': 'Agenda',
      'notes_screen': 'Catatan',
      'pdf_reader_screen': 'Pembaca PDF',
      'app_permissions': 'Izin Aplikasi',
      'permissions_coming_soon': 'Manajemen izin segera hadir!',
      'could_not_open_url': 'Tidak dapat membuka URL',
      'error_opening_url': 'Error membuka URL: {error}',
      'storage_usage': 'Penggunaan Penyimpanan',
      'storage_usage_coming_soon':
          'Informasi penggunaan penyimpanan segera hadir!',
      'calendar_sync': 'Sinkronisasi Kalender',
      'calendar_sync_coming_soon': 'Sinkronisasi kalender segera hadir!',
      'third_party_apps': 'Aplikasi Pihak Ketiga',
      'third_party_apps_coming_soon':
          'Manajemen aplikasi pihak ketiga segera hadir!',
      'app_information': 'Informasi Aplikasi',
      'version': 'Versi: 1.0.0',
      'build': 'Build: 100',
      'app_description':
          'Aplikasi produktivitas yang dirancang untuk membantu Anda fokus dan mengelola tugas secara efektif.',
      'help_support': 'Bantuan & Dukungan',
      'help_support_coming_soon': 'Fitur bantuan dan dukungan segera hadir!',
      'total_sessions_setting': 'Total Sesi',
      'selected_sessions': 'Sesi Terpilih',
      'adjust_sessions': 'Sesuaikan Sesi',
      'quick_presets': 'Preset Cepat',
      'sessions_range': 'rentang 1-20',
      'total_sessions_set': 'Total sesi diatur ke {sessions}',
      'duration_minutes': 'Atur durasi dalam menit (1-60)',
      'slider_minutes': 'Atau gunakan slider: {minutes} menit',
      'quick_presets_label': 'Preset cepat:',
      'enable_sound_effects': 'Aktifkan Efek Suara',
      'sound_effects_description': 'Putar suara untuk acara timer',
      'notification_sounds_description': 'Putar suara untuk notifikasi',
      'volume_percentage': 'Volume: {percent}%',
      'enable_focus_mode_description': 'Blokir gangguan selama sesi fokus',
      'focus_features_title': 'Fitur Fokus',
      'enable_focus_mode_configure':
          'Aktifkan Mode Fokus untuk mengkonfigurasi fitur pemblokiran',
      'current_theme': 'Tema Saat Ini',
      'system_default': 'Default Sistem',
      'system_default_description':
          'Gunakan tema sistem dengan pengaturan mode tema',
      'available_themes': 'Tema Tersedia',
      'built_in': 'Bawaan',
      'create_new': 'Buat Baru',
      'delete_theme': 'Hapus Tema',
      'delete_theme_confirm':
          'Apakah Anda yakin ingin menghapus tema kustom ini?',
      'theme_deleted': 'Tema berhasil dihapus',
      'clear_cache': 'Bersihkan Cache',
      'clear_cache_description':
          'Ini akan menghapus semua data cache dan file sementara.',
      'clear_cache_benefits': 'Manfaat:',
      'clear_cache_benefits_list':
          '• Bebaskan ruang penyimpanan\n• Atasi potensi korupsi data\n• Tingkatkan performa aplikasi',
      'clear_cache_note':
          'Catatan: Aplikasi mungkin lebih lambat sementara saat membangun kembali cache.',
      'clearing_cache': 'Membersihkan cache...',
      'clear_cache_button': 'Bersihkan Cache',
      'cache_cleared':
          'Cache berhasil dibersihkan! Membebaskan {size}MB penyimpanan.',
      'failed_clear_cache': 'Gagal membersihkan cache: {error}',
      'music_library': 'Perpustakaan Musik',
      'music_status': 'Status Musik',
      'background_music_description': 'Putar suara ambient selama sesi fokus',
      'library_statistics': 'Statistik Perpustakaan',
      'tracks': 'Trek',
      'playlists': 'Daftar Putar',
      'quick_actions': 'Tindakan Cepat',
      'app_lock_settings': 'Pengaturan Kunci Aplikasi',
      'app_security': 'Keamanan Aplikasi',
      'enable_app_lock': 'Aktifkan Kunci Aplikasi',
      'app_lock_description': 'Memerlukan autentikasi untuk membuka aplikasi',
      'lock_method': 'Metode Kunci',
      'pin_code': 'Kode PIN',
      'pin_code_description': 'PIN 4-6 digit',
      'biometric': 'Biometrik',
      'biometric_available': 'Sidik jari atau Face ID',
      'biometric_not_available': 'Tidak tersedia di perangkat ini',
      'setup_lock_method': 'Fitur pengaturan {method} segera hadir!',
      'setup_pin': 'Atur PIN',
      'setup_biometric': 'Atur Biometrik',
      'app_lock_saved': 'Pengaturan kunci aplikasi disimpan',
      'create_custom_theme': 'Buat Tema Kustom',
      'theme_name': 'Nama Tema',
      'theme_name_required': 'Nama tema diperlukan',
      'brightness': 'Kecerahan',
      'light_mode': 'Terang',
      'dark_mode': 'Gelap',
      'colors': 'Warna',
      'primary_color': 'Warna Utama',
      'secondary_color': 'Warna Sekunder',
      'preview': 'Pratinjau',
      'theme_name_placeholder': 'Nama Tema',
      'custom_theme': 'Tema Kustom',
      'creating_theme': 'Membuat tema...',
      'create': 'Buat',
      'select_color': 'Pilih Warna {type}',
      'theme_created': 'Tema "{name}" berhasil dibuat!',
      'failed_create_theme': 'Gagal membuat tema: {error}',
      'backup_restore': 'Cadangkan & Pulihkan',
      'backup_status': 'Status Cadangan',
      'last_backup': 'Cadangan terakhir: {date}',
      'backup_ready': 'Data Anda dicadangkan dan siap untuk dipulihkan.',
      'no_backup_found': 'Tidak ada cadangan ditemukan',
      'create_first_backup':
          'Buat cadangan pertama Anda untuk melindungi data.',
      'backup_actions': 'Tindakan Cadangan',
      'creating_backup': 'Membuat Cadangan...',
      'create_backup': 'Buat Cadangan',
      'restoring_backup': 'Memulihkan...',
      'restore_backup': 'Pulihkan Cadangan',
      'backup_includes': 'Yang dicadangkan:',
      'backup_includes_list':
          '• Data sesi fokus dan statistik\n• Tugas dan item agenda\n• Catatan dan konten\n• Pengaturan dan preferensi\n• Tema kustom dan preset',
      'backup_created': 'Cadangan berhasil dibuat!',
      'failed_create_backup': 'Gagal membuat cadangan: {error}',
      'restore_backup_title': 'Pulihkan Cadangan',
      'restore_backup_confirm':
          'Ini akan mengganti semua data saat ini dengan data cadangan. Apakah Anda yakin ingin melanjutkan?',
      'restore': 'Pulihkan',
      'backup_restored':
          'Cadangan berhasil dipulihkan! Silakan restart aplikasi.',
      'failed_restore_backup': 'Gagal memulihkan cadangan: {error}',
    },
    // Add more languages as needed...
  };
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return AppLocalizations.supportedLocales.any((supportedLocale) =>
        supportedLocale.languageCode == locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
