import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:csv/csv.dart';

/// Enhanced Export Service for FocusBro analytics and data
class ExportService {
  static final ExportService _instance = ExportService._internal();
  factory ExportService() => _instance;
  ExportService._internal();

  /// Export data as JSON format
  Future<bool> exportAsJSON({
    required Map<String, dynamic> data,
    required String fileName,
    String? customPath,
  }) async {
    try {
      final jsonString = const JsonEncoder.withIndent('  ').convert(data);
      return await _saveAndShareFile(
        content: jsonString,
        fileName: fileName.endsWith('.json') ? fileName : '$fileName.json',
        mimeType: 'application/json',
        customPath: customPath,
      );
    } catch (e) {
      debugPrint('ExportService: JSON export failed: $e');
      return false;
    }
  }

  /// Export data as CSV format
  Future<bool> exportAsCSV({
    required List<List<dynamic>> data,
    required String fileName,
    String? customPath,
  }) async {
    try {
      final csvString = const ListToCsvConverter().convert(data);
      return await _saveAndShareFile(
        content: csvString,
        fileName: fileName.endsWith('.csv') ? fileName : '$fileName.csv',
        mimeType: 'text/csv',
        customPath: customPath,
      );
    } catch (e) {
      debugPrint('ExportService: CSV export failed: $e');
      return false;
    }
  }

  /// Export data as formatted text report
  Future<bool> exportAsTextReport({
    required String content,
    required String fileName,
    String? customPath,
  }) async {
    try {
      return await _saveAndShareFile(
        content: content,
        fileName: fileName.endsWith('.txt') ? fileName : '$fileName.txt',
        mimeType: 'text/plain',
        customPath: customPath,
      );
    } catch (e) {
      debugPrint('ExportService: Text export failed: $e');
      return false;
    }
  }

  /// Export analytics data in multiple formats
  Future<Map<String, bool>> exportAnalyticsData({
    required Map<String, dynamic> analyticsData,
    required List<String> formats, // ['json', 'csv', 'txt']
    String? baseFileName,
  }) async {
    final results = <String, bool>{};
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final baseName = baseFileName ?? 'focusbro_analytics_$timestamp';

    for (final format in formats) {
      switch (format.toLowerCase()) {
        case 'json':
          results['json'] = await exportAsJSON(
            data: analyticsData,
            fileName: '${baseName}.json',
          );
          break;
        case 'csv':
          final csvData = convertAnalyticsToCSV(analyticsData);
          results['csv'] = await exportAsCSV(
            data: csvData,
            fileName: '${baseName}.csv',
          );
          break;
        case 'txt':
          final textReport = generateAnalyticsTextReport(analyticsData);
          results['txt'] = await exportAsTextReport(
            content: textReport,
            fileName: '${baseName}.txt',
          );
          break;
      }
    }

    return results;
  }

  /// Convert analytics data to CSV format
  List<List<dynamic>> convertAnalyticsToCSV(Map<String, dynamic> data) {
    final csvData = <List<dynamic>>[];

    // Headers
    csvData.add(['Metric', 'Value', 'Category', 'Date', 'Description']);

    final timestamp = DateTime.now().toIso8601String();

    // Focus Statistics
    final focusData = data['focus'] ?? {};
    csvData.add([
      'Total Sessions',
      focusData['totalSessions'] ?? 0,
      'Focus',
      timestamp,
      'Total number of focus sessions'
    ]);
    csvData.add([
      'Total Focus Time',
      focusData['totalFocusTime'] ?? 0,
      'Focus',
      timestamp,
      'Total focus time in seconds'
    ]);
    csvData.add([
      'Completion Rate',
      focusData['completionRate'] ?? 0,
      'Focus',
      timestamp,
      'Session completion rate (0-1)'
    ]);
    csvData.add([
      'Average Session',
      focusData['averageSession'] ?? 0,
      'Focus',
      timestamp,
      'Average session duration in seconds'
    ]);

    // Streak Information
    final streakData = data['streak'] ?? {};
    csvData.add([
      'Current Streak',
      streakData['currentStreak'] ?? 0,
      'Streak',
      timestamp,
      'Current consecutive days'
    ]);
    csvData.add([
      'Longest Streak',
      streakData['longestStreak'] ?? 0,
      'Streak',
      timestamp,
      'Longest streak achieved'
    ]);

    // Productivity Insights
    final insights = data['insights'] ?? {};
    csvData.add([
      'Productivity Score',
      insights['score'] ?? 0,
      'Insights',
      timestamp,
      'Overall productivity score (0-10)'
    ]);
    csvData.add([
      'Peak Hour',
      insights['peakHour'] ?? 'N/A',
      'Insights',
      timestamp,
      'Most productive hour of day'
    ]);

    // Weekly Summary
    final weekly = data['weekly'] ?? {};
    if (weekly['dailyStats'] is List) {
      final dailyStats = weekly['dailyStats'] as List;
      for (int i = 0; i < dailyStats.length; i++) {
        final dayData = dailyStats[i];
        final dayName = [
          'Monday',
          'Tuesday',
          'Wednesday',
          'Thursday',
          'Friday',
          'Saturday',
          'Sunday'
        ][i % 7];
        csvData.add([
          'Daily Sessions $dayName',
          dayData['sessions'] ?? 0,
          'Weekly',
          timestamp,
          'Sessions for $dayName'
        ]);
        csvData.add([
          'Daily Duration $dayName',
          dayData['duration'] ?? 0,
          'Weekly',
          timestamp,
          'Duration for $dayName in seconds'
        ]);
      }
    }

    return csvData;
  }

