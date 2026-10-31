import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../widgets/music_import_dialog.dart';
import '../widgets/create_playlist_dialog.dart';
import '../widgets/music_library_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../providers/focus_provider.dart';
import '../theme/theme_provider.dart';
import '../screens/enhanced_analytics_screen.dart';
import '../screens/enhanced_webview_screen.dart';
import '../screens/cloud_sync_screen.dart';
import '../screens/language_selection_screen.dart';
import '../utils/legal_content.dart';
import '../widgets/settings_section.dart';
import '../widgets/settings_tile.dart';
import '../widgets/settings_search_delegate.dart';
import '../l10n/app_localizations.dart';
import '../services/onboarding_service.dart';
import '../services/backup_service.dart';
import '../services/app_lock_service.dart';
import '../services/permissions_service.dart';
import '../services/analytics_service.dart';
import '../services/crash_reporting_service.dart';
import '../services/data_collection_service.dart';
import '../services/calendar_export_service.dart';
import '../providers/task_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class EnhancedSettingsScreen extends StatefulWidget {
  const EnhancedSettingsScreen({super.key});

  @override
  State<EnhancedSettingsScreen> createState() => _EnhancedSettingsScreenState();
}

class _EnhancedSettingsScreenState extends State<EnhancedSettingsScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();

  // Settings state
  bool _isLoading = false;
  Map<String, dynamic> _appSettings = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadSettings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _appSettings = {
          // App preferences
          'auto_save_enabled': prefs.getBool('auto_save_enabled') ?? true,
          'default_view': prefs.getString('default_view') ?? 'focus',
          'show_onboarding': prefs.getBool('show_onboarding') ?? true,

          // Accessibility
          'font_scale': prefs.getDouble('font_scale') ?? 1.0,
          'high_contrast': prefs.getBool('high_contrast') ?? false,
          'reduce_animations': prefs.getBool('reduce_animations') ?? false,

          // Privacy
          'analytics_enabled': prefs.getBool('analytics_enabled') ?? true,
          'crash_reporting': prefs.getBool('crash_reporting') ?? true,
          'data_collection': prefs.getBool('data_collection') ?? false,

          // Advanced
          'debug_mode': prefs.getBool('debug_mode') ?? false,
          'performance_monitoring':
              prefs.getBool('performance_monitoring') ?? false,
        };
      });
    } catch (e) {
      debugPrint('Error loading settings: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSetting(String key, dynamic value) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (value is bool) {
        await prefs.setBool(key, value);
      } else if (value is int) {
        await prefs.setInt(key, value);
      } else if (value is double) {
        await prefs.setDouble(key, value);
      } else if (value is String) {
        await prefs.setString(key, value);
      }

      setState(() {
        _appSettings[key] = value;
      });
    } catch (e) {
      debugPrint('Error saving setting $key: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;
    final isLandscape = screenSize.width > screenSize.height;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: NestedScrollView(
        controller: _scrollController,
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: isLandscape ? 60 : (isTablet ? 80 : 70),
              floating: false,
              pinned: true,
              automaticallyImplyLeading: false,
              backgroundColor: colorScheme.surface,
              surfaceTintColor: Colors.transparent,
              title: Text(
                l10n?.settings ?? 'Settings',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                  fontSize: isTablet ? 22 : (isLandscape ? 18 : 20),
                ),
              ),
              centerTitle: false,
              actions: [
                IconButton(
                  onPressed: () {
                    showSearch(
                      context: context,
                      delegate: SettingsSearchDelegate(
                        settings: _getAllSettings(),
                        onSettingTap: _navigateToSetting,
                      ),
                    );
                  },
                  icon: const Icon(Icons.search),
                  tooltip: 'Search Settings',
                ),
                SizedBox(width: isTablet ? 16 : 8),
              ],
              bottom: PreferredSize(
                preferredSize: Size.fromHeight(isLandscape ? 44 : 48),
                child: TabBar(
                  controller: _tabController,
                  isScrollable: !isTablet,
                  tabAlignment:
                      isTablet ? TabAlignment.center : TabAlignment.start,
                  labelStyle: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: isLandscape ? 12 : 14,
                  ),
                  unselectedLabelStyle: theme.textTheme.labelLarge?.copyWith(
                    fontSize: isLandscape ? 12 : 14,
                  ),
                  indicatorColor: colorScheme.primary,
                  labelColor: colorScheme.primary,
                  unselectedLabelColor: colorScheme.onSurfaceVariant,
                  tabs: [
                    Tab(text: isLandscape ? 'Appearance' : 'Appearance'),
                    Tab(text: isLandscape ? 'Focus' : 'Focus & Timer'),
                    Tab(text: isLandscape ? 'App' : 'App Settings'),
                    Tab(text: isLandscape ? 'Privacy' : 'Privacy'),
                    Tab(text: isLandscape ? 'Advanced' : 'Advanced'),
                  ],
                ),
              ),
            ),
          ];
        },
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                controller: _tabController,
                children: [
                  _buildAppearanceTab(),
                  _buildFocusTimerTab(),
                  _buildAppSettingsTab(),
                  _buildPrivacyTab(),
                  _buildAdvancedTab(),
                ],
              ),
      ),
    );
  }

  Widget _buildAppearanceTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SettingsSection(
          title: 'Theme',
          children: [
            Consumer<ThemeProvider>(
              builder: (context, themeProvider, child) {
                final l10n = AppLocalizations.of(context);
                return SettingsTile(
                  icon: Icons.palette,
                  title: 'Theme Mode',
                  subtitle: themeProvider.currentThemeName,
                  trailing: SizedBox(
                    width: 100,
                    child: DropdownButton<ThemeMode>(
                      value: themeProvider.themeMode,
                      underline: Container(),
                      isExpanded: true,
                      items: [
                        DropdownMenuItem(
                          value: ThemeMode.system,
                          child: Text(l10n?.systemTheme ?? 'System'),
                        ),
                        DropdownMenuItem(
                          value: ThemeMode.light,
                          child: Text(l10n?.lightTheme ?? 'Light'),
                        ),
                        DropdownMenuItem(
                          value: ThemeMode.dark,
                          child: Text(l10n?.darkTheme ?? 'Dark'),
                        ),
                      ],
                      onChanged: (ThemeMode? mode) {
                        if (mode != null) {
                          themeProvider.setThemeMode(mode);
                        }
                      },
                    ),
                  ),
                );
              },
            ),
            SettingsTile(
              icon: Icons.color_lens,
              title: 'Custom Themes',
              subtitle: 'Create and manage custom color themes',
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => _showCustomThemesDialog(),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SettingsSection(
          title: 'Accessibility',
          children: [
            Consumer<ThemeProvider>(
              builder: (context, themeProvider, child) {
                final theme = Theme.of(context);
                final l10n = AppLocalizations.of(context);
                return Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.text_fields),
                      title: Text(l10n?.fontSize ?? 'Font Size'),
                      subtitle: Text((l10n?.fontSizeDescription ??
                              'Adjust text size for better readability ({percent}%)')
                          .replaceAll('{percent}',
                              '${(themeProvider.fontScale * 100).round()}')),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: [
                          SizedBox(
                            height: 50,
                            child: Slider(
                              value: themeProvider.fontScale,
                              min: 0.8,
                              max: 1.5,
                              divisions: 14,
                              label:
                                  '${(themeProvider.fontScale * 100).round()}%',
                              onChanged: (value) {
                                themeProvider.setFontScale(value);
                              },
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                l10n?.smallFont ?? 'Small (80%)',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              Text(
                                l10n?.normalFont ?? 'Normal (100%)',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              Text(
                                l10n?.largeFont ?? 'Large (150%)',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
            Consumer<ThemeProvider>(
              builder: (context, themeProvider, child) {
                return SettingsTile.switchTile(
                  icon: Icons.contrast,
                  title: 'High Contrast',
                  subtitle: 'Increase contrast for better visibility',
                  value: themeProvider.highContrast,
                  onChanged: (value) => themeProvider.setHighContrast(value),
                );
              },
            ),
            Consumer<ThemeProvider>(
              builder: (context, themeProvider, child) {
                return SettingsTile.switchTile(
                  icon: Icons.animation,
                  title: 'Reduce Animations',
                  subtitle: 'Minimize motion for accessibility',
                  value: themeProvider.reduceAnimations,
                  onChanged: (value) =>
                      themeProvider.setReduceAnimations(value),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFocusTimerTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SettingsSection(
          title: 'Timer Settings',
          children: [
            Consumer<FocusProvider>(
              builder: (context, focusProvider, child) {
                return Column(
                  children: [
                    SettingsTile(
                      icon: Icons.work,
                      title: 'Work Duration',
                      subtitle: '${focusProvider.workDuration ~/ 60} minutes',
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () => _showDurationPicker(
                        'Work Duration',
                        focusProvider.workDuration,
                        focusProvider.setWorkDuration,
                      ),
                    ),
                    SettingsTile(
                      icon: Icons.coffee,
                      title: 'Break Duration',
                      subtitle: '${focusProvider.breakDuration ~/ 60} minutes',
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () => _showDurationPicker(
                        'Break Duration',
                        focusProvider.breakDuration,
                        focusProvider.setBreakDuration,
                      ),
                    ),
                    SettingsTile(
                      icon: Icons.repeat,
                      title: 'Total Sessions',
                      subtitle: '${focusProvider.totalSessions} sessions',
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () => _showSessionPicker(focusProvider),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        SettingsSection(
          title: 'Audio & Music',
          children: [
            Consumer<FocusProvider>(
              builder: (context, focusProvider, child) {
                return Column(
                  children: [
                    SettingsTile.switchTile(
                      icon: Icons.music_note,
                      title: 'Background Music',
                      subtitle: 'Enable ambient sounds during focus',
                      value: focusProvider.isMusicEnabled,
                      onChanged: (value) => focusProvider.toggleMusic(),
                    ),
                    SettingsTile(
                      icon: Icons.volume_up,
                      title: 'Sound Settings',
                      subtitle: 'Notification sounds and volume',
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () => _showSoundSettings(),
                    ),
                    SettingsTile(
                      icon: Icons.library_music,
                      title: 'Music Library',
                      subtitle: 'Manage your focus music collection',
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () => _showMusicLibrary(),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        SettingsSection(
          title: 'Focus Mode Features',
          children: [
            Consumer<FocusProvider>(
              builder: (context, focusProvider, child) {
                return Column(
                  children: [
                    SettingsTile.switchTile(
                      icon: Icons.do_not_disturb,
                      title: 'Focus Mode',
                      subtitle: 'Enable advanced focus features',
                      value: focusProvider.isFocusModeEnabled,
                      onChanged: (value) => focusProvider.toggleFocusMode(),
                    ),
                    SettingsTile(
                      icon: Icons.settings,
                      title: 'Focus Mode Settings',
                      subtitle: 'Configure blocking and brightness',
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () => _showFocusModeSettings(),
                    ),
                    SettingsTile.switchTile(
                      icon: Icons.mic,
                      title: 'Voice Commands',
                      subtitle: 'Control timer with voice',
                      value: focusProvider.isVoiceEnabled,
                      onChanged: (value) => focusProvider.toggleVoiceCommands(),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAppSettingsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SettingsSection(
          title: 'App Lock',
          children: [
            Consumer<AppLockService>(
              builder: (context, appLock, child) {
                return Column(
                  children: [
                    SettingsTile(
                      icon: Icons.lock,
                      title: 'Enable App Lock',
                      subtitle:
                          'Secure your app with PIN or biometric authentication',
                      trailing: Switch(
                        value: appLock.isAppLockEnabled,
                        onChanged: (value) async {
                          if (value) {
                            // Show method selection dialog
                            final method = await showDialog<String>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Choose Lock Method'),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (appLock.biometricAvailable)
                                      ListTile(
                                        leading: const Icon(Icons.fingerprint),
                                        title: const Text('Biometric'),
                                        onTap: () =>
                                            Navigator.pop(context, 'biometric'),
                                      ),
                                    ListTile(
                                      leading: const Icon(Icons.pin),
                                      title: const Text('PIN'),
                                      onTap: () =>
                                          Navigator.pop(context, 'pin'),
                                    ),
                                  ],
                                ),
                              ),
                            );

                            if (method != null) {
                              if (method == 'pin') {
                                // Show PIN setup dialog
                                final pin = await showDialog<String>(
                                  context: context,
                                  builder: (context) =>
                                      _buildPinSetupDialog(context),
                                );
                                if (pin != null) {
                                  await appLock.setPIN(pin);
                                  await appLock.enableAppLock('pin');
                                }
                              } else {
                                await appLock.enableAppLock('biometric');
                              }
                            }
                          } else {
                            await appLock.disableAppLock();
                          }
                        },
                      ),
                    ),
                    if (appLock.isAppLockEnabled) ...[
                      SettingsTile(
                        icon: Icons.timer,
                        title: 'Auto-lock Timeout',
                        subtitle: '${appLock.lockTimeoutMinutes} minutes',
                        onTap: () async {
                          final minutes = await showDialog<int>(
                            context: context,
                            builder: (context) => _buildTimeoutDialog(
                              context,
                              appLock.lockTimeoutMinutes,
                            ),
                          );
                          if (minutes != null) {
                            await appLock.setLockTimeout(minutes);
                          }
                        },
                      ),
                      if (appLock.lockMethod == 'pin')
                        SettingsTile(
                          icon: Icons.edit,
                          title: 'Change PIN',
                          onTap: () async {
                            final pin = await showDialog<String>(
                              context: context,
                              builder: (context) =>
                                  _buildPinSetupDialog(context),
                            );
                            if (pin != null) {
                              await appLock.setPIN(pin);
                            }
                          },
                        ),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        SettingsSection(
          title: 'General',
          children: [
            SettingsTile.switchTile(
              icon: Icons.auto_awesome,
              title: 'Auto-save',
              subtitle: 'Automatically save notes and tasks',
              value: _appSettings['auto_save_enabled'] ?? true,
              onChanged: (value) => _saveSetting('auto_save_enabled', value),
            ),
            SettingsTile(
              icon: Icons.home,
              title: 'Default View',
              subtitle:
                  _getDefaultViewName(_appSettings['default_view'] ?? 'focus'),
              trailing: SizedBox(
                width: 100,
                child: DropdownButton<String>(
                  value: _appSettings['default_view'] ?? 'focus',
                  underline: Container(),
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: 'focus', child: Text('Focus')),
                    DropdownMenuItem(value: 'agenda', child: Text('Agenda')),
                    DropdownMenuItem(value: 'notes', child: Text('Notes')),
                    DropdownMenuItem(value: 'pdf', child: Text('PDF Reader')),
                  ],
                  onChanged: (value) {
                    if (value != null) _saveSetting('default_view', value);
                  },
                ),
              ),
            ),
            SettingsTile.switchTile(
              icon: Icons.help_outline,
              title: 'Show Onboarding',
              subtitle: 'Display help tips for new features',
              value: _appSettings['show_onboarding'] ?? true,
              onChanged: (value) async {
                await _saveSetting('show_onboarding', value);
                // Update onboarding service
                await OnboardingService.instance.setOnboardingEnabled(value);
              },
            ),

            // Show Onboarding Again button
            SettingsTile(
              icon: Icons.school,
              title: 'Show Tutorial Again',
              subtitle: 'Replay the app introduction tutorial',
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => _showOnboardingAgain(),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SettingsSection(
          title: 'Data Management',
          children: [
            SettingsTile(
              icon: Icons.cloud_sync,
              title: 'Cloud Sync',
              subtitle: 'Sync your data across devices',
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const CloudSyncScreen()),
              ),
            ),
            SettingsTile(
              icon: Icons.backup,
              title: 'Backup & Restore',
              subtitle: 'Create local backups of your data',
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => _showBackupOptions(),
            ),
            SettingsTile(
              icon: Icons.clear_all,
              title: 'Clear Cache',
              subtitle: 'Free up storage space',
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => _showClearCacheDialog(),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SettingsSection(
          title: 'Language & Region',
          children: [
            SettingsTile(
              icon: Icons.language,
              title: 'Language',
              subtitle: 'Choose your preferred language',
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const LanguageSelectionScreen()),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPinSetupDialog(BuildContext context) {
    final TextEditingController pinController = TextEditingController();
    final TextEditingController confirmPinController = TextEditingController();
    bool obscurePin = true;
    bool obscureConfirmPin = true;

    return StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Set PIN'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: pinController,
              obscureText: obscurePin,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: InputDecoration(
                labelText: 'Enter PIN',
                suffixIcon: IconButton(
                  icon: Icon(
                      obscurePin ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => obscurePin = !obscurePin),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: confirmPinController,
              obscureText: obscureConfirmPin,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: InputDecoration(
                labelText: 'Confirm PIN',
                suffixIcon: IconButton(
                  icon: Icon(obscureConfirmPin
                      ? Icons.visibility
                      : Icons.visibility_off),
                  onPressed: () =>
                      setState(() => obscureConfirmPin = !obscureConfirmPin),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (pinController.text.length >= 4 &&
                  pinController.text == confirmPinController.text) {
                Navigator.pop(context, pinController.text);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('PINs do not match or are too short'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Set PIN'),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeoutDialog(BuildContext context, int currentTimeout) {
    final TextEditingController controller = TextEditingController(
      text: currentTimeout.toString(),
    );

    return AlertDialog(
      title: const Text('Set Auto-lock Timeout'),
      content: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          labelText: 'Timeout (minutes)',
          hintText: 'Enter timeout in minutes',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            final minutes = int.tryParse(controller.text);
            if (minutes != null && minutes > 0) {
              Navigator.pop(context, minutes);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please enter a valid number of minutes'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
          child: const Text('Set'),
        ),
      ],
    );
  }

  Widget _buildPrivacyTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SettingsSection(
          title: 'Data Collection',
          children: [
            SettingsTile.switchTile(
              icon: Icons.analytics,
              title: 'Analytics',
              subtitle: 'Help improve the app by sharing usage data',
              value: _appSettings['analytics_enabled'] ?? true,
              onChanged: (value) => _saveSetting('analytics_enabled', value),
            ),
            SettingsTile.switchTile(
              icon: Icons.bug_report,
              title: 'Crash Reporting',
              subtitle: 'Automatically report crashes to help fix issues',
              value: _appSettings['crash_reporting'] ?? true,
              onChanged: (value) => _saveSetting('crash_reporting', value),
            ),
            SettingsTile.switchTile(
              icon: Icons.data_usage,
              title: 'Data Collection',
              subtitle: 'Allow collection of usage data for improvements',
              value: _appSettings['data_collection'] ?? false,
              onChanged: (value) => _saveSetting('data_collection', value),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SettingsSection(
          title: 'Legal',
          children: [
            SettingsTile(
              icon: Icons.privacy_tip,
              title: 'Privacy Policy',
              subtitle: 'Read our privacy policy',
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: _openPrivacyPolicy,
            ),
            SettingsTile(
              icon: Icons.description,
              title: 'Terms of Service',
              subtitle: 'Read our terms of service',
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: _openTermsOfService,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAdvancedTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SettingsSection(
          title: 'Developer Options',
          children: [
            SettingsTile.switchTile(
              icon: Icons.developer_mode,
              title: 'Debug Mode',
              subtitle: 'Enable advanced debugging features',
              value: _appSettings['debug_mode'] ?? false,
              onChanged: (value) => _saveSetting('debug_mode', value),
            ),
            SettingsTile.switchTile(
              icon: Icons.speed,
              title: 'Performance Monitoring',
              subtitle: 'Monitor app performance metrics',
              value: _appSettings['performance_monitoring'] ?? false,
              onChanged: (value) =>
                  _saveSetting('performance_monitoring', value),
            ),
            SettingsTile(
              icon: Icons.storage,
              title: 'Storage Usage',
              subtitle: 'View app storage and cache usage',
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => _showStorageUsage(),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SettingsSection(
          title: 'Integrations',
          children: [
            SettingsTile(
              icon: Icons.calendar_today,
              title: 'Calendar Export',
              subtitle: 'Sync tasks with calendar apps',
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => _showCalendarSync(),
            ),
            SettingsTile(
              icon: Icons.extension,
              title: 'Third-party Apps',
              subtitle: 'Manage connected applications',
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => _showThirdPartyApps(),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SettingsSection(
          title: 'About',
          children: [
            SettingsTile(
              icon: Icons.info,
              title: 'App Version',
              subtitle: 'FocusBro v1.0.0 (Build 100)',
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => _showAppInfo(),
            ),
            SettingsTile(
              icon: Icons.help,
              title: 'Help & Support',
              subtitle: 'Get help and contact support',
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => _showHelpSupport(),
            ),
            SettingsTile(
              icon: Icons.analytics,
              title: 'Analytics Dashboard',
              subtitle: 'View your focus statistics',
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const EnhancedAnalyticsScreen()),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Helper methods
  Map<String, dynamic> _getAllSettings() {
    return {
      ..._appSettings,
      'theme_mode': context.read<ThemeProvider>().themeMode.toString(),
      'work_duration': context.read<FocusProvider>().workDuration,
      'break_duration': context.read<FocusProvider>().breakDuration,
      'total_sessions': context.read<FocusProvider>().totalSessions,
      'music_enabled': context.read<FocusProvider>().isMusicEnabled,
      'voice_enabled': context.read<FocusProvider>().isVoiceEnabled,
      'focus_mode_enabled': context.read<FocusProvider>().isFocusModeEnabled,
    };
  }

  void _navigateToSetting(String settingKey) {
    // Navigate to specific setting based on key
    switch (settingKey) {
      case 'theme_mode':
        _tabController.animateTo(0);
        break;
      case 'work_duration':
      case 'break_duration':
      case 'total_sessions':
      case 'music_enabled':
      case 'voice_enabled':
      case 'focus_mode_enabled':
        _tabController.animateTo(1);
        break;
      case 'auto_save_enabled':
      case 'default_view':
      case 'show_onboarding':
        _tabController.animateTo(2);
        break;
      case 'analytics_enabled':
      case 'crash_reporting':
      case 'data_collection':
        _tabController.animateTo(3);
        break;
      case 'debug_mode':
      case 'performance_monitoring':
        _tabController.animateTo(4);
        break;
    }
  }

  Future<void> _showOnboardingAgain() async {
    try {
      // Reset onboarding status
      await OnboardingService.instance.resetOnboarding();

      // Show confirmation and navigate to onboarding
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tutorial will be shown again on next app start'),
            duration: Duration(seconds: 2),
          ),
        );

        // Navigate to onboarding immediately
        Navigator.pushNamed(context, '/onboarding');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _getDefaultViewName(String value) {
    switch (value) {
      case 'focus':
        return 'Focus Timer';
      case 'agenda':
        return 'Task Agenda';
      case 'notes':
        return 'Notes';
      case 'pdf':
        return 'PDF Reader';
      default:
        return 'Focus Timer';
    }
  }

  // Dialog and sheet methods
  void _showCustomThemesDialog() {
    showDialog(
      context: context,
      builder: (context) => _CustomThemesDialog(),
    );
  }

  void _showDurationPicker(
      String title, int currentDuration, Function(int) onChanged) {
    showDialog(
      context: context,
      builder: (context) => _DurationPickerDialog(
        title: title,
        currentDuration: currentDuration,
        onChanged: onChanged,
      ),
    );
  }

  void _showSessionPicker(FocusProvider provider) {
    showDialog(
      context: context,
      builder: (context) => _SessionPickerDialog(provider: provider),
    );
  }

  void _showSoundSettings() {
    showDialog(
      context: context,
      builder: (context) => _SoundSettingsDialog(),
    );
  }

  void _showFocusModeSettings() {
    showDialog(
      context: context,
      builder: (context) => _FocusModeSettingsDialog(),
    );
  }

  void _showBackupOptions() {
    showDialog(
      context: context,
      builder: (context) => _BackupOptionsDialog(),
    );
  }

  void _showClearCacheDialog() {
    showDialog(
      context: context,
      builder: (context) => _ClearCacheDialog(),
    );
  }

  void _showAppLockSettings() {
    showDialog(
      context: context,
      builder: (context) => _AppLockSettingsDialog(),
    );
  }

  void _showPermissionsDialog() {
    showDialog(
      context: context,
      builder: (context) => _PermissionsDialog(),
    );
  }

  void _showAnalyticsDialog() {
    showDialog(
      context: context,
      builder: (context) => _AnalyticsDialog(),
    );
  }

  void _showCrashReportingDialog() {
    showDialog(
      context: context,
      builder: (context) => _CrashReportingDialog(),
    );
  }

  void _showDataCollectionDialog() {
    showDialog(
      context: context,
      builder: (context) => _DataCollectionDialog(),
    );
  }

  void _openPrivacyPolicy() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EnhancedWebViewScreen(
          title: 'Privacy Policy',
          url: 'local',
          fallbackContent: LegalContent.privacyPolicyHtml,
          showRefreshButton: false,
          showShareButton: true,
        ),
      ),
    );
  }

  void _openTermsOfService() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EnhancedWebViewScreen(
          title: 'Terms of Service',
          url: 'local',
          fallbackContent: LegalContent.termsOfServiceHtml,
          showRefreshButton: false,
          showShareButton: true,
        ),
      ),
    );
  }

  void _showStorageUsage() {
    showDialog(
      context: context,
      builder: (context) => _StorageUsageDialog(),
    );
  }

  void _showMusicLibrary() {
    showDialog(
      context: context,
      builder: (context) => ChangeNotifierProvider.value(
        value: Provider.of<FocusProvider>(context, listen: false).musicService,
        child: const MusicLibraryDialog(),
      ),
    );
  }

  void _showMusicImportDialog() {
    showDialog(
      context: context,
      builder: (context) => ChangeNotifierProvider.value(
        value: Provider.of<FocusProvider>(context, listen: false).musicService,
        child: const MusicImportDialog(),
      ),
    );
  }

  void _showCreatePlaylistDialog() {
    showDialog(
      context: context,
      builder: (context) => ChangeNotifierProvider.value(
        value: Provider.of<FocusProvider>(context, listen: false).musicService,
        child: const CreatePlaylistDialog(),
      ),
    );
  }

  Widget _buildMusicActionButton(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.2),
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      icon,
                      color: theme.colorScheme.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCalendarSync() {
    showDialog(
      context: context,
      builder: (context) => _CalendarSyncDialog(),
    );
  }

  void _showThirdPartyApps() {
    showDialog(
      context: context,
      builder: (context) => _ThirdPartyAppsDialog(),
    );
  }

  void _showAppInfo() {
    showDialog(
      context: context,
      builder: (context) => _AppInfoDialog(),
    );
  }

  void _showHelpSupport() {
    showDialog(
      context: context,
      builder: (context) => _HelpSupportDialog(),
    );
  }
}

// Dialog Widgets

class _SessionPickerDialog extends StatefulWidget {
  final FocusProvider provider;

  const _SessionPickerDialog({required this.provider});

  @override
  State<_SessionPickerDialog> createState() => _SessionPickerDialogState();
}

class _SessionPickerDialogState extends State<_SessionPickerDialog> {
  late int _sessions;

  @override
  void initState() {
    super.initState();
    _sessions = widget.provider.totalSessions;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.repeat,
              color: theme.colorScheme.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Total Sessions',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: isTablet ? 400 : double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Current value display with animation
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.repeat,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Selected Sessions',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          transitionBuilder: (child, animation) {
                            return ScaleTransition(
                              scale: animation,
                              child: FadeTransition(
                                opacity: animation,
                                child: child,
                              ),
                            );
                          },
                          child: Text(
                            '$_sessions ${_sessions == 1 ? 'session' : 'sessions'}',
                            key: ValueKey(_sessions),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Animated Slider with custom styling
            Text(
              'Adjust Sessions',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),

            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: theme.colorScheme.primary,
                inactiveTrackColor:
                    theme.colorScheme.primary.withValues(alpha: 0.2),
                thumbColor: theme.colorScheme.primary,
                overlayColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 12,
                  elevation: 4,
                ),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
                trackHeight: 6,
                tickMarkShape:
                    const RoundSliderTickMarkShape(tickMarkRadius: 3),
                activeTickMarkColor:
                    theme.colorScheme.primary.withValues(alpha: 0.7),
                inactiveTickMarkColor:
                    theme.colorScheme.primary.withValues(alpha: 0.3),
                valueIndicatorShape: const PaddleSliderValueIndicatorShape(),
                valueIndicatorColor: theme.colorScheme.primary,
                valueIndicatorTextStyle: TextStyle(
                  color: theme.colorScheme.onPrimary,
                  fontWeight: FontWeight.bold,
                ),
                showValueIndicator: ShowValueIndicator.onlyForDiscrete,
              ),
              child: Slider(
                value: _sessions.toDouble(),
                min: 1.0,
                max: 20.0,
                divisions: 19,
                label: '$_sessions ${_sessions == 1 ? 'session' : 'sessions'}',
                onChanged: (value) {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _sessions = value.round();
                  });
                },
              ),
            ),

            const SizedBox(height: 16),

            // Quick preset buttons
            Text(
              'Quick Presets',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),

            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      _buildQuickSessionButton(theme, 4),
                      const SizedBox(width: 8),
                      _buildQuickSessionButton(theme, 6),
                      const SizedBox(width: 8),
                      _buildQuickSessionButton(theme, 8),
                      const SizedBox(width: 8),
                      _buildQuickSessionButton(theme, 10),
                    ],
                  ),
                ),
                Text(
                  '1-20 range',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            widget.provider.setTotalSessions(_sessions);
            Navigator.pop(context);

            // Show success feedback
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Total sessions set to $_sessions'),
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 2),
              ),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }

  Widget _buildQuickSessionButton(ThemeData theme, int sessions) {
    final isSelected = _sessions == sessions;

    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            setState(() {
              _sessions = sessions;
            });
          },
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.primary.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              '$sessions',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isSelected
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DurationPickerDialog extends StatefulWidget {
  final String title;
  final int currentDuration;
  final Function(int) onChanged;

  const _DurationPickerDialog({
    required this.title,
    required this.currentDuration,
    required this.onChanged,
  });

  @override
  State<_DurationPickerDialog> createState() => _DurationPickerDialogState();
}

class _DurationPickerDialogState extends State<_DurationPickerDialog> {
  late TextEditingController _textController;
  late int _minutes;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _minutes = widget.currentDuration ~/ 60;
    _textController = TextEditingController(text: _minutes.toString());
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _validateAndUpdate(String value) {
    setState(() {
      final parsed = int.tryParse(value);
      if (parsed == null) {
        _errorText = 'Please enter a valid number';
      } else if (parsed < 1 || parsed > 60) {
        _errorText = 'Duration must be between 1 and 60 minutes';
      } else {
        _errorText = null;
        _minutes = parsed;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    return AlertDialog(
      title: Text(
        widget.title,
        style: theme.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
      content: SizedBox(
        width: isTablet ? 400 : double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Set duration in minutes (1-60)',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),

            // Text Input Field
            TextField(
              controller: _textController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Minutes',
                errorText: _errorText,
                suffixText: 'min',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.timer),
              ),
              onChanged: _validateAndUpdate,
            ),

            const SizedBox(height: 16),

            // Slider
            Text(
              'Or use slider: $_minutes minutes',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Slider(
              value: _minutes.toDouble(),
              min: 1,
              max: 60,
              divisions: 59,
              label: '$_minutes min',
              onChanged: (value) {
                setState(() {
                  _minutes = value.round();
                  _textController.text = _minutes.toString();
                  _errorText = null;
                });
              },
            ),

            const SizedBox(height: 16),

            // Quick Preset Buttons
            Text(
              'Quick presets:',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                _buildPresetChip(5, '5 min'),
                _buildPresetChip(15, '15 min'),
                _buildPresetChip(25, '25 min'),
                _buildPresetChip(45, '45 min'),
                _buildPresetChip(60, '1 hour'),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _errorText == null
              ? () {
                  widget.onChanged(_minutes * 60);
                  Navigator.pop(context);
                }
              : null,
          child: const Text('Save'),
        ),
      ],
    );
  }

  Widget _buildPresetChip(int minutes, String label) {
    final theme = Theme.of(context);
    final isSelected = _minutes == minutes;

    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _minutes = minutes;
            _textController.text = minutes.toString();
            _errorText = null;
          });
        }
      },
      selectedColor: theme.colorScheme.primaryContainer,
    );
  }
}

class _SoundSettingsDialog extends StatefulWidget {
  @override
  State<_SoundSettingsDialog> createState() => _SoundSettingsDialogState();
}

class _SoundSettingsDialogState extends State<_SoundSettingsDialog> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    return Consumer<FocusProvider>(
      builder: (context, focusProvider, child) {
        return AlertDialog(
          title: Text(
            'Sound Settings',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SizedBox(
            width: isTablet ? 500 : double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Sound Effects Section
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.volume_up,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Sound Effects',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Sound Effects Toggle
                        SwitchListTile(
                          title: const Text('Enable Sound Effects'),
                          subtitle: const Text('Play sounds for timer events'),
                          value: focusProvider.soundEffectsEnabled,
                          onChanged: (value) {
                            focusProvider.setSoundEffectsEnabled(value);
                          },
                        ),

                        // Notification Sounds Toggle
                        SwitchListTile(
                          title: const Text('Notification Sounds'),
                          subtitle: const Text('Play sounds for notifications'),
                          value: focusProvider.notificationSoundsEnabled,
                          onChanged: (value) {
                            focusProvider.setNotificationSoundsEnabled(value);
                          },
                        ),

                        // Volume Slider
                        const SizedBox(height: 8),
                        Text(
                          'Volume: ${(focusProvider.audioVolume * 100).round()}%',
                          style: theme.textTheme.bodyMedium,
                        ),
                        Slider(
                          value: focusProvider.audioVolume,
                          min: 0.0,
                          max: 1.0,
                          divisions: 10,
                          label:
                              '${(focusProvider.audioVolume * 100).round()}%',
                          onChanged: (value) {
                            focusProvider.setAudioVolume(value);
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Test Sounds Section
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.play_circle,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Test Sounds',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Test Sound Buttons
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildTestSoundButton(
                              'Work Start',
                              Icons.play_arrow,
                              () => focusProvider.audioService
                                  .playWorkSessionStart(),
                            ),
                            _buildTestSoundButton(
                              'Work Complete',
                              Icons.check_circle,
                              () => focusProvider.audioService
                                  .playWorkSessionComplete(),
                            ),
                            _buildTestSoundButton(
                              'Break Start',
                              Icons.pause_circle,
                              () => focusProvider.audioService
                                  .playBreakSessionStart(),
                            ),
                            _buildTestSoundButton(
                              'Break Complete',
                              Icons.stop_circle,
                              () => focusProvider.audioService
                                  .playBreakSessionComplete(),
                            ),
                            _buildTestSoundButton(
                              'Session Complete',
                              Icons.celebration,
                              () => focusProvider.audioService
                                  .playSessionCompletion(),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTestSoundButton(
      String label, IconData icon, VoidCallback onPressed) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }
}

class _FocusModeSettingsDialog extends StatefulWidget {
  @override
  State<_FocusModeSettingsDialog> createState() =>
      _FocusModeSettingsDialogState();
}

class _FocusModeSettingsDialogState extends State<_FocusModeSettingsDialog> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    return Consumer<FocusProvider>(
      builder: (context, focusProvider, child) {
        return AlertDialog(
          title: Text(
            'Focus Mode Settings',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SizedBox(
            width: isTablet ? 500 : double.maxFinite,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.7,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Focus Mode Toggle
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.do_not_disturb,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Focus Mode',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Enable Focus Mode'),
                              subtitle: const Text(
                                  'Block distractions during focus sessions'),
                              value: focusProvider.isFocusModeEnabled,
                              onChanged: (value) {
                                focusProvider.toggleFocusMode();
                              },
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Focus Mode Features
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Consumer<FocusProvider>(
                          builder: (context, focusProvider, child) {
                            final focusModeService =
                                focusProvider.focusModeService;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.settings,
                                      color: theme.colorScheme.primary,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Focus Features',
                                      style:
                                          theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                // Screen Brightness Control
                                _buildFocusFeatureTile(
                                  icon: Icons.brightness_low,
                                  title: 'Dim Screen',
                                  subtitle: 'Reduce screen brightness to 20%',
                                  value: focusModeService.enableScreenDimming,
                                  onChanged: focusProvider.isFocusModeEnabled
                                      ? (value) {
                                          focusModeService
                                              .setScreenDimmingEnabled(
                                                  value ?? false);
                                        }
                                      : null,
                                  theme: theme,
                                ),

                                // Notification Blocking
                                _buildFocusFeatureTile(
                                  icon: Icons.notifications_off,
                                  title: 'Block Notifications',
                                  subtitle:
                                      'Silence non-essential notifications',
                                  value: focusModeService
                                      .enableNotificationBlocking,
                                  onChanged: focusProvider.isFocusModeEnabled
                                      ? (value) {
                                          focusModeService
                                              .setNotificationBlockingEnabled(
                                                  value ?? false);
                                        }
                                      : null,
                                  theme: theme,
                                ),

                                // Social Media Blocking
                                _buildFocusFeatureTile(
                                  icon: Icons.block,
                                  title: 'Block Social Media',
                                  subtitle:
                                      'Restrict access to social apps and websites',
                                  value: focusModeService
                                      .enableSocialMediaBlocking,
                                  onChanged: focusProvider.isFocusModeEnabled
                                      ? (value) {
                                          focusModeService
                                              .setSocialMediaBlockingEnabled(
                                                  value ?? false);
                                        }
                                      : null,
                                  theme: theme,
                                ),

                                // Auto-enable Feature
                                _buildFocusFeatureTile(
                                  icon: Icons.auto_mode,
                                  title: 'Auto-enable on Focus Start',
                                  subtitle:
                                      'Automatically enable when starting focus sessions',
                                  value:
                                      focusModeService.autoEnableOnFocusStart,
                                  onChanged: (value) {
                                    focusModeService.setAutoEnableOnFocusStart(
                                        value ?? false);
                                  },
                                  theme: theme,
                                ),

                                if (!focusProvider.isFocusModeEnabled)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 12),
                                    child: Text(
                                      'Enable Focus Mode to configure blocking features',
                                      style:
                                          theme.textTheme.bodySmall?.copyWith(
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                        fontStyle: FontStyle.italic,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFocusFeatureTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool?>? onChanged,
    required ThemeData theme,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: CheckboxListTile(
        secondary: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            icon,
            color: theme.colorScheme.primary,
            size: 20,
          ),
        ),
        title: Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        value: value,
        onChanged: onChanged,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }
}

class _CustomThemesDialog extends StatefulWidget {
  @override
  State<_CustomThemesDialog> createState() => _CustomThemesDialogState();
}

class _CustomThemesDialogState extends State<_CustomThemesDialog> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return AlertDialog(
          title: Text(
            'Custom Themes',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SizedBox(
            width: isTablet ? 600 : double.maxFinite,
            height: isTablet ? 500 : 400,
            child: Column(
              children: [
                // Current Theme Section
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.palette,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Current Theme',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          themeProvider.selectedCustomThemeId == 'none'
                              ? 'System Default'
                              : (themeProvider.selectedCustomTheme?.name ??
                                  'Default'),
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Available Themes List
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Available Themes',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: ListView(
                          children: [
                            // System Default option
                            Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: theme.colorScheme.outline
                                          .withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Icon(
                                    themeProvider.selectedCustomThemeId ==
                                            'none'
                                        ? Icons.check
                                        : Icons.brightness_auto,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                                title: Text(
                                  'System Default',
                                  style: TextStyle(
                                    fontWeight:
                                        themeProvider.selectedCustomThemeId ==
                                                'none'
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                  ),
                                ),
                                subtitle: Text(
                                  'Use system theme with theme mode settings',
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                trailing: Radio<String>(
                                  value: 'none',
                                  groupValue:
                                      themeProvider.selectedCustomThemeId,
                                  onChanged: (value) {
                                    if (value != null) {
                                      themeProvider.selectCustomTheme(value);
                                    }
                                  },
                                ),
                                onTap: () {
                                  themeProvider.selectCustomTheme('none');
                                },
                              ),
                            ),

                            // Custom themes
                            ...themeProvider.customThemes.map((customTheme) {
                              final isSelected =
                                  themeProvider.selectedCustomThemeId ==
                                      customTheme.id;

                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  leading: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: customTheme.primaryColor,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: theme.colorScheme.outline
                                            .withValues(alpha: 0.3),
                                      ),
                                    ),
                                    child: Icon(
                                      isSelected ? Icons.check : Icons.palette,
                                      color: customTheme.brightness ==
                                              Brightness.light
                                          ? Colors.black
                                          : Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                  title: Text(
                                    customTheme.name,
                                    style: TextStyle(
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                  subtitle: Text(
                                    customTheme.isBuiltIn
                                        ? 'Built-in'
                                        : 'Custom',
                                    style: TextStyle(
                                      color: customTheme.isBuiltIn
                                          ? theme.colorScheme.primary
                                          : theme.colorScheme.secondary,
                                    ),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (!customTheme.isBuiltIn) ...[
                                        IconButton(
                                          icon: const Icon(Icons.delete,
                                              size: 20),
                                          onPressed: () => _deleteCustomTheme(
                                              themeProvider, customTheme.id),
                                          tooltip: 'Delete Theme',
                                        ),
                                      ],
                                      Radio<String>(
                                        value: customTheme.id,
                                        groupValue:
                                            themeProvider.selectedCustomThemeId,
                                        onChanged: (value) {
                                          if (value != null) {
                                            themeProvider
                                                .selectCustomTheme(value);
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                  onTap: () {
                                    themeProvider
                                        .selectCustomTheme(customTheme.id);
                                  },
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => _showCreateThemeDialog(themeProvider),
              child: const Text('Create New'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _deleteCustomTheme(ThemeProvider themeProvider, String themeId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Theme'),
        content:
            const Text('Are you sure you want to delete this custom theme?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              themeProvider.deleteCustomTheme(themeId);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Theme deleted successfully')),
              );
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showCreateThemeDialog(ThemeProvider themeProvider) {
    Navigator.pop(context); // Close current dialog
    showDialog(
      context: context,
      builder: (context) => _CreateThemeDialog(themeProvider: themeProvider),
    );
  }
}

class _ClearCacheDialog extends StatefulWidget {
  @override
  State<_ClearCacheDialog> createState() => _ClearCacheDialogState();
}

class _ClearCacheDialogState extends State<_ClearCacheDialog> {
  bool _isClearing = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(
        'Clear Cache',
        style: theme.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.warning_amber,
                color: theme.colorScheme.error,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'This will clear all cached data and temporary files.',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Benefits:',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '• Free up storage space\n'
            '• Resolve potential data corruption\n'
            '• Improve app performance',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          Text(
            'Note: The app may be slower temporarily while rebuilding cache.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
          if (_isClearing) ...[
            const SizedBox(height: 16),
            const LinearProgressIndicator(),
            const SizedBox(height: 8),
            Text(
              'Clearing cache...',
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isClearing ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isClearing ? null : _clearCache,
          child: _isClearing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Clear Cache'),
        ),
      ],
    );
  }

  void _clearCache() async {
    setState(() {
      _isClearing = true;
    });

    try {
      int totalClearedBytes = 0;

      // Clear temporary directory
      final tempDir = await getTemporaryDirectory();
      if (await tempDir.exists()) {
        final tempFiles = tempDir.listSync(recursive: true);
        for (final file in tempFiles) {
          if (file is File) {
            try {
              final fileSize = await file.length();
              await file.delete();
              totalClearedBytes += fileSize;
            } catch (e) {
              debugPrint('Error deleting temp file: $e');
            }
          }
        }
      }

      // Clear application cache directory
      try {
        final cacheDir = await getApplicationCacheDirectory();
        if (await cacheDir.exists()) {
          final cacheFiles = cacheDir.listSync(recursive: true);
          for (final file in cacheFiles) {
            if (file is File) {
              try {
                final fileSize = await file.length();
                await file.delete();
                totalClearedBytes += fileSize;
              } catch (e) {
                debugPrint('Error deleting cache file: $e');
              }
            }
          }
        }
      } catch (e) {
        debugPrint('Error accessing cache directory: $e');
      }

      // Clear image cache (Flutter's image cache)
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();

      // Add a small delay for user experience
      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        Navigator.pop(context);
        final sizeInMB = (totalClearedBytes / (1024 * 1024)).toStringAsFixed(2);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Cache cleared successfully! Freed ${sizeInMB}MB of storage.'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isClearing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to clear cache: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class _MusicLibraryDialog extends StatefulWidget {
  @override
  State<_MusicLibraryDialog> createState() => _MusicLibraryDialogState();
}

class _MusicLibraryDialogState extends State<_MusicLibraryDialog> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;
    final isLandscape = screenSize.width > screenSize.height;

    return Consumer<FocusProvider>(
      builder: (context, focusProvider, child) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.library_music,
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Music Library',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isTablet ? 500 : screenSize.width * 0.9,
              maxHeight: isLandscape
                  ? screenSize.height * 0.6
                  : screenSize.height * 0.7,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Music Status Card
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.music_note,
                                color: theme.colorScheme.primary,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Music Status',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Music Toggle with better layout
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Background Music',
                                        style:
                                            theme.textTheme.bodyLarge?.copyWith(
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Play ambient sounds during focus sessions',
                                        style:
                                            theme.textTheme.bodySmall?.copyWith(
                                          color: theme.colorScheme.onSurface
                                              .withValues(alpha: 0.7),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Switch(
                                  value: focusProvider.isMusicEnabled,
                                  onChanged: (value) {
                                    focusProvider.toggleMusic();
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Music Library Info Card
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.queue_music,
                                color: theme.colorScheme.primary,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Library Statistics',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Statistics with real-time updates
                          Consumer<FocusProvider>(
                            builder: (context, focusProvider, child) {
                              final musicService = focusProvider.musicService;
                              return Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.primary
                                            .withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Column(
                                        children: [
                                          Text(
                                            '${musicService.allTracks.length}',
                                            style: theme.textTheme.headlineSmall
                                                ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: theme.colorScheme.primary,
                                            ),
                                          ),
                                          Text(
                                            'Tracks',
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                              color: theme.colorScheme.primary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.secondary
                                            .withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Column(
                                        children: [
                                          Text(
                                            '${musicService.allPlaylists.length}',
                                            style: theme.textTheme.headlineSmall
                                                ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color:
                                                  theme.colorScheme.secondary,
                                            ),
                                          ),
                                          Text(
                                            'Playlists',
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                              color:
                                                  theme.colorScheme.secondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),

                          const SizedBox(height: 20),

                          // Quick Actions Section
                          Text(
                            'Quick Actions',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Action buttons with responsive layout
                          isTablet
                              ? Row(
                                  children: [
                                    Expanded(
                                        child: _buildFunctionalActionButton(
                                            context,
                                            theme,
                                            Icons.file_upload,
                                            'Import',
                                            () => _showMusicImportDialog(
                                                context, focusProvider))),
                                    const SizedBox(width: 8),
                                    Expanded(
                                        child: _buildFunctionalActionButton(
                                            context,
                                            theme,
                                            Icons.playlist_add,
                                            'Create',
                                            () => _showCreatePlaylistDialog(
                                                context, focusProvider))),
                                    const SizedBox(width: 8),
                                    Expanded(
                                        child: _buildFunctionalActionButton(
                                            context,
                                            theme,
                                            Icons.library_music,
                                            'Manage',
                                            () => _showFullMusicLibraryDialog(
                                                context, focusProvider))),
                                  ],
                                )
                              : Column(
                                  children: [
                                    SizedBox(
                                      width: double.infinity,
                                      child: _buildFunctionalActionButton(
                                          context,
                                          theme,
                                          Icons.file_upload,
                                          'Import Music',
                                          () => _showMusicImportDialog(
                                              context, focusProvider)),
                                    ),
                                    const SizedBox(height: 8),
                                    SizedBox(
                                      width: double.infinity,
                                      child: _buildFunctionalActionButton(
                                          context,
                                          theme,
                                          Icons.playlist_add,
                                          'Create Playlist',
                                          () => _showCreatePlaylistDialog(
                                              context, focusProvider)),
                                    ),
                                    const SizedBox(height: 8),
                                    SizedBox(
                                      width: double.infinity,
                                      child: _buildFunctionalActionButton(
                                          context,
                                          theme,
                                          Icons.library_music,
                                          'Manage Library',
                                          () => _showFullMusicLibraryDialog(
                                              context, focusProvider)),
                                    ),
                                  ],
                                ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildActionButton(BuildContext context, ThemeData theme,
      IconData icon, String label, String message) {
    return OutlinedButton.icon(
      onPressed: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      },
      icon: Icon(icon, size: 16),
      label: Text(
        label,
        style: theme.textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }

  Widget _buildFunctionalActionButton(BuildContext context, ThemeData theme,
      IconData icon, String label, VoidCallback onPressed) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(
        label,
        style: theme.textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        side: BorderSide(
          color: theme.colorScheme.primary.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  // Music Library Action Methods
  void _showMusicImportDialog(
      BuildContext context, FocusProvider focusProvider) {
    showDialog(
      context: context,
      builder: (context) => ChangeNotifierProvider.value(
        value: focusProvider.musicService,
        child: const MusicImportDialog(),
      ),
    );
  }

  void _showCreatePlaylistDialog(
      BuildContext context, FocusProvider focusProvider) {
    showDialog(
      context: context,
      builder: (context) => ChangeNotifierProvider.value(
        value: focusProvider.musicService,
        child: const CreatePlaylistDialog(),
      ),
    );
  }

  void _showFullMusicLibraryDialog(
      BuildContext context, FocusProvider focusProvider) {
    // Close current dialog first
    Navigator.of(context).pop();

    // Show full music library dialog
    showDialog(
      context: context,
      builder: (context) => ChangeNotifierProvider.value(
        value: focusProvider.musicService,
        child: const MusicLibraryDialog(),
      ),
    );
  }
}

class _AppLockSettingsDialog extends StatefulWidget {
  @override
  State<_AppLockSettingsDialog> createState() => _AppLockSettingsDialogState();
}

class _AppLockSettingsDialogState extends State<_AppLockSettingsDialog> {
  final AppLockService _appLockService = AppLockService.instance;
  bool _isLoading = true;
  bool _isAppLockEnabled = false;
  String _lockMethod = 'pin';
  bool _biometricAvailable = false;

  @override
  void initState() {
    super.initState();
    _initializeAppLock();
  }

  Future<void> _initializeAppLock() async {
    await _appLockService.initialize();
    if (mounted) {
      setState(() {
        _isAppLockEnabled = _appLockService.isAppLockEnabled;
        _lockMethod = _appLockService.lockMethod;
        _biometricAvailable = _appLockService.biometricAvailable;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    return AlertDialog(
      title: Text(
        'App Lock Settings',
        style: theme.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
      content: SizedBox(
        width: isTablet ? 500 : double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // App Lock Toggle
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.security,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'App Security',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text('Enable App Lock'),
                      subtitle:
                          const Text('Require authentication to open app'),
                      value: _isAppLockEnabled,
                      onChanged: _isLoading
                          ? null
                          : (value) async {
                              if (value) {
                                await _enableAppLock();
                              } else {
                                await _disableAppLock();
                              }
                            },
                    ),
                  ],
                ),
              ),
            ),

            if (_isAppLockEnabled) ...[
              const SizedBox(height: 16),

              // Lock Method Selection
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.lock,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Lock Method',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      RadioListTile<String>(
                        title: const Text('PIN Code'),
                        subtitle: const Text('4-6 digit PIN'),
                        value: 'pin',
                        groupValue: _lockMethod,
                        onChanged: (value) {
                          setState(() {
                            _lockMethod = value!;
                          });
                        },
                      ),

                      RadioListTile<String>(
                        title: const Text('Biometric'),
                        subtitle: Text(_biometricAvailable
                            ? 'Fingerprint or Face ID'
                            : 'Not available on this device'),
                        value: 'biometric',
                        groupValue: _lockMethod,
                        onChanged: _biometricAvailable
                            ? (value) {
                                setState(() {
                                  _lockMethod = value!;
                                });
                              }
                            : null,
                      ),

                      const SizedBox(height: 16),

                      // Setup Button
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _isLoading ? null : () => _setupAppLock(),
                          icon: Icon(_lockMethod == 'pin'
                              ? Icons.pin
                              : Icons.fingerprint),
                          label: Text(
                              'Setup ${_lockMethod == 'pin' ? 'PIN' : 'Biometric'}'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            // Save settings
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('App lock settings saved')),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }

  Future<void> _enableAppLock() async {
    final success = await _appLockService.enableAppLock(_lockMethod);
    if (success && mounted) {
      setState(() {
        _isAppLockEnabled = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('App lock enabled successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to enable app lock'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _disableAppLock() async {
    final success = await _appLockService.disableAppLock();
    if (success && mounted) {
      setState(() {
        _isAppLockEnabled = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('App lock disabled successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to disable app lock'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _setupAppLock() async {
    if (_lockMethod == 'pin') {
      await _setupPIN();
    } else if (_lockMethod == 'biometric') {
      await _setupBiometric();
    }
  }

  Future<void> _setupPIN() async {
    final pinController = TextEditingController();
    final confirmPinController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Setup PIN'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: pinController,
              decoration: const InputDecoration(
                labelText: 'Enter PIN (4-6 digits)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              maxLength: 6,
              obscureText: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: confirmPinController,
              decoration: const InputDecoration(
                labelText: 'Confirm PIN',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              maxLength: 6,
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final pin = pinController.text;
              final confirmPin = confirmPinController.text;

              if (pin.length < 4 || pin.length > 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('PIN must be 4-6 digits'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              if (pin != confirmPin) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('PINs do not match'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              Navigator.pop(context, true);
            },
            child: const Text('Set PIN'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      final success = await _appLockService.setPIN(pinController.text);
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('PIN set successfully'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to set PIN'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _setupBiometric() async {
    final success = await _appLockService.authenticateWithBiometric();
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '${_appLockService.getBiometricTypeString()} setup successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Failed to setup ${_appLockService.getBiometricTypeString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

// Permissions Dialog
class _PermissionsDialog extends StatefulWidget {
  @override
  State<_PermissionsDialog> createState() => _PermissionsDialogState();
}

class _PermissionsDialogState extends State<_PermissionsDialog> {
  final PermissionsService _permissionsService = PermissionsService.instance;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializePermissions();
  }

  Future<void> _initializePermissions() async {
    await _permissionsService.initialize();
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    return AlertDialog(
      title: Text(
        'App Permissions',
        style: theme.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
      content: SizedBox(
        width: isTablet ? 500 : double.maxFinite,
        height: 400,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _buildPermissionsList(theme),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        FilledButton(
          onPressed: () async {
            await _permissionsService.refreshPermissions();
            setState(() {});
          },
          child: const Text('Refresh'),
        ),
      ],
    );
  }

  Widget _buildPermissionsList(ThemeData theme) {
    final summary = _permissionsService.getPermissionsSummary();

    return Column(
      children: [
        // Summary Card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      summary.allGranted ? Icons.check_circle : Icons.warning,
                      color: summary.allGranted ? Colors.green : Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Permissions Summary',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: summary.grantedPercentage / 100,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    summary.allGranted ? Colors.green : Colors.orange,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${summary.granted}/${summary.total} permissions granted',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Permissions List
        Expanded(
          child: ListView.builder(
            itemCount: _permissionsService.permissionStatuses.length,
            itemBuilder: (context, index) {
              final permission =
                  _permissionsService.permissionStatuses.keys.elementAt(index);
              return _buildPermissionTile(permission, theme);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPermissionTile(Permission permission, ThemeData theme) {
    final status = _permissionsService.permissionStatuses[permission]!;
    final isGranted = status == PermissionStatus.granted;
    final isPermanentlyDenied = status == PermissionStatus.permanentlyDenied;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          _permissionsService.getPermissionStatusIcon(permission),
          color: _permissionsService.getPermissionStatusColor(permission),
        ),
        title: Text(
          _permissionsService.getPermissionDisplayName(permission),
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _permissionsService.getPermissionDescription(permission),
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _permissionsService
                        .getPermissionStatusColor(permission)
                        .withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _permissionsService.getPermissionStatusText(permission),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: _permissionsService
                          .getPermissionStatusColor(permission),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (_permissionsService.isPermissionCritical(permission)) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Critical',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.red,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        trailing: isGranted
            ? Icon(Icons.check, color: Colors.green)
            : isPermanentlyDenied
                ? IconButton(
                    icon: const Icon(Icons.settings),
                    onPressed: () => _permissionsService.openAppSettings(),
                    tooltip: 'Open Settings',
                  )
                : IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: () => _requestPermission(permission),
                    tooltip: 'Request Permission',
                  ),
      ),
    );
  }

  Future<void> _requestPermission(Permission permission) async {
    final status = await _permissionsService.requestPermission(permission);

    if (mounted) {
      setState(() {});

      String message;
      Color backgroundColor;

      switch (status) {
        case PermissionStatus.granted:
          message = 'Permission granted successfully';
          backgroundColor = Colors.green;
          break;
        case PermissionStatus.denied:
          message = 'Permission denied';
          backgroundColor = Colors.orange;
          break;
        case PermissionStatus.permanentlyDenied:
          message = 'Permission permanently denied. Please enable in settings.';
          backgroundColor = Colors.red;
          break;
        default:
          message = 'Permission status: ${status.toString()}';
          backgroundColor = Colors.grey;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: backgroundColor,
        ),
      );
    }
  }
}

// Analytics Dialog
class _AnalyticsDialog extends StatefulWidget {
  @override
  State<_AnalyticsDialog> createState() => _AnalyticsDialogState();
}

class _AnalyticsDialogState extends State<_AnalyticsDialog> {
  final AnalyticsService _analyticsService = AnalyticsService.instance;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeAnalytics();
  }

  Future<void> _initializeAnalytics() async {
    await _analyticsService.initialize();
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    return AlertDialog(
      title: Text(
        'Analytics & Tracking',
        style: theme.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
      content: SizedBox(
        width: isTablet ? 500 : double.maxFinite,
        height: 500,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _buildAnalyticsContent(theme),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        FilledButton(
          onPressed: () async {
            final summary = await _analyticsService.getAnalyticsSummary();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content:
                      Text('Analytics: ${summary.totalEvents} events tracked'),
                ),
              );
            }
          },
          child: const Text('View Summary'),
        ),
      ],
    );
  }

  Widget _buildAnalyticsContent(ThemeData theme) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Analytics Overview Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.analytics,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Analytics Overview',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Analytics help us understand how you use FocusBro to improve your experience.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Analytics Controls
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Enable Analytics'),
                    subtitle: const Text('Allow collection of usage data'),
                    value: _analyticsService.analyticsEnabled,
                    onChanged: (value) async {
                      if (value) {
                        await _analyticsService.enableAnalytics();
                      } else {
                        await _analyticsService.disableAnalytics();
                      }
                      setState(() {});
                    },
                  ),
                  const Divider(),
                  SwitchListTile(
                    title: const Text('Performance Tracking'),
                    subtitle: const Text('Track app performance metrics'),
                    value: _analyticsService.performanceTrackingEnabled,
                    onChanged: _analyticsService.analyticsEnabled
                        ? (value) async {
                            if (value) {
                              await _analyticsService
                                  .enablePerformanceTracking();
                            } else {
                              await _analyticsService
                                  .disablePerformanceTracking();
                            }
                            setState(() {});
                          }
                        : null,
                  ),
                  const Divider(),
                  SwitchListTile(
                    title: const Text('Usage Statistics'),
                    subtitle: const Text('Track feature usage patterns'),
                    value: _analyticsService.usageStatisticsEnabled,
                    onChanged: _analyticsService.analyticsEnabled
                        ? (value) async {
                            if (value) {
                              await _analyticsService.enableUsageStatistics();
                            } else {
                              await _analyticsService.disableUsageStatistics();
                            }
                            setState(() {});
                          }
                        : null,
                  ),
                  const Divider(),
                  SwitchListTile(
                    title: const Text('Productivity Metrics'),
                    subtitle:
                        const Text('Track focus sessions and productivity'),
                    value: _analyticsService.productivityMetricsEnabled,
                    onChanged: _analyticsService.analyticsEnabled
                        ? (value) async {
                            if (value) {
                              await _analyticsService
                                  .enableProductivityMetrics();
                            } else {
                              await _analyticsService
                                  .disableProductivityMetrics();
                            }
                            setState(() {});
                          }
                        : null,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Data Usage Information
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'What Data We Collect',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildDataItem('App Usage', 'Screen views and feature usage'),
                  _buildDataItem(
                      'Focus Sessions', 'Duration and completion rates'),
                  _buildDataItem('Performance', 'App speed and responsiveness'),
                  _buildDataItem('Errors', 'Crash reports and error logs'),
                  const SizedBox(height: 12),
                  Text(
                    'Your privacy is important. All data is anonymized and used only to improve the app.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataItem(String title, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(Icons.circle,
              size: 6, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: Theme.of(context).textTheme.bodySmall,
                children: [
                  TextSpan(
                    text: '$title: ',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  TextSpan(text: description),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Crash Reporting Dialog
class _CrashReportingDialog extends StatefulWidget {
  @override
  State<_CrashReportingDialog> createState() => _CrashReportingDialogState();
}

class _CrashReportingDialogState extends State<_CrashReportingDialog> {
  final CrashReportingService _crashReportingService =
      CrashReportingService.instance;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeCrashReporting();
  }

  Future<void> _initializeCrashReporting() async {
    await _crashReportingService.initialize();
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    return AlertDialog(
      title: Text(
        'Crash Reporting',
        style: theme.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
      content: SizedBox(
        width: isTablet ? 500 : double.maxFinite,
        height: 500,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _buildCrashReportingContent(theme),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        FilledButton(
          onPressed: () async {
            final summary = _crashReportingService.getCrashReportingSummary();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content:
                      Text('Crash Reports: ${summary.totalCrashReports} total'),
                ),
              );
            }
          },
          child: const Text('View Summary'),
        ),
      ],
    );
  }

  Widget _buildCrashReportingContent(ThemeData theme) {
    final summary = _crashReportingService.getCrashReportingSummary();

    return SingleChildScrollView(
      child: Column(
        children: [
          // Crash Reporting Overview Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.bug_report,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Crash Reporting Overview',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Help us improve FocusBro by automatically reporting crashes and errors.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Crash Statistics Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Crash Statistics',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildStatItem(
                      'Total Crash Reports', '${summary.totalCrashReports}'),
                  _buildStatItem(
                      'Crashes (Last 7 Days)', '${summary.crashesLast7Days}'),
                  _buildStatItem(
                      'Crashes (Last 30 Days)', '${summary.crashesLast30Days}'),
                  _buildStatItem('Error Logs', '${summary.totalErrorLogs}'),
                  if (summary.lastCrashTime != null)
                    _buildStatItem(
                        'Last Crash', _formatDateTime(summary.lastCrashTime!)),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: summary.isStable
                          ? Colors.green.withValues(alpha: 0.1)
                          : Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          summary.isStable ? Icons.check_circle : Icons.warning,
                          color:
                              summary.isStable ? Colors.green : Colors.orange,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          summary.isStable
                              ? 'App is running stable'
                              : 'Recent issues detected',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color:
                                summary.isStable ? Colors.green : Colors.orange,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Crash Reporting Controls
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Enable Crash Reporting'),
                    subtitle:
                        const Text('Automatically report crashes and errors'),
                    value: _crashReportingService.crashReportingEnabled,
                    onChanged: (value) async {
                      if (value) {
                        await _crashReportingService.enableCrashReporting();
                      } else {
                        await _crashReportingService.disableCrashReporting();
                      }
                      setState(() {});
                    },
                  ),
                  const Divider(),
                  SwitchListTile(
                    title: const Text('Automatic Reporting'),
                    subtitle: const Text('Send crash reports automatically'),
                    value: _crashReportingService.automaticReportingEnabled,
                    onChanged: _crashReportingService.crashReportingEnabled
                        ? (value) async {
                            if (value) {
                              await _crashReportingService
                                  .enableAutomaticReporting();
                            } else {
                              await _crashReportingService
                                  .disableAutomaticReporting();
                            }
                            setState(() {});
                          }
                        : null,
                  ),
                  const Divider(),
                  SwitchListTile(
                    title: const Text('Include Device Info'),
                    subtitle: const Text('Include device details in reports'),
                    value: _crashReportingService.includeDeviceInfoEnabled,
                    onChanged: _crashReportingService.crashReportingEnabled
                        ? (value) async {
                            if (value) {
                              await _crashReportingService
                                  .enableDeviceInfoInclusion();
                            } else {
                              await _crashReportingService
                                  .disableDeviceInfoInclusion();
                            }
                            setState(() {});
                          }
                        : null,
                  ),
                  const Divider(),
                  SwitchListTile(
                    title: const Text('Include App State'),
                    subtitle: const Text('Include app state in crash reports'),
                    value: _crashReportingService.includeAppStateEnabled,
                    onChanged: _crashReportingService.crashReportingEnabled
                        ? (value) async {
                            if (value) {
                              await _crashReportingService
                                  .enableAppStateInclusion();
                            } else {
                              await _crashReportingService
                                  .disableAppStateInclusion();
                            }
                            setState(() {});
                          }
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays} days ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hours ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minutes ago';
    } else {
      return 'Just now';
    }
  }
}

// Data Collection Dialog
class _DataCollectionDialog extends StatefulWidget {
  @override
  State<_DataCollectionDialog> createState() => _DataCollectionDialogState();
}

class _DataCollectionDialogState extends State<_DataCollectionDialog> {
  final DataCollectionService _dataCollectionService =
      DataCollectionService.instance;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeDataCollection();
  }

  Future<void> _initializeDataCollection() async {
    await _dataCollectionService.initialize();
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    return AlertDialog(
      title: Text(
        'Data Collection',
        style: theme.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
      content: SizedBox(
        width: isTablet ? 500 : double.maxFinite,
        height: 600,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _buildDataCollectionContent(theme),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        FilledButton(
          onPressed: () => _showDataTransparencyReport(),
          child: const Text('View Transparency Report'),
        ),
      ],
    );
  }

  Widget _buildDataCollectionContent(ThemeData theme) {
    final summary = _dataCollectionService.getDataCollectionSummary();

    return SingleChildScrollView(
      child: Column(
        children: [
          // Data Collection Overview Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.data_usage,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Data Collection Overview',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Control what data FocusBro collects to improve your experience while respecting your privacy.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Data Summary Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Data Summary',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildSummaryItem(
                      'Status', summary.isEnabled ? 'Enabled' : 'Disabled'),
                  _buildSummaryItem('Active Categories',
                      '${summary.activeCategories.length}'),
                  _buildSummaryItem(
                      'Data Points', '${summary.totalDataPoints}'),
                  _buildSummaryItem('Data Size', summary.dataSizeFormatted),
                  if (summary.lastCollectionTime != null)
                    _buildSummaryItem('Last Collection',
                        _formatDateTime(summary.lastCollectionTime!)),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Data Collection Controls
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Enable Data Collection'),
                    subtitle: const Text('Allow collection of usage data'),
                    value: _dataCollectionService.dataCollectionEnabled,
                    onChanged: (value) async {
                      if (value) {
                        await _dataCollectionService.enableDataCollection();
                      } else {
                        await _dataCollectionService.disableDataCollection();
                      }
                      setState(() {});
                    },
                  ),
                  const Divider(),
                  SwitchListTile(
                    title: const Text('Personal Data'),
                    subtitle:
                        const Text('Collect personal preferences and settings'),
                    value: _dataCollectionService.personalDataCollectionEnabled,
                    onChanged: _dataCollectionService.dataCollectionEnabled
                        ? (value) async {
                            if (value) {
                              await _dataCollectionService
                                  .enablePersonalDataCollection();
                            } else {
                              await _dataCollectionService
                                  .disablePersonalDataCollection();
                            }
                            setState(() {});
                          }
                        : null,
                  ),
                  const Divider(),
                  SwitchListTile(
                    title: const Text('Usage Patterns'),
                    subtitle: const Text('Track how you use app features'),
                    value:
                        _dataCollectionService.usagePatternsCollectionEnabled,
                    onChanged: _dataCollectionService.dataCollectionEnabled
                        ? (value) async {
                            if (value) {
                              await _dataCollectionService
                                  .enableUsagePatternsCollection();
                            } else {
                              await _dataCollectionService
                                  .disableUsagePatternsCollection();
                            }
                            setState(() {});
                          }
                        : null,
                  ),
                  const Divider(),
                  SwitchListTile(
                    title: const Text('Performance Data'),
                    subtitle: const Text('Collect app performance metrics'),
                    value:
                        _dataCollectionService.performanceDataCollectionEnabled,
                    onChanged: _dataCollectionService.dataCollectionEnabled
                        ? (value) async {
                            if (value) {
                              await _dataCollectionService
                                  .enablePerformanceDataCollection();
                            } else {
                              await _dataCollectionService
                                  .disablePerformanceDataCollection();
                            }
                            setState(() {});
                          }
                        : null,
                  ),
                  const Divider(),
                  SwitchListTile(
                    title: const Text('Diagnostic Data'),
                    subtitle: const Text('Collect diagnostic information'),
                    value:
                        _dataCollectionService.diagnosticDataCollectionEnabled,
                    onChanged: _dataCollectionService.dataCollectionEnabled
                        ? (value) async {
                            if (value) {
                              await _dataCollectionService
                                  .enableDiagnosticDataCollection();
                            } else {
                              await _dataCollectionService
                                  .disableDiagnosticDataCollection();
                            }
                            setState(() {});
                          }
                        : null,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Sensitive Data Controls
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sensitive Data (Optional)',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'These data types require explicit consent and can be disabled at any time.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('Location Data'),
                    subtitle: const Text(
                        'Collect location for context-aware features'),
                    value: _dataCollectionService.locationDataCollectionEnabled,
                    onChanged: _dataCollectionService.dataCollectionEnabled
                        ? (value) async {
                            if (value) {
                              await _dataCollectionService
                                  .enableLocationDataCollection();
                            } else {
                              await _dataCollectionService
                                  .disableLocationDataCollection();
                            }
                            setState(() {});
                          }
                        : null,
                  ),
                  const Divider(),
                  SwitchListTile(
                    title: const Text('Contacts Data'),
                    subtitle:
                        const Text('Access contacts for sharing features'),
                    value: _dataCollectionService.contactsDataCollectionEnabled,
                    onChanged: _dataCollectionService.dataCollectionEnabled
                        ? (value) async {
                            if (value) {
                              await _dataCollectionService
                                  .enableContactsDataCollection();
                            } else {
                              await _dataCollectionService
                                  .disableContactsDataCollection();
                            }
                            setState(() {});
                          }
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays} days ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hours ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minutes ago';
    } else {
      return 'Just now';
    }
  }

  void _showDataTransparencyReport() {
    final report = _dataCollectionService.getDataTransparencyReport();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Data Transparency Report'),
        content: SizedBox(
          width: 400,
          height: 400,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildReportSection('Data Collection Status',
                    report['data_collection_enabled'] ? 'Enabled' : 'Disabled'),
                const SizedBox(height: 16),
                _buildReportSection('Data Usage Purposes', ''),
                for (final purpose in report['data_usage_purposes'])
                  Padding(
                    padding: const EdgeInsets.only(left: 16, bottom: 4),
                    child: Text('• $purpose',
                        style: Theme.of(context).textTheme.bodySmall),
                  ),
                const SizedBox(height: 16),
                _buildReportSection(
                    'Data Retention', report['data_retention_period']),
                _buildReportSection('Data Sharing', report['data_sharing']),
                const SizedBox(height: 16),
                _buildReportSection('Your Rights', ''),
                for (final right in report['user_rights'])
                  Padding(
                    padding: const EdgeInsets.only(left: 16, bottom: 4),
                    child: Text('• $right',
                        style: Theme.of(context).textTheme.bodySmall),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildReportSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        if (content.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            content,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}

// App Info Dialog
class _AppInfoDialog extends StatefulWidget {
  @override
  State<_AppInfoDialog> createState() => _AppInfoDialogState();
}

class _AppInfoDialogState extends State<_AppInfoDialog> {
  bool _isLoading = true;
  Map<String, String> _appInfo = {};
  Map<String, String> _deviceInfo = {};

  @override
  void initState() {
    super.initState();
    _loadAppInfo();
  }

  Future<void> _loadAppInfo() async {
    try {
      // Get package info
      final packageInfo = await PackageInfo.fromPlatform();

      // Get device info
      final deviceInfoPlugin = DeviceInfoPlugin();
      Map<String, String> deviceData = {};

      if (Platform.isAndroid) {
        final androidInfo = await deviceInfoPlugin.androidInfo;
        deviceData = {
          'Platform': 'Android',
          'Version': androidInfo.version.release,
          'SDK': androidInfo.version.sdkInt.toString(),
          'Model': androidInfo.model,
          'Manufacturer': androidInfo.manufacturer,
          'Brand': androidInfo.brand,
        };
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfoPlugin.iosInfo;
        deviceData = {
          'Platform': 'iOS',
          'Version': iosInfo.systemVersion,
          'Model': iosInfo.model,
          'Name': iosInfo.name,
        };
      }

      if (mounted) {
        setState(() {
          _appInfo = {
            'App Name': packageInfo.appName,
            'Package Name': packageInfo.packageName,
            'Version': packageInfo.version,
            'Build Number': packageInfo.buildNumber,
            'Build Signature': packageInfo.buildSignature,
            'Installer Store': packageInfo.installerStore ?? 'Unknown',
          };
          _deviceInfo = deviceData;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _appInfo = {
            'App Name': 'FocusBro',
            'Version': '1.0.0',
            'Build Number': '100',
            'Error': 'Could not load app info: $e',
          };
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    return AlertDialog(
      title: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.info,
              color: theme.colorScheme.onPrimary,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'App Information',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: isTablet ? 500 : double.maxFinite,
        height: 400,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _buildAppInfoContent(theme),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        FilledButton(
          onPressed: () => _copyAppInfo(),
          child: const Text('Copy Info'),
        ),
      ],
    );
  }

  Widget _buildAppInfoContent(ThemeData theme) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // App Description
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'FocusBro',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'A comprehensive productivity app designed to help you focus, manage tasks, and boost your productivity with advanced features.',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // App Information Section
          _buildInfoSection('App Details', _appInfo, theme),

          const SizedBox(height: 16),

          // Device Information Section
          if (_deviceInfo.isNotEmpty)
            _buildInfoSection('Device Information', _deviceInfo, theme),

          const SizedBox(height: 16),

          // Additional Info
          _buildAdditionalInfo(theme),
        ],
      ),
    );
  }

  Widget _buildInfoSection(
      String title, Map<String, String> info, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            children: info.entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 120,
                      child: Text(
                        '${entry.key}:',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        entry.value,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildAdditionalInfo(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Additional Information',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoRow(
                  'Debug Mode', kDebugMode ? 'Enabled' : 'Disabled', theme),
              _buildInfoRow(
                  'Profile Mode', kProfileMode ? 'Enabled' : 'Disabled', theme),
              _buildInfoRow(
                  'Release Mode', kReleaseMode ? 'Enabled' : 'Disabled', theme),
              _buildInfoRow('Flutter Version', 'Flutter 3.x', theme),
              _buildInfoRow('Dart Version', 'Dart 3.x', theme),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _copyAppInfo() {
    final buffer = StringBuffer();
    buffer.writeln('=== FocusBro App Information ===\n');

    buffer.writeln('App Details:');
    _appInfo.forEach((key, value) {
      buffer.writeln('$key: $value');
    });

    if (_deviceInfo.isNotEmpty) {
      buffer.writeln('\nDevice Information:');
      _deviceInfo.forEach((key, value) {
        buffer.writeln('$key: $value');
      });
    }

    buffer.writeln('\nAdditional Information:');
    buffer.writeln('Debug Mode: ${kDebugMode ? 'Enabled' : 'Disabled'}');
    buffer.writeln('Profile Mode: ${kProfileMode ? 'Enabled' : 'Disabled'}');
    buffer.writeln('Release Mode: ${kReleaseMode ? 'Enabled' : 'Disabled'}');
    buffer.writeln('Generated: ${DateTime.now().toIso8601String()}');

    Clipboard.setData(ClipboardData(text: buffer.toString()));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('App information copied to clipboard'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
}

// Storage Usage Dialog
class _StorageUsageDialog extends StatefulWidget {
  @override
  State<_StorageUsageDialog> createState() => _StorageUsageDialogState();
}

class _StorageUsageDialogState extends State<_StorageUsageDialog> {
  bool _isLoading = true;
  Map<String, dynamic> _storageInfo = {};

  @override
  void initState() {
    super.initState();
    _loadStorageInfo();
  }

  Future<void> _loadStorageInfo() async {
    try {
      // Get app directory paths
      final appDocDir = await getApplicationDocumentsDirectory();
      final appSupportDir = await getApplicationSupportDirectory();
      final tempDir = await getTemporaryDirectory();
      final cacheDir = await getApplicationCacheDirectory();

      // Calculate directory sizes
      final appDocSize = await _calculateDirectorySize(appDocDir);
      final appSupportSize = await _calculateDirectorySize(appSupportDir);
      final tempSize = await _calculateDirectorySize(tempDir);
      final cacheSize = await _calculateDirectorySize(cacheDir);

      // Get SharedPreferences size
      final prefs = await SharedPreferences.getInstance();
      final prefsSize = _calculatePreferencesSize(prefs);

      if (mounted) {
        setState(() {
          _storageInfo = {
            'app_documents': {
              'path': appDocDir.path,
              'size': appDocSize,
              'description': 'User documents and data files',
            },
            'app_support': {
              'path': appSupportDir.path,
              'size': appSupportSize,
              'description': 'Application support files',
            },
            'cache': {
              'path': cacheDir.path,
              'size': cacheSize,
              'description': 'Temporary cache files',
            },
            'temp': {
              'path': tempDir.path,
              'size': tempSize,
              'description': 'Temporary files',
            },
            'preferences': {
              'path': 'SharedPreferences',
              'size': prefsSize,
              'description': 'App settings and preferences',
            },
          };
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _storageInfo = {
            'error': {
              'path': 'Error',
              'size': 0,
              'description': 'Could not load storage info: $e',
            }
          };
          _isLoading = false;
        });
      }
    }
  }

  Future<int> _calculateDirectorySize(Directory directory) async {
    try {
      if (!await directory.exists()) return 0;

      int totalSize = 0;
      await for (final entity in directory.list(recursive: true)) {
        if (entity is File) {
          try {
            final stat = await entity.stat();
            totalSize += stat.size;
          } catch (e) {
            // Skip files that can't be accessed
          }
        }
      }
      return totalSize;
    } catch (e) {
      return 0;
    }
  }

  int _calculatePreferencesSize(SharedPreferences prefs) {
    try {
      int totalSize = 0;
      final keys = prefs.getKeys();

      for (final key in keys) {
        final value = prefs.get(key);
        if (value != null) {
          totalSize += key.length * 2; // Key size (UTF-16)
          if (value is String) {
            totalSize += value.length * 2; // String size (UTF-16)
          } else {
            totalSize += 8; // Approximate size for other types
          }
        }
      }

      return totalSize;
    } catch (e) {
      return 0;
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  int _getTotalSize() {
    int total = 0;
    for (final info in _storageInfo.values) {
      if (info is Map && info.containsKey('size')) {
        total += info['size'] as int;
      }
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    return AlertDialog(
      title: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.storage,
              color: theme.colorScheme.onPrimary,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Storage Usage',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: isTablet ? 500 : double.maxFinite,
        height: 500,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _buildStorageContent(theme),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        FilledButton(
          onPressed: () => _clearCache(),
          child: const Text('Clear Cache'),
        ),
      ],
    );
  }

  Widget _buildStorageContent(ThemeData theme) {
    final totalSize = _getTotalSize();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Total Storage Summary
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total Storage Used',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _formatBytes(totalSize),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Across ${_storageInfo.length} storage locations',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Storage Breakdown
          Text(
            'Storage Breakdown',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.primary,
            ),
          ),

          const SizedBox(height: 12),

          // Storage Items
          ..._storageInfo.entries.map((entry) {
            final info = entry.value as Map<String, dynamic>;
            final size = info['size'] as int;
            final percentage = totalSize > 0 ? (size / totalSize) * 100 : 0.0;

            return _buildStorageItem(
              _getStorageDisplayName(entry.key),
              info['description'] as String,
              size,
              percentage,
              _getStorageIcon(entry.key),
              _getStorageColor(entry.key),
              theme,
            );
          }),

          const SizedBox(height: 20),

          // Storage Tips
          _buildStorageTips(theme),
        ],
      ),
    );
  }

  Widget _buildStorageItem(
    String title,
    String description,
    int size,
    double percentage,
    IconData icon,
    Color color,
    ThemeData theme,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatBytes(size),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${percentage.toStringAsFixed(1)}%',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: percentage / 100,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ],
      ),
    );
  }

  Widget _buildStorageTips(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.blue.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb, color: Colors.blue, size: 20),
              const SizedBox(width: 8),
              Text(
                'Storage Tips',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '• Clear cache regularly to free up space\n'
            '• Remove unused notes and tasks\n'
            '• Export important data before clearing\n'
            '• Check temporary files periodically',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  String _getStorageDisplayName(String key) {
    switch (key) {
      case 'app_documents':
        return 'App Documents';
      case 'app_support':
        return 'App Support';
      case 'cache':
        return 'Cache Files';
      case 'temp':
        return 'Temporary Files';
      case 'preferences':
        return 'Settings & Preferences';
      default:
        return key;
    }
  }

  IconData _getStorageIcon(String key) {
    switch (key) {
      case 'app_documents':
        return Icons.folder;
      case 'app_support':
        return Icons.support;
      case 'cache':
        return Icons.cached;
      case 'temp':
        return Icons.delete_sweep;
      case 'preferences':
        return Icons.settings;
      default:
        return Icons.storage;
    }
  }

  Color _getStorageColor(String key) {
    switch (key) {
      case 'app_documents':
        return Colors.blue;
      case 'app_support':
        return Colors.green;
      case 'cache':
        return Colors.orange;
      case 'temp':
        return Colors.red;
      case 'preferences':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  Future<void> _clearCache() async {
    try {
      final cacheDir = await getApplicationCacheDirectory();
      final tempDir = await getTemporaryDirectory();

      // Clear cache directory
      if (await cacheDir.exists()) {
        await for (final entity in cacheDir.list()) {
          try {
            await entity.delete(recursive: true);
          } catch (e) {
            // Skip files that can't be deleted
          }
        }
      }

      // Clear temp directory (be careful with this)
      if (await tempDir.exists()) {
        await for (final entity in tempDir.list()) {
          try {
            if (entity.path.contains('focusbro') ||
                entity.path.contains('flutter')) {
              await entity.delete(recursive: true);
            }
          } catch (e) {
            // Skip files that can't be deleted
          }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cache cleared successfully'),
            backgroundColor: Colors.green,
          ),
        );

        // Reload storage info
        _loadStorageInfo();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error clearing cache: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

// Help & Support Dialog
class _HelpSupportDialog extends StatefulWidget {
  @override
  State<_HelpSupportDialog> createState() => _HelpSupportDialogState();
}

class _HelpSupportDialogState extends State<_HelpSupportDialog>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final _contactFormKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    return AlertDialog(
      title: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.help,
              color: theme.colorScheme.onPrimary,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Help & Support',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: isTablet ? 600 : double.maxFinite,
        height: 500,
        child: Column(
          children: [
            TabBar(
              controller: _tabController,
              isScrollable: !isTablet,
              tabs: const [
                Tab(text: 'FAQ', icon: Icon(Icons.quiz)),
                Tab(text: 'Contact', icon: Icon(Icons.contact_support)),
                Tab(text: 'Guides', icon: Icon(Icons.book)),
                Tab(text: 'About', icon: Icon(Icons.info)),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildFAQTab(theme),
                  _buildContactTab(theme),
                  _buildGuidesTab(theme),
                  _buildAboutTab(theme),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildFAQTab(ThemeData theme) {
    final faqs = [
      {
        'question': 'How do I start a focus session?',
        'answer':
            'Go to the Focus tab and tap the play button. You can customize the duration in Settings > Focus & Timer.',
      },
      {
        'question': 'How do I add background music?',
        'answer':
            'Enable background music in Settings > Focus & Timer > Audio & Music. You can import your own music or use built-in ambient sounds.',
      },
      {
        'question': 'How do I create tasks?',
        'answer':
            'Go to the Agenda tab and tap the + button. You can set priority, category, due date, and add descriptions.',
      },
      {
        'question': 'How do I sync my data?',
        'answer':
            'Your data is saved on this device. Cloud sync is not available yet; export a backup from Settings > Backup & Restore to move data between devices.',
      },
      {
        'question': 'How do I enable focus mode?',
        'answer':
            'Go to Settings > Focus & Timer > Focus Mode Features and enable Focus Mode. This will block distractions during sessions.',
      },
      {
        'question': 'How do I backup my data?',
        'answer':
            'Go to Settings > App Settings > Backup & Restore to export your data or restore from a backup.',
      },
      {
        'question': 'How do I change the app theme?',
        'answer':
            'Go to Settings > Appearance > Theme Mode to switch between light, dark, or system theme.',
      },
      {
        'question': 'How do I reset my statistics?',
        'answer':
            'Go to Settings > Advanced > Analytics Dashboard and use the reset options in the analytics menu.',
      },
    ];

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Frequently Asked Questions',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          ...faqs.map((faq) => _buildFAQItem(
                faq['question']!,
                faq['answer']!,
                theme,
              )),
        ],
      ),
    );
  }

  Widget _buildFAQItem(String question, String answer, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: ExpansionTile(
        title: Text(
          question,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(
              answer,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactTab(ThemeData theme) {
    return SingleChildScrollView(
      child: Form(
        key: _contactFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Contact Support',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Have a question or need help? Send us a message and we\'ll get back to you as soon as possible.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),

            // Contact Form
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your email';
                }
                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                    .hasMatch(value)) {
                  return 'Please enter a valid email';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _subjectController,
              decoration: const InputDecoration(
                labelText: 'Subject',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.subject),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a subject';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _messageController,
              decoration: const InputDecoration(
                labelText: 'Message',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.message),
                alignLabelWithHint: true,
              ),
              maxLines: 4,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your message';
                }
                if (value.length < 10) {
                  return 'Message must be at least 10 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isSubmitting ? null : _submitContactForm,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Send Message'),
              ),
            ),

            const SizedBox(height: 20),

            // Quick Contact Options
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color:
                    theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Other Ways to Reach Us',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildContactOption(
                    Icons.email,
                    'Email Support',
                    'support@focusbro.app',
                    () => _launchEmail('support@focusbro.app'),
                    theme,
                  ),
                  _buildContactOption(
                    Icons.bug_report,
                    'Report Bug',
                    'bugs@focusbro.app',
                    () => _launchEmail('bugs@focusbro.app'),
                    theme,
                  ),
                  _buildContactOption(
                    Icons.feedback,
                    'Feature Request',
                    'feedback@focusbro.app',
                    () => _launchEmail('feedback@focusbro.app'),
                    theme,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactOption(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
    ThemeData theme,
  ) {
    return ListTile(
      leading: Icon(icon, color: theme.colorScheme.primary),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildGuidesTab(ThemeData theme) {
    final guides = [
      {
        'title': 'Getting Started',
        'description': 'Learn the basics of FocusBro',
        'icon': Icons.play_circle,
        'color': Colors.green,
      },
      {
        'title': 'Focus Sessions',
        'description': 'Master the Pomodoro technique',
        'icon': Icons.timer,
        'color': Colors.blue,
      },
      {
        'title': 'Task Management',
        'description': 'Organize your tasks effectively',
        'icon': Icons.task,
        'color': Colors.orange,
      },
      {
        'title': 'Music & Sounds',
        'description': 'Customize your focus environment',
        'icon': Icons.music_note,
        'color': Colors.purple,
      },
      {
        'title': 'Analytics & Insights',
        'description': 'Track your productivity',
        'icon': Icons.analytics,
        'color': Colors.red,
      },
      {
        'title': 'Settings & Customization',
        'description': 'Personalize your experience',
        'icon': Icons.settings,
        'color': Colors.teal,
      },
    ];

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'User Guides',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Step-by-step guides to help you get the most out of FocusBro.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          ...guides.map((guide) => _buildGuideItem(
                guide['title'] as String,
                guide['description'] as String,
                guide['icon'] as IconData,
                guide['color'] as Color,
                theme,
              )),
        ],
      ),
    );
  }

  Widget _buildGuideItem(
    String title,
    String description,
    IconData icon,
    Color color,
    ThemeData theme,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(description),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () => _openGuide(title),
      ),
    );
  }

  Widget _buildAboutTab(ThemeData theme) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'About FocusBro',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'FocusBro',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'A comprehensive productivity app designed to help you focus, manage tasks, take notes, and boost your productivity with advanced features.',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _buildInfoSection(
              'Features',
              [
                'Pomodoro Timer with customizable durations',
                'Task management with priorities and categories',
                'Note-taking with rich text editing',
                'PDF reader with annotations',
                'Background music and ambient sounds',
                'Focus mode with distraction blocking',
                'Analytics and productivity insights',
                'Customizable themes and accessibility options',
              ],
              theme),
          const SizedBox(height: 16),
          _buildInfoSection(
              'Support',
              [
                'Email: support@focusbro.app',
                'Bug Reports: bugs@focusbro.app',
                'Feature Requests: feedback@focusbro.app',
                'Documentation: docs.focusbro.app',
              ],
              theme),
          const SizedBox(height: 16),
          _buildInfoSection(
              'Legal',
              [
                'Privacy Policy',
                'Terms of Service',
                'Open Source Licenses',
                'Third-party Acknowledgments',
              ],
              theme),
        ],
      ),
    );
  }

  Widget _buildInfoSection(String title, List<String> items, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: items.map((item) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '• ',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        item,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Future<void> _submitContactForm() async {
    if (!_contactFormKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      // Simulate API call
      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Message sent successfully! We\'ll get back to you soon.'),
            backgroundColor: Colors.green,
          ),
        );

        // Clear form
        _nameController.clear();
        _emailController.clear();
        _subjectController.clear();
        _messageController.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending message: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _launchEmail(String email) {
    // In a real app, you would use url_launcher to open email client
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Opening email client for $email'),
        action: SnackBarAction(
          label: 'Copy',
          onPressed: () {
            Clipboard.setData(ClipboardData(text: email));
          },
        ),
      ),
    );
  }

  void _openGuide(String guideTitle) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Opening guide: $guideTitle'),
        action: SnackBarAction(
          label: 'OK',
          onPressed: () {},
        ),
      ),
    );
  }
}

// Calendar Sync Dialog
class _CalendarSyncDialog extends StatefulWidget {
  @override
  State<_CalendarSyncDialog> createState() => _CalendarSyncDialogState();
}

class _CalendarSyncDialogState extends State<_CalendarSyncDialog> {
  bool _isLoading = true;
  List<String> _exportHistory = [];
  Map<String, dynamic> _syncStats = {};

  @override
  void initState() {
    super.initState();
    _loadCalendarSettings();
  }

  Future<void> _loadCalendarSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final history = prefs.getStringList('calendar_export_history') ?? [];
      final exportedEvents = history.fold<int>(0, (total, entry) {
        final parts = entry.split('|');
        return total + (parts.length == 2 ? int.tryParse(parts.last) ?? 0 : 0);
      });
      if (!mounted) return;
      setState(() {
        _exportHistory = history;
        _syncStats = {
          'totalExported': exportedEvents,
          'lastExport': history.isEmpty
              ? null
              : DateTime.tryParse(history.first.split('|').first),
        };
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _syncStats = {'totalExported': 0, 'lastExport': null};
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    return AlertDialog(
      title: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.calendar_today,
              color: theme.colorScheme.onPrimary,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Calendar Export',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: isTablet ? 500 : double.maxFinite,
        height: 500,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _buildCalendarSyncContent(theme),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildCalendarSyncContent(ThemeData theme) {
    final dueTaskCount = context
        .watch<TaskProvider>()
        .tasks
        .where((task) => task.dueDate != null)
        .length;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Automatic calendar sync is not configured. Export your task due dates as an .ics file and choose a compatible calendar app from the share sheet.',
              style: theme.textTheme.bodyMedium,
            ),
          ),
          const SizedBox(height: 16),
          _buildSyncStatistics(theme, dueTaskCount),
          const SizedBox(height: 16),
          _buildSyncActions(theme),
        ],
      ),
    );
  }

  Widget _buildSyncStatistics(ThemeData theme, int dueTaskCount) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Calendar Export',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Events exported',
                    '${_syncStats['totalExported'] ?? 0}',
                    Icons.event_available,
                    Colors.blue,
                    theme,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatItem(
                    'Tasks with due dates',
                    '$dueTaskCount',
                    Icons.event_note,
                    Colors.orange,
                    theme,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildStatItem(
              'Last export',
              _formatRelativeTime(_syncStats['lastExport'] as DateTime?),
              Icons.access_time,
              Colors.green,
              theme,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    IconData icon,
    Color color,
    ThemeData theme,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSyncActions(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Calendar Export',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _exportCalendarFile,
                icon: const Icon(Icons.share),
                label: const Text('Export due dates (.ics)'),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _showSyncHistory,
                    icon: const Icon(Icons.history),
                    label: const Text('Export history'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _clearSyncData,
                    icon: const Icon(Icons.clear),
                    label: const Text('Clear history'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatRelativeTime(DateTime? dateTime) {
    if (dateTime == null) return 'Never';

    final difference = DateTime.now().difference(dateTime);
    if (difference.inDays > 0) return '${difference.inDays}d ago';
    if (difference.inHours > 0) return '${difference.inHours}h ago';
    if (difference.inMinutes > 0) return '${difference.inMinutes}m ago';
    return 'Just now';
  }

  Future<void> _exportCalendarFile() async {
    try {
      final tasks = context.read<TaskProvider>().tasks;
      final exportedCount = await CalendarExportService().shareDueTasks(tasks);
      if (exportedCount == 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No tasks with due dates to export')),
          );
        }
        return;
      }

      final now = DateTime.now();
      final prefs = await SharedPreferences.getInstance();
      final history = prefs.getStringList('calendar_export_history') ?? [];
      history.insert(0, '${now.toIso8601String()}|$exportedCount');
      final trimmedHistory = history.take(50).toList();
      await prefs.setStringList('calendar_export_history', trimmedHistory);
      if (!mounted) return;
      setState(() {
        _exportHistory = trimmedHistory;
        _syncStats = {
          'totalExported': trimmedHistory.fold<int>(0, (total, entry) {
            final parts = entry.split('|');
            return total +
                (parts.length == 2 ? int.tryParse(parts.last) ?? 0 : 0);
          }),
          'lastExport': now,
        };
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Shared $exportedCount calendar event(s)')),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not export calendar events: $error')),
        );
      }
    }
  }

  Future<void> _clearSyncData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Export History'),
        content: const Text(
          'This removes the saved calendar export history on this device. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('calendar_export_history');
      setState(() {
        _exportHistory = [];
        _syncStats = {'totalExported': 0, 'lastExport': null};
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Calendar export history cleared')),
      );
    }
  }

  void _showSyncHistory() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Calendar Export History'),
        content: SizedBox(
          width: 360,
          height: 320,
          child: _exportHistory.isEmpty
              ? const Center(child: Text('No calendar exports yet'))
              : ListView.builder(
                  itemCount: _exportHistory.length,
                  itemBuilder: (context, index) {
                    final parts = _exportHistory[index].split('|');
                    final date = parts.isNotEmpty
                        ? DateTime.tryParse(parts.first)
                        : null;
                    final count = parts.length > 1 ? parts.last : '0';
                    return ListTile(
                      leading: const Icon(Icons.event_available),
                      title: Text('$count event(s) exported'),
                      subtitle:
                          Text(date?.toLocal().toString() ?? 'Unknown date'),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

// Third-party Apps Dialog
class _ThirdPartyAppsDialog extends StatefulWidget {
  @override
  State<_ThirdPartyAppsDialog> createState() => _ThirdPartyAppsDialogState();
}

class _ThirdPartyAppsDialogState extends State<_ThirdPartyAppsDialog>
    with TickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<Map<String, dynamic>> _connectedApps = [];
  List<Map<String, dynamic>> _availableApps = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadThirdPartyApps();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadThirdPartyApps() async {
    setState(() => _isLoading = true);

    try {
      // Simulate loading third-party app data
      await Future.delayed(const Duration(seconds: 1));

      if (mounted) {
        setState(() {
          // Mock connected apps
          _connectedApps = [
            {
              'name': 'Google Calendar',
              'icon': Icons.calendar_today,
              'color': Colors.blue,
              'status': 'Connected',
              'lastSync': DateTime.now().subtract(const Duration(hours: 1)),
              'permissions': ['Read calendar', 'Write events'],
              'description': 'Sync tasks with Google Calendar',
            },
            {
              'name': 'Spotify',
              'icon': Icons.music_note,
              'color': Colors.green,
              'status': 'Connected',
              'lastSync': DateTime.now().subtract(const Duration(minutes: 30)),
              'permissions': ['Read playlists', 'Control playback'],
              'description': 'Background music integration',
            },
          ];

          // Mock available apps
          _availableApps = [
            {
              'name': 'Todoist',
              'icon': Icons.task_alt,
              'color': Colors.red,
              'status': 'Available',
              'description': 'Import tasks from Todoist',
              'features': ['Task import', 'Project sync', 'Label mapping'],
            },
            {
              'name': 'Notion',
              'icon': Icons.note,
              'color': Colors.black,
              'status': 'Available',
              'description': 'Export notes to Notion',
              'features': ['Note export', 'Database sync', 'Template sharing'],
            },
            {
              'name': 'Slack',
              'icon': Icons.chat,
              'color': Colors.purple,
              'status': 'Available',
              'description': 'Focus status integration',
              'features': ['Status updates', 'Do not disturb', 'Notifications'],
            },
            {
              'name': 'GitHub',
              'icon': Icons.code,
              'color': Colors.grey,
              'status': 'Available',
              'description': 'Track coding sessions',
              'features': [
                'Commit tracking',
                'Issue integration',
                'Time logging'
              ],
            },
            {
              'name': 'Trello',
              'icon': Icons.dashboard,
              'color': Colors.blue,
              'status': 'Available',
              'description': 'Board and card synchronization',
              'features': ['Board sync', 'Card import', 'Due date mapping'],
            },
            {
              'name': 'Apple Health',
              'icon': Icons.favorite,
              'color': Colors.red,
              'status': 'Available',
              'description': 'Wellness and productivity tracking',
              'features': [
                'Activity tracking',
                'Mindfulness data',
                'Sleep integration'
              ],
            },
          ];

          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    return AlertDialog(
      title: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.apps,
              color: theme.colorScheme.onPrimary,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Third-party Apps',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: isTablet ? 600 : double.maxFinite,
        height: 500,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  TabBar(
                    controller: _tabController,
                    tabs: const [
                      Tab(text: 'Connected', icon: Icon(Icons.link)),
                      Tab(text: 'Available', icon: Icon(Icons.add_link)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildConnectedAppsTab(theme),
                        _buildAvailableAppsTab(theme),
                      ],
                    ),
                  ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildConnectedAppsTab(ThemeData theme) {
    if (_connectedApps.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.link_off,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No Connected Apps',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Connect third-party apps to enhance your productivity',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Connected Apps (${_connectedApps.length})',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          ..._connectedApps.map((app) => _buildConnectedAppCard(app, theme)),
        ],
      ),
    );
  }

  Widget _buildConnectedAppCard(Map<String, dynamic> app, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: (app['color'] as Color).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    app['icon'] as IconData,
                    color: app['color'] as Color,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        app['name'],
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        app['description'],
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.green.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      app['status'],
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.green,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Last sync: ${_formatLastSync(app['lastSync'])}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => _showAppDetails(app),
                        child: const Text('Manage'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _disconnectApp(app),
                        child: const Text('Disconnect'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvailableAppsTab(ThemeData theme) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Available Integrations',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Connect these apps to enhance your FocusBro experience',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          ..._availableApps.map((app) => _buildAvailableAppCard(app, theme)),
        ],
      ),
    );
  }

  Widget _buildAvailableAppCard(Map<String, dynamic> app, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: (app['color'] as Color).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    app['icon'] as IconData,
                    color: app['color'] as Color,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        app['name'],
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        app['description'],
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: FilledButton(
                    onPressed: () => _connectApp(app),
                    child: const Text('Connect'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: (app['features'] as List<String>).map((feature) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer
                        .withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    feature,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  String _formatLastSync(DateTime? lastSync) {
    if (lastSync == null) return 'Never';

    final now = DateTime.now();
    final difference = now.difference(lastSync);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  void _showAppDetails(Map<String, dynamic> app) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: (app['color'] as Color).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                app['icon'] as IconData,
                color: app['color'] as Color,
                size: 16,
              ),
            ),
            const SizedBox(width: 8),
            Text(app['name']),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Description: ${app['description']}'),
            const SizedBox(height: 8),
            Text('Status: ${app['status']}'),
            const SizedBox(height: 8),
            Text('Last sync: ${_formatLastSync(app['lastSync'])}'),
            const SizedBox(height: 12),
            const Text('Permissions:'),
            ...(app['permissions'] as List<String>).map((permission) {
              return Padding(
                padding: const EdgeInsets.only(left: 16, top: 4),
                child: Text('• $permission'),
              );
            }),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          OutlinedButton(
            onPressed: () {
              Navigator.pop(context);
              _disconnectApp(app);
            },
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );
  }

  Future<void> _connectApp(Map<String, dynamic> app) async {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Connecting...'),
          ],
        ),
      ),
    );

    // Simulate connection process
    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      Navigator.pop(context); // Close loading dialog

      // Add to connected apps
      setState(() {
        _connectedApps.add({
          ...app,
          'status': 'Connected',
          'lastSync': DateTime.now(),
          'permissions': ['Read data', 'Write data'],
        });
        _availableApps.remove(app);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${app['name']} connected successfully'),
          backgroundColor: Colors.green,
        ),
      );

      // Switch to connected tab
      _tabController.animateTo(0);
    }
  }

  Future<void> _disconnectApp(Map<String, dynamic> app) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Disconnect ${app['name']}'),
        content: Text(
          'Are you sure you want to disconnect ${app['name']}? This will remove all synced data and permissions.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() {
        _connectedApps.remove(app);
        _availableApps.add({
          ...app,
          'status': 'Available',
        });
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${app['name']} disconnected'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }
}

class _CreateThemeDialog extends StatefulWidget {
  final ThemeProvider themeProvider;

  const _CreateThemeDialog({required this.themeProvider});

  @override
  State<_CreateThemeDialog> createState() => _CreateThemeDialogState();
}

class _CreateThemeDialogState extends State<_CreateThemeDialog> {
  final _nameController = TextEditingController();
  Color _primaryColor = Colors.blue;
  Color _secondaryColor = Colors.blueAccent;
  Brightness _brightness = Brightness.light;
  bool _isCreating = false;
  String? _errorText;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    return AlertDialog(
      title: Text(
        'Create Custom Theme',
        style: theme.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
      content: SizedBox(
        width: isTablet ? 500 : double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Theme Name
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Theme Name',
                errorText: _errorText,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.palette),
              ),
              onChanged: (value) {
                setState(() {
                  _errorText =
                      value.trim().isEmpty ? 'Theme name is required' : null;
                });
              },
            ),

            const SizedBox(height: 24),

            // Brightness Selection
            Text(
              'Brightness',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            SegmentedButton<Brightness>(
              segments: const [
                ButtonSegment(
                  value: Brightness.light,
                  label: Text('Light'),
                  icon: Icon(Icons.light_mode),
                ),
                ButtonSegment(
                  value: Brightness.dark,
                  label: Text('Dark'),
                  icon: Icon(Icons.dark_mode),
                ),
              ],
              selected: {_brightness},
              onSelectionChanged: (Set<Brightness> selection) {
                setState(() {
                  _brightness = selection.first;
                });
              },
            ),

            const SizedBox(height: 24),

            // Color Selection
            Text(
              'Colors',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),

            // Primary Color
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Primary Color',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                GestureDetector(
                  onTap: () => _showColorPicker('primary'),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _primaryColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: theme.colorScheme.outline.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Secondary Color
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Secondary Color',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                GestureDetector(
                  onTap: () => _showColorPicker('secondary'),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _secondaryColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: theme.colorScheme.outline.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Preview
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Preview',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      height: 60,
                      decoration: BoxDecoration(
                        color: _brightness == Brightness.light
                            ? Colors.white
                            : Colors.grey[900],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color:
                              theme.colorScheme.outline.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: _primaryColor,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(8),
                                bottomLeft: Radius.circular(8),
                              ),
                            ),
                            child: Icon(
                              Icons.palette,
                              color: _brightness == Brightness.light
                                  ? Colors.white
                                  : Colors.black,
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    _nameController.text.isEmpty
                                        ? 'Theme Name'
                                        : _nameController.text,
                                    style: TextStyle(
                                      color: _brightness == Brightness.light
                                          ? Colors.black
                                          : Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    'Custom Theme',
                                    style: TextStyle(
                                      color: _secondaryColor,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            if (_isCreating) ...[
              const SizedBox(height: 16),
              const LinearProgressIndicator(),
              const SizedBox(height: 8),
              Text(
                'Creating theme...',
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isCreating ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isCreating || _nameController.text.trim().isEmpty
              ? null
              : _createTheme,
          child: _isCreating
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create'),
        ),
      ],
    );
  }

  void _showColorPicker(String colorType) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
            'Select ${colorType == 'primary' ? 'Primary' : 'Secondary'} Color'),
        content: SizedBox(
          width: 300,
          height: 300,
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 6,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: _predefinedColors.length,
            itemBuilder: (context, index) {
              final color = _predefinedColors[index];
              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (colorType == 'primary') {
                      _primaryColor = color;
                    } else {
                      _secondaryColor = color;
                    }
                  });
                  Navigator.pop(context);
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.grey.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _createTheme() async {
    setState(() {
      _isCreating = true;
    });

    try {
      // Simulate theme creation process
      await Future.delayed(const Duration(seconds: 1));

      // In a real implementation, you would:
      // - Create a CustomTheme object
      // - Save it to the theme provider
      // - Persist it to storage

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Theme "${_nameController.text}" created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCreating = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create theme: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  static const List<Color> _predefinedColors = [
    Colors.red,
    Colors.pink,
    Colors.purple,
    Colors.deepPurple,
    Colors.indigo,
    Colors.blue,
    Colors.lightBlue,
    Colors.cyan,
    Colors.teal,
    Colors.green,
    Colors.lightGreen,
    Colors.lime,
    Colors.yellow,
    Colors.amber,
    Colors.orange,
    Colors.deepOrange,
    Colors.brown,
    Colors.grey,
    Colors.blueGrey,
    Colors.black,
  ];
}

class _BackupOptionsDialog extends StatefulWidget {
  @override
  State<_BackupOptionsDialog> createState() => _BackupOptionsDialogState();
}

class _BackupOptionsDialogState extends State<_BackupOptionsDialog> {
  bool _isBackingUp = false;
  bool _isRestoring = false;
  String? _lastBackupDate;

  @override
  void initState() {
    super.initState();
    _loadLastBackupDate();
  }

  void _loadLastBackupDate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _lastBackupDate = prefs.getString('last_backup_date');
      });
    } catch (e) {
      debugPrint('Error loading last backup date: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    return AlertDialog(
      title: Text(
        'Backup & Restore',
        style: theme.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
      content: SizedBox(
        width: isTablet ? 500 : double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Backup Status
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.backup,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Backup Status',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_lastBackupDate != null) ...[
                      Text(
                        'Last backup: $_lastBackupDate',
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Your data is backed up and ready for restore.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.green,
                        ),
                      ),
                    ] else ...[
                      Text(
                        'No backup found',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Create your first backup to protect your data.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Backup Actions
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.save,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Backup Actions',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Create Backup Button
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed:
                            _isBackingUp || _isRestoring ? null : _createBackup,
                        icon: _isBackingUp
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.backup),
                        label: Text(_isBackingUp
                            ? 'Creating Backup...'
                            : 'Create Backup'),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Restore Backup Button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _isBackingUp ||
                                _isRestoring ||
                                _lastBackupDate == null
                            ? null
                            : _restoreBackup,
                        icon: _isRestoring
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.restore),
                        label: Text(
                            _isRestoring ? 'Restoring...' : 'Restore Backup'),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Backup Info
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'What gets backed up:',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '• Focus session data and statistics\n'
                            '• Tasks and agenda items\n'
                            '• Notes and documents\n'
                            '• App settings and preferences\n'
                            '• Custom themes and configurations',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isBackingUp || _isRestoring
              ? null
              : () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }

  void _createBackup() async {
    setState(() {
      _isBackingUp = true;
    });

    try {
      // Create backup using BackupService
      final result = await BackupService.instance.createBackup();

      setState(() {
        _isBackingUp = false;
      });

      if (result.success) {
        final now = DateTime.now();
        final backupDate =
            '${now.day}/${now.month}/${now.year} ${now.hour}:${now.minute.toString().padLeft(2, '0')}';

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('last_backup_date', backupDate);

        setState(() {
          _lastBackupDate = backupDate;
        });

        if (mounted) {
          final sizeInMB =
              (result.fileSize! / (1024 * 1024)).toStringAsFixed(2);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Backup created successfully!\nSize: ${sizeInMB}MB, Items: ${result.itemCount}'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Backup failed: ${result.error}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isBackingUp = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create backup: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _restoreBackup() async {
    // Show confirmation dialog first
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore Backup'),
        content: const Text(
            'This will replace all current data with the backup data. '
            'Are you sure you want to continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isRestoring = true;
    });

    try {
      // Restore backup using BackupService
      final result = await BackupService.instance.restoreFromBackup();

      setState(() {
        _isRestoring = false;
      });

      if (result.success) {
        if (mounted) {
          Navigator.pop(context); // Close dialog
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Backup restored successfully!\nItems restored: ${result.itemCount}\nPlease restart the app.'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Restore failed: ${result.error}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isRestoring = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to restore backup: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
