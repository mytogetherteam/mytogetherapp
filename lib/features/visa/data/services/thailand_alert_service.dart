import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Thailand Visa Categories for Tailored Legal Alerts
enum ThailandVisaCategory {
  mouWork,   // MOU / Non-B (Work Permit)
  dtv,       // DTV (Destination Thailand Visa)
  education, // Non-ED (Education / Language)
  tourist,   // Tourist / Visa-Exempt (60 Days)
  nonO,      // Non-O (Family / Retirement)
  ltr,       // LTR (Long-Term Resident)
}

/// Compliance Urgency Status for dynamic alerts
enum ComplianceUrgency {
  safe,      // Safe (> 30 days)
  warning,   // Needs attention (15 - 30 days)
  urgent,    // Critical action (< 15 days)
  overdue,   // Overdue / Expired
}

/// Service managing Thailand 90-Day (TM.47) and Visa Compliance Reminders
class ThailandAlertService {
  static final ThailandAlertService instance = ThailandAlertService._();
  ThailandAlertService._();

  static const String _kChannelId = 'thailand_compliance_channel_v1';
  static const String _kChannelName = 'Thailand Visa & Legal Compliance';
  static const String _kChannelDesc =
      'Important reminders for 90-day reports, visa extensions, and work permits.';

  // Notification IDs
  static const int idTm47WindowOpen = 9001; // Day 75 (15 days before)
  static const int idTm47Urgent = 9002;     // Day 83 (7 days before)
  static const int idTm47Due = 9003;        // Day 90 (Due date)
  static const int idTm47Grace = 9004;      // Day 93 (3 days in grace)
  static const int idTm47Test = 9005;

  static const int idVisa30Days = 9011;
  static const int idVisa14Days = 9012;
  static const int idVisa3Days = 9013;
  static const int idVisaTest = 9014;

  static const int idWp30Days = 9021;
  static const int idWp14Days = 9022;
  static const int idWp3Days = 9023;

  // SharedPreferences Keys
  static const String keyTm47Reminder = 'thailand_tm47_reminder_enabled';
  static const String keySelectedVisa = 'thailand_selected_visa_category';
  static const String keyVisaExpiryMs = 'thailand_visa_expiry_ms';
  static const String keyWpExpiryMs = 'thailand_work_permit_expiry_ms';
  static const String keyVisaReminder = 'thailand_visa_reminder_enabled';

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  bool _isTzInitialized = false;

  Future<void> _ensureTz() async {
    if (!_isTzInitialized) {
      try {
        tz_data.initializeTimeZones();
        _isTzInitialized = true;
      } catch (e) {
        if (kDebugMode) debugPrint('ThailandAlertService TZ init error: $e');
      }
    }
  }

  NotificationDetails _buildDetails() {
    const android = AndroidNotificationDetails(
      _kChannelId,
      _kChannelName,
      channelDescription: _kChannelDesc,
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/launcher_icon',
      playSound: true,
      enableVibration: true,
      showWhen: true,
    );
    const ios = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    return const NotificationDetails(android: android, iOS: ios);
  }

  // ==========================================
  // 1. TM.47 90-DAY REMINDER SYSTEM
  // ==========================================

