import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/attendance_automation_log_model.dart';
import '../models/attendance_model.dart';
import '../models/user_model.dart';
import '../../features/company_admin/models/shift_model.dart';

/// Centralized service handling Attendance Automation Rules:
/// - Morning Check-in Reminders
/// - Auto Absent Marking
/// - Evening Check-out Reminders & Field Employee Verification
/// - System Auto Checkout
/// - Notification Routing & Audit Logging
class AttendanceAutomationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final Set<String> _executedTriggersToday = {};

  /// Evaluates attendance automation rules for all active employees in a company for today.
  static Future<void> evaluateCompanyAutomation(String companyId) async {
    try {
      final now = DateTime.now();
      final todayStr = DateFormat('yyyy-MM-dd').format(now);

      // Fetch active employees
      final empSnap = await _firestore
          .collection('users')
          .where('companyId', isEqualTo: companyId)
          .where('status', isEqualTo: 'active')
          .get();

      if (empSnap.docs.isEmpty) return;

      final employees = empSnap.docs.map((d) => UserModel.fromMap(d.data())).toList();

      // Fetch company shifts
      final shiftSnap = await _firestore
          .collection('shifts')
          .where('companyId', isEqualTo: companyId)
          .get();

      final shifts = shiftSnap.docs.map((d) => ShiftModel.fromMap(d.data())).toList();
      final shiftMap = {for (var s in shifts) s.shiftId: s};

      // Fetch today's attendance records
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

      final attSnap = await _firestore
          .collection('attendance')
          .where('companyId', isEqualTo: companyId)
          .where('checkInTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('checkInTime', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
          .get();

      final attendanceList = attSnap.docs.map((d) => AttendanceModel.fromMap(d.data())).toList();
      final attMap = {for (var a in attendanceList) a.employeeId: a};

      for (final emp in employees) {
        // Skip super admins or company admins without shifts if not applicable
        final shift = emp.shiftId != null ? shiftMap[emp.shiftId] : null;

        // Parse shift start and end times for today
        DateTime shiftStart = _getShiftDateTime(now, shift?.startTime ?? '09:00 AM');
        DateTime shiftEnd = _getShiftDateTime(now, shift?.endTime ?? '06:00 PM');

        if (shiftEnd.isBefore(shiftStart)) {
          // Night shift crossing midnight
          shiftEnd = shiftEnd.add(const Duration(days: 1));
        }

        final att = attMap[emp.uid];

        // 1. MORNING CHECK-IN REMINDER
        if (emp.enableCheckInReminder && att == null) {
          final reminderTime = shiftStart.add(Duration(minutes: emp.checkInGraceMinutes));
          final triggerKey = '${emp.uid}_${todayStr}_checkin_reminder';

          if (now.isAfter(reminderTime) && !_executedTriggersToday.contains(triggerKey)) {
            _executedTriggersToday.add(triggerKey);
            await _sendCheckInReminder(emp, shiftStart);
          }
        }

        // 2. AUTO ABSENT LOGIC
        if (emp.enableAutoAbsent && att == null) {
          final autoAbsentTime = shiftStart.add(Duration(minutes: emp.autoAbsentGraceMinutes));
          final triggerKey = '${emp.uid}_${todayStr}_auto_absent';

          if (now.isAfter(autoAbsentTime) && !_executedTriggersToday.contains(triggerKey)) {
            _executedTriggersToday.add(triggerKey);
            await _performAutoAbsent(emp, shiftStart);
          }
        }

        // 3. EVENING CHECK-OUT REMINDER & FIELD EMPLOYEE VERIFICATION
        if (att != null && att.checkOutTime == null && att.status.toLowerCase() != 'absent') {
          final checkoutReminderTime = shiftEnd.add(Duration(minutes: emp.checkOutGraceMinutes));
          final triggerKey = '${emp.uid}_${todayStr}_checkout_reminder';

          if (now.isAfter(checkoutReminderTime) && !_executedTriggersToday.contains(triggerKey)) {
            _executedTriggersToday.add(triggerKey);
            if (emp.employeeWorkType == 'field') {
              await _sendFieldCheckoutVerificationAlert(emp, att);
            } else {
              await _sendCheckOutReminder(emp, att);
            }
          }

          // 4. FIELD EMPLOYEE / SYSTEM AUTO CHECKOUT
          if (emp.enableAutoCheckout) {
            final autoCheckoutTime = shiftEnd.add(Duration(minutes: emp.autoCheckoutGraceMinutes));
            final autoCheckoutKey = '${emp.uid}_${todayStr}_auto_checkout';

            if (now.isAfter(autoCheckoutTime) && !_executedTriggersToday.contains(autoCheckoutKey)) {
              _executedTriggersToday.add(autoCheckoutKey);
              await _performAutoCheckout(emp, att, autoCheckoutTime);
            }
          }
        }
      }
    } catch (e) {
      // Non-blocking background error trap
    }
  }

  static DateTime _getShiftDateTime(DateTime baseDate, String timeStr) {
    try {
      final clean = timeStr.trim().toUpperCase();
      final isPm = clean.contains('PM');
      final isAm = clean.contains('AM');
      final parts = clean.replaceAll('AM', '').replaceAll('PM', '').trim().split(':');

      int hour = int.parse(parts[0]);
      int minute = parts.length > 1 ? int.parse(parts[1]) : 0;

      if (isPm && hour < 12) hour += 12;
      if (isAm && hour == 12) hour = 0;

      return DateTime(baseDate.year, baseDate.month, baseDate.day, hour, minute);
    } catch (_) {
      return DateTime(baseDate.year, baseDate.month, baseDate.day, 9, 0);
    }
  }

  static Future<void> _sendCheckInReminder(UserModel emp, DateTime shiftStart) async {
    final title = 'Check-in Reminder';
    final body = 'Reminder: You have not checked in for today\'s shift (${DateFormat('hh:mm a').format(shiftStart)}). Please check in or contact your supervisor.';

    await _notifyRecipients(
      emp: emp,
      title: title,
      body: body,
      type: 'checkin_reminder',
      actionName: 'Check-in Reminder',
    );
  }

  static Future<void> _performAutoAbsent(UserModel emp, DateTime shiftStart) async {
    final attId = const Uuid().v4();
    final att = AttendanceModel(
      attendanceId: attId,
      companyId: emp.companyId,
      employeeId: emp.uid,
      userEmployeeId: emp.displayEmployeeId,
      employeeName: emp.name,
      checkInTime: shiftStart,
      status: 'Absent',
      createdAt: DateTime.now(),
      correctionReason: 'System Auto Absent',
      isAutoAbsent: true,
    );

    await _firestore.collection('attendance').doc(attId).set(att.toMap());

    final title = 'Auto Absent Notice';
    final body = 'Attendance Update: You were not checked in within the allowed time and have been marked absent automatically.';

    final managerBody = 'Employee ${emp.name} (${emp.displayEmployeeId}) has not checked in and was automatically marked absent.';

    await _notifyRecipients(
      emp: emp,
      title: title,
      body: body,
      managerBody: managerBody,
      type: 'auto_absent',
      actionName: 'Auto Absent',
    );
  }

  static Future<void> _sendCheckOutReminder(UserModel emp, AttendanceModel att) async {
    final title = 'Check-out Reminder';
    final body = 'You have not checked out from today\'s shift. Please complete your check-out.';
    final managerBody = 'Employee ${emp.name} (${emp.displayEmployeeId}) has not checked out after their scheduled shift.';

    await _notifyRecipients(
      emp: emp,
      title: title,
      body: body,
      managerBody: managerBody,
      type: 'checkout_reminder',
      actionName: 'Check-out Reminder',
    );
  }

  static Future<void> _sendFieldCheckoutVerificationAlert(UserModel emp, AttendanceModel att) async {
    final title = 'Field Employee Missing Checkout';
    final body = 'Field employee ${emp.name} (${emp.displayEmployeeId}) has not checked out. Please verify their work status.';

    await _notifyRecipients(
      emp: emp,
      title: title,
      body: body,
      type: 'field_verification_required',
      actionName: 'Field Verification Required',
    );
  }

  static Future<void> _performAutoCheckout(UserModel emp, AttendanceModel att, DateTime autoCheckoutTime) async {
    final updated = att.copyWith(
      checkOutTime: autoCheckoutTime,
      checkoutAddress: 'System Auto Checkout',
      checkoutSource: 'System Auto Checkout',
    );

    await _firestore.collection('attendance').doc(att.attendanceId).set(updated.toMap());

    final title = 'System Auto Checkout';
    final body = 'Your checkout was automatically completed at ${DateFormat('hh:mm a').format(autoCheckoutTime)} by the system.';
    final managerBody = 'System Auto Checkout generated for ${emp.name} (${emp.displayEmployeeId}) at ${DateFormat('hh:mm a').format(autoCheckoutTime)}.';

    await _notifyRecipients(
      emp: emp,
      title: title,
      body: body,
      managerBody: managerBody,
      type: 'auto_checkout',
      actionName: 'System Auto Checkout',
    );
  }

  static Future<void> _notifyRecipients({
    required UserModel emp,
    required String title,
    required String body,
    String? managerBody,
    required String type,
    required String actionName,
  }) async {
    final now = DateTime.now();

    // 1. Notify Employee directly
    final empNotifId = const Uuid().v4();
    await _firestore.collection('notifications').doc(empNotifId).set({
      'notificationId': empNotifId,
      'userId': emp.uid,
      'companyId': emp.companyId,
      'title': title,
      'body': body,
      'type': type,
      'createdAt': Timestamp.fromDate(now),
      'isRead': false,
      'data': {
        'employeeId': emp.uid,
        'employeeName': emp.name,
        'employeeCode': emp.displayEmployeeId,
      },
    });

    // 2. Resolve selected recipients (HR, Manager, Team Leader, Company Admin)
    final recipients = emp.attendanceNotificationRecipients;
    if (recipients.isNotEmpty) {
      final userSnap = await _firestore
          .collection('users')
          .where('companyId', isEqualTo: emp.companyId)
          .where('status', isEqualTo: 'active')
          .get();

      final allUsers = userSnap.docs.map((d) => UserModel.fromMap(d.data())).toList();
      final Set<String> notifiedUserIds = {emp.uid};

      for (final recipientRole in recipients) {
        final targetUsers = allUsers.where((u) {
          if (notifiedUserIds.contains(u.uid)) return false;
          final r = u.role.toLowerCase();
          if (recipientRole == 'hr' && (r.contains('hr') || r == 'hr')) return true;
          if (recipientRole == 'reporting_manager' && (u.uid == emp.managerId || r == 'manager')) return true;
          if (recipientRole == 'team_leader' && (r.contains('team') || r == 'team_leader')) return true;
          if (recipientRole == 'company_admin' && r == 'company_admin') return true;
          return false;
        });

        for (final target in targetUsers) {
          notifiedUserIds.add(target.uid);
          final nId = const Uuid().v4();
          await _firestore.collection('notifications').doc(nId).set({
            'notificationId': nId,
            'userId': target.uid,
            'companyId': emp.companyId,
            'title': '$title: ${emp.name}',
            'body': managerBody ?? body,
            'type': type,
            'createdAt': Timestamp.fromDate(now),
            'isRead': false,
            'data': {
              'employeeId': emp.uid,
              'employeeName': emp.name,
              'employeeCode': emp.displayEmployeeId,
            },
          });
        }
      }
    }

    // 3. Log audit trail entry
    final logId = const Uuid().v4();
    final log = AttendanceAutomationLogModel(
      logId: logId,
      companyId: emp.companyId,
      employeeId: emp.uid,
      employeeName: emp.name,
      userEmployeeId: emp.displayEmployeeId,
      action: actionName,
      triggeredBy: 'System',
      details: body,
      notificationRecipients: recipients,
      timestamp: now,
    );

    await _firestore.collection('attendance_automation_logs').doc(logId).set(log.toMap());
  }
}
