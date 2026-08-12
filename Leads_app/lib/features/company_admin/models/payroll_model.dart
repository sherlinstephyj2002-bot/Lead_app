import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore collection: payrolls/{payrollId}
/// Represents a fully-computed payroll record for one employee for one month.
class PayrollModel {
  final String payrollId;
  final String companyId;

  // Employee snapshot
  final String employeeId;
  final String employeeName;
  final String? designation;
  final String? department;

  // Payroll period
  final int month; // 1–12
  final int year;
  final String payrollPeriod; // e.g. "July 2026"

  // Salary structure snapshot
  final String? salaryStructureId;
  final String? salaryStructureName;

  // ── Attendance metrics ──────────────────────────────
  final int totalWorkingDays;   // Calendar working days in the period (from PayrollSettings)
  final double presentDays;     // Full present + late = 1.0 each, half-day = 0.5
  final double paidLeaveDays;   // Approved paid leave days (Annual/Casual/Sick)
  final double unpaidLeaveDays; // LOP days
  final double paidDays;        // presentDays + paidLeaveDays
  final double lopDays;         // totalWorkingDays − paidDays (clamped ≥ 0)

  // ── Earnings & Deductions ───────────────────────────
  /// componentName → pro-rated amount
  final Map<String, double> earnings;

  /// componentName → amount
  final Map<String, double> deductions;

  // ── Computed amounts ────────────────────────────────
  final double grossSalary;
  final double overtimePay;

  final double pfEmployeeAmount;
  final double pfEmployerAmount;
  final double esiEmployeeAmount;
  final double esiEmployerAmount;
  final double professionalTax;
  final double tdsAmount;

  final double totalDeductions;
  final double netSalary;

  // ── Status & Audit ──────────────────────────────────
  /// 'Draft' | 'Approved' | 'Rejected' | 'Paid'
  final String status;
  final String? remarks;
  final String generatedBy;
  final String? approvedBy;

  final DateTime generatedAt;
  final DateTime? approvedAt;
  final DateTime? paidAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  PayrollModel({
    required this.payrollId,
    required this.companyId,
    required this.employeeId,
    required this.employeeName,
    this.designation,
    this.department,
    required this.month,
    required this.year,
    required this.payrollPeriod,
    this.salaryStructureId,
    this.salaryStructureName,
    required this.totalWorkingDays,
    required this.presentDays,
    required this.paidLeaveDays,
    required this.unpaidLeaveDays,
    required this.paidDays,
    required this.lopDays,
    required this.earnings,
    required this.deductions,
    required this.grossSalary,
    this.overtimePay = 0.0,
    this.pfEmployeeAmount = 0.0,
    this.pfEmployerAmount = 0.0,
    this.esiEmployeeAmount = 0.0,
    this.esiEmployerAmount = 0.0,
    this.professionalTax = 0.0,
    this.tdsAmount = 0.0,
    required this.totalDeductions,
    required this.netSalary,
    this.status = 'Draft',
    this.remarks,
    required this.generatedBy,
    this.approvedBy,
    required this.generatedAt,
    this.approvedAt,
    this.paidAt,
    required this.createdAt,
    required this.updatedAt,
  });

  static DateTime _parseDate(dynamic v) {
    if (v == null) return DateTime.now();
    if (v is Timestamp) return v.toDate();
    return DateTime.tryParse(v.toString()) ?? DateTime.now();
  }

  static DateTime? _parseDateNullable(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    return DateTime.tryParse(v.toString());
  }

