import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../constants/user_roles.dart';
import '../../../shared/models/user_model.dart';
import '../../../shared/providers/providers.dart';
import '../models/ess_models.dart';

class ESSPortalState {
  final ESSProfileModel profile;
  final int presentDays;
  final double leaveBalance;
  final int pendingLeaveRequests;
  final int tasksAssigned;
  final int completedTasks;
  final double pendingExpensesAmount;
  final double monthlyAttendancePercent;
  final String latestPayslipAmount;
  final String nextPayrollDate;
  final String upcomingBirthday;
  final List<ESSLeaveModel> leaves;
  final List<ESSPayslipModel> payslips;
  final List<ESSExpenseModel> expenses;
  final List<ESSDocumentModel> documents;
  final List<ESSTaskModel> tasks;
  final List<ESSTimelineEventModel> timeline;
  final List<ESSAnnouncementModel> announcements;

  const ESSPortalState({
    required this.profile,
    required this.presentDays,
    required this.leaveBalance,
    required this.pendingLeaveRequests,
    required this.tasksAssigned,
    required this.completedTasks,
    required this.pendingExpensesAmount,
    required this.monthlyAttendancePercent,
    required this.latestPayslipAmount,
    required this.nextPayrollDate,
    required this.upcomingBirthday,
    required this.leaves,
    required this.payslips,
    required this.expenses,
    required this.documents,
    required this.tasks,
    required this.timeline,
    required this.announcements,
  });

  ESSPortalState copyWith({
    ESSProfileModel? profile,
    int? presentDays,
    double? leaveBalance,
    int? pendingLeaveRequests,
    int? tasksAssigned,
    int? completedTasks,
    double? pendingExpensesAmount,
    double? monthlyAttendancePercent,
    String? latestPayslipAmount,
    String? nextPayrollDate,
    String? upcomingBirthday,
    List<ESSLeaveModel>? leaves,
    List<ESSPayslipModel>? payslips,
    List<ESSExpenseModel>? expenses,
    List<ESSDocumentModel>? documents,
    List<ESSTaskModel>? tasks,
    List<ESSTimelineEventModel>? timeline,
    List<ESSAnnouncementModel>? announcements,
  }) {
    return ESSPortalState(
      profile: profile ?? this.profile,
      presentDays: presentDays ?? this.presentDays,
      leaveBalance: leaveBalance ?? this.leaveBalance,
      pendingLeaveRequests: pendingLeaveRequests ?? this.pendingLeaveRequests,
      tasksAssigned: tasksAssigned ?? this.tasksAssigned,
      completedTasks: completedTasks ?? this.completedTasks,
      pendingExpensesAmount: pendingExpensesAmount ?? this.pendingExpensesAmount,
      monthlyAttendancePercent: monthlyAttendancePercent ?? this.monthlyAttendancePercent,
      latestPayslipAmount: latestPayslipAmount ?? this.latestPayslipAmount,
      nextPayrollDate: nextPayrollDate ?? this.nextPayrollDate,
      upcomingBirthday: upcomingBirthday ?? this.upcomingBirthday,
      leaves: leaves ?? this.leaves,
      payslips: payslips ?? this.payslips,
      expenses: expenses ?? this.expenses,
      documents: documents ?? this.documents,
      tasks: tasks ?? this.tasks,
      timeline: timeline ?? this.timeline,
      announcements: announcements ?? this.announcements,
    );
  }
}

