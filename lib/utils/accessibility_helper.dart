import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

/// Accessibility helper utility for the FocusBro app
class AccessibilityHelper {
  /// Create a semantic label for timer display
  static String formatTimerSemantics(int timeLeft, bool isWorkTime) {
    final minutes = timeLeft ~/ 60;
    final seconds = timeLeft % 60;
    final timeType = isWorkTime ? 'work' : 'break';

    String timeString;
    if (minutes > 0) {
      timeString = '$minutes minute${minutes != 1 ? 's' : ''}';
      if (seconds > 0) {
        timeString += ' and $seconds second${seconds != 1 ? 's' : ''}';
      }
    } else {
      timeString = '$seconds second${seconds != 1 ? 's' : ''}';
    }

    return '$timeString remaining in $timeType session';
  }

  /// Create semantic label for progress indicator
  static String formatProgressSemantics(
      int timeLeft, int totalTime, bool isWorkTime) {
    final percentage = ((totalTime - timeLeft) / totalTime * 100).round();
    final timeType = isWorkTime ? 'work' : 'break';
    return '$timeType session $percentage percent complete';
  }

  /// Create semantic label for session counter
  static String formatSessionSemantics(int currentSession, int totalSessions) {
    return 'Session $currentSession of $totalSessions';
  }

  /// Create semantic label for streak information
  static String formatStreakSemantics(int currentStreak, int longestStreak) {
    return 'Current streak: $currentStreak day${currentStreak != 1 ? 's' : ''}. Longest streak: $longestStreak day${longestStreak != 1 ? 's' : ''}';
  }

  /// Create semantic label for timer controls
  static String getTimerControlSemantics(bool isRunning) {
    return isRunning ? 'Pause timer' : 'Start timer';
  }

  /// Create semantic label for task completion
  static String getTaskCompletionSemantics(String taskTitle, bool isCompleted) {
    return isCompleted
        ? 'Mark task "$taskTitle" as incomplete'
        : 'Mark task "$taskTitle" as complete';
  }

  /// Create semantic label for priority levels
  static String getPrioritySemantics(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return 'High priority task';
      case 'medium':
        return 'Medium priority task';
      case 'low':
        return 'Low priority task';
      default:
        return 'Normal priority task';
    }
  }

  /// Create semantic label for due dates
  static String getDueDateSemantics(DateTime? dueDate) {
    if (dueDate == null) return 'No due date';

    final now = DateTime.now();
    final difference = dueDate.difference(now).inDays;

    if (difference < 0) {
      return 'Overdue by ${-difference} day${-difference != 1 ? 's' : ''}';
    } else if (difference == 0) {
      return 'Due today';
    } else if (difference == 1) {
      return 'Due tomorrow';
    } else {
      return 'Due in $difference days';
    }
  }

  /// Create semantic label for note categories
  static String getCategorySemantics(String category) {
    return 'Category: $category';
  }

  /// Create semantic label for music controls
  static String getMusicControlSemantics(bool isPlaying, String musicName) {
    return isPlaying ? 'Stop $musicName music' : 'Play $musicName music';
  }

  /// Create semantic label for volume controls
  static String getVolumeSemantics(double volume) {
    final percentage = (volume * 100).round();
    return 'Volume: $percentage percent';
  }

  /// Create semantic label for theme selection
  static String getThemeSemantics(String themeName) {
    return 'Current theme: $themeName';
  }

  /// Wrap widget with proper semantics for screen readers
  static Widget wrapWithSemantics({
    required Widget child,
    required String label,
    String? hint,
    String? value,
    bool? button,
    bool? slider,
    bool? header,
    VoidCallback? onTap,
    bool excludeSemantics = false,
  }) {
    return Semantics(
      label: label,
      hint: hint,
      value: value,
      button: button ?? false,
      slider: slider ?? false,
      header: header ?? false,
      onTap: onTap,
      excludeSemantics: excludeSemantics,
      child: child,
    );
  }

  /// Create accessible button with proper semantics
  static Widget accessibleButton({
    required Widget child,
    required String semanticLabel,
    String? semanticHint,
    required VoidCallback onPressed,
    ButtonStyle? style,
  }) {
    return Semantics(
      label: semanticLabel,
      hint: semanticHint,
      button: true,
      onTap: onPressed,
      child: ElevatedButton(
        onPressed: onPressed,
        style: style,
        child: child,
      ),
    );
  }

  /// Create accessible icon button with proper semantics
  static Widget accessibleIconButton({
    required IconData icon,
    required String semanticLabel,
    String? semanticHint,
    required VoidCallback onPressed,
    Color? color,
    double? size,
  }) {
    return Semantics(
      label: semanticLabel,
      hint: semanticHint,
      button: true,
      onTap: onPressed,
      child: IconButton(
        icon: Icon(icon, color: color, size: size),
        onPressed: onPressed,
      ),
    );
  }

  /// Create accessible switch with proper semantics
  static Widget accessibleSwitch({
    required bool value,
    required String label,
    String? hint,
    required ValueChanged<bool> onChanged,
  }) {
    return Semantics(
      label: label,
      hint: hint,
      toggled: value,
      onTap: () => onChanged(!value),
      child: Switch(
        value: value,
        onChanged: onChanged,
      ),
    );
  }

  /// Create accessible slider with proper semantics
  static Widget accessibleSlider({
    required double value,
    required double min,
    required double max,
    required String label,
    String? hint,
    required ValueChanged<double> onChanged,
    int? divisions,
  }) {
    return Semantics(
      label: label,
      hint: hint,
      value: '${(value * 100).round()}%',
      slider: true,
      child: Slider(
        value: value,
        min: min,
        max: max,
        divisions: divisions,
        onChanged: onChanged,
      ),
    );
  }

  /// Create accessible text field with proper semantics
  static Widget accessibleTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    String? semanticHint,
    TextInputType? keyboardType,
    bool obscureText = false,
    int? maxLines,
    ValueChanged<String>? onChanged,
    String? Function(String?)? validator,
  }) {
    return Semantics(
      label: label,
      hint: semanticHint,
      textField: true,
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
        ),
        keyboardType: keyboardType,
        obscureText: obscureText,
        maxLines: maxLines,
        onChanged: onChanged,
        validator: validator,
      ),
    );
  }

  /// Announce message to screen readers
  static void announceToScreenReader(BuildContext context, String message) {
    SemanticsService.announce(message, TextDirection.ltr);
  }

  /// Check if screen reader is enabled
  static bool isScreenReaderEnabled(BuildContext context) {
    return MediaQuery.of(context).accessibleNavigation;
  }

  /// Get recommended minimum touch target size
  static double get minimumTouchTargetSize => 48.0;

  /// Get recommended spacing for accessibility
  static double get accessibleSpacing => 16.0;

  /// Create accessible card with proper semantics
  static Widget accessibleCard({
    required Widget child,
    required String semanticLabel,
    String? semanticHint,
    VoidCallback? onTap,
    EdgeInsetsGeometry? padding,
  }) {
    return Semantics(
      label: semanticLabel,
      hint: semanticHint,
      button: onTap != null,
      onTap: onTap,
      child: Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: padding ?? const EdgeInsets.all(16),
            child: child,
          ),
        ),
      ),
    );
  }
}
