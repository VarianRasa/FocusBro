import 'package:flutter/foundation.dart';

import 'analytics_service.dart';
import 'audio_feedback_service.dart';
import 'focus_mode_service.dart';
import 'music_service.dart';
import 'session_notification_service.dart';
import 'smart_notification_service.dart';
import 'voice_command_service.dart';

/// Initializes peripheral services used by [FocusProvider].
class FocusProviderBootstrap {
  FocusProviderBootstrap({
    VoiceCommandService? voiceService,
    SmartNotificationService? notificationService,
    AudioFeedbackService? audioService,
    MusicService? musicService,
    FocusModeService? focusModeService,
    AnalyticsService? analyticsService,
    SessionNotificationService? sessionNotificationService,
  })  : voiceService = voiceService ?? VoiceCommandService(),
        notificationService = notificationService ?? SmartNotificationService(),
        audioService = audioService ?? AudioFeedbackService(),
        musicService = musicService ?? MusicService(),
        focusModeService = focusModeService ?? FocusModeService(),
        analyticsService = analyticsService ?? AnalyticsService(),
        sessionNotificationService =
            sessionNotificationService ?? SessionNotificationService();

  final VoiceCommandService voiceService;
  final SmartNotificationService notificationService;
  final AudioFeedbackService audioService;
  final MusicService musicService;
  final FocusModeService focusModeService;
  final AnalyticsService analyticsService;
  final SessionNotificationService sessionNotificationService;

  Future<void> initialize() async {
    try {
      await voiceService.initialize();
      await notificationService.initialize();
      await audioService.initialize();
      await musicService.initialize();
      await focusModeService.initialize();
      await sessionNotificationService.initialize();
    } catch (error) {
      debugPrint('FocusBro: Service initialization error: $error');
    }
  }
}
