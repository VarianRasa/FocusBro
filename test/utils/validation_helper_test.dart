import 'package:flutter_test/flutter_test.dart';
import 'package:focusbro/utils/validation_helper.dart';

void main() {
  group('ValidationHelper Tests', () {
    group('Email Validation', () {
      test('should validate correct email addresses', () {
        expect(ValidationHelper.isValidEmail('test@example.com'), isTrue);
        expect(ValidationHelper.isValidEmail('user.name@domain.co.uk'), isTrue);
        expect(ValidationHelper.isValidEmail('user+tag@example.org'), isTrue);
        expect(ValidationHelper.isValidEmail('123@example.com'), isTrue);
      });

      test('should reject invalid email addresses', () {
        expect(ValidationHelper.isValidEmail(''), isFalse);
        expect(ValidationHelper.isValidEmail('invalid-email'), isFalse);
        expect(ValidationHelper.isValidEmail('@example.com'), isFalse);
        expect(ValidationHelper.isValidEmail('user@'), isFalse);
        expect(ValidationHelper.isValidEmail('user@.com'), isFalse);
        expect(
            ValidationHelper.isValidEmail('user..name@example.com'), isFalse);
      });
    });

    group('Phone Validation', () {
      test('should validate correct phone numbers', () {
        expect(ValidationHelper.isValidPhone('+1234567890'), isTrue);
        expect(ValidationHelper.isValidPhone('(555) 123-4567'), isTrue);
        expect(ValidationHelper.isValidPhone('555-123-4567'), isTrue);
        expect(ValidationHelper.isValidPhone('5551234567'), isTrue);
        expect(ValidationHelper.isValidPhone('+44 20 7946 0958'), isTrue);
      });

      test('should reject invalid phone numbers', () {
        expect(ValidationHelper.isValidPhone(''), isFalse);
        expect(ValidationHelper.isValidPhone('123'), isFalse);
        expect(ValidationHelper.isValidPhone('abc-def-ghij'), isFalse);
        expect(ValidationHelper.isValidPhone('++1234567890'), isFalse);
      });
    });

    group('Timer Duration Validation', () {
      test('should validate correct timer durations', () {
        expect(ValidationHelper.isValidTimerDuration(60), isTrue); // 1 minute
        expect(
            ValidationHelper.isValidTimerDuration(1500), isTrue); // 25 minutes
        expect(ValidationHelper.isValidTimerDuration(3600), isTrue); // 1 hour
        expect(ValidationHelper.isValidTimerDuration(86400),
            isTrue); // 24 hours (max)
      });

      test('should reject invalid timer durations', () {
        expect(ValidationHelper.isValidTimerDuration(0), isFalse);
        expect(ValidationHelper.isValidTimerDuration(-100), isFalse);
        expect(ValidationHelper.isValidTimerDuration(86401),
            isFalse); // Over 24 hours
      });

      test('should validate timer duration strings', () {
        expect(ValidationHelper.isValidTimerDurationString('60'), isTrue);
        expect(ValidationHelper.isValidTimerDurationString('1500'), isTrue);
        expect(ValidationHelper.isValidTimerDurationString('3600'), isTrue);
      });

      test('should reject invalid timer duration strings', () {
        expect(ValidationHelper.isValidTimerDurationString(''), isFalse);
        expect(ValidationHelper.isValidTimerDurationString('abc'), isFalse);
        expect(ValidationHelper.isValidTimerDurationString('-100'), isFalse);
        expect(ValidationHelper.isValidTimerDurationString('100000'), isFalse);
      });
    });

    group('Session Count Validation', () {
      test('should validate correct session counts', () {
        expect(ValidationHelper.isValidSessionCount(1), isTrue);
        expect(ValidationHelper.isValidSessionCount(4), isTrue);
        expect(ValidationHelper.isValidSessionCount(10), isTrue);
        expect(ValidationHelper.isValidSessionCount(100), isTrue);
      });

      test('should reject invalid session counts', () {
        expect(ValidationHelper.isValidSessionCount(0), isFalse);
        expect(ValidationHelper.isValidSessionCount(-1), isFalse);
        expect(ValidationHelper.isValidSessionCount(101), isFalse);
      });
    });

    group('Text Validation', () {
      test('should validate safe text', () {
        expect(ValidationHelper.isSafeText('Hello World'), isTrue);
        expect(ValidationHelper.isSafeText('Test 123'), isTrue);
        expect(ValidationHelper.isSafeText('Valid text with punctuation!'),
            isTrue);
        expect(ValidationHelper.isSafeText(''), isTrue); // Empty is safe
      });

      test('should reject unsafe text', () {
        expect(ValidationHelper.isSafeText('<script>alert("xss")</script>'),
            isFalse);
        expect(ValidationHelper.isSafeText('Text with <tags>'), isFalse);
        expect(ValidationHelper.isSafeText('Text with "quotes"'), isFalse);
      });

      test('should validate alphanumeric text', () {
        expect(ValidationHelper.isValidAlphanumeric('Hello World'), isTrue);
        expect(ValidationHelper.isValidAlphanumeric('Test123'), isTrue);
        expect(ValidationHelper.isValidAlphanumeric('Valid Text'), isTrue);
      });

      test('should reject non-alphanumeric text', () {
        expect(ValidationHelper.isValidAlphanumeric(''), isFalse);
        expect(ValidationHelper.isValidAlphanumeric('Text with @symbols'),
            isFalse);
        expect(
            ValidationHelper.isValidAlphanumeric('Text-with-dashes'), isFalse);
      });
    });

    group('Note Validation', () {
      test('should validate correct note titles', () {
        expect(ValidationHelper.isValidNoteTitle('My Note'), isTrue);
        expect(ValidationHelper.isValidNoteTitle('Project Ideas'), isTrue);
        expect(ValidationHelper.isValidNoteTitle('Meeting Notes 2024'), isTrue);
      });

      test('should reject invalid note titles', () {
        expect(ValidationHelper.isValidNoteTitle(''), isFalse);
        expect(
            ValidationHelper.isValidNoteTitle('A' * 201), isFalse); // Too long
        expect(
            ValidationHelper.isValidNoteTitle('Note with <script>'), isFalse);
      });

      test('should validate note content', () {
        expect(ValidationHelper.isValidNoteContent('This is valid content'),
            isTrue);
        expect(ValidationHelper.isValidNoteContent(''),
            isTrue); // Empty content is valid
        expect(ValidationHelper.isValidNoteContent('A' * 1000),
            isTrue); // Long but valid
      });

      test('should reject invalid note content', () {
        expect(ValidationHelper.isValidNoteContent('A' * 50001),
            isFalse); // Too long
        expect(ValidationHelper.isValidNoteContent('Content with <script>'),
            isFalse);
      });
    });

    group('Task Validation', () {
      test('should validate correct task titles', () {
        expect(ValidationHelper.isValidTaskTitle('Complete project'), isTrue);
        expect(ValidationHelper.isValidTaskTitle('Review code'), isTrue);
        expect(ValidationHelper.isValidTaskTitle('Task 123'), isTrue);
      });

      test('should reject invalid task titles', () {
        expect(ValidationHelper.isValidTaskTitle(''), isFalse);
        expect(ValidationHelper.isValidTaskTitle('A' * 201), isFalse);
        expect(
            ValidationHelper.isValidTaskTitle('Task with <script>'), isFalse);
      });

      test('should validate task descriptions', () {
        expect(ValidationHelper.isValidTaskDescription('Task description'),
            isTrue);
        expect(ValidationHelper.isValidTaskDescription(''), isTrue);
        expect(ValidationHelper.isValidTaskDescription('A' * 500), isTrue);
      });

      test('should reject invalid task descriptions', () {
        expect(ValidationHelper.isValidTaskDescription('A' * 1001), isFalse);
        expect(
            ValidationHelper.isValidTaskDescription(
                'Description with <script>'),
            isFalse);
      });
    });

    group('Preset Name Validation', () {
      test('should validate correct preset names', () {
        expect(ValidationHelper.isValidPresetName('Pomodoro'), isTrue);
        expect(ValidationHelper.isValidPresetName('Work Session'), isTrue);
        expect(ValidationHelper.isValidPresetName('Focus 25'), isTrue);
      });

      test('should reject invalid preset names', () {
        expect(ValidationHelper.isValidPresetName(''), isFalse);
        expect(ValidationHelper.isValidPresetName('A' * 51), isFalse);
        expect(
            ValidationHelper.isValidPresetName('Name with @symbols'), isFalse);
      });
    });

    group('Category Validation', () {
      test('should validate correct category names', () {
        expect(ValidationHelper.isValidCategoryName('Work'), isTrue);
        expect(ValidationHelper.isValidCategoryName('Personal'), isTrue);
        expect(ValidationHelper.isValidCategoryName('Study 2024'), isTrue);
      });

      test('should reject invalid category names', () {
        expect(ValidationHelper.isValidCategoryName(''), isFalse);
        expect(ValidationHelper.isValidCategoryName('A' * 51), isFalse);
        expect(ValidationHelper.isValidCategoryName('Category@work'), isFalse);
      });
    });

    group('URL Validation', () {
      test('should validate correct URLs', () {
        expect(ValidationHelper.isValidUrl('https://example.com'), isTrue);
        expect(ValidationHelper.isValidUrl('http://test.org'), isTrue);
        expect(
            ValidationHelper.isValidUrl('https://sub.domain.com/path'), isTrue);
      });

      test('should reject invalid URLs', () {
        expect(ValidationHelper.isValidUrl(''), isFalse);
        expect(ValidationHelper.isValidUrl('not-a-url'), isFalse);
        expect(ValidationHelper.isValidUrl('ftp://example.com'), isFalse);
        expect(ValidationHelper.isValidUrl('javascript:alert("xss")'), isFalse);
      });
    });

    group('Text Sanitization', () {
      test('should sanitize dangerous text', () {
        expect(
          ValidationHelper.sanitizeText('<script>alert("xss")</script>'),
          equals('scriptalert(xss)/script'),
        );
        expect(
          ValidationHelper.sanitizeText('Text with "quotes" and <tags>'),
          equals('Text with quotes and tags'),
        );
        expect(
          ValidationHelper.sanitizeText('Normal text'),
          equals('Normal text'),
        );
      });

      test('should limit text length during sanitization', () {
        final longText = 'A' * 1500;
        final sanitized = ValidationHelper.sanitizeText(longText);
        expect(sanitized.length, equals(1000));
      });

      test('should handle empty and whitespace text', () {
        expect(ValidationHelper.sanitizeText(''), equals(''));
        expect(ValidationHelper.sanitizeText('   '), equals(''));
        expect(ValidationHelper.sanitizeText('  text  '), equals('text'));
      });
    });

    group('Timer Preset Validation', () {
      test('should validate correct timer preset data', () {
        final validPreset = {
          'name': 'Pomodoro',
          'workDuration': 1500,
          'breakDuration': 300,
          'sessionsUntilLongBreak': 4,
        };

        final result = ValidationHelper.validateTimerPreset(validPreset);
        expect(result, isNotNull);
        expect(result!['name'], equals('Pomodoro'));
        expect(result['workDuration'], equals(1500));
        expect(result['breakDuration'], equals(300));
        expect(result['sessionsUntilLongBreak'], equals(4));
      });

      test('should reject invalid timer preset data', () {
        final invalidPresets = [
          {
            'name': '', // Invalid name
            'workDuration': 1500,
            'breakDuration': 300,
            'sessionsUntilLongBreak': 4,
          },
          {
            'name': 'Valid Name',
            'workDuration': -100, // Invalid duration
            'breakDuration': 300,
            'sessionsUntilLongBreak': 4,
          },
          {
            'name': 'Valid Name',
            'workDuration': 1500,
            'breakDuration': 300,
            'sessionsUntilLongBreak': 0, // Invalid session count
          },
        ];

        for (final preset in invalidPresets) {
          final result = ValidationHelper.validateTimerPreset(preset);
          expect(result, isNull);
        }
      });
    });

    group('File Name Validation', () {
      test('should validate safe file names', () {
        expect(ValidationHelper.isSafeFileName('document.pdf'), isTrue);
        expect(ValidationHelper.isSafeFileName('my_file.txt'), isTrue);
        expect(ValidationHelper.isSafeFileName('report-2024.docx'), isTrue);
      });

      test('should reject unsafe file names', () {
        expect(ValidationHelper.isSafeFileName(''), isFalse);
        expect(ValidationHelper.isSafeFileName('file/with/slashes'), isFalse);
        expect(ValidationHelper.isSafeFileName('file:with:colons'), isFalse);
        expect(ValidationHelper.isSafeFileName('file*with*asterisks'), isFalse);
      });

      test('should sanitize file names', () {
        expect(
          ValidationHelper.sanitizeFileName('file/with\\unsafe:chars'),
          equals('file_with_unsafe_chars'),
        );
        expect(
          ValidationHelper.sanitizeFileName(''),
          equals('untitled'),
        );
        expect(
          ValidationHelper.sanitizeFileName('A' * 150),
          equals('A' * 100),
        );
      });
    });

    group('Numeric Range Validation', () {
      test('should validate numeric ranges', () {
        expect(ValidationHelper.isValidNumericRange('5.5', 0.0, 10.0), isTrue);
        expect(ValidationHelper.isValidNumericRange('0', 0.0, 10.0), isTrue);
        expect(ValidationHelper.isValidNumericRange('10', 0.0, 10.0), isTrue);
      });

      test('should reject out-of-range numeric values', () {
        expect(ValidationHelper.isValidNumericRange('-1', 0.0, 10.0), isFalse);
        expect(ValidationHelper.isValidNumericRange('11', 0.0, 10.0), isFalse);
        expect(ValidationHelper.isValidNumericRange('abc', 0.0, 10.0), isFalse);
        expect(ValidationHelper.isValidNumericRange('', 0.0, 10.0), isFalse);
      });

      test('should validate integer ranges', () {
        expect(ValidationHelper.isValidIntegerRange('5', 0, 10), isTrue);
        expect(ValidationHelper.isValidIntegerRange('0', 0, 10), isTrue);
        expect(ValidationHelper.isValidIntegerRange('10', 0, 10), isTrue);
      });

      test('should reject out-of-range integer values', () {
        expect(ValidationHelper.isValidIntegerRange('-1', 0, 10), isFalse);
        expect(ValidationHelper.isValidIntegerRange('11', 0, 10), isFalse);
        expect(ValidationHelper.isValidIntegerRange('5.5', 0, 10), isFalse);
        expect(ValidationHelper.isValidIntegerRange('abc', 0, 10), isFalse);
      });
    });

    group('Validation Error Messages', () {
      test('should return appropriate error messages', () {
        expect(
          ValidationHelper.getValidationError('email', ''),
          equals('Email is required'),
        );
        expect(
          ValidationHelper.getValidationError('email', 'invalid-email'),
          equals('Please enter a valid email address'),
        );
        expect(
          ValidationHelper.getValidationError('presetName', ''),
          equals('Preset name is required'),
        );
        expect(
          ValidationHelper.getValidationError('presetName', 'A' * 51),
          equals('Preset name must be less than 50 characters'),
        );
      });
    });
  });
}
