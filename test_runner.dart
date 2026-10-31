#!/usr/bin/env dart

import 'dart:io';
import 'dart:async';

/// Comprehensive test runner for FocusBro app
/// Runs unit tests, widget tests, and integration tests
class TestRunner {
  static const String _separator = '=' * 80;
  static const String _subSeparator = '-' * 40;
  
  static void main(List<String> args) async {
    print('🚀 FocusBro Comprehensive Test Suite');
    print(_separator);
    
    final runner = TestRunner();
    var exitCode = 0;
    
    try {
      // Parse command line arguments
      final options = _parseArgs(args);
      
      if (options['help'] == true) {
        _printUsage();
        return;
      }
      
      // Run tests based on options
      if (options['unit'] == true || options['all'] == true) {
        exitCode += await runner._runUnitTests();
      }
      
      if (options['widget'] == true || options['all'] == true) {
        exitCode += await runner._runWidgetTests();
      }
      
      if (options['integration'] == true || options['all'] == true) {
        exitCode += await runner._runIntegrationTests();
      }
      
      if (options['coverage'] == true) {
        await runner._generateCoverageReport();
      }
      
      // Print summary
      runner._printSummary(exitCode);
      
    } catch (e) {
      print('❌ Error running tests: $e');
      exitCode = 1;
    }
    
    exit(exitCode);
  }
  
  /// Parse command line arguments
  static Map<String, dynamic> _parseArgs(List<String> args) {
    final options = <String, dynamic>{
      'unit': false,
      'widget': false,
      'integration': false,
      'coverage': false,
      'all': false,
      'help': false,
    };
    
    if (args.isEmpty) {
      options['all'] = true;
    }
    
    for (final arg in args) {
      switch (arg) {
        case '--unit':
        case '-u':
          options['unit'] = true;
          break;
        case '--widget':
        case '-w':
          options['widget'] = true;
          break;
        case '--integration':
        case '-i':
          options['integration'] = true;
          break;
        case '--coverage':
        case '-c':
          options['coverage'] = true;
          break;
        case '--all':
        case '-a':
          options['all'] = true;
          break;
        case '--help':
        case '-h':
          options['help'] = true;
          break;
      }
    }
    
    return options;
  }
  
  /// Print usage information
  static void _printUsage() {
    print('''
Usage: dart test_runner.dart [options]

Options:
  -u, --unit         Run unit tests only
  -w, --widget       Run widget tests only
  -i, --integration  Run integration tests only
  -c, --coverage     Generate coverage report
  -a, --all          Run all tests (default)
  -h, --help         Show this help message

Examples:
  dart test_runner.dart                    # Run all tests
  dart test_runner.dart --unit --coverage  # Run unit tests with coverage
  dart test_runner.dart -w -i              # Run widget and integration tests
''');
  }
  
  /// Run unit tests
  Future<int> _runUnitTests() async {
    print('\n🧪 Running Unit Tests');
    print(_subSeparator);
    
    final stopwatch = Stopwatch()..start();
    
    try {
      // Run specific unit test files
      final testFiles = [
        'test/services/analytics_service_test.dart',
        'test/utils/validation_helper_test.dart',
        'test/utils/cache_manager_test.dart',
        'test/utils/error_handler_test.dart',
        'test/services/cloud_sync_service_test.dart',
        'test/services/voice_command_service_test.dart',
      ];
      
      var failedTests = 0;
      
      for (final testFile in testFiles) {
        if (await File(testFile).exists()) {
          print('Running $testFile...');
          final result = await _runFlutterTest(testFile);
          if (result != 0) {
            failedTests++;
            print('❌ Failed: $testFile');
          } else {
            print('✅ Passed: $testFile');
          }
        } else {
          print('⚠️  Test file not found: $testFile');
        }
      }
      
      stopwatch.stop();
      print('\n📊 Unit Tests Summary:');
      print('Time: ${stopwatch.elapsed.inSeconds}s');
      print('Failed: $failedTests/${testFiles.length}');
      
      return failedTests;
      
    } catch (e) {
      print('❌ Error running unit tests: $e');
      return 1;
    }
  }
  
