import 'dart:convert';

/// Input validation and sanitization utility for the FocusBro app
class ValidationHelper {
  // Common validation patterns
  static final RegExp _emailPattern = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );

  static final RegExp _phonePattern = RegExp(
    r'^\+?[\d\s\-\(\)]{10,}$',
  );

  static final RegExp _alphanumericPattern = RegExp(
    r'^[a-zA-Z0-9\s]+$',
  );

  static final RegExp _safeTextPattern = RegExp(
    r'^[a-zA-Z0-9\s\.\,\!\?\-\_\(\)\[\]]+$',
  );

  /// Validate email address
  static bool isValidEmail(String email) {
    if (email.isEmpty) return false;
    return _emailPattern.hasMatch(email.trim());
  }

  /// Validate phone number
  static bool isValidPhone(String phone) {
    if (phone.isEmpty) return false;
    return _phonePattern.hasMatch(phone.trim());
  }

  /// Validate text input (alphanumeric with spaces)
  static bool isValidAlphanumeric(String text) {
    if (text.isEmpty) return false;
    return _alphanumericPattern.hasMatch(text.trim());
  }

  /// Validate safe text input (prevents XSS and injection)
  static bool isSafeText(String text) {
    if (text.isEmpty) return true; // Empty is safe
    return _safeTextPattern.hasMatch(text.trim());
  }

  /// Validate timer duration (in seconds)
  static bool isValidTimerDuration(int duration) {
    return duration > 0 && duration <= 86400; // Max 24 hours
  }

  /// Validate timer duration string input
  static bool isValidTimerDurationString(String duration) {
    if (duration.isEmpty) return false;
    final parsed = int.tryParse(duration);
    return parsed != null && isValidTimerDuration(parsed);
  }

  /// Validate session count
  static bool isValidSessionCount(int count) {
    return count > 0 && count <= 100; // Reasonable limit
  }

  /// Validate note title
  static bool isValidNoteTitle(String title) {
    if (title.isEmpty) return false;
    if (title.length > 200) return false; // Reasonable title length
    return isSafeText(title);
  }

  /// Validate note content
  static bool isValidNoteContent(String content) {
    if (content.length > 50000) return false; // Reasonable content length
    return isSafeText(content);
  }

  /// Validate task title
  static bool isValidTaskTitle(String title) {
    if (title.isEmpty) return false;
    if (title.length > 200) return false;
    return isSafeText(title);
  }

  /// Validate task description
  static bool isValidTaskDescription(String description) {
    if (description.length > 1000) return false;
    return isSafeText(description);
  }

  /// Validate category name
  static bool isValidCategoryName(String category) {
    if (category.isEmpty) return false;
    if (category.length > 50) return false;
    return isValidAlphanumeric(category);
  }

  /// Validate preset name
  static bool isValidPresetName(String name) {
    if (name.isEmpty) return false;
    if (name.length > 50) return false;
    return isValidAlphanumeric(name);
  }

  /// Validate URL
  static bool isValidUrl(String url) {
    if (url.isEmpty) return false;
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      return false;
    }
  }

  /// Validate file path
  static bool isValidFilePath(String path) {
    if (path.isEmpty) return false;
    // Basic path validation - no dangerous characters
    final dangerousChars = ['<', '>', '|', '*', '?', '"'];
    return !dangerousChars.any((char) => path.contains(char));
  }

  /// Sanitize text input
  static String sanitizeText(String input) {
    if (input.isEmpty) return input;

    // Remove potentially dangerous characters
    String sanitized = input
        .replaceAll(RegExp(r'[<>"\x27]'), '') // Remove HTML/script chars
        .replaceAll(RegExp(r'[&]'), '&amp;') // Escape ampersand
        .trim();

    // Limit length
    if (sanitized.length > 1000) {
      sanitized = sanitized.substring(0, 1000);
    }

    return sanitized;
  }

  /// Sanitize HTML content
  static String sanitizeHtml(String input) {
    if (input.isEmpty) return input;

    return input
        .replaceAll(
            RegExp(r'<script[^>]*>.*?</script>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<[^>]*>'), '') // Remove all HTML tags
        .replaceAll(RegExp(r'javascript:', caseSensitive: false), '')
        .replaceAll(RegExp(r'on\w+\s*=', caseSensitive: false), '')
        .trim();
  }

  /// Sanitize JSON input
  static String sanitizeJson(String input) {
    if (input.isEmpty) return input;

    try {
      // Parse and re-encode to ensure valid JSON
      final decoded = jsonDecode(input);
      return jsonEncode(decoded);
    } catch (e) {
      return '{}'; // Return empty object if invalid
    }
  }

  /// Validate and sanitize timer preset data
  static Map<String, dynamic>? validateTimerPreset(
      Map<String, dynamic> preset) {
    try {
      final name = preset['name']?.toString() ?? '';
      final workDuration = preset['workDuration'] as int?;
      final breakDuration = preset['breakDuration'] as int?;
      final sessionsUntilLongBreak = preset['sessionsUntilLongBreak'] as int?;

      if (!isValidPresetName(name)) return null;
      if (workDuration == null || !isValidTimerDuration(workDuration))
        return null;
      if (breakDuration == null || !isValidTimerDuration(breakDuration))
        return null;
      if (sessionsUntilLongBreak == null ||
          !isValidSessionCount(sessionsUntilLongBreak)) return null;

      return {
        'name': sanitizeText(name),
        'workDuration': workDuration,
        'breakDuration': breakDuration,
        'sessionsUntilLongBreak': sessionsUntilLongBreak,
      };
    } catch (e) {
      return null;
    }
  }

  /// Validate and sanitize note data
  static Map<String, dynamic>? validateNoteData(Map<String, dynamic> note) {
    try {
      final title = note['title']?.toString() ?? '';
      final content = note['content']?.toString() ?? '';
      final category = note['category']?.toString() ?? 'General';

      if (!isValidNoteTitle(title)) return null;
      if (!isValidNoteContent(content)) return null;
      if (!isValidCategoryName(category)) return null;

      return {
        'title': sanitizeText(title),
        'content': sanitizeText(content),
        'category': sanitizeText(category),
        'createdAt': note['createdAt'] ?? DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      return null;
    }
  }

  /// Validate and sanitize task data
  static Map<String, dynamic>? validateTaskData(Map<String, dynamic> task) {
    try {
      final title = task['title']?.toString() ?? '';
      final description = task['description']?.toString() ?? '';
      final priority = task['priority']?.toString() ?? 'medium';
      final isCompleted = task['isCompleted'] as bool? ?? false;

      if (!isValidTaskTitle(title)) return null;
      if (!isValidTaskDescription(description)) return null;
      if (!['low', 'medium', 'high'].contains(priority)) return null;

      return {
        'title': sanitizeText(title),
        'description': sanitizeText(description),
        'priority': priority,
        'isCompleted': isCompleted,
        'createdAt': task['createdAt'] ?? DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      return null;
    }
  }

  /// Get validation error message
  static String getValidationError(String field, String value) {
    switch (field) {
      case 'email':
        if (value.isEmpty) return 'Email is required';
        if (!isValidEmail(value)) return 'Please enter a valid email address';
        break;
      case 'phone':
        if (value.isEmpty) return 'Phone number is required';
        if (!isValidPhone(value)) return 'Please enter a valid phone number';
        break;
      case 'noteTitle':
        if (value.isEmpty) return 'Note title is required';
        if (value.length > 200)
          return 'Note title must be less than 200 characters';
        if (!isSafeText(value)) return 'Note title contains invalid characters';
        break;
      case 'taskTitle':
        if (value.isEmpty) return 'Task title is required';
        if (value.length > 200)
          return 'Task title must be less than 200 characters';
        if (!isSafeText(value)) return 'Task title contains invalid characters';
        break;
      case 'presetName':
        if (value.isEmpty) return 'Preset name is required';
        if (value.length > 50)
          return 'Preset name must be less than 50 characters';
        if (!isValidAlphanumeric(value))
          return 'Preset name can only contain letters, numbers, and spaces';
        break;
      case 'category':
        if (value.isEmpty) return 'Category is required';
        if (value.length > 50)
          return 'Category must be less than 50 characters';
        if (!isValidAlphanumeric(value))
          return 'Category can only contain letters, numbers, and spaces';
        break;
      case 'timerDuration':
        if (value.isEmpty) return 'Duration is required';
        final duration = int.tryParse(value);
        if (duration == null) return 'Duration must be a number';
        if (!isValidTimerDuration(duration))
          return 'Duration must be between 1 second and 24 hours';
        break;
      default:
        return 'Invalid input';
    }
    return '';
  }

  /// Check if string contains only safe characters for file names
  static bool isSafeFileName(String fileName) {
    if (fileName.isEmpty) return false;
    final unsafeChars = ['/', '\\', ':', '*', '?', '"', '<', '>', '|'];
    return !unsafeChars.any((char) => fileName.contains(char));
  }

  /// Sanitize file name
  static String sanitizeFileName(String fileName) {
    if (fileName.isEmpty) return 'untitled';

    final unsafeChars = ['/', '\\', ':', '*', '?', '"', '<', '>', '|'];
    String sanitized = fileName;

    for (final char in unsafeChars) {
      sanitized = sanitized.replaceAll(char, '_');
    }

    // Limit length and trim
    sanitized = sanitized.trim();
    if (sanitized.length > 100) {
      sanitized = sanitized.substring(0, 100);
    }

    return sanitized.isEmpty ? 'untitled' : sanitized;
  }

  /// Validate numeric input within range
  static bool isValidNumericRange(String input, double min, double max) {
    if (input.isEmpty) return false;
    final value = double.tryParse(input);
    return value != null && value >= min && value <= max;
  }

  /// Validate integer input within range
  static bool isValidIntegerRange(String input, int min, int max) {
    if (input.isEmpty) return false;
    final value = int.tryParse(input);
    return value != null && value >= min && value <= max;
  }
}