  factory PayrollModel.fromMap(Map<String, dynamic> map) {
    return PayrollModel(
      payrollId: map['payrollId'] ?? '',
      companyId: map['companyId'] ?? '',
      employeeId: map['employeeId'] ?? '',
      employeeName: map['employeeName'] ?? '',
      designation: map['designation'],
      department: map['department'],
      month: (map['month'] as num?)?.toInt() ?? 1,
      year: (map['year'] as num?)?.toInt() ?? DateTime.now().year,
      payrollPeriod: map['payrollPeriod'] ?? '',
      salaryStructureId: map['salaryStructureId'],
      salaryStructureName: map['salaryStructureName'],
      totalWorkingDays: (map['totalWorkingDays'] as num?)?.toInt() ?? 26,
      presentDays: (map['presentDays'] as num?)?.toDouble() ?? 0.0,
      paidLeaveDays: (map['paidLeaveDays'] as num?)?.toDouble() ?? 0.0,
      unpaidLeaveDays: (map['unpaidLeaveDays'] as num?)?.toDouble() ?? 0.0,
      paidDays: (map['paidDays'] as num?)?.toDouble() ?? 0.0,
      lopDays: (map['lopDays'] as num?)?.toDouble() ?? 0.0,
      earnings: (map['earnings'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, (v as num).toDouble())) ??
          {},
      deductions: (map['deductions'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, (v as num).toDouble())) ??
          {},
      grossSalary: (map['grossSalary'] as num?)?.toDouble() ?? 0.0,
      overtimePay: (map['overtimePay'] as num?)?.toDouble() ?? 0.0,
      pfEmployeeAmount: (map['pfEmployeeAmount'] as num?)?.toDouble() ?? 0.0,
      pfEmployerAmount: (map['pfEmployerAmount'] as num?)?.toDouble() ?? 0.0,
      esiEmployeeAmount: (map['esiEmployeeAmount'] as num?)?.toDouble() ?? 0.0,
      esiEmployerAmount: (map['esiEmployerAmount'] as num?)?.toDouble() ?? 0.0,
      professionalTax: (map['professionalTax'] as num?)?.toDouble() ?? 0.0,
      tdsAmount: (map['tdsAmount'] as num?)?.toDouble() ?? 0.0,
      totalDeductions: (map['totalDeductions'] as num?)?.toDouble() ?? 0.0,
      netSalary: (map['netSalary'] as num?)?.toDouble() ?? 0.0,
      status: map['status'] ?? 'Draft',
      remarks: map['remarks'],
      generatedBy: map['generatedBy'] ?? '',
      approvedBy: map['approvedBy'],
      generatedAt: _parseDate(map['generatedAt']),
      approvedAt: _parseDateNullable(map['approvedAt']),
      paidAt: _parseDateNullable(map['paidAt']),
      createdAt: _parseDate(map['createdAt']),
      updatedAt: _parseDate(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'payrollId': payrollId,
      'companyId': companyId,
      'employeeId': employeeId,
      'employeeName': employeeName,
      'designation': designation,
      'department': department,
      'month': month,
      'year': year,
      'payrollPeriod': payrollPeriod,
      'salaryStructureId': salaryStructureId,
      'salaryStructureName': salaryStructureName,
      'totalWorkingDays': totalWorkingDays,
      'presentDays': presentDays,
      'paidLeaveDays': paidLeaveDays,
      'unpaidLeaveDays': unpaidLeaveDays,
      'paidDays': paidDays,
      'lopDays': lopDays,
      'earnings': earnings,
      'deductions': deductions,
      'grossSalary': grossSalary,
      'overtimePay': overtimePay,
      'pfEmployeeAmount': pfEmployeeAmount,
      'pfEmployerAmount': pfEmployerAmount,
      'esiEmployeeAmount': esiEmployeeAmount,
      'esiEmployerAmount': esiEmployerAmount,
      'professionalTax': professionalTax,
      'tdsAmount': tdsAmount,
      'totalDeductions': totalDeductions,
      'netSalary': netSalary,
      'status': status,
      'remarks': remarks,
      'generatedBy': generatedBy,
      'approvedBy': approvedBy,
      'generatedAt': Timestamp.fromDate(generatedAt),
      'approvedAt': approvedAt != null ? Timestamp.fromDate(approvedAt!) : null,
      'paidAt': paidAt != null ? Timestamp.fromDate(paidAt!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  PayrollModel copyWith({
    String? payrollId,
    String? companyId,
    String? employeeId,
    String? employeeName,
    String? designation,
    String? department,
    int? month,
    int? year,
    String? payrollPeriod,
    String? salaryStructureId,
    String? salaryStructureName,
    int? totalWorkingDays,
    double? presentDays,
    double? paidLeaveDays,
    double? unpaidLeaveDays,
    double? paidDays,
    double? lopDays,
    Map<String, double>? earnings,
    Map<String, double>? deductions,
    double? grossSalary,
    double? overtimePay,
    double? pfEmployeeAmount,
    double? pfEmployerAmount,
    double? esiEmployeeAmount,
    double? esiEmployerAmount,
    double? professionalTax,
    double? tdsAmount,
    double? totalDeductions,
    double? netSalary,
    String? status,
    String? remarks,
    String? generatedBy,
    String? approvedBy,
    DateTime? generatedAt,
    DateTime? approvedAt,
    DateTime? paidAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PayrollModel(
      payrollId: payrollId ?? this.payrollId,
      companyId: companyId ?? this.companyId,
      employeeId: employeeId ?? this.employeeId,
      employeeName: employeeName ?? this.employeeName,
      designation: designation ?? this.designation,
      department: department ?? this.department,
      month: month ?? this.month,
      year: year ?? this.year,
      payrollPeriod: payrollPeriod ?? this.payrollPeriod,
      salaryStructureId: salaryStructureId ?? this.salaryStructureId,
      salaryStructureName: salaryStructureName ?? this.salaryStructureName,
      totalWorkingDays: totalWorkingDays ?? this.totalWorkingDays,
      presentDays: presentDays ?? this.presentDays,
      paidLeaveDays: paidLeaveDays ?? this.paidLeaveDays,
      unpaidLeaveDays: unpaidLeaveDays ?? this.unpaidLeaveDays,
      paidDays: paidDays ?? this.paidDays,
      lopDays: lopDays ?? this.lopDays,
      earnings: earnings ?? this.earnings,
      deductions: deductions ?? this.deductions,
      grossSalary: grossSalary ?? this.grossSalary,
      overtimePay: overtimePay ?? this.overtimePay,
      pfEmployeeAmount: pfEmployeeAmount ?? this.pfEmployeeAmount,
      pfEmployerAmount: pfEmployerAmount ?? this.pfEmployerAmount,
      esiEmployeeAmount: esiEmployeeAmount ?? this.esiEmployeeAmount,
      esiEmployerAmount: esiEmployerAmount ?? this.esiEmployerAmount,
      professionalTax: professionalTax ?? this.professionalTax,
      tdsAmount: tdsAmount ?? this.tdsAmount,
      totalDeductions: totalDeductions ?? this.totalDeductions,
      netSalary: netSalary ?? this.netSalary,
      status: status ?? this.status,
      remarks: remarks ?? this.remarks,
      generatedBy: generatedBy ?? this.generatedBy,
      approvedBy: approvedBy ?? this.approvedBy,
      generatedAt: generatedAt ?? this.generatedAt,
      approvedAt: approvedAt ?? this.approvedAt,
      paidAt: paidAt ?? this.paidAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

