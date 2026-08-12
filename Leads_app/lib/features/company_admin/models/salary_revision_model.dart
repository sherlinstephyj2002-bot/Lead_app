import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a single salary revision entry for an employee.
/// Stored in Firestore under: salary_revisions/{revisionId}
class SalaryRevisionModel {
  final String revisionId;
  final String companyId;
  final String employeeId;
  final String employeeName;
  final String structureId;
  final String structureName;

  // Computed snapshot values at time of revision
  final double basic;
  final double totalAllowances;
  final double totalDeductions;
  final double grossSalary;
  final double netSalary;

  // Formula strings stored for audit/display purposes
  final String grossFormula;
  final String netFormula;

  // Snapshot of full earnings & deductions breakdown
  final Map<String, double> earnings;
  final Map<String, double> deductions;

  final DateTime effectiveDate;
  final String revisedBy; // Name of HR/admin who made the change
  final String? notes;
  final DateTime createdAt;

  SalaryRevisionModel({
    required this.revisionId,
    required this.companyId,
    required this.employeeId,
    required this.employeeName,
    required this.structureId,
    required this.structureName,
    required this.basic,
    required this.totalAllowances,
    required this.totalDeductions,
    required this.grossSalary,
    required this.netSalary,
    this.grossFormula = 'Basic + Allowances',
    this.netFormula = 'Gross - Deductions',
    this.earnings = const {},
    this.deductions = const {},
    required this.effectiveDate,
    required this.revisedBy,
    this.notes,
    required this.createdAt,
  });

  factory SalaryRevisionModel.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic v) {
      if (v == null) return DateTime.now();
      if (v is Timestamp) return v.toDate();
      return DateTime.parse(v.toString());
    }

    return SalaryRevisionModel(
      revisionId: map['revisionId'] ?? '',
      companyId: map['companyId'] ?? '',
      employeeId: map['employeeId'] ?? '',
      employeeName: map['employeeName'] ?? '',
      structureId: map['structureId'] ?? '',
      structureName: map['structureName'] ?? '',
      basic: (map['basic'] as num?)?.toDouble() ?? 0.0,
      totalAllowances: (map['totalAllowances'] as num?)?.toDouble() ?? 0.0,
      totalDeductions: (map['totalDeductions'] as num?)?.toDouble() ?? 0.0,
      grossSalary: (map['grossSalary'] as num?)?.toDouble() ?? 0.0,
      netSalary: (map['netSalary'] as num?)?.toDouble() ?? 0.0,
      grossFormula: map['grossFormula'] ?? 'Basic + Allowances',
      netFormula: map['netFormula'] ?? 'Gross - Deductions',
      earnings: (map['earnings'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, (v as num).toDouble())) ??
          {},
      deductions: (map['deductions'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, (v as num).toDouble())) ??
          {},
      effectiveDate: parseDate(map['effectiveDate']),
      revisedBy: map['revisedBy'] ?? '',
      notes: map['notes'],
      createdAt: parseDate(map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'revisionId': revisionId,
      'companyId': companyId,
      'employeeId': employeeId,
      'employeeName': employeeName,
      'structureId': structureId,
      'structureName': structureName,
      'basic': basic,
      'totalAllowances': totalAllowances,
      'totalDeductions': totalDeductions,
      'grossSalary': grossSalary,
      'netSalary': netSalary,
      'grossFormula': grossFormula,
      'netFormula': netFormula,
      'earnings': earnings,
      'deductions': deductions,
      'effectiveDate': Timestamp.fromDate(effectiveDate),
      'revisedBy': revisedBy,
      'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  SalaryRevisionModel copyWith({
    String? revisionId,
    String? companyId,
    String? employeeId,
    String? employeeName,
    String? structureId,
    String? structureName,
    double? basic,
    double? totalAllowances,
    double? totalDeductions,
    double? grossSalary,
    double? netSalary,
    String? grossFormula,
    String? netFormula,
    Map<String, double>? earnings,
    Map<String, double>? deductions,
    DateTime? effectiveDate,
    String? revisedBy,
    String? notes,
    DateTime? createdAt,
  }) {
    return SalaryRevisionModel(
      revisionId: revisionId ?? this.revisionId,
      companyId: companyId ?? this.companyId,
      employeeId: employeeId ?? this.employeeId,
      employeeName: employeeName ?? this.employeeName,
      structureId: structureId ?? this.structureId,
      structureName: structureName ?? this.structureName,
      basic: basic ?? this.basic,
      totalAllowances: totalAllowances ?? this.totalAllowances,
      totalDeductions: totalDeductions ?? this.totalDeductions,
      grossSalary: grossSalary ?? this.grossSalary,
      netSalary: netSalary ?? this.netSalary,
      grossFormula: grossFormula ?? this.grossFormula,
      netFormula: netFormula ?? this.netFormula,
      earnings: earnings ?? this.earnings,
      deductions: deductions ?? this.deductions,
      effectiveDate: effectiveDate ?? this.effectiveDate,
      revisedBy: revisedBy ?? this.revisedBy,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
