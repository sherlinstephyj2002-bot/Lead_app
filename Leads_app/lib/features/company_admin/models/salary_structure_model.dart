import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a reusable salary template assigned to employees.
/// Firestore collection: salary_structures/{structureId}
class SalaryStructureModel {
  final String structureId;
  final String companyId;

  /// Human-readable template name (alias: structureName)
  final String name;

  /// Alias getter for requirement field: structureName
  String get structureName => name;

  final String description;

  /// Basic salary amount
  final double basic;

  /// Flat allowances map: componentId -> amount
  final Map<String, double> earnings;

  /// Deductions map: componentId -> amount
  final Map<String, double> deductions;

  /// Formula string for gross pay display/audit (e.g. "Basic + Allowances")
  final String grossFormula;

  /// Formula string for net pay display/audit (e.g. "Gross - Deductions")
  final String netFormula;

  final String status; // 'active', 'archived', 'deleted'
  final DateTime createdAt;
  final DateTime updatedAt;

  SalaryStructureModel({
    required this.structureId,
    required this.companyId,
    required this.name,
    this.description = '',
    this.basic = 0.0,
    required this.earnings,
    required this.deductions,
    this.grossFormula = 'Basic + Allowances',
    this.netFormula = 'Gross - Deductions',
    this.status = 'active',
    required this.createdAt,
    required this.updatedAt,
  });

  /// Computed total allowances (non-basic earnings)
  double get totalAllowances {
    double sum = 0.0;
    for (final entry in earnings.entries) {
      sum += entry.value;
    }
    // Subtract basic from earnings sum to get pure allowances
    return sum - basic;
  }

  /// Computed gross = basic + all earnings
  double get grossSalary {
    return earnings.values.fold(0.0, (prev, e) => prev + e);
  }

  /// Computed total deductions
  double get totalDeductions {
    return deductions.values.fold(0.0, (prev, e) => prev + e);
  }

  /// Computed net salary
  double get netSalary => grossSalary - totalDeductions;

  factory SalaryStructureModel.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic v) {
      if (v == null) return DateTime.now();
      if (v is Timestamp) return v.toDate();
      return DateTime.parse(v.toString());
    }

    return SalaryStructureModel(
      structureId: map['structureId'] ?? '',
      companyId: map['companyId'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      basic: (map['basic'] as num?)?.toDouble() ?? 0.0,
      earnings: (map['earnings'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, (v as num).toDouble())) ??
          {},
      deductions: (map['deductions'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, (v as num).toDouble())) ??
          {},
      grossFormula: map['grossFormula'] ?? 'Basic + Allowances',
      netFormula: map['netFormula'] ?? 'Gross - Deductions',
      status: map['status'] ?? 'active',
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'structureId': structureId,
      'companyId': companyId,
      'name': name,
      'description': description,
      'basic': basic,
      'earnings': earnings,
      'deductions': deductions,
      'grossFormula': grossFormula,
      'netFormula': netFormula,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  SalaryStructureModel copyWith({
    String? structureId,
    String? companyId,
    String? name,
    String? description,
    double? basic,
    Map<String, double>? earnings,
    Map<String, double>? deductions,
    String? grossFormula,
    String? netFormula,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SalaryStructureModel(
      structureId: structureId ?? this.structureId,
      companyId: companyId ?? this.companyId,
      name: name ?? this.name,
      description: description ?? this.description,
      basic: basic ?? this.basic,
      earnings: earnings ?? this.earnings,
      deductions: deductions ?? this.deductions,
      grossFormula: grossFormula ?? this.grossFormula,
      netFormula: netFormula ?? this.netFormula,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
