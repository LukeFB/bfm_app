import 'dart:async';

import 'package:bfm_app/models/alert_model.dart';
import 'package:bfm_app/repositories/alert_repository.dart';
import 'package:bfm_app/repositories/recurring_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Schedules day-before and day-of notifications for manual alerts.
class AlertNotificationService {
  AlertNotificationService._internal();

  static final AlertNotificationService instance =
      AlertNotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialised = false;
  bool _timezoneInitialised = false;

  static const _channelId = 'bfm_alerts_channel';
  static const _channelName = 'Upcoming alerts';
  static const _channelDescription =
      'Reminders for manual alerts and upcoming payments.';
  static const _reminderHour = 9;
  static const _reminderMinute = 0;

  Future<void> init() async {
    if (_initialised) return;

    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    await _plugin.initialize(initializationSettings);
    await _configureTimeZone();
    await _requestPermissions();

    _initialised = true;
  }

  Future<void> _requestPermissions() async {
    final androidImplementation = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidImplementation?.requestNotificationsPermission();

    final iosImplementation = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    await iosImplementation?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );

    final macImplementation = _plugin
        .resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin
        >();
    await macImplementation?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  Future<void> _configureTimeZone() async {
    if (_timezoneInitialised) return;
    tz.initializeTimeZones();
    try {
      final timezoneInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezoneInfo.identifier));
    } catch (err, stack) {
      debugPrint('AlertNotificationService: timezone lookup failed: $err');
      debugPrint('$stack');
      tz.setLocalLocation(tz.getLocation('UTC'));
    }
    _timezoneInitialised = true;
  }

  /// Clears pending alert notifications and rebuilds the schedule for all alerts.
  /// Enriches recurring alerts with their due dates from the recurring transaction.
  Future<void> resyncScheduledAlerts() async {
    await init();
    await _plugin.cancelAll();
    
    final alerts = await AlertRepository.getAll();
    final activeAlerts = alerts.where((a) => a.isActive).toList();
    
    // Get recurring transaction IDs to look up their due dates
    final recurringIds = activeAlerts
        .map((a) => a.recurringTransactionId)
        .whereType<int>()
        .toSet();
    
    // Look up recurring transactions to get their next due dates
    Map<int, DateTime?> recurringDueDates = {};
    if (recurringIds.isNotEmpty) {
      final recurringList = await RecurringRepository.getByIds(recurringIds);
      for (final r in recurringList) {
        if (r.id != null) {
          recurringDueDates[r.id!] = DateTime.tryParse(r.nextDueDate);
        }
      }
    }
    
    // Schedule notifications for all active alerts
    for (final alert in activeAlerts) {
      AlertModel enrichedAlert = alert;
      
      // Enrich recurring alerts with due date from recurring transaction
      if (alert.recurringTransactionId != null && alert.dueDate == null) {
        final recurringDueDate = recurringDueDates[alert.recurringTransactionId];
        if (recurringDueDate != null) {
          enrichedAlert = alert.copyWith(dueDate: recurringDueDate);
        }
      }
      
      await schedule(enrichedAlert);
    }
  }

  /// Schedules notifications for the provided alert (if it has a due date).
  Future<void> schedule(AlertModel alert) async {
    await init();
    if (alert.id == null || alert.dueDate == null || !alert.isActive) {
      return;
    }
    await cancel(alert.id!); // prevent duplicates when editing

    final entries = _buildEntries(alert);
    final now = DateTime.now();

    for (final entry in entries) {
      final fireDate = _nextFireDate(entry, now, alert.dueDate!);
      if (fireDate == null) continue;
      try {
        await _plugin.zonedSchedule(
          entry.id,
          entry.title,
          entry.body,
          tz.TZDateTime.from(fireDate, tz.local),
          _notificationDetails(),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        );
      } catch (err, stack) {
        debugPrint(
          'AlertNotificationService: failed to schedule ${entry.id}. $err',
        );
        debugPrint('$stack');
      }
    }
  }

  Future<void> cancel(int alertId) async {
    await init();
    for (final moment in _ReminderMoment.values) {
      await _plugin.cancel(_notificationId(alertId, moment));
    }
  }

  NotificationDetails _notificationDetails() {
    const android = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
    );
    const darwin = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    return const NotificationDetails(
      android: android,
      iOS: darwin,
      macOS: darwin,
    );
  }

  List<_ReminderEntry> _buildEntries(AlertModel alert) {
    final due = alert.dueDate!;
    final dueMorning = DateTime(
      due.year,
      due.month,
      due.day,
      _reminderHour,
      _reminderMinute,
    );
    final title = 'Reminder: ${alert.title}';
    final friendlyDate = _friendlyDate(due);
    return [
      _ReminderEntry(
        id: _notificationId(alert.id!, _ReminderMoment.dayBefore),
        fireDate: dueMorning.subtract(const Duration(days: 1)),
        title: title,
        body: '${alert.title} is due tomorrow ($friendlyDate).',
        moment: _ReminderMoment.dayBefore,
      ),
      _ReminderEntry(
        id: _notificationId(alert.id!, _ReminderMoment.dayOf),
        fireDate: dueMorning,
        title: title,
        body: '${alert.title} is due today.',
        moment: _ReminderMoment.dayOf,
      ),
    ];
  }

  int _notificationId(int alertId, _ReminderMoment moment) {
    return alertId * 10 + moment.index;
  }

  String _friendlyDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final weekday = weekdays[date.weekday - 1];
    final month = months[date.month - 1];
    return '$weekday ${date.day} $month';
  }

  DateTime? _nextFireDate(
    _ReminderEntry entry,
    DateTime now,
    DateTime dueDate,
  ) {
    if (entry.fireDate.isAfter(now)) return entry.fireDate;
    final today = DateTime(now.year, now.month, now.day);
    final dueDay = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final dayBefore = dueDay.subtract(const Duration(days: 1));

    if (entry.moment == _ReminderMoment.dayOf && _isSameDate(today, dueDay)) {
      return now.add(const Duration(minutes: 1));
    }

    if (entry.moment == _ReminderMoment.dayBefore &&
        _isSameDate(today, dayBefore)) {
      return now.add(const Duration(minutes: 1));
    }

    return null;
  }

  bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

enum _ReminderMoment { dayBefore, dayOf }

class _ReminderEntry {
  final int id;
  final DateTime fireDate;
  final String title;
  final String body;
  final _ReminderMoment moment;

  const _ReminderEntry({
    required this.id,
    required this.fireDate,
    required this.title,
    required this.body,
    required this.moment,
  });
}
