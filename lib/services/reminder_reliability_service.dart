import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_observability_service.dart';

enum ReminderLogStatus {
  scheduled,
  skipped,
  delivered,
  failed,
  snoozed,
  retryQueued,
}

class ReminderLogEntry {
  final String id;
  final int? notificationId;
  final String type;
  final ReminderLogStatus status;
  final String title;
  final String? payload;
  final String? reason;
  final DateTime? scheduledFor;
  final DateTime createdAt;
  final Map<String, dynamic> metadata;

  const ReminderLogEntry({
    required this.id,
    required this.type,
    required this.status,
    required this.title,
    required this.createdAt,
    this.notificationId,
    this.payload,
    this.reason,
    this.scheduledFor,
    this.metadata = const {},
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'notificationId': notificationId,
      'type': type,
      'status': status.name,
      'title': title,
      'payload': payload,
      'reason': reason,
      'scheduledFor': scheduledFor?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'metadata': metadata,
    };
  }

  factory ReminderLogEntry.fromJson(Map<String, dynamic> json) {
    final statusName = (json['status'] ?? '').toString();
    final metadata = json['metadata'];

    return ReminderLogEntry(
      id: (json['id'] ?? '').toString(),
      notificationId: _readInt(json['notificationId']),
      type: (json['type'] ?? 'general').toString(),
      status: ReminderLogStatus.values.firstWhere(
        (item) => item.name == statusName,
        orElse: () => ReminderLogStatus.failed,
      ),
      title: (json['title'] ?? 'Reminder').toString(),
      payload: json['payload']?.toString(),
      reason: json['reason']?.toString(),
      scheduledFor: _readDate(json['scheduledFor']),
      createdAt: _readDate(json['createdAt']) ?? DateTime.now(),
      metadata: metadata is Map
          ? Map<String, dynamic>.from(metadata)
          : const <String, dynamic>{},
    );
  }

  static int? _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static DateTime? _readDate(dynamic value) {
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}

class ReminderReliabilitySummary {
  final int total;
  final int scheduled;
  final int failed;
  final int skipped;
  final int delivered;
  final int snoozed;
  final int retryQueued;
  final DateTime generatedAt;

  const ReminderReliabilitySummary({
    required this.total,
    required this.scheduled,
    required this.failed,
    required this.skipped,
    required this.delivered,
    required this.snoozed,
    required this.retryQueued,
    required this.generatedAt,
  });

  int get actionableFailures => failed + retryQueued;

  double get reliabilityRate {
    final attempted = scheduled + failed;
    if (attempted == 0) return 1;
    return scheduled / attempted;
  }

  bool get needsAttention => actionableFailures > 0;

  Map<String, dynamic> toJson() {
    return {
      'total': total,
      'scheduled': scheduled,
      'failed': failed,
      'skipped': skipped,
      'delivered': delivered,
      'snoozed': snoozed,
      'retryQueued': retryQueued,
      'reliabilityRate': reliabilityRate,
      'generatedAt': generatedAt.toIso8601String(),
    };
  }
}

class ReminderReliabilityService {
  static final ReminderReliabilityService _instance =
      ReminderReliabilityService._internal();
  factory ReminderReliabilityService() => _instance;
  static ReminderReliabilityService get instance => _instance;
  ReminderReliabilityService._internal();

  static const String _historyKey = 'reminder_reliability_history_v1';
  static const int _historyLimit = 250;

  SharedPreferences? _prefs;
  final FirebaseObservabilityService _observability =
      FirebaseObservabilityService.instance;

  Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  Future<void> recordScheduled({
    required int notificationId,
    required String type,
    required String title,
    required DateTime scheduledFor,
    String? payload,
    Map<String, dynamic> metadata = const {},
  }) async {
    await _append(
      ReminderLogEntry(
        id: _newId('scheduled'),
        notificationId: notificationId,
        type: type,
        status: ReminderLogStatus.scheduled,
        title: title,
        payload: payload,
        scheduledFor: scheduledFor,
        createdAt: DateTime.now(),
        metadata: metadata,
      ),
    );
  }

  Future<void> recordSkipped({
    required String type,
    required String title,
    required String reason,
    DateTime? scheduledFor,
    String? payload,
    Map<String, dynamic> metadata = const {},
  }) async {
    await _append(
      ReminderLogEntry(
        id: _newId('skipped'),
        type: type,
        status: ReminderLogStatus.skipped,
        title: title,
        payload: payload,
        reason: reason,
        scheduledFor: scheduledFor,
        createdAt: DateTime.now(),
        metadata: metadata,
      ),
    );
  }

  Future<void> recordFailed({
    required int notificationId,
    required String type,
    required String title,
    required String reason,
    DateTime? scheduledFor,
    String? payload,
    Map<String, dynamic> metadata = const {},
  }) async {
    await _append(
      ReminderLogEntry(
        id: _newId('failed'),
        notificationId: notificationId,
        type: type,
        status: ReminderLogStatus.failed,
        title: title,
        payload: payload,
        reason: reason,
        scheduledFor: scheduledFor,
        createdAt: DateTime.now(),
        metadata: metadata,
      ),
    );
  }

