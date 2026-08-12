class LeadActivityModel {
  final String activityId;
  final String leadId;
  final String companyId;

  final String activityType;
  final String description;

  final String performedBy;
  final String performedById;

  final DateTime createdAt;

  const LeadActivityModel({
    required this.activityId,
    required this.leadId,
    required this.companyId,
    required this.activityType,
    required this.description,
    required this.performedBy,
    required this.performedById,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'activityId': activityId,
      'leadId': leadId,
      'companyId': companyId,
      'activityType': activityType,
      'description': description,
      'performedBy': performedBy,
      'performedById': performedById,
      'createdAt': createdAt,
    };
  }

  factory LeadActivityModel.fromMap(Map<String, dynamic> map) {
    return LeadActivityModel(
      activityId: map['activityId'],
      leadId: map['leadId'],
      companyId: map['companyId'],
      activityType: map['activityType'],
      description: map['description'],
      performedBy: map['performedBy'],
      performedById: map['performedById'],
      createdAt: map['createdAt'].toDate(),
    );
  }
}