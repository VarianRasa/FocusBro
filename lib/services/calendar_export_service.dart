import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/task_model.dart';

class CalendarExportService {
  Future<int> shareDueTasks(List<Task> tasks) async {
    final dueTasks = tasks.where((task) => task.dueDate != null).toList();
    if (dueTasks.isEmpty) return 0;

    final content = createCalendarContent(dueTasks);
    if (kIsWeb) {
      await Share.share(content, subject: 'FocusBro calendar events');
    } else {
      final directory = await getTemporaryDirectory();
      final file = File(
        '${directory.path}/focusbro_tasks_${DateTime.now().millisecondsSinceEpoch}.ics',
      );
      await file.writeAsString(content, flush: true);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'text/calendar')],
        text: 'FocusBro calendar events',
      );
    }
    return dueTasks.length;
  }

  String createCalendarContent(List<Task> dueTasks) {
    String escape(String value) => value
        .replaceAll('\\', r'\\')
        .replaceAll(';', r'\;')
        .replaceAll(',', r'\,')
        .replaceAll('\r\n', r'\n')
        .replaceAll('\r', r'\n')
        .replaceAll('\n', r'\n');

    String formatDate(DateTime value) =>
        '${value.year.toString().padLeft(4, '0')}'
        '${value.month.toString().padLeft(2, '0')}'
        '${value.day.toString().padLeft(2, '0')}';

    final events = dueTasks.map((task) {
      final start = task.dueDate!.toLocal();
      final end = DateTime(start.year, start.month, start.day + 1);
      final timestamp = DateTime.now()
          .toUtc()
          .toIso8601String()
          .replaceAll('-', '')
          .replaceAll(':', '')
          .split('.')
          .first;
      return [
        'BEGIN:VEVENT',
        'UID:${Uri.encodeComponent(task.id)}@focusbro.local',
        'DTSTAMP:${timestamp}Z',
        'DTSTART;VALUE=DATE:${formatDate(start)}',
        'DTEND;VALUE=DATE:${formatDate(end)}',
        'SUMMARY:${escape(task.title)}',
        if (task.description.isNotEmpty)
          'DESCRIPTION:${escape(task.description)}',
        'END:VEVENT',
      ].join('\r\n');
    }).join('\r\n');

    return [
      'BEGIN:VCALENDAR',
      'VERSION:2.0',
      'PRODID:-//FocusBro//Tasks//EN',
      events,
      'END:VCALENDAR',
      '',
    ].join('\r\n');
  }
}
