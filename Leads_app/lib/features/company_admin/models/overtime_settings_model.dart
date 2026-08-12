class OvertimeSettingsModel {
  final String companyId;
  final int minOt; // in minutes
  final int maxOt; // in minutes
  final String rateType; // e.g. "Hourly Rate", "Fixed Multiplier"
  final double hourlyRate;
  final bool approvalRequired;

  OvertimeSettingsModel({
    required this.companyId,
    this.minOt = 30,
    this.maxOt = 240,
    this.rateType = 'Hourly Rate',
    this.hourlyRate = 0.0,
    this.approvalRequired = true,
  });

  factory OvertimeSettingsModel.fromMap(Map<String, dynamic> map, String companyId) {
    return OvertimeSettingsModel(
      companyId: companyId,
      minOt: map['minOt'] != null ? (map['minOt'] as num).toInt() : 30,
      maxOt: map['maxOt'] != null ? (map['maxOt'] as num).toInt() : 240,
      rateType: map['rateType'] ?? 'Hourly Rate',
      hourlyRate: map['hourlyRate'] != null ? (map['hourlyRate'] as num).toDouble() : 0.0,
      approvalRequired: map['approvalRequired'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'minOt': minOt,
      'maxOt': maxOt,
      'rateType': rateType,
      'hourlyRate': hourlyRate,
      'approvalRequired': approvalRequired,
    };
  }

  OvertimeSettingsModel copyWith({
    String? companyId,
    int? minOt,
    int? maxOt,
    String? rateType,
    double? hourlyRate,
    bool? approvalRequired,
  }) {
    return OvertimeSettingsModel(
      companyId: companyId ?? this.companyId,
      minOt: minOt ?? this.minOt,
      maxOt: maxOt ?? this.maxOt,
      rateType: rateType ?? this.rateType,
      hourlyRate: hourlyRate ?? this.hourlyRate,
      approvalRequired: approvalRequired ?? this.approvalRequired,
    );
  }
}
