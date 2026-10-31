import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/focus_provider.dart';
import '../providers/preset_provider.dart';
import '../models/timer_preset.dart';
import '../widgets/preset_form_dialog.dart';
import '../widgets/session_completion_dialog.dart';
import '../widgets/music_player_widget.dart';
import '../widgets/music_library_dialog.dart';
import '../widgets/create_playlist_dialog.dart';
import '../utils/accessibility_helper.dart';
import '../services/voice_command_service.dart';
import '../services/music_service.dart';
import '../widgets/help_tip_widget.dart';
import '../services/onboarding_service.dart';
import '../l10n/app_localizations.dart';
import 'enhanced_analytics_screen.dart';

/// Enhanced Focus Screen with advanced features
class EnhancedFocusScreen extends StatefulWidget {
  const EnhancedFocusScreen({super.key});

  @override
  State<EnhancedFocusScreen> createState() => _EnhancedFocusScreenState();
}

class _EnhancedFocusScreenState extends State<EnhancedFocusScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _progressController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _progressAnimation;
  final VoiceCommandService _voiceService = VoiceCommandService();

  // Dialog state management
  bool _isCompletionDialogShowing = false;
  bool _hasShownCompletionForCurrentCycle = false;

  // Music player state
  bool _isMusicPlayerExpanded = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();

    // Listen for session completion
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupSessionCompletionListener();
      _setupVoiceCommands();
    });
  }

  void _setupVoiceCommands() {
    final provider = Provider.of<FocusProvider>(context, listen: false);

    // Initialize voice service
    _voiceService.initialize();

    // Set up voice command callbacks
    _voiceService.setCallbacks(
      onStartTimer: () {
        if (!provider.isRunning) {
          provider.toggleTimer();
        }
      },
      onPauseTimer: () {
        if (provider.isRunning) {
          provider.toggleTimer();
        }
      },
      onResetTimer: () => provider.resetTimer(),
      onSkipSession: () => provider.skipSession(),
      onSetWorkDuration: (duration) => provider.setWorkDuration(duration),
      onSetBreakDuration: (duration) => provider.setBreakDuration(duration),
      onShowStats: () {
        // Navigate to stats tab
        DefaultTabController.of(context).animateTo(1);
      },
      onShowSettings: () {
        // Navigate to settings tab
        DefaultTabController.of(context).animateTo(2);
      },
    );
  }

  void _setupSessionCompletionListener() {
    final focusProvider = Provider.of<FocusProvider>(context, listen: false);
    focusProvider.addListener(_onFocusProviderChanged);
  }

  void _onFocusProviderChanged() {
    // Check if widget is still mounted before accessing context
    if (!mounted) return;

    final focusProvider = Provider.of<FocusProvider>(context, listen: false);

    // Check if all sessions are complete, timer is not running, and completion was just triggered
    if (focusProvider.isAllSessionsComplete &&
        !focusProvider.isRunning &&
        !_isCompletionDialogShowing &&
        !_hasShownCompletionForCurrentCycle) {
      _hasShownCompletionForCurrentCycle = true;

      // Show completion dialog after a short delay to allow audio to play
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && !_isCompletionDialogShowing) {
          _showSessionCompletionDialog(focusProvider);
        }
      });
    } else if (!focusProvider.isAllSessionsComplete) {
      // Reset the flag when sessions are not complete (new cycle started)
      _hasShownCompletionForCurrentCycle = false;
    }
  }

  void _showSessionCompletionDialog(FocusProvider provider) {
    // Set dialog showing flag
    _isCompletionDialogShowing = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => SessionCompletionDialog(
        completedSessions: provider.completedSessions,
        totalSessions: provider.totalSessions,
        totalFocusTime: provider.completedSessions * provider.workDuration,
        onClose: () {
          // Reset timer when dialog is closed
          provider.resetTimer();
          // Reset dialog state flags
          _isCompletionDialogShowing = false;
          _hasShownCompletionForCurrentCycle = false;
        },
      ),
    ).then((_) {
      // Ensure flags are reset even if dialog is dismissed in other ways
      _isCompletionDialogShowing = false;
      _hasShownCompletionForCurrentCycle = false;
    });
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _progressController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeInOut,
    ));

    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    // Remove listener to prevent memory leaks
    try {
      final focusProvider = Provider.of<FocusProvider>(context, listen: false);
      focusProvider.removeListener(_onFocusProviderChanged);
    } catch (e) {
      // Provider might not be available during disposal in tests
      debugPrint(
          'Warning: Could not remove FocusProvider listener during disposal: $e');
    }

    _pulseController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Consumer<FocusProvider>(
      builder: (context, focusProvider, child) {
        return Scaffold(
          body: SafeArea(
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height -
                      MediaQuery.of(context).padding.top -
                      MediaQuery.of(context).padding.bottom -
                      kToolbarHeight,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      // Enhanced Header with Quick Actions
                      _buildEnhancedHeader(context, focusProvider),

                      // Main Timer Display with Animations
                      Expanded(
                        child: HelpTipWidget(
                          tipId: 'focus_timer_start',
                          title: l10n?.onboardingFocusTitle ?? 'Focus Timer',
                          description: l10n?.onboardingFocusDescription ??
                              'Use the Pomodoro technique to boost your productivity with customizable work and break sessions.',
                          child: _buildAnimatedTimerDisplay(
                              context, focusProvider),
                        ),
                      ),

                      // Session Information Panel
                      _buildSessionInfoPanel(context, focusProvider),

                      // Music Player Widget
                      ChangeNotifierProvider.value(
                        value: focusProvider.musicService,
                        child: MusicPlayerWidget(
                          isExpanded: _isMusicPlayerExpanded,
                          onToggleExpanded: () {
                            setState(() {
                              _isMusicPlayerExpanded = !_isMusicPlayerExpanded;
                            });
                          },
                        ),
                      ),

                      // Enhanced Control Panel
                      _buildEnhancedControlPanel(context, focusProvider),

                      // Quick Settings Bar
                      _buildQuickSettingsBar(context, focusProvider),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEnhancedHeader(BuildContext context, FocusProvider provider) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Current Session Type Indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: provider.isWorkTime
                  ? Colors.red.withOpacity(0.1)
                  : Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: provider.isWorkTime ? Colors.red : Colors.green,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  provider.isWorkTime ? Icons.work : Icons.coffee,
                  size: 16,
                  color: provider.isWorkTime ? Colors.red : Colors.green,
                ),
                const SizedBox(width: 4),
                Text(
                  provider.isWorkTime ? 'FOCUS' : 'BREAK',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: provider.isWorkTime ? Colors.red : Colors.green,
                  ),
                ),
              ],
            ),
          ),

          const Spacer(),

          // Quick Action Buttons
          Row(
            children: [
              // Voice Command Toggle
              HelpTipWidget(
                tipId: 'focus_voice_commands',
                title: 'Voice Commands',
                description:
                    'Enable voice commands to control your timer hands-free. Say "start timer" or "pause timer" to control your session.',
                child: IconButton(
                  onPressed: () => _toggleVoiceCommands(provider),
                  icon: Icon(
                    provider.isVoiceEnabled ? Icons.mic : Icons.mic_off,
                    color: provider.isVoiceEnabled
                        ? theme.colorScheme.primary
                        : Colors.grey,
                  ),
                  tooltip: 'Voice Commands',
                ),
              ),

              // Focus Mode Toggle
              IconButton(
                onPressed: () => _toggleFocusMode(provider),
                icon: Icon(
                  provider.isFocusModeEnabled
                      ? Icons.do_not_disturb_on
                      : Icons.do_not_disturb_off,
                  color: provider.isFocusModeEnabled
                      ? theme.colorScheme.primary
                      : Colors.grey,
                ),
                tooltip: 'Toggle Focus Mode',
              ),

              // Focus Mode Settings
              IconButton(
                onPressed: _showFocusModeSettings,
                icon: Icon(
                  Icons.psychology_alt,
                  color: theme.colorScheme.primary,
                ),
                tooltip: 'Focus Mode Settings',
              ),

              // Settings
              IconButton(
                onPressed: () => _openQuickSettings(context),
                icon: const Icon(Icons.tune),
                tooltip: 'Quick Settings',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedTimerDisplay(
      BuildContext context, FocusProvider provider) {
    final theme = Theme.of(context);
    final progress = provider.progress;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Animated Circular Progress
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              final screenHeight = MediaQuery.of(context).size.height;
              final availableHeight =
                  screenHeight * 0.35; // Use 35% of screen height
              final size = MediaQuery.of(context).size.width * 0.65;
              final timerSize =
                  size.clamp(180.0, availableHeight.clamp(180.0, 250.0));

              return Transform.scale(
                scale: provider.isRunning ? _pulseAnimation.value : 1.0,
                child: Container(
                  width: timerSize,
                  height: timerSize,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Background Circle
                      Container(
                        width: timerSize,
                        height: timerSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: theme.colorScheme.surface,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                      ),

                      // Progress Circle
                      SizedBox(
                        width: timerSize - 20,
                        height: timerSize - 20,
                        child: CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 8,
                          backgroundColor: Colors.grey.withOpacity(0.2),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            provider.isWorkTime ? Colors.red : Colors.green,
                          ),
                        ),
                      ),

                      // Timer Text
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            provider.formattedTime,
                            style: TextStyle(
                              fontSize: (timerSize * 0.18).clamp(32.0, 48.0),
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${(progress * 100).toInt()}% Complete',
                            style: TextStyle(
                              fontSize: 16,
                              color:
                                  theme.colorScheme.onSurface.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 8),

          // Session Progress Indicator
          _buildSessionProgressIndicator(context, provider),
        ],
      ),
    );
  }

  Widget _buildSessionProgressIndicator(
      BuildContext context, FocusProvider provider) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Session Dots
          ...List.generate(provider.totalSessions, (index) {
            final isCompleted = index < provider.completedSessions;
            final isCurrent = index == provider.completedSessions;

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCompleted
                    ? Colors.green
                    : isCurrent
                        ? theme.colorScheme.primary
                        : Colors.grey.withOpacity(0.3),
                border: isCurrent
                    ? Border.all(color: theme.colorScheme.primary, width: 2)
                    : null,
              ),
            );
          }),

          const SizedBox(width: 12),

          Text(
            'Session ${provider.completedSessions + 1}/${provider.totalSessions}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionInfoPanel(BuildContext context, FocusProvider provider) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          // Today's Stats
          Expanded(
            child: _buildStatItem(
              context,
              'Today',
              '${provider.todaysSessions}',
              'sessions',
              Icons.today,
            ),
          ),

          Container(
            width: 1,
            height: 40,
            color: theme.colorScheme.outline.withOpacity(0.2),
          ),

          // Current Streak
          Expanded(
            child: _buildStatItem(
              context,
              'Streak',
              '${provider.currentStreak}',
              'days',
              Icons.local_fire_department,
            ),
          ),

          Container(
            width: 1,
            height: 40,
            color: theme.colorScheme.outline.withOpacity(0.2),
          ),

          // Total Focus Time
          Expanded(
            child: _buildStatItem(
              context,
              'Focus',
              '${provider.totalFocusHours}h',
              'total',
              Icons.timer,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    String label,
    String value,
    String unit,
    IconData icon,
  ) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Icon(
          icon,
          size: 20,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        Text(
          unit,
          style: TextStyle(
            fontSize: 12,
            color: theme.colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: theme.colorScheme.onSurface.withOpacity(0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildEnhancedControlPanel(
      BuildContext context, FocusProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Skip Button
          _buildControlButton(
            context,
            icon: Icons.skip_next,
            label: 'Skip',
            onPressed: provider.canSkip ? () => provider.skipSession() : null,
            color: Colors.orange,
          ),

          // Main Play/Pause Button
          _buildMainControlButton(context, provider),

          // Reset Button
          _buildControlButton(
            context,
            icon: Icons.refresh,
            label: 'Reset',
            onPressed: () => provider.resetTimer(),
            color: Colors.grey,
          ),
        ],
      ),
    );
  }

  Widget _buildMainControlButton(BuildContext context, FocusProvider provider) {
    final theme = Theme.of(context);

    return AccessibilityHelper.accessibleButton(
      semanticLabel: provider.isRunning ? 'Pause timer' : 'Start timer',
      semanticHint:
          'Double tap to ${provider.isRunning ? 'pause' : 'start'} the focus timer',
      onPressed: () => provider.toggleTimer(),
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: theme.colorScheme.primary,
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.primary.withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Icon(
          provider.isRunning ? Icons.pause : Icons.play_arrow,
          size: 36,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildControlButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withOpacity(0.1),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: IconButton(
            onPressed: onPressed,
            icon: Icon(icon, color: color),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickSettingsBar(BuildContext context, FocusProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Timer Presets
          Expanded(
            child: _buildQuickSettingChip(
              context,
              'Presets',
              Icons.bookmark,
              () => _showTimerPresets(context),
            ),
          ),

          const SizedBox(width: 8),

          // Music Library
          Expanded(
            child: _buildQuickSettingChip(
              context,
              'Music',
              provider.isMusicEnabled ? Icons.library_music : Icons.music_off,
              () => _showMusicLibrary(context),
            ),
          ),

          const SizedBox(width: 8),

          // Sound Settings
          Expanded(
            child: _buildQuickSettingChip(
              context,
              'Sounds',
              Icons.tune,
              () => _showSoundSettings(context),
            ),
          ),

          const SizedBox(width: 8),

          // Analytics
          Expanded(
            child: _buildQuickSettingChip(
              context,
              'Stats',
              Icons.analytics,
              () => _showQuickStats(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickSettingChip(
    BuildContext context,
    String label,
    IconData icon,
    VoidCallback onTap,
  ) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.outline.withOpacity(0.2),
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: theme.colorScheme.primary),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper methods for actions
  void _toggleVoiceCommands(FocusProvider provider) {
    provider.toggleVoiceCommands();

    // Start or stop voice listening based on the new state
    if (provider.isVoiceEnabled) {
      _voiceService.startListening();
    } else {
      _voiceService.stopListening();
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          provider.isVoiceEnabled
              ? 'Voice commands enabled - Say "start timer" to begin'
              : 'Voice commands disabled',
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _toggleFocusMode(FocusProvider provider) {
    provider.toggleFocusMode();

    // Apply focus mode settings
    if (provider.isFocusModeEnabled) {
      _enableFocusMode();
    } else {
      _disableFocusMode();
    }

    final focusModeService = provider.focusModeService;
    final activeFeatures = focusModeService.getActiveFeatures();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              provider.isFocusModeEnabled
                  ? 'Focus mode enabled'
                  : 'Focus mode disabled',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (provider.isFocusModeEnabled && activeFeatures.isNotEmpty)
              Text(
                'Active: ${activeFeatures.join(', ')}',
                style: const TextStyle(fontSize: 12),
              )
            else if (provider.isFocusModeEnabled)
              const Text(
                'No features enabled - Configure in settings',
                style: TextStyle(fontSize: 12),
              ),
          ],
        ),
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'Settings',
          onPressed: () => _showFocusModeSettings(),
        ),
      ),
    );
  }

  void _enableFocusMode() {
    // Focus mode is now handled by the FocusProvider and FocusModeService
    // This method is called automatically when focus mode is toggled
  }

  void _disableFocusMode() {
    // Focus mode is now handled by the FocusProvider and FocusModeService
    // This method is called automatically when focus mode is toggled
  }

  void _testVoiceCommand(String command) {
    final provider = Provider.of<FocusProvider>(context, listen: false);

    // Simulate voice command execution
    if (command.contains('Start timer') || command.contains('Begin focus')) {
      if (!provider.isRunning) {
        provider.toggleTimer();
        _voiceService.speakTimerStatus(
          timeLeft: provider.timeLeft,
          isWorkTime: provider.isWorkTime,
          isRunning: provider.isRunning,
        );
      }
    } else if (command.contains('Pause timer') ||
        command.contains('Stop focus')) {
      if (provider.isRunning) {
        provider.toggleTimer();
        _voiceService.speakTimerStatus(
          timeLeft: provider.timeLeft,
          isWorkTime: provider.isWorkTime,
          isRunning: provider.isRunning,
        );
      }
    } else if (command.contains('Reset timer') ||
        command.contains('Restart focus')) {
      provider.resetTimer();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Timer reset')),
      );
    } else if (command.contains('Skip session') ||
        command.contains('Next session')) {
      provider.skipSession();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session skipped')),
      );
    } else if (command.contains('Show stats') ||
        command.contains('Show analytics')) {
      // Navigate to stats tab
      DefaultTabController.of(context).animateTo(1);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Showing statistics')),
      );
    } else if (command.contains('Show settings') ||
        command.contains('Open settings')) {
      // Navigate to settings tab
      DefaultTabController.of(context).animateTo(2);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Opening settings')),
      );
    } else if (command.contains('Set work') || command.contains('Set break')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Voice command recognized')),
      );
    }
  }

  void _showVoiceCommandsSettings() {
    showDialog(
      context: context,
      builder: (context) => Consumer<FocusProvider>(
        builder: (context, provider, child) {
          final voiceService = _voiceService;
          final theme = Theme.of(context);

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
                    Icons.mic,
                    color: theme.colorScheme.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Voice Commands',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: provider.isVoiceEnabled
                          ? Colors.green.withValues(alpha: 0.1)
                          : theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: provider.isVoiceEnabled
                            ? Colors.green.withValues(alpha: 0.3)
                            : theme.colorScheme.outline.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          provider.isVoiceEnabled ? Icons.mic : Icons.mic_off,
                          color: provider.isVoiceEnabled
                              ? Colors.green
                              : theme.colorScheme.onSurface
                                  .withValues(alpha: 0.6),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                provider.isVoiceEnabled
                                    ? 'Voice Commands Enabled'
                                    : 'Voice Commands Disabled',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: provider.isVoiceEnabled
                                      ? Colors.green
                                      : null,
                                ),
                              ),
                              Text(
                                provider.isVoiceEnabled
                                    ? 'Voice feedback and commands are active'
                                    : 'Enable to use voice control features',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Supported Commands
                  Text(
                    'Supported Commands',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  ...voiceService.supportedCommands
                      .map((command) => Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: theme.colorScheme.outline
                                    .withValues(alpha: 0.2),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.keyboard_voice,
                                  color: theme.colorScheme.primary,
                                  size: 16,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    command,
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                ),
                                IconButton(
                                  onPressed: provider.isVoiceEnabled
                                      ? () => _testVoiceCommand(command)
                                      : null,
                                  icon: const Icon(Icons.play_arrow, size: 16),
                                  tooltip: 'Test Command',
                                  style: IconButton.styleFrom(
                                    minimumSize: const Size(32, 32),
                                    padding: const EdgeInsets.all(4),
                                  ),
                                ),
                              ],
                            ),
                          ))
                      .toList(),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
              ElevatedButton(
                onPressed: () {
                  provider.toggleVoiceCommands();
                  Navigator.pop(context);
                },
                child: Text(
                  provider.isVoiceEnabled ? 'Disable Voice' : 'Enable Voice',
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showFocusModeSettings() {
    showDialog(
      context: context,
      builder: (context) => Consumer<FocusProvider>(
        builder: (context, provider, child) {
          final focusModeService = provider.focusModeService;
          final theme = Theme.of(context);

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
                    Icons.psychology_alt,
                    color: theme.colorScheme.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Focus Mode Settings',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Consumer<FocusProvider>(
                builder: (context, focusProvider, child) {
                  final focusModeService = focusProvider.focusModeService;
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status Card with real-time updates
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: focusModeService.isFocusModeActive
                              ? Colors.green.withValues(alpha: 0.1)
                              : theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: focusModeService.isFocusModeActive
                                ? Colors.green.withValues(alpha: 0.3)
                                : theme.colorScheme.outline
                                    .withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              focusModeService.isFocusModeActive
                                  ? Icons.check_circle
                                  : Icons.info_outline,
                              color: focusModeService.isFocusModeActive
                                  ? Colors.green
                                  : theme.colorScheme.onSurface
                                      .withValues(alpha: 0.6),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    focusModeService.isFocusModeActive
                                        ? 'Focus Mode Active'
                                        : 'Focus Mode Inactive',
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: focusModeService.isFocusModeActive
                                          ? Colors.green
                                          : null,
                                    ),
                                  ),
                                  Text(
                                    focusModeService.getFocusModeSummary(),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.7),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Features Section
                      Text(
                        'Focus Features',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),

                      _buildFocusFeatureTile(
                        icon: Icons.notifications_off,
                        title: 'Block Notifications',
                        subtitle: 'Silence non-essential notifications',
                        value: focusModeService.enableNotificationBlocking,
                        onChanged: (value) {
                          focusModeService
                              .setNotificationBlockingEnabled(value ?? false);
                        },
                        theme: theme,
                      ),

                      _buildFocusFeatureTile(
                        icon: Icons.block,
                        title: 'Block Social Media',
                        subtitle: 'Restrict access to social apps and websites',
                        value: focusModeService.enableSocialMediaBlocking,
                        onChanged: (value) {
                          focusModeService
                              .setSocialMediaBlockingEnabled(value ?? false);
                        },
                        theme: theme,
                      ),

                      _buildFocusFeatureTile(
                        icon: Icons.brightness_low,
                        title: 'Dim Screen',
                        subtitle: 'Reduce screen brightness to 20%',
                        value: focusModeService.enableScreenDimming,
                        onChanged: (value) {
                          focusModeService
                              .setScreenDimmingEnabled(value ?? false);
                        },
                        theme: theme,
                      ),

                      const SizedBox(height: 20),

                      // Auto-enable Section
                      Text(
                        'Automation',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),

                      _buildFocusFeatureTile(
                        icon: Icons.auto_mode,
                        title: 'Auto-enable on Focus Start',
                        subtitle:
                            'Automatically enable when starting focus sessions',
                        value: focusModeService.autoEnableOnFocusStart,
                        onChanged: (value) {
                          focusModeService
                              .setAutoEnableOnFocusStart(value ?? false);
                        },
                        theme: theme,
                      ),
                    ],
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
              Consumer<FocusProvider>(
                builder: (context, focusProvider, child) {
                  final focusModeService = focusProvider.focusModeService;
                  if (focusModeService.isFocusModeActive)
                    return ElevatedButton(
                      onPressed: () async {
                        // Disable focus mode through the service
                        await focusModeService.disableFocusMode();

                        // Sync FocusProvider state with the service state
                        focusProvider.setFocusModeState(false);

                        if (mounted) Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Disable Focus Mode'),
                    );
                  else
                    return ElevatedButton(
                      onPressed: () async {
                        // Enable focus mode through the service
                        await focusModeService.enableFocusMode();

                        // Sync FocusProvider state with the service state
                        focusProvider.setFocusModeState(true);

                        if (mounted) Navigator.pop(context);
                      },
                      child: const Text('Enable Focus Mode'),
                    );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFocusFeatureTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool?> onChanged,
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

  void _openQuickSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildQuickSettingsModal(context),
    );
  }

  void _showTimerPresets(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildTimerPresetsSheet(context),
    );
  }

  void _showMusicLibrary(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => ChangeNotifierProvider.value(
        value: Provider.of<FocusProvider>(context, listen: false).musicService,
        child: const MusicLibraryDialog(),
      ),
    );
  }

  void _showSoundSettings(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _buildSoundSettingsDialog(context),
    );
  }

  void _showQuickStats(BuildContext context) async {
    // Refresh statistics before showing dialog
    final focusProvider = Provider.of<FocusProvider>(context, listen: false);
    await focusProvider.refreshStatistics();

    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => _buildQuickStatsDialog(context),
      );
    }
  }

  Widget _buildQuickSettingsModal(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Text(
                  'Quick Settings',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),

          // Settings List
          Expanded(
            child: Consumer<FocusProvider>(
              builder: (context, provider, child) {
                return ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    _buildSettingsTile(
                      icon: Icons.music_note,
                      title: 'Background Music',
                      subtitle: 'Enable ambient sounds',
                      value: provider.isMusicEnabled,
                      onChanged: (value) => provider.toggleMusic(),
                    ),
                    _buildSettingsTile(
                      icon: Icons.mic,
                      title: 'Voice Commands',
                      subtitle: 'Control timer with voice',
                      value: provider.isVoiceEnabled,
                      onChanged: (value) => provider.toggleVoiceCommands(),
                      hasSettings: true,
                      onSettingsPressed: _showVoiceCommandsSettings,
                    ),
                    _buildSettingsTile(
                      icon: Icons.do_not_disturb,
                      title: 'Focus Mode',
                      subtitle: 'Block distracting notifications',
                      value: provider.isFocusModeEnabled,
                      onChanged: (value) => provider.toggleFocusMode(),
                      hasSettings: true,
                      onSettingsPressed: _showFocusModeSettings,
                    ),
                    const SizedBox(height: 20),

                    // Timer Duration Settings
                    Text(
                      'Timer Durations',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),

                    _buildDurationSetting(
                      'Work Duration',
                      provider.workDuration,
                      (value) => provider.setWorkDuration(value),
                    ),
                    _buildDurationSetting(
                      'Break Duration',
                      provider.breakDuration,
                      (value) => provider.setBreakDuration(value),
                    ),
                    _buildSessionCountSetting(
                      'Total Sessions',
                      provider.totalSessions,
                      (value) => provider.setTotalSessions(value),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool hasSettings = false,
    VoidCallback? onSettingsPressed,
  }) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: theme.colorScheme.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
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
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasSettings && onSettingsPressed != null) ...[
                IconButton(
                  onPressed: onSettingsPressed,
                  icon: const Icon(Icons.settings, size: 20),
                  tooltip: 'Settings',
                  style: IconButton.styleFrom(
                    minimumSize: const Size(32, 32),
                    padding: const EdgeInsets.all(4),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Switch(
                value: value,
                onChanged: onChanged,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDurationSetting(
    String title,
    int duration,
    ValueChanged<int> onChanged,
  ) {
    final theme = Theme.of(context);
    final minutes = duration ~/ 60;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),

          // Input Controls Row
          Row(
            children: [
              // Decrement Button
              IconButton(
                onPressed:
                    minutes > 1 ? () => onChanged((minutes - 1) * 60) : null,
                icon: const Icon(Icons.remove),
                iconSize: 20,
                style: IconButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                  foregroundColor: theme.colorScheme.primary,
                  minimumSize: const Size(40, 40),
                ),
              ),

              const SizedBox(width: 12),

              // Text Input Field
              Expanded(
                child: _buildDurationTextField(
                  minutes,
                  onChanged,
                  theme,
                ),
              ),

              const SizedBox(width: 12),

              // Increment Button
              IconButton(
                onPressed:
                    minutes < 60 ? () => onChanged((minutes + 1) * 60) : null,
                icon: const Icon(Icons.add),
                iconSize: 20,
                style: IconButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                  foregroundColor: theme.colorScheme.primary,
                  minimumSize: const Size(40, 40),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDurationTextField(
    int currentMinutes,
    ValueChanged<int> onChanged,
    ThemeData theme,
  ) {
    final controller = TextEditingController(text: currentMinutes.toString());

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          suffixText: 'min',
          suffixStyle: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.6),
          ),
          hintText: '1-60',
          hintStyle: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.4),
          ),
        ),
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(2),
        ],
        onChanged: (value) {
          if (value.isEmpty) return;

          final minutes = int.tryParse(value);
          if (minutes != null && minutes >= 1 && minutes <= 60) {
            onChanged(minutes * 60);
          }
        },
        onFieldSubmitted: (value) {
          _validateAndApplyDuration(value, onChanged, controller);
        },
        onTapOutside: (event) {
          _validateAndApplyDuration(controller.text, onChanged, controller);
        },
      ),
    );
  }

  void _validateAndApplyDuration(
    String value,
    ValueChanged<int> onChanged,
    TextEditingController controller,
  ) {
    if (value.isEmpty) {
      // Reset to minimum value if empty
      controller.text = '1';
      onChanged(60); // 1 minute
      _showDurationValidationFeedback('Duration set to minimum: 1 minute');
      return;
    }

    final minutes = int.tryParse(value);
    if (minutes == null) {
      // Invalid input - reset to current value
      final currentMinutes =
          controller.text.isEmpty ? 1 : int.tryParse(controller.text) ?? 1;
      controller.text = currentMinutes.toString();
      _showDurationValidationFeedback('Please enter a valid number');
      return;
    }

    if (minutes < 1) {
      // Below minimum - set to minimum
      controller.text = '1';
      onChanged(60);
      _showDurationValidationFeedback('Minimum duration is 1 minute');
    } else if (minutes > 60) {
      // Above maximum - set to maximum
      controller.text = '60';
      onChanged(3600);
      _showDurationValidationFeedback('Maximum duration is 60 minutes');
    } else {
      // Valid input
      onChanged(minutes * 60);
    }
  }

  void _showDurationValidationFeedback(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Widget _buildSessionCountSetting(
    String title,
    int sessionCount,
    ValueChanged<int> onChanged,
  ) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with title and current value
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.repeat,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
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
                        '$sessionCount',
                        key: ValueKey(sessionCount),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      sessionCount == 1 ? 'session' : 'sessions',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Animated Slider with custom styling
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
              tickMarkShape: const RoundSliderTickMarkShape(tickMarkRadius: 3),
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
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              child: Slider(
                value: sessionCount.toDouble(),
                min: 1.0,
                max: 20.0,
                divisions: 19,
                label:
                    '$sessionCount ${sessionCount == 1 ? 'session' : 'sessions'}',
                onChanged: (value) {
                  // Add haptic feedback for better user experience
                  HapticFeedback.selectionClick();
                  onChanged(value.round());
                },
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Session indicators with animation
          Row(
            children: [
              // Quick preset buttons
              Expanded(
                child: Row(
                  children: [
                    _buildQuickSessionButton(theme, 4, sessionCount, onChanged),
                    const SizedBox(width: 8),
                    _buildQuickSessionButton(theme, 6, sessionCount, onChanged),
                    const SizedBox(width: 8),
                    _buildQuickSessionButton(theme, 8, sessionCount, onChanged),
                    const SizedBox(width: 8),
                    _buildQuickSessionButton(
                        theme, 10, sessionCount, onChanged),
                  ],
                ),
              ),

              // Range indicator
              Text(
                '1-20 sessions',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickSessionButton(
    ThemeData theme,
    int sessions,
    int currentSessions,
    ValueChanged<int> onChanged,
  ) {
    final isSelected = currentSessions == sessions;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onChanged(sessions);
        },
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
            style: theme.textTheme.bodySmall?.copyWith(
              color: isSelected
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimerPresetsSheet(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => PresetProvider()..initialize(),
      child: Consumer<PresetProvider>(
        builder: (context, presetProvider, child) {
          final theme = Theme.of(context);

          return Container(
            height: MediaQuery.of(context).size.height * 0.8,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                // Handle
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Header with Add Button
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Timer Presets',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () =>
                            _showPresetFormDialog(context, presetProvider),
                        icon: const Icon(Icons.add),
                        style: IconButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: theme.colorScheme.onPrimary,
                        ),
                        tooltip: 'Add New Preset',
                      ),
                    ],
                  ),
                ),

                // Loading or Error State
                if (presetProvider.isLoading)
                  const Expanded(
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (presetProvider.error != null)
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 48,
                            color: theme.colorScheme.error,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            presetProvider.error!,
                            style: TextStyle(color: theme.colorScheme.error),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () => presetProvider.loadPresets(),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  // Presets List
                  Expanded(
                    child: _buildPresetsList(context, presetProvider),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPresetsList(
      BuildContext context, PresetProvider presetProvider) {
    final theme = Theme.of(context);
    final builtInPresets = presetProvider.builtInPresets;
    final customPresets = presetProvider.customPresets;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        // Built-in Presets Section
        if (builtInPresets.isNotEmpty) ...[
          Text(
            'Built-in Presets',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 12),
          ...builtInPresets.map((preset) => _buildPresetItem(
                context,
                preset,
                presetProvider,
                isBuiltIn: true,
              )),
          const SizedBox(height: 24),
        ],

        // Custom Presets Section
        Row(
          children: [
            Expanded(
              child: Text(
                'Custom Presets',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.secondary,
                ),
              ),
            ),
            if (customPresets.isEmpty)
              Text(
                'No custom presets yet',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),

        if (customPresets.isNotEmpty)
          ...customPresets.map((preset) => _buildPresetItem(
                context,
                preset,
                presetProvider,
                isBuiltIn: false,
              ))
        else
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.outline.withOpacity(0.2),
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.timer_outlined,
                  size: 48,
                  color: theme.colorScheme.onSurface.withOpacity(0.4),
                ),
                const SizedBox(height: 16),
                Text(
                  'Create Your First Custom Preset',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap the + button above to create a custom timer preset with your preferred work and break durations.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildPresetItem(
    BuildContext context,
    TimerPreset preset,
    PresetProvider presetProvider, {
    required bool isBuiltIn,
  }) {
    final theme = Theme.of(context);
    final isActive = presetProvider.activePreset?.id == preset.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isActive
                ? theme.colorScheme.primary
                : theme.colorScheme.outline.withOpacity(0.2),
            width: isActive ? 2 : 1,
          ),
        ),
        tileColor:
            isActive ? theme.colorScheme.primary.withOpacity(0.05) : null,
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isBuiltIn
                ? theme.colorScheme.primary.withOpacity(0.1)
                : theme.colorScheme.secondary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            isBuiltIn ? Icons.star : Icons.timer,
            color: isBuiltIn
                ? theme.colorScheme.primary
                : theme.colorScheme.secondary,
            size: 20,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                preset.name,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isActive ? theme.colorScheme.primary : null,
                ),
              ),
            ),
            if (isActive)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'ACTIVE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onPrimary,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Text(
          '${preset.workDuration ~/ 60}min work • ${preset.breakDuration ~/ 60}min break • ${preset.totalSessions} sessions',
        ),
        trailing: isBuiltIn
            ? const Icon(Icons.arrow_forward_ios, size: 16)
            : PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) => _handlePresetAction(
                  context,
                  value,
                  preset,
                  presetProvider,
                ),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit),
                        SizedBox(width: 8),
                        Text('Edit'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'duplicate',
                    child: Row(
                      children: [
                        Icon(Icons.copy),
                        SizedBox(width: 8),
                        Text('Duplicate'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Delete', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
        onTap: () => _applyPreset(context, preset, presetProvider),
      ),
    );
  }

  Widget _buildSoundSettingsDialog(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Sound Settings'),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.8,
        child: Consumer<FocusProvider>(
          builder: (context, provider, child) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Background Music
                ListTile(
                  leading: const Icon(Icons.music_note),
                  title: const Text('Background Music'),
                  subtitle: const Text('Ambient sounds for focus'),
                  trailing: Switch(
                    value: provider.isMusicEnabled,
                    onChanged: (value) => provider.toggleMusic(),
                  ),
                ),

                const Divider(),

                // Sound Effects
                ListTile(
                  leading: const Icon(Icons.celebration),
                  title: const Text('Sound Effects'),
                  subtitle: const Text('Completion and celebration sounds'),
                  trailing: Switch(
                    value: provider.soundEffectsEnabled,
                    onChanged: (value) =>
                        provider.setSoundEffectsEnabled(value),
                  ),
                ),

                const Divider(),

                // Notification Sounds
                ListTile(
                  leading: const Icon(Icons.notifications_active),
                  title: const Text('Notification Sounds'),
                  subtitle: const Text('Session transition alerts'),
                  trailing: Switch(
                    value: provider.notificationSoundsEnabled,
                    onChanged: (value) =>
                        provider.setNotificationSoundsEnabled(value),
                  ),
                ),

                const Divider(),

                // Volume Control
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.volume_up, size: 20),
                          const SizedBox(width: 12),
                          Text(
                            'Volume',
                            style: theme.textTheme.titleMedium,
                          ),
                          const Spacer(),
                          Text(
                            '${(provider.audioVolume * 100).round()}%',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: theme.colorScheme.primary,
                          inactiveTrackColor:
                              theme.colorScheme.primary.withOpacity(0.3),
                          thumbColor: theme.colorScheme.primary,
                          overlayColor:
                              theme.colorScheme.primary.withOpacity(0.2),
                          trackHeight: 4,
                        ),
                        child: Slider(
                          value: provider.audioVolume,
                          min: 0.0,
                          max: 1.0,
                          divisions: 10,
                          onChanged: (value) => provider.setAudioVolume(value),
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(),

                // Test Sounds Section
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Test Sounds',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _testNotificationSound(provider),
                              icon: const Icon(Icons.play_arrow, size: 18),
                              label: const Text('Notification'),
                              style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _testCompletionSound(provider),
                              icon: const Icon(Icons.celebration, size: 18),
                              label: const Text('Completion'),
                              style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Sound settings saved'),
                duration: Duration(seconds: 2),
              ),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }

  Widget _buildQuickStatsDialog(BuildContext context) {
    final theme = Theme.of(context);

    return Consumer<FocusProvider>(
      builder: (context, provider, child) {
        return AlertDialog(
          title: const Text('Quick Stats'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildStatRow('Today\'s Sessions', '${provider.todaysSessions}'),
              _buildStatRow('Current Streak', '${provider.currentStreak}'),
              _buildStatRow('Total Focus Time', '${provider.totalFocusHours}h'),
              _buildStatRow('Completed Sessions', '${provider.totalSessions}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
            TextButton(
              onPressed: () => _navigateToAnalytics(context),
              child: const Text('View Details'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  /// Navigate to Enhanced Analytics Screen with proper error handling
  void _navigateToAnalytics(BuildContext context) async {
    try {
      // Close the current dialog first
      Navigator.pop(context);

      // Small delay to ensure dialog is closed before navigation
      await Future.delayed(const Duration(milliseconds: 100));

      if (mounted) {
        // Navigate to Enhanced Analytics Screen
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const EnhancedAnalyticsScreen(),
          ),
        );
      }
    } catch (e) {
      // Handle navigation errors gracefully
      debugPrint('Error navigating to analytics: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to open analytics: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // Preset Management Methods
  void _applyPreset(BuildContext context, TimerPreset preset,
      PresetProvider presetProvider) async {
    final values = await presetProvider.applyPreset(preset.id!);
    if (values != null) {
      final focusProvider = Provider.of<FocusProvider>(context, listen: false);
      focusProvider.setWorkDuration(values['workDuration']!);
      focusProvider.setBreakDuration(values['breakDuration']!);
      focusProvider.setTotalSessions(values['totalSessions']!);

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Applied ${preset.name} preset'),
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to apply preset: ${presetProvider.error}'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  void _handlePresetAction(
    BuildContext context,
    String action,
    TimerPreset preset,
    PresetProvider presetProvider,
  ) {
    switch (action) {
      case 'edit':
        _showPresetFormDialog(context, presetProvider, editingPreset: preset);
        break;
      case 'duplicate':
        _showDuplicateDialog(context, preset, presetProvider);
        break;
      case 'delete':
        _showDeleteConfirmationDialog(context, preset, presetProvider);
        break;
    }
  }

  void _showPresetFormDialog(
    BuildContext context,
    PresetProvider presetProvider, {
    TimerPreset? editingPreset,
  }) {
    showDialog(
      context: context,
      builder: (context) => PresetFormDialog(
        presetProvider: presetProvider,
        editingPreset: editingPreset,
      ),
    );
  }

  void _showDuplicateDialog(
    BuildContext context,
    TimerPreset preset,
    PresetProvider presetProvider,
  ) {
    final nameController = TextEditingController(text: '${preset.name} Copy');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Duplicate Preset'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'New preset name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = nameController.text.trim();
              if (newName.isNotEmpty) {
                Navigator.pop(context);
                final success =
                    await presetProvider.duplicatePreset(preset.id!, newName);
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Preset duplicated as "$newName"')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          'Failed to duplicate preset: ${presetProvider.error}'),
                      backgroundColor: Theme.of(context).colorScheme.error,
                    ),
                  );
                }
              }
            },
            child: const Text('Duplicate'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmationDialog(
    BuildContext context,
    TimerPreset preset,
    PresetProvider presetProvider,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Preset'),
        content: Text(
            'Are you sure you want to delete "${preset.name}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await presetProvider.deletePreset(preset.id!);
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Deleted "${preset.name}" preset')),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        'Failed to delete preset: ${presetProvider.error}'),
                    backgroundColor: Theme.of(context).colorScheme.error,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // Sound testing methods
  void _testNotificationSound(FocusProvider provider) async {
    try {
      // Use the audio service through the provider
      await provider.audioService.testNotificationSound();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🔔 Playing notification sound...'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error playing notification sound: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _testCompletionSound(FocusProvider provider) async {
    try {
      // Use the audio service through the provider
      await provider.audioService.testCompletionSound();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 Playing completion sound...'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error playing completion sound: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
}
