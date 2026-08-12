class PayrollSettingsModel {
  final String companyId;
  final int payrollStartDate; // e.g. 1 (1st of month)
  final int payrollEndDate;   // e.g. 30/31 (end of month)
  final int salaryCreditDate; // e.g. 5 (5th of next month)
  final int workingDays;      // e.g. 26
  final List<String> weeklyOff; // e.g. ["Sunday"]

  PayrollSettingsModel({
    required this.companyId,
    this.payrollStartDate = 1,
    this.payrollEndDate = 30,
    this.salaryCreditDate = 5,
    this.workingDays = 26,
    this.weeklyOff = const ['Sunday'],
  });

  factory PayrollSettingsModel.fromMap(Map<String, dynamic> map, String companyId) {
    return PayrollSettingsModel(
      companyId: companyId,
      payrollStartDate: map['payrollStartDate'] != null ? (map['payrollStartDate'] as num).toInt() : 1,
      payrollEndDate: map['payrollEndDate'] != null ? (map['payrollEndDate'] as num).toInt() : 30,
      salaryCreditDate: map['salaryCreditDate'] != null ? (map['salaryCreditDate'] as num).toInt() : 5,
      workingDays: map['workingDays'] != null ? (map['workingDays'] as num).toInt() : 26,
      weeklyOff: map['weeklyOff'] != null ? List<String>.from(map['weeklyOff']) : const ['Sunday'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'payrollStartDate': payrollStartDate,
      'payrollEndDate': payrollEndDate,
      'salaryCreditDate': salaryCreditDate,
      'workingDays': workingDays,
      'weeklyOff': weeklyOff,
    };
  }

  PayrollSettingsModel copyWith({
    String? companyId,
    int? payrollStartDate,
    int? payrollEndDate,
    int? salaryCreditDate,
    int? workingDays,
    List<String>? weeklyOff,
  }) {
    return PayrollSettingsModel(
      companyId: companyId ?? this.companyId,
      payrollStartDate: payrollStartDate ?? this.payrollStartDate,
      payrollEndDate: payrollEndDate ?? this.payrollEndDate,
      salaryCreditDate: salaryCreditDate ?? this.salaryCreditDate,
      workingDays: workingDays ?? this.workingDays,
      weeklyOff: weeklyOff ?? this.weeklyOff,
    );
  }
}