  /// Run widget tests
  Future<int> _runWidgetTests() async {
    print('\n🎨 Running Widget Tests');
    print(_subSeparator);
    
    final stopwatch = Stopwatch()..start();
    
    try {
      final testFiles = [
        'test/screens/focus_screen_test.dart',
        'test/screens/analytics_screen_test.dart',
        'test/screens/cloud_sync_screen_test.dart',
        'test/widgets/timer_display_test.dart',
        'test/widgets/settings_card_test.dart',
      ];
      
      var failedTests = 0;
      
      for (final testFile in testFiles) {
        if (await File(testFile).exists()) {
          print('Running $testFile...');
          final result = await _runFlutterTest(testFile);
          if (result != 0) {
            failedTests++;
            print('❌ Failed: $testFile');
          } else {
            print('✅ Passed: $testFile');
          }
        } else {
          print('⚠️  Test file not found: $testFile');
        }
      }
      
      stopwatch.stop();
      print('\n📊 Widget Tests Summary:');
      print('Time: ${stopwatch.elapsed.inSeconds}s');
      print('Failed: $failedTests/${testFiles.length}');
      
      return failedTests;
      
    } catch (e) {
      print('❌ Error running widget tests: $e');
      return 1;
    }
  }
  
  /// Run integration tests
  Future<int> _runIntegrationTests() async {
    print('\n🔗 Running Integration Tests');
    print(_subSeparator);
    
    final stopwatch = Stopwatch()..start();
    
    try {
      print('Starting integration tests...');
      print('Note: This requires a connected device or emulator');
      
      // Check if integration test file exists
      final integrationTestFile = 'test_driver/app_test.dart';
      if (!await File(integrationTestFile).exists()) {
        print('⚠️  Integration test file not found: $integrationTestFile');
        return 0;
      }
      
      // Run integration tests
      final result = await Process.run(
        'flutter',
        ['drive', '--target=test_driver/app.dart'],
        workingDirectory: Directory.current.path,
      );
      
      stopwatch.stop();
      
      if (result.exitCode == 0) {
        print('✅ Integration tests passed');
        print('Time: ${stopwatch.elapsed.inSeconds}s');
        return 0;
      } else {
        print('❌ Integration tests failed');
        print('Error: ${result.stderr}');
        return 1;
      }
      
    } catch (e) {
      print('❌ Error running integration tests: $e');
      print('Make sure you have a device/emulator connected');
      return 1;
    }
  }
  
  /// Generate coverage report
  Future<void> _generateCoverageReport() async {
    print('\n📈 Generating Coverage Report');
    print(_subSeparator);
    
    try {
      print('Running tests with coverage...');
      
      final result = await Process.run(
        'flutter',
        ['test', '--coverage'],
        workingDirectory: Directory.current.path,
      );
      
      if (result.exitCode == 0) {
        print('✅ Coverage data generated');
        
        // Check if lcov is available for HTML report
        final lcovResult = await Process.run('which', ['lcov']);
        if (lcovResult.exitCode == 0) {
          print('Generating HTML coverage report...');
          
          await Process.run(
            'genhtml',
            ['coverage/lcov.info', '-o', 'coverage/html'],
            workingDirectory: Directory.current.path,
          );
          
          print('✅ HTML coverage report generated at coverage/html/index.html');
        } else {
          print('⚠️  lcov not found. Install lcov to generate HTML reports.');
          print('Coverage data available at coverage/lcov.info');
        }
      } else {
        print('❌ Failed to generate coverage');
        print('Error: ${result.stderr}');
      }
      
    } catch (e) {
      print('❌ Error generating coverage: $e');
    }
  }
  
  /// Run flutter test command
  Future<int> _runFlutterTest(String testFile) async {
    final result = await Process.run(
      'flutter',
      ['test', testFile],
      workingDirectory: Directory.current.path,
    );
    
    return result.exitCode;
  }
  
  /// Print test summary
  void _printSummary(int exitCode) {
    print('\n' + _separator);
    if (exitCode == 0) {
      print('🎉 All tests passed successfully!');
      print('✅ FocusBro is ready for deployment');
    } else {
      print('❌ Some tests failed');
      print('🔧 Please fix the failing tests before deployment');
    }
    print(_separator);
  }
}

void main(List<String> args) {
  TestRunner.main(args);
}
