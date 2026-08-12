import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore collection: salary_payslips/{payslipId}
class SalaryPayslipModel {
  final String payslipId;
  final String companyId;

  // Employee snapshot
  final String employeeId;
  final String employeeName;
  final String? employeeCode;
  final String? department;
  final String? designation;

  // Salary structure snapshot
  final String? salaryStructureId;
  final String? salaryStructureName;

  // Period
  final int month; // 1–12
  final int year;

  // Base salary
  final double basicSalary;

  // From structure: componentName -> amount
  final Map<String, double> earnings;   // allowances
  final Map<String, double> deductions; // statutory / structural deductions

  // Manual admin inputs
  final double bonus;
  final double overtime;
  final double incentive;
  final double otherDeduction;

  // Attendance
  final int presentDays;
  final int absentDays;
  final int leaveDays;

  // Computed totals (stored for history)
  final double grossSalary;
  final double netSalary;

  // Meta
  final String generatedBy;
  final DateTime generatedDate;
  /// 'Draft' | 'Generated' | 'Sent'
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  SalaryPayslipModel({
    required this.payslipId,
    required this.companyId,
    required this.employeeId,
    required this.employeeName,
    this.employeeCode,
    this.department,
    this.designation,
    this.salaryStructureId,
    this.salaryStructureName,
    required this.month,
    required this.year,
    required this.basicSalary,
    required this.earnings,
    required this.deductions,
    this.bonus = 0.0,
    this.overtime = 0.0,
    this.incentive = 0.0,
    this.otherDeduction = 0.0,
    this.presentDays = 0,
    this.absentDays = 0,
    this.leaveDays = 0,
    required this.grossSalary,
    required this.netSalary,
    required this.generatedBy,
    required this.generatedDate,
    this.status = 'Generated',
    required this.createdAt,
    required this.updatedAt,
  });

  // ── Computed getters ───────────────────────────────
  double get totalEarnings =>
      basicSalary +
      earnings.values.fold(0.0, (s, v) => s + v) +
      bonus +
      overtime +
      incentive;

  double get totalStructureDeductions =>
      deductions.values.fold(0.0, (s, v) => s + v);

  double get totalDeductions => totalStructureDeductions + otherDeduction;

  String get payrollPeriod {
    const months = [
      '', 'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${months[month]} $year';
  }

  // ── Serialization ──────────────────────────────────
  static DateTime _parseDate(dynamic v) {
    if (v == null) return DateTime.now();
    if (v is Timestamp) return v.toDate();
    return DateTime.tryParse(v.toString()) ?? DateTime.now();
  }

  factory SalaryPayslipModel.fromMap(Map<String, dynamic> map) {
    return SalaryPayslipModel(
      payslipId: map['payslipId'] ?? '',
      companyId: map['companyId'] ?? '',
      employeeId: map['employeeId'] ?? '',
      employeeName: map['employeeName'] ?? '',
      employeeCode: map['employeeCode'],
      department: map['department'],
      designation: map['designation'],
      salaryStructureId: map['salaryStructureId'],
      salaryStructureName: map['salaryStructureName'],
      month: (map['month'] as num?)?.toInt() ?? 1,
      year: (map['year'] as num?)?.toInt() ?? DateTime.now().year,
      basicSalary: (map['basicSalary'] as num?)?.toDouble() ?? 0.0,
      earnings: (map['earnings'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, (v as num).toDouble())) ??
          {},
      deductions: (map['deductions'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, (v as num).toDouble())) ??
          {},
      bonus: (map['bonus'] as num?)?.toDouble() ?? 0.0,
      overtime: (map['overtime'] as num?)?.toDouble() ?? 0.0,
      incentive: (map['incentive'] as num?)?.toDouble() ?? 0.0,
      otherDeduction: (map['otherDeduction'] as num?)?.toDouble() ?? 0.0,
      presentDays: (map['presentDays'] as num?)?.toInt() ?? 0,
      absentDays: (map['absentDays'] as num?)?.toInt() ?? 0,
      leaveDays: (map['leaveDays'] as num?)?.toInt() ?? 0,
      grossSalary: (map['grossSalary'] as num?)?.toDouble() ?? 0.0,
      netSalary: (map['netSalary'] as num?)?.toDouble() ?? 0.0,
      generatedBy: map['generatedBy'] ?? '',
      generatedDate: _parseDate(map['generatedDate']),
      status: map['status'] ?? 'Generated',
      createdAt: _parseDate(map['createdAt']),
      updatedAt: _parseDate(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'payslipId': payslipId,
      'companyId': companyId,
      'employeeId': employeeId,
      'employeeName': employeeName,
      'employeeCode': employeeCode,
      'department': department,
      'designation': designation,
      'salaryStructureId': salaryStructureId,
      'salaryStructureName': salaryStructureName,
      'month': month,
      'year': year,
      'basicSalary': basicSalary,
      'earnings': earnings,
      'deductions': deductions,
      'bonus': bonus,
      'overtime': overtime,
      'incentive': incentive,
      'otherDeduction': otherDeduction,
      'presentDays': presentDays,
      'absentDays': absentDays,
      'leaveDays': leaveDays,
      'grossSalary': grossSalary,
      'netSalary': netSalary,
      'generatedBy': generatedBy,
      'generatedDate': Timestamp.fromDate(generatedDate),
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  SalaryPayslipModel copyWith({
    String? payslipId,
    String? companyId,
    String? employeeId,
    String? employeeName,
    String? employeeCode,
    String? department,
    String? designation,
    String? salaryStructureId,
    String? salaryStructureName,
    int? month,
    int? year,
    double? basicSalary,
    Map<String, double>? earnings,
    Map<String, double>? deductions,
    double? bonus,
    double? overtime,
    double? incentive,
    double? otherDeduction,
    int? presentDays,
    int? absentDays,
    int? leaveDays,
    double? grossSalary,
    double? netSalary,
    String? generatedBy,
    DateTime? generatedDate,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SalaryPayslipModel(
      payslipId: payslipId ?? this.payslipId,
      companyId: companyId ?? this.companyId,
      employeeId: employeeId ?? this.employeeId,
      employeeName: employeeName ?? this.employeeName,
      employeeCode: employeeCode ?? this.employeeCode,
      department: department ?? this.department,
      designation: designation ?? this.designation,
      salaryStructureId: salaryStructureId ?? this.salaryStructureId,
      salaryStructureName: salaryStructureName ?? this.salaryStructureName,
      month: month ?? this.month,
      year: year ?? this.year,
      basicSalary: basicSalary ?? this.basicSalary,
      earnings: earnings ?? this.earnings,
      deductions: deductions ?? this.deductions,
      bonus: bonus ?? this.bonus,
      overtime: overtime ?? this.overtime,
      incentive: incentive ?? this.incentive,
      otherDeduction: otherDeduction ?? this.otherDeduction,
      presentDays: presentDays ?? this.presentDays,
      absentDays: absentDays ?? this.absentDays,
      leaveDays: leaveDays ?? this.leaveDays,
      grossSalary: grossSalary ?? this.grossSalary,
      netSalary: netSalary ?? this.netSalary,
      generatedBy: generatedBy ?? this.generatedBy,
      generatedDate: generatedDate ?? this.generatedDate,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

