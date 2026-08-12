class PfEsiTaxSettingsModel {
  final String companyId;
  final bool pfEnabled;
  final bool esiEnabled;
  final bool profTaxEnabled;
  final double pfEmployerContribution; // e.g. 12%
  final double pfEmployeeContribution; // e.g. 12%
  final double esiEmployerContribution; // e.g. 3.25%
  final double esiEmployeeContribution; // e.g. 0.75%
  final List<Map<String, dynamic>> taxSlabs; // e.g. [{'min': 0, 'max': 10000, 'tax': 0}]

  PfEsiTaxSettingsModel({
    required this.companyId,
    this.pfEnabled = false,
    this.esiEnabled = false,
    this.profTaxEnabled = false,
    this.pfEmployerContribution = 12.0,
    this.pfEmployeeContribution = 12.0,
    this.esiEmployerContribution = 3.25,
    this.esiEmployeeContribution = 0.75,
    this.taxSlabs = const [],
  });

  factory PfEsiTaxSettingsModel.fromMap(Map<String, dynamic> map, String companyId) {
    return PfEsiTaxSettingsModel(
      companyId: companyId,
      pfEnabled: map['pfEnabled'] ?? false,
      esiEnabled: map['esiEnabled'] ?? false,
      profTaxEnabled: map['profTaxEnabled'] ?? false,
      pfEmployerContribution: map['pfEmployerContribution'] != null ? (map['pfEmployerContribution'] as num).toDouble() : 12.0,
      pfEmployeeContribution: map['pfEmployeeContribution'] != null ? (map['pfEmployeeContribution'] as num).toDouble() : 12.0,
      esiEmployerContribution: map['esiEmployerContribution'] != null ? (map['esiEmployerContribution'] as num).toDouble() : 3.25,
      esiEmployeeContribution: map['esiEmployeeContribution'] != null ? (map['esiEmployeeContribution'] as num).toDouble() : 0.75,
      taxSlabs: map['taxSlabs'] != null ? List<Map<String, dynamic>>.from(map['taxSlabs'].map((item) => Map<String, dynamic>.from(item))) : const [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'pfEnabled': pfEnabled,
      'esiEnabled': esiEnabled,
      'profTaxEnabled': profTaxEnabled,
      'pfEmployerContribution': pfEmployerContribution,
      'pfEmployeeContribution': pfEmployeeContribution,
      'esiEmployerContribution': esiEmployerContribution,
      'esiEmployeeContribution': esiEmployeeContribution,
      'taxSlabs': taxSlabs,
    };
  }

  PfEsiTaxSettingsModel copyWith({
    String? companyId,
    bool? pfEnabled,
    bool? esiEnabled,
    bool? profTaxEnabled,
    double? pfEmployerContribution,
    double? pfEmployeeContribution,
    double? esiEmployerContribution,
    double? esiEmployeeContribution,
    List<Map<String, dynamic>>? taxSlabs,
  }) {
    return PfEsiTaxSettingsModel(
      companyId: companyId ?? this.companyId,
      pfEnabled: pfEnabled ?? this.pfEnabled,
      esiEnabled: esiEnabled ?? this.esiEnabled,
      profTaxEnabled: profTaxEnabled ?? this.profTaxEnabled,
      pfEmployerContribution: pfEmployerContribution ?? this.pfEmployerContribution,
      pfEmployeeContribution: pfEmployeeContribution ?? this.pfEmployeeContribution,
      esiEmployerContribution: esiEmployerContribution ?? this.esiEmployerContribution,
      esiEmployeeContribution: esiEmployeeContribution ?? this.esiEmployeeContribution,
      taxSlabs: taxSlabs ?? this.taxSlabs,
    );
  }
}
