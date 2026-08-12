class SubscriptionPlanModel {
  final String planId;
  final String name;
  final int freeEmployeeLimit;
  final double pricePerEmployee;
  final String description;

  SubscriptionPlanModel({
    required this.planId,
    required this.name,
    required this.freeEmployeeLimit,
    required this.pricePerEmployee,
    required this.description,
  });

  factory SubscriptionPlanModel.fromMap(Map<String, dynamic> map) {
    return SubscriptionPlanModel(
      planId: map['planId'] ?? '',
      name: map['name'] ?? '',
      freeEmployeeLimit: map['freeEmployeeLimit'] ?? 0,
      pricePerEmployee: (map['pricePerEmployee'] as num?)?.toDouble() ?? 0.0,
      description: map['description'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'planId': planId,
      'name': name,
      'freeEmployeeLimit': freeEmployeeLimit,
      'pricePerEmployee': pricePerEmployee,
      'description': description,
    };
  }
}