  /// Generate formatted text report from analytics data
  String generateAnalyticsTextReport(Map<String, dynamic> data) {
    final buffer = StringBuffer();
    final now = DateTime.now();
    final dateStr = '${now.day}/${now.month}/${now.year}';
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    buffer.writeln('📊 FocusBro Analytics Report');
    buffer.writeln('=' * 50);
    buffer.writeln('Generated: $dateStr at $timeStr');
    buffer.writeln('');

    // Focus Statistics
    final focusData = data['focus'] ?? {};
    buffer.writeln('🎯 FOCUS STATISTICS');
    buffer.writeln('-' * 30);
    buffer.writeln('Total Sessions: ${focusData['totalSessions'] ?? 0}');
    buffer.writeln(
        'Total Focus Time: ${_formatDuration(focusData['totalFocusTime'] ?? 0)}');
    buffer.writeln(
        'Completion Rate: ${((focusData['completionRate'] ?? 0) * 100).toStringAsFixed(1)}%');
    buffer.writeln(
        'Average Session: ${_formatDuration(focusData['averageSession'] ?? 0)}');
    buffer.writeln('');

    // Streak Information
    final streakData = data['streak'] ?? {};
    buffer.writeln('🔥 STREAK INFORMATION');
    buffer.writeln('-' * 30);
    buffer.writeln('Current Streak: ${streakData['currentStreak'] ?? 0} days');
    buffer.writeln('Longest Streak: ${streakData['longestStreak'] ?? 0} days');
    buffer.writeln('');

    // Productivity Insights
    final insights = data['insights'] ?? {};
    buffer.writeln('💡 PRODUCTIVITY INSIGHTS');
    buffer.writeln('-' * 30);
    buffer.writeln(
        'Productivity Score: ${(insights['score'] ?? 0).toStringAsFixed(1)}/10');
    buffer.writeln(
        'Peak Performance Hour: ${insights['peakHour'] ?? 'Not determined'}');
    buffer.writeln('');

    // Weekly Summary
    final weekly = data['weekly'] ?? {};
    buffer.writeln('📅 WEEKLY SUMMARY');
    buffer.writeln('-' * 30);
    if (weekly['dailyStats'] is List) {
      final dailyStats = weekly['dailyStats'] as List;
      final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      for (int i = 0; i < dailyStats.length && i < dayNames.length; i++) {
        final dayData = dailyStats[i];
        buffer.writeln(
            '${dayNames[i]}: ${dayData['sessions'] ?? 0} sessions, ${_formatDuration(dayData['duration'] ?? 0)}');
      }
    }
    buffer.writeln('');

    // Recommendations
    buffer.writeln('🎯 RECOMMENDATIONS');
    buffer.writeln('-' * 30);
    buffer.writeln('• Maintain consistent daily sessions for better streaks');
    buffer.writeln('• Focus on your peak performance hours');
    buffer.writeln('• Aim for 80%+ completion rate for optimal productivity');
    buffer.writeln('• Take regular breaks to maintain focus quality');
    buffer.writeln('');

    buffer.writeln('Generated by FocusBro - Your Productivity Companion');

    return buffer.toString();
  }

  /// Format duration from seconds to human readable format
  String _formatDuration(int seconds) {
    if (seconds < 60) return '${seconds}s';
    if (seconds < 3600) return '${(seconds / 60).toStringAsFixed(1)}m';
    return '${(seconds / 3600).toStringAsFixed(1)}h';
  }

  /// Save file and share it
  Future<bool> _saveAndShareFile({
    required String content,
    required String fileName,
    required String mimeType,
    String? customPath,
  }) async {
    try {
      if (kIsWeb) {
        // For web, trigger download
        await _downloadFileWeb(content, fileName, mimeType);
        return true;
      } else {
        // For mobile/desktop, save and share
        final file = await _saveToFile(content, fileName, customPath);
        if (file != null) {
          await Share.shareXFiles(
            [XFile(file.path)],
            text: 'FocusBro Analytics Export: $fileName',
          );
          return true;
        }
      }
      return false;
    } catch (e) {
      debugPrint('ExportService: Save and share failed: $e');
      return false;
    }
  }

  /// Save content to file
  Future<File?> _saveToFile(
      String content, String fileName, String? customPath) async {
    try {
      Directory directory;
      if (customPath != null) {
        directory = Directory(customPath);
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      final file = File('${directory.path}/$fileName');
      await file.writeAsString(content);
      return file;
    } catch (e) {
      debugPrint('ExportService: Save to file failed: $e');
      return null;
    }
  }

  /// Download file for web platform
  Future<void> _downloadFileWeb(
      String content, String fileName, String mimeType) async {
    // This would be implemented with web-specific download functionality
    // For now, we'll copy to clipboard as fallback
    await Clipboard.setData(ClipboardData(text: content));
    debugPrint('ExportService: Content copied to clipboard (web fallback)');
  }

  /// Get export statistics
  Future<Map<String, dynamic>> getExportStatistics() async {
    // This could track export usage statistics
    return {
      'totalExports': 0,
      'lastExportDate': null,
      'popularFormats': ['json', 'csv', 'txt'],
      'exportSizes': {},
    };
  }
}