  Future<void> recordDelivered({
    required String type,
    required String title,
    int? notificationId,
    String? payload,
    Map<String, dynamic> metadata = const {},
  }) async {
    await _append(
      ReminderLogEntry(
        id: _newId('delivered'),
        notificationId: notificationId,
        type: type,
        status: ReminderLogStatus.delivered,
        title: title,
        payload: payload,
        createdAt: DateTime.now(),
        metadata: metadata,
      ),
    );
  }

  Future<void> recordSnoozed({
    required String taskId,
    required String title,
    required DateTime snoozedUntil,
    required Duration duration,
  }) async {
    await _append(
      ReminderLogEntry(
        id: _newId('snoozed'),
        type: 'task',
        status: ReminderLogStatus.snoozed,
        title: title,
        payload: 'task_alert:$taskId',
        reason: 'Snoozed for ${duration.inMinutes} minutes',
        scheduledFor: snoozedUntil,
        createdAt: DateTime.now(),
        metadata: {
          'taskId': taskId,
          'durationMinutes': duration.inMinutes,
        },
      ),
    );
  }

  Future<void> markRetryQueued(ReminderLogEntry entry) async {
    await _append(
      ReminderLogEntry(
        id: _newId('retry'),
        notificationId: entry.notificationId,
        type: entry.type,
        status: ReminderLogStatus.retryQueued,
        title: entry.title,
        payload: entry.payload,
        reason: 'Retry queued from failed reminder ${entry.id}',
        scheduledFor: entry.scheduledFor,
        createdAt: DateTime.now(),
        metadata: entry.metadata,
      ),
    );
  }

  Future<List<ReminderLogEntry>> getHistory({int limit = 100}) async {
    await initialize();
    final raw = _prefs!.getStringList(_historyKey) ?? const <String>[];
    final entries = <ReminderLogEntry>[];

    for (final item in raw) {
      try {
        final decoded = jsonDecode(item);
        if (decoded is Map) {
          entries.add(
            ReminderLogEntry.fromJson(Map<String, dynamic>.from(decoded)),
          );
        }
      } catch (_) {
        // Ignore malformed historical entries.
      }
    }

    entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return entries.take(limit).toList();
  }

  Future<List<ReminderLogEntry>> getFailedReminders({int limit = 20}) async {
    final history = await getHistory(limit: _historyLimit);
    return history
        .where((entry) => entry.status == ReminderLogStatus.failed)
        .take(limit)
        .toList();
  }

  Future<ReminderReliabilitySummary> getSummary({int days = 14}) async {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    final history = await getHistory(limit: _historyLimit);
    final recent =
        history.where((entry) => entry.createdAt.isAfter(cutoff)).toList();

    int count(ReminderLogStatus status) {
      return recent.where((entry) => entry.status == status).length;
    }

    return ReminderReliabilitySummary(
      total: recent.length,
      scheduled: count(ReminderLogStatus.scheduled),
      failed: count(ReminderLogStatus.failed),
      skipped: count(ReminderLogStatus.skipped),
      delivered: count(ReminderLogStatus.delivered),
      snoozed: count(ReminderLogStatus.snoozed),
      retryQueued: count(ReminderLogStatus.retryQueued),
      generatedAt: DateTime.now(),
    );
  }

  Future<void> clearHistory() async {
    await initialize();
    await _prefs!.remove(_historyKey);
  }

  Future<void> _append(ReminderLogEntry entry) async {
    await initialize();
    final raw = _prefs!.getStringList(_historyKey) ?? const <String>[];
    final updated = [jsonEncode(entry.toJson()), ...raw].take(_historyLimit);
    await _prefs!.setStringList(_historyKey, updated.toList());
    await _recordObservability(entry);
  }

  String _newId(String prefix) {
    return '${prefix}_${DateTime.now().microsecondsSinceEpoch}';
  }

  Future<void> _recordObservability(ReminderLogEntry entry) async {
    final eventName = switch (entry.status) {
      ReminderLogStatus.scheduled => 'reminder_scheduled',
      ReminderLogStatus.skipped => 'reminder_skipped',
      ReminderLogStatus.delivered => 'reminder_sent',
      ReminderLogStatus.failed => 'reminder_failed',
      ReminderLogStatus.snoozed => 'reminder_snoozed',
      ReminderLogStatus.retryQueued => 'reminder_retry_scheduled',
    };

    await _observability.logEvent(eventName, {
      'notification_id': entry.notificationId,
      'type': entry.type,
      'status': entry.status.name,
      'duration_minutes': entry.metadata['durationMinutes'],
      'scheduled_delay_minutes': _scheduledDelayMinutes(entry.scheduledFor),
    });

    if (entry.status == ReminderLogStatus.failed) {
      await _observability.recordNonFatal(
        'reminder_failed',
        Exception('Reminder failed'),
        null,
        {
          'notification_id': entry.notificationId,
          'type': entry.type,
          'status': entry.status.name,
          'error_code': 'reminder_schedule_failed',
        },
      );
    }
  }

  int? _scheduledDelayMinutes(DateTime? scheduledFor) {
    if (scheduledFor == null) return null;
    return scheduledFor.difference(DateTime.now()).inMinutes;
  }
}