  Future<bool> isTm47ReminderEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(keyTm47Reminder) ?? true;
    } catch (_) {
      return true;
    }
  }

  Future<void> setTm47ReminderEnabled(bool enabled, {DateTime? baseDate}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(keyTm47Reminder, enabled);
      if (enabled && baseDate != null) {
        await scheduleTm47Notifications(baseDate);
      } else if (!enabled) {
        await cancelTm47Notifications();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error setTm47ReminderEnabled: $e');
    }
  }

  /// Schedules 4 real-world notification milestones for the 90-day report
  Future<void> scheduleTm47Notifications(DateTime baseDate) async {
    try {
      await _ensureTz();
      await cancelTm47Notifications();

      final dueDate = DateTime(baseDate.year, baseDate.month, baseDate.day)
          .add(const Duration(days: 90));
      final now = DateTime.now();

      // Milestone 1: 15 days before (Window opens - Day 75) at 09:00 AM
      final m1Time = dueDate.subtract(const Duration(days: 15)).copyWith(
            hour: 9,
            minute: 0,
            second: 0,
          );
      if (m1Time.isAfter(now)) {
        await _scheduleSingle(
          id: idTm47WindowOpen,
          scheduledTime: m1Time,
          title: '🔔 90-Day (TM.47) တင်သွင်းရန် ရက်စတင်ပါပြီ',
          body:
              'သတ်မှတ်ရက် မတိုင်မီ ၁၅ ရက်ကြိုတင်၍ အွန်လိုင်း (tm47.immigration.go.th) မှ ယခုပင် စတင်တင်သွင်းနိုင်ပါပြီ။',
          payload: 'tm47_reminder_window_open',
        );
      }

      // Milestone 2: 7 days before (Urgent reminder - Day 83) at 09:00 AM
      final m2Time = dueDate.subtract(const Duration(days: 7)).copyWith(
            hour: 9,
            minute: 0,
            second: 0,
          );
      if (m2Time.isAfter(now)) {
        await _scheduleSingle(
          id: idTm47Urgent,
          scheduledTime: m2Time,
          title: '⚠️ 90-Day တင်သွင်းရန် ၇ ရက်သာ လိုပါတော့သည်',
          body:
              'ဒဏ်ကြေး ဘတ် ၂,၀၀၀ မကျသင့်စေရန် သတ်မှတ်ရက်မတိုင်မီ အချိန်မီ တင်သွင်းပါ။',
          payload: 'tm47_reminder_urgent',
        );
      }

      // Milestone 3: Due date (Day 90) at 09:00 AM
      final m3Time = dueDate.copyWith(hour: 9, minute: 0, second: 0);
      if (m3Time.isAfter(now)) {
        await _scheduleSingle(
          id: idTm47Due,
          scheduledTime: m3Time,
          title: '🚨 ယနေ့သည် 90-Day နောက်ဆုံးရက် ဖြစ်ပါသည်',
          body:
              'ယနေ့ နောက်ဆုံးထား၍ အွန်လိုင်း သို့မဟုတ် လ.ဝ.က တွင် မပျက်မကွက် သတင်းပို့ပါ။',
          payload: 'tm47_reminder_due_date',
        );
      }

      // Milestone 4: Grace Period (3 days in grace - Day 93) at 09:00 AM
      final m4Time = dueDate.add(const Duration(days: 3)).copyWith(
            hour: 9,
            minute: 0,
            second: 0,
          );
      if (m4Time.isAfter(now)) {
        await _scheduleSingle(
          id: idTm47Grace,
          scheduledTime: m4Time,
          title: '⏳ ၇ ရက် သက်ညှာခွင့် (Grace Period) အတွင်း ရောက်ရှိနေပါပြီ',
          body:
              'လ.ဝ.က ရုံးသို့ လူကိုယ်တိုင် အမြန်ဆုံး သွားရောက်တင်သွင်းပါ။ ရက်ကျော်ပါက ဒဏ်ကြေး ၂,၀၀၀ ဘတ် ကျသင့်ပါမည်။',
          payload: 'tm47_reminder_grace_period',
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error scheduling TM47 notifications: $e');
    }
  }

  Future<void> _scheduleSingle({
    required int id,
    required DateTime scheduledTime,
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      final tzTime = tz.TZDateTime.from(scheduledTime, tz.local);
      await _notifications.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: tzTime,
        notificationDetails: _buildDetails(),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: payload,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to schedule single noti $id: $e');
    }
  }

  Future<void> cancelTm47Notifications() async {
    try {
      await _notifications.cancel(id: idTm47WindowOpen);
      await _notifications.cancel(id: idTm47Urgent);
      await _notifications.cancel(id: idTm47Due);
      await _notifications.cancel(id: idTm47Grace);
    } catch (_) {}
  }

  /// Sends a real, immediate test notification to verify sounds & banner
  Future<void> sendTestNotification({
    required String title,
    required String body,
  }) async {
    try {
      await _notifications.show(
        id: idTm47Test,
        title: title,
        body: body,
        notificationDetails: _buildDetails(),
        payload: json.encode({'type': 'compliance_test'}),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('Failed sendTestNotification: $e');
    }
  }

  // ==========================================
  // 2. VISA CATEGORY & COMPLIANCE ALERTS
  // ==========================================

  Future<ThailandVisaCategory> getSelectedCategory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final idx = prefs.getInt(keySelectedVisa);
      if (idx != null && idx >= 0 && idx < ThailandVisaCategory.values.length) {
        return ThailandVisaCategory.values[idx];
      }
    } catch (_) {}
    return ThailandVisaCategory.mouWork; // Default to MOU/Work
  }

  Future<void> setSelectedCategory(ThailandVisaCategory cat) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(keySelectedVisa, cat.index);
    } catch (_) {}
  }

  Future<DateTime?> getVisaExpiryDate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ms = prefs.getInt(keyVisaExpiryMs);
      if (ms != null) return DateTime.fromMillisecondsSinceEpoch(ms);
    } catch (_) {}
    return null;
  }

  Future<void> setVisaExpiryDate(DateTime? date) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (date != null) {
        await prefs.setInt(keyVisaExpiryMs, date.millisecondsSinceEpoch);
        final enabled = await isVisaReminderEnabled();
        if (enabled) {
          await scheduleVisaExpiryNotifications(date);
        }
      } else {
        await prefs.remove(keyVisaExpiryMs);
        await cancelVisaExpiryNotifications();
      }
    } catch (_) {}
  }

  Future<DateTime?> getWorkPermitExpiryDate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ms = prefs.getInt(keyWpExpiryMs);
      if (ms != null) return DateTime.fromMillisecondsSinceEpoch(ms);
    } catch (_) {}
    return null;
  }

  Future<void> setWorkPermitExpiryDate(DateTime? date) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (date != null) {
        await prefs.setInt(keyWpExpiryMs, date.millisecondsSinceEpoch);
      } else {
        await prefs.remove(keyWpExpiryMs);
      }
    } catch (_) {}
  }

  Future<bool> isVisaReminderEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(keyVisaReminder) ?? true;
    } catch (_) {
      return true;
    }
  }

  Future<void> setVisaReminderEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(keyVisaReminder, enabled);
      if (enabled) {
        final date = await getVisaExpiryDate();
        if (date != null) await scheduleVisaExpiryNotifications(date);
      } else {
        await cancelVisaExpiryNotifications();
      }
    } catch (_) {}
  }

  Future<void> scheduleVisaExpiryNotifications(DateTime expiryDate) async {
    try {
      await _ensureTz();
      await cancelVisaExpiryNotifications();

      final now = DateTime.now();

      // 30 days before
      final t30 = expiryDate.subtract(const Duration(days: 30)).copyWith(hour: 9);
      if (t30.isAfter(now)) {
        await _scheduleSingle(
          id: idVisa30Days,
          scheduledTime: t30,
          title: '⚠️ ဗီဇာ/နေထိုင်ခွင့် သက်တမ်းကုန်ရန် ၃၀ ရက်သာ လိုပါတော့သည်',
          body:
              'သက်တမ်းမကုန်မီ ကြိုတင်ပြင်ဆင်၍ လ.ဝ.က တွင် သက်တမ်းတိုးပါ။ ရက်ကျော်ပါက ဒဏ်ကြေး တစ်ရက်လျှင် ၅၀၀ ဘတ် ကျသင့်ပါမည်။',
          payload: 'visa_reminder_30d',
        );
      }

      // 14 days before
      final t14 = expiryDate.subtract(const Duration(days: 14)).copyWith(hour: 9);
      if (t14.isAfter(now)) {
        await _scheduleSingle(
          id: idVisa14Days,
          scheduledTime: t14,
          title: '🚨 ဗီဇာ သက်တမ်းတိုးရန် ၁၄ ရက်သာ လိုပါတော့သည်',
          body:
              'စာရွက်စာတမ်းများ ပြည့်စုံစွာ ယူဆောင်၍ အမြန်ဆုံး သက်တမ်းတိုးပါ။',
          payload: 'visa_reminder_14d',
        );
      }

      // 3 days before
      final t3 = expiryDate.subtract(const Duration(days: 3)).copyWith(hour: 9);
      if (t3.isAfter(now)) {
        await _scheduleSingle(
          id: idVisa3Days,
          scheduledTime: t3,
          title: '⚡ အရေးကြီး: ၃ ရက်အတွင်း မပျက်မကွက် သက်တမ်းတိုးပါ',
          body:
              'Overstay ဖြစ်ပါက ဒဏ်ကြေးနှင့် နိုင်ငံတွင်း ပြန်လည်ဝင်ရောက်ခွင့် ပိတ်ပင်ခံရနိုင်ပါသည်။',
          payload: 'visa_reminder_3d',
        );
      }
    } catch (_) {}
  }

  Future<void> cancelVisaExpiryNotifications() async {
    try {
      await _notifications.cancel(id: idVisa30Days);
      await _notifications.cancel(id: idVisa14Days);
      await _notifications.cancel(id: idVisa3Days);
    } catch (_) {}
  }
}