ESSProfileModel _buildProfileFromUser(UserModel? user) {
  if (user == null) {
    return const ESSProfileModel(
      employeeId: '-',
      name: 'User',
      photoUrl: '',
      designation: '-',
      department: '-',
      reportingManager: '-',
      branch: '-',
      shift: 'General Shift',
      email: '',
      phone: '',
      joinDate: '-',
      status: 'Active',
      emergencyContactName: '',
      emergencyContactPhone: '',
      bankName: '',
      accountNumber: '',
      ifscCode: '',
      panNumber: '',
      aadhaarNumber: '',
      skills: [],
    );
  }

  String roleDesignation = user.role == UserRoles.companyAdmin
      ? 'Company Admin'
      : (user.role == UserRoles.superAdmin ? 'Super Admin' : 'Employee');

  return ESSProfileModel(
    employeeId: (user.employeeId != null && user.employeeId!.isNotEmpty)
        ? user.employeeId!
        : (user.uid.length > 8 ? user.uid.substring(0, 8).toUpperCase() : user.uid),
    name: user.name.isNotEmpty ? user.name : 'User',
    photoUrl: user.profileImageUrl ?? '',
    designation: (user.designation != null && user.designation!.isNotEmpty)
        ? user.designation!
        : roleDesignation,
    department: (user.department != null && user.department!.isNotEmpty)
        ? user.department!
        : (user.companyName.isNotEmpty ? user.companyName : '-'),
    reportingManager: user.managerId ?? '-',
    branch: user.branchName ?? (user.companyName.isNotEmpty ? user.companyName : '-'),
    shift: 'General Shift (09:00 AM - 06:00 PM)',
    email: user.companyEmail ?? user.email,
    phone: user.phoneNumber ?? '',
    joinDate: user.joiningDate != null
        ? '${user.joiningDate!.day}/${user.joiningDate!.month}/${user.joiningDate!.year}'
        : '-',
    status: user.accountStatus ?? user.status,
    emergencyContactName: '',
    emergencyContactPhone: '',
    bankName: '',
    accountNumber: '',
    ifscCode: '',
    panNumber: '',
    aadhaarNumber: '',
    skills: const [],
  );
}

class ESSNotifier extends StateNotifier<ESSPortalState> {
  ESSNotifier(UserModel? user)
      : super(ESSPortalState(
          profile: _buildProfileFromUser(user),
          presentDays: 0,
          leaveBalance: 0.0,
          pendingLeaveRequests: 0,
          tasksAssigned: 0,
          completedTasks: 0,
          pendingExpensesAmount: 0.0,
          monthlyAttendancePercent: 0.0,
          latestPayslipAmount: '₹0',
          nextPayrollDate: '-',
          upcomingBirthday: '-',
          leaves: const [],
          payslips: const [],
          expenses: const [],
          documents: const [],
          tasks: const [],
          timeline: const [],
          announcements: const [],
        ));

  void applyLeave(ESSLeaveModel leave) {
    final updated = [...state.leaves, leave];
    state = state.copyWith(
      leaves: updated,
      leaveBalance: state.leaveBalance - leave.daysCount,
      pendingLeaveRequests: state.pendingLeaveRequests + 1,
    );
  }

  void cancelLeave(String id) {
    final updated = state.leaves.map((l) {
      if (l.id == id) {
        return ESSLeaveModel(
          id: l.id,
          type: l.type,
          startDate: l.startDate,
          endDate: l.endDate,
          daysCount: l.daysCount,
          reason: l.reason,
          status: 'Cancelled',
        );
      }
      return l;
    }).toList();
    final pendingCount = updated.where((l) => l.status.toLowerCase() == 'pending').length;
    state = state.copyWith(leaves: updated, pendingLeaveRequests: pendingCount);
  }

  void submitExpense(ESSExpenseModel expense) {
    final updated = [...state.expenses, expense];
    state = state.copyWith(
      expenses: updated,
      pendingExpensesAmount: state.pendingExpensesAmount + expense.amount,
    );
  }

  void updateTaskStatus(String taskId, String newStatus, double progress) {
    final updated = state.tasks.map((t) {
      if (t.id == taskId) {
        return ESSTaskModel(
          id: t.id,
          title: t.title,
          description: t.description,
          dueDate: t.dueDate,
          priority: t.priority,
          status: newStatus,
          assignedBy: t.assignedBy,
          progress: progress,
        );
      }
      return t;
    }).toList();

    final completedCount = updated.where((t) => t.status == 'Completed').length;
    state = state.copyWith(tasks: updated, completedTasks: completedCount);
  }
}

final essProvider = StateNotifierProvider<ESSNotifier, ESSPortalState>((ref) {
  final user = ref.watch(authProvider).user;
  return ESSNotifier(user);
});

