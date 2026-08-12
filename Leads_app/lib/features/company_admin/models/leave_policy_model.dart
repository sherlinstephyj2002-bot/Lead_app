class LeavePolicyItem {
  final String leaveType; // 'Annual', 'Casual', 'Sick', 'Paternity', 'Loss Of Pay'
  final int maxDays;
  final bool carryForward;
  final String approvalFlow; // e.g. "Direct Manager", "HR Admin", "Company Admin"

  LeavePolicyItem({
    required this.leaveType,
    this.maxDays = 12,
    this.carryForward = false,
    this.approvalFlow = 'Company Admin',
  });

  factory LeavePolicyItem.fromMap(Map<String, dynamic> map, String leaveType) {
    return LeavePolicyItem(
      leaveType: leaveType,
      maxDays: map['maxDays'] != null ? (map['maxDays'] as num).toInt() : 12,
      carryForward: map['carryForward'] ?? false,
      approvalFlow: map['approvalFlow'] ?? 'Company Admin',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'maxDays': maxDays,
      'carryForward': carryForward,
      'approvalFlow': approvalFlow,
    };
  }

  LeavePolicyItem copyWith({
    String? leaveType,
    int? maxDays,
    bool? carryForward,
    String? approvalFlow,
  }) {
    return LeavePolicyItem(
      leaveType: leaveType ?? this.leaveType,
      maxDays: maxDays ?? this.maxDays,
      carryForward: carryForward ?? this.carryForward,
      approvalFlow: approvalFlow ?? this.approvalFlow,
    );
  }
}

class LeavePolicyModel {
  final String companyId;
  final Map<String, LeavePolicyItem> policies;

  LeavePolicyModel({
    required this.companyId,
    required this.policies,
  });

  factory LeavePolicyModel.fromMap(Map<String, dynamic> map, String companyId) {
    final Map<String, LeavePolicyItem> policiesMap = {};
    final defaultTypes = ['Annual', 'Casual', 'Sick', 'Paternity', 'Loss Of Pay'];
    
    for (final type in defaultTypes) {
      if (map[type] != null) {
        policiesMap[type] = LeavePolicyItem.fromMap(Map<String, dynamic>.from(map[type]), type);
      } else {
        policiesMap[type] = LeavePolicyItem(leaveType: type);
      }
    }
    return LeavePolicyModel(
      companyId: companyId,
      policies: policiesMap,
    );
  }

  Map<String, dynamic> toMap() {
    return policies.map((key, value) => MapEntry(key, value.toMap()));
  }

  LeavePolicyModel copyWith({
    String? companyId,
    Map<String, LeavePolicyItem>? policies,
  }) {
    return LeavePolicyModel(
      companyId: companyId ?? this.companyId,
      policies: policies ?? this.policies,
    );
  }
}
