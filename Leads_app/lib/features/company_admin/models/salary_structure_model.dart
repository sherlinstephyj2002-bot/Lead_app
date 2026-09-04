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

  /// Monthly salary target
  final double monthlySalary;

  /// Annual salary target (monthlySalary * 12)
  final double annualSalary;

  /// Basic salary amount
  final double basic;

  /// Dedicated bonus amount
  final double bonus;

  /// Dedicated incentive amount
  final double incentive;

  /// Flat allowances map: componentId -> amount
  final Map<String, double> earnings;

  /// Deductions map: componentId -> amount
  final Map<String, double> deductions;

  /// Percentages map: componentId -> percentage rate (e.g. 40.0 for HRA)
  final Map<String, double> componentPercentages;

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
    this.monthlySalary = 0.0,
    this.annualSalary = 0.0,
    this.basic = 0.0,
    this.bonus = 0.0,
    this.incentive = 0.0,
    required this.earnings,
    required this.deductions,
    this.componentPercentages = const {},
    this.grossFormula = 'Basic + Allowances + Incentive + Bonus',
    this.netFormula = 'Gross - Deductions',
    this.status = 'active',
    required this.createdAt,
    required this.updatedAt,
  });

  /// Computed total allowances (non-basic earnings)
  double get totalAllowances {
    double sum = 0.0;
    for (final entry in earnings.entries) {
      if (entry.key.toLowerCase().contains('basic')) continue;
      sum += entry.value;
    }
    return sum;
  }

  /// Computed gross = basic + allowances + incentive + bonus
  double get grossSalary {
    final earningsSum = earnings.values.fold(0.0, (prev, e) => prev + e);
    // If earnings map doesn't already contain basic, add basic
    final hasBasicKey = earnings.keys.any((k) => k.toLowerCase().contains('basic'));
    final totalBase = hasBasicKey ? earningsSum : basic + earningsSum;
    return totalBase + bonus + incentive;
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

    final basicVal = (map['basic'] as num?)?.toDouble() ?? 0.0;
    final monthlyVal = (map['monthlySalary'] as num?)?.toDouble() ?? (basicVal > 0 ? basicVal : 0.0);
    final annualVal = (map['annualSalary'] as num?)?.toDouble() ?? (monthlyVal * 12);

    return SalaryStructureModel(
      structureId: map['structureId'] ?? '',
      companyId: map['companyId'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      monthlySalary: monthlyVal,
      annualSalary: annualVal,
      basic: basicVal,
      bonus: (map['bonus'] as num?)?.toDouble() ?? 0.0,
      incentive: (map['incentive'] as num?)?.toDouble() ?? 0.0,
      earnings: (map['earnings'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, (v as num).toDouble())) ??
          {},
      deductions: (map['deductions'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, (v as num).toDouble())) ??
          {},
      componentPercentages: (map['componentPercentages'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, (v as num).toDouble())) ??
          {},
      grossFormula: map['grossFormula'] ?? 'Basic + Allowances + Incentive + Bonus',
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
      'monthlySalary': monthlySalary,
      'annualSalary': annualSalary,
      'basic': basic,
      'bonus': bonus,
      'incentive': incentive,
      'earnings': earnings,
      'deductions': deductions,
      'componentPercentages': componentPercentages,
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
    double? monthlySalary,
    double? annualSalary,
    double? basic,
    double? bonus,
    double? incentive,
    Map<String, double>? earnings,
    Map<String, double>? deductions,
    Map<String, double>? componentPercentages,
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
      monthlySalary: monthlySalary ?? this.monthlySalary,
      annualSalary: annualSalary ?? this.annualSalary,
      basic: basic ?? this.basic,
      bonus: bonus ?? this.bonus,
      incentive: incentive ?? this.incentive,
      earnings: earnings ?? this.earnings,
      deductions: deductions ?? this.deductions,
      componentPercentages: componentPercentages ?? this.componentPercentages,
      grossFormula: grossFormula ?? this.grossFormula,
      netFormula: netFormula ?? this.netFormula,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
