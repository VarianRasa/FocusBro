import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';

/// Centralized error handling utility for the FocusBro app
class ErrorHandler {
  /// Show a user-friendly error message in a SnackBar
  static void showError(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 4),
    SnackBarAction? action,
  }) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red[600],
        duration: duration,
        action: action,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  /// Show a success message in a SnackBar
  static void showSuccess(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.check_circle_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green[600],
        duration: duration,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  /// Show a warning message in a SnackBar
  static void showWarning(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.warning_outlined,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.orange[600],
        duration: duration,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  /// Show an info message in a SnackBar
  static void showInfo(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.info_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.blue[600],
        duration: duration,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  /// Handle and format common exceptions
  static String getErrorMessage(dynamic error) {
    if (error is PlatformException) {
      switch (error.code) {
        case 'permission_denied':
          return 'Permission denied. Please grant the required permissions.';
        case 'network_error':
          return 'Network error. Please check your internet connection.';
        case 'file_not_found':
          return 'File not found. Please try again.';
        default:
          return error.message ?? 'An unexpected error occurred.';
      }
    }

    if (error is FormatException) {
      return 'Invalid data format. Please check your input.';
    }

    if (error is TimeoutException) {
      return 'Operation timed out. Please try again.';
    }

    if (error is Exception) {
      return error.toString().replaceFirst('Exception: ', '');
    }

    return error?.toString() ?? 'An unknown error occurred.';
  }

  /// Log an error with optional context
  static void logError(String message,
      [dynamic error, StackTrace? stackTrace]) {
    // In production, you would send this to a logging service
    // For now, we'll use print for debugging
    print('ERROR: $message');
    if (error != null) {
      print('Error details: $error');
    }
    if (stackTrace != null) {
      print('Stack trace: $stackTrace');
    }
  }

  /// Show an error dialog for critical errors
  static Future<void> showErrorDialog(
    BuildContext context,
    String title,
    String message, {
    String? actionText,
    VoidCallback? onAction,
  }) async {
    if (!context.mounted) return;

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                Icons.error_outline,
                color: Colors.red[600],
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(title),
            ],
          ),
          content: Text(message),
          actions: [
            if (actionText != null && onAction != null)
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  onAction();
                },
                child: Text(actionText),
              ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  /// Handle async operations with proper error handling
  static Future<T?> handleAsync<T>(
    BuildContext context,
    Future<T> operation, {
    String? errorMessage,
    String? successMessage,
    bool showLoading = false,
  }) async {
    try {
      if (showLoading && context.mounted) {
        // Show loading indicator if needed
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );
      }

      final result = await operation;

      if (showLoading && context.mounted) {
        Navigator.of(context).pop(); // Hide loading
      }

      if (successMessage != null && context.mounted) {
        showSuccess(context, successMessage);
      }

      return result;
    } catch (error) {
      if (showLoading && context.mounted) {
        Navigator.of(context).pop(); // Hide loading
      }

      if (context.mounted) {
        final message = errorMessage ?? getErrorMessage(error);
        showError(context, message);
      }

      return null;
    }
  }
}

/// Custom exception classes for better error handling
class FocusAppException implements Exception {
  final String message;
  final String? code;

  const FocusAppException(this.message, {this.code});

  @override
  String toString() => message;
}

class DatabaseException extends FocusAppException {
  const DatabaseException(String message)
      : super(message, code: 'database_error');
}

class ValidationException extends FocusAppException {
  const ValidationException(String message)
      : super(message, code: 'validation_error');
}

class NetworkException extends FocusAppException {
  const NetworkException(String message)
      : super(message, code: 'network_error');
}

class PermissionException extends FocusAppException {
  const PermissionException(String message)
      : super(message, code: 'permission_error');
}

/// Extension to add logging functionality to ErrorHandler
extension ErrorHandlerLogging on ErrorHandler {
  /// Log an error with optional context
  static void logError(String message,
      [dynamic error, StackTrace? stackTrace]) {
    // In production, you would send this to a logging service
    // For now, we'll use print for debugging
    print('ERROR: $message');
    if (error != null) {
      print('Error details: $error');
    }
    if (stackTrace != null) {
      print('Stack trace: $stackTrace');
    }
  }

  /// Log a warning message
  static void logWarning(String message, [dynamic context]) {
    print('WARNING: $message');
    if (context != null) {
      print('Context: $context');
    }
  }

  /// Log an info message
  static void logInfo(String message, [dynamic context]) {
    print('INFO: $message');
    if (context != null) {
      print('Context: $context');
    }
  }
}

/// Add static methods directly to ErrorHandler class
extension ErrorHandlerStatic on ErrorHandler {
  /// Log an error with optional context (static method)
  static void logError(String message,
      [dynamic error, StackTrace? stackTrace]) {
    // In production, you would send this to a logging service
    // For now, we'll use print for debugging
    print('ERROR: $message');
    if (error != null) {
      print('Error details: $error');
    }
    if (stackTrace != null) {
      print('Stack trace: $stackTrace');
    }
  }
}
