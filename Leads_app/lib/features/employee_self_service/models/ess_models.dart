class ESSProfileModel {
  final String employeeId;
  final String name;
  final String photoUrl;
  final String designation;
  final String department;
  final String reportingManager;
  final String branch;
  final String shift;
  final String email;
  final String phone;
  final String joinDate;
  final String status;
  final String emergencyContactName;
  final String emergencyContactPhone;
  final String bankName;
  final String accountNumber;
  final String ifscCode;
  final String panNumber;
  final String aadhaarNumber;
  final List<String> skills;

  const ESSProfileModel({
    required this.employeeId,
    required this.name,
    required this.photoUrl,
    required this.designation,
    required this.department,
    required this.reportingManager,
    required this.branch,
    required this.shift,
    required this.email,
    required this.phone,
    required this.joinDate,
    required this.status,
    required this.emergencyContactName,
    required this.emergencyContactPhone,
    required this.bankName,
    required this.accountNumber,
    required this.ifscCode,
    required this.panNumber,
    required this.aadhaarNumber,
    required this.skills,
  });
}

class ESSLeaveModel {
  final String id;
  final String type; // Casual, Sick, Earned, Paternity
  final DateTime startDate;
  final DateTime endDate;
  final double daysCount;
  final String reason;
  final String status; // Approved, Pending, Rejected

  const ESSLeaveModel({
    required this.id,
    required this.type,
    required this.startDate,
    required this.endDate,
    required this.daysCount,
    required this.reason,
    required this.status,
  });
}

class ESSPayslipModel {
  final String id;
  final String monthYear; // e.g. July 2026
  final double basicSalary;
  final double hra;
  final double specialAllowance;
  final double grossEarnings;
  final double pfDeduction;
  final double esiDeduction;
  final double taxDeduction;
  final double totalDeductions;
  final double netSalary;
  final String paymentStatus;

  const ESSPayslipModel({
    required this.id,
    required this.monthYear,
    required this.basicSalary,
    required this.hra,
    required this.specialAllowance,
    required this.grossEarnings,
    required this.pfDeduction,
    required this.esiDeduction,
    required this.taxDeduction,
    required this.totalDeductions,
    required this.netSalary,
    required this.paymentStatus,
  });
}

class ESSExpenseModel {
  final String id;
  final String title;
  final String category; // Travel, Meals, Supplies, Client Meeting
  final double amount;
  final DateTime date;
  final String status; // Approved, Pending, Rejected
  final String receiptUrl;

  const ESSExpenseModel({
    required this.id,
    required this.title,
    required this.category,
    required this.amount,
    required this.date,
    required this.status,
    required this.receiptUrl,
  });
}

class ESSDocumentModel {
  final String id;
  final String name;
  final String category; // KYC, HR Letters, Tax, Certificates
  final String uploadDate;
  final String status; // Verified, Pending Verification
  final String fileType;

  const ESSDocumentModel({
    required this.id,
    required this.name,
    required this.category,
    required this.uploadDate,
    required this.status,
    required this.fileType,
  });
}

class ESSTaskModel {
  final String id;
  final String title;
  final String description;
  final DateTime dueDate;
  final String priority; // Urgent, High, Medium, Low
  final String status; // Pending, In Progress, Completed
  final String assignedBy;
  final double progress; // 0.0 to 1.0

  const ESSTaskModel({
    required this.id,
    required this.title,
    required this.description,
    required this.dueDate,
    required this.priority,
    required this.status,
    required this.assignedBy,
    required this.progress,
  });
}

class ESSTimelineEventModel {
  final String id;
  final String title;
  final String description;
  final String date;
  final String iconType; // 'joining', 'promotion', 'award', 'document', 'salary'

  const ESSTimelineEventModel({
    required this.id,
    required this.title,
    required this.description,
    required this.date,
    required this.iconType,
  });
}

class ESSAnnouncementModel {
  final String id;
  final String title;
  final String description;
  final String date;
  final String category; // News, HR Update, Holiday, Policy

  const ESSAnnouncementModel({
    required this.id,
    required this.title,
    required this.description,
    required this.date,
    required this.category,
  });
}
