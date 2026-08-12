enum NotificationType {
  // Attendance
  employeeCheckedIn,
  employeeCheckedOut,
  lateAttendance,
  missedCheckIn,
  attendanceReminder,

  // Leave
  leaveRequested,
  leaveApproved,
  leaveRejected,
  leaveCancelled,

  // Leads
  newLeadAssigned,
  leadStatusUpdated,
  leadConvertedToOrder,
  followupDue,

  // Orders
  orderAssigned,
  orderCompleted,
  invoiceGenerated,

  // Expense
  expenseSubmitted,
  expenseApproved,
  expenseRejected,

  // Payroll
  payrollGenerated,
  payslipAvailable,
  salaryProcessed,

  // Employee
  employeeJoined,
  employeeUpdated,
  employeeDeactivated,

  // Task
  taskAssigned,
  taskCompleted,
  taskDueTomorrow,

  // HR
  departmentAdded,
  designationUpdated,
  shiftUpdated,
  holidayAdded,

  // Company
  companyProfileUpdated,
  branchCreated,
  roleChanged,

  // Subscription
  planExpiring,
  paymentSuccessful,
  paymentFailed,
  trialEnding,

  // Announcements
  holidayAnnouncement,
  meetingReminder,
  generalAnnouncement,

  // System
  backupCompleted,
  databaseUpdated,
  newVersionAvailable,
  maintenanceScheduled,
}

extension NotificationTypeExtension on NotificationType {
  String get label {
    switch (this) {
      case NotificationType.employeeCheckedIn:
        return 'Employee Checked In';
      case NotificationType.employeeCheckedOut:
        return 'Employee Checked Out';
      case NotificationType.lateAttendance:
        return 'Late Attendance';
      case NotificationType.missedCheckIn:
        return 'Missed Check-In';
      case NotificationType.attendanceReminder:
        return 'Attendance Reminder';

      case NotificationType.leaveRequested:
        return 'Leave Requested';
      case NotificationType.leaveApproved:
        return 'Leave Approved';
      case NotificationType.leaveRejected:
        return 'Leave Rejected';
      case NotificationType.leaveCancelled:
        return 'Leave Cancelled';

      case NotificationType.newLeadAssigned:
        return 'New Lead Assigned';
      case NotificationType.leadStatusUpdated:
        return 'Lead Status Updated';
      case NotificationType.leadConvertedToOrder:
        return 'Lead Converted to Order';
      case NotificationType.followupDue:
        return 'Follow-Up Due';

      case NotificationType.orderAssigned:
        return 'Order Assigned';
      case NotificationType.orderCompleted:
        return 'Order Completed';
      case NotificationType.invoiceGenerated:
        return 'Invoice Generated';

      case NotificationType.expenseSubmitted:
        return 'Expense Submitted';
      case NotificationType.expenseApproved:
        return 'Expense Approved';
      case NotificationType.expenseRejected:
        return 'Expense Rejected';

      case NotificationType.payrollGenerated:
        return 'Payroll Generated';
      case NotificationType.payslipAvailable:
        return 'Payslip Available';
      case NotificationType.salaryProcessed:
        return 'Salary Processed';

      case NotificationType.employeeJoined:
        return 'Employee Joined';
      case NotificationType.employeeUpdated:
        return 'Employee Profile Updated';
      case NotificationType.employeeDeactivated:
        return 'Employee Deactivated';

      case NotificationType.taskAssigned:
        return 'Task Assigned';
      case NotificationType.taskCompleted:
        return 'Task Completed';
      case NotificationType.taskDueTomorrow:
        return 'Task Due Tomorrow';

      case NotificationType.departmentAdded:
        return 'Department Added';
      case NotificationType.designationUpdated:
        return 'Designation Updated';
      case NotificationType.shiftUpdated:
        return 'Shift Updated';
      case NotificationType.holidayAdded:
        return 'Holiday Added';

      case NotificationType.companyProfileUpdated:
        return 'Company Profile Updated';
      case NotificationType.branchCreated:
        return 'Branch Created';
      case NotificationType.roleChanged:
        return 'Role Changed';

      case NotificationType.planExpiring:
        return 'Subscription Plan Expiring';
      case NotificationType.paymentSuccessful:
        return 'Payment Successful';
      case NotificationType.paymentFailed:
        return 'Payment Failed';
      case NotificationType.trialEnding:
        return 'Trial Period Ending';

      case NotificationType.holidayAnnouncement:
        return 'Holiday Announcement';
      case NotificationType.meetingReminder:
        return 'Meeting Reminder';
      case NotificationType.generalAnnouncement:
        return 'General Announcement';

      case NotificationType.backupCompleted:
        return 'System Backup Completed';
      case NotificationType.databaseUpdated:
        return 'Database Updated';
      case NotificationType.newVersionAvailable:
        return 'New App Version Available';
      case NotificationType.maintenanceScheduled:
        return 'System Maintenance Scheduled';
    }
  }
}
