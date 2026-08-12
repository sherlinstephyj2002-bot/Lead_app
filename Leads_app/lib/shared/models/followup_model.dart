import 'package:cloud_firestore/cloud_firestore.dart';

class FollowupModel {
  final String followUpId;
  final String leadId;
  final String companyId;
  final String assignedUser;
  final String assignedUserId;
  final DateTime followUpDate;
  final String remarks;
  final String status; // 'Upcoming', 'Completed', 'Missed'
  final DateTime createdAt;

  FollowupModel({
    required this.followUpId,
    required this.leadId,
    required this.companyId,
    required this.assignedUser,
    required this.assignedUserId,
    required this.followUpDate,
    required this.remarks,
    required this.status,
    required this.createdAt,
  });

  static DateTime _parseDate(dynamic v) {
    if (v == null) return DateTime.now();
    if (v is Timestamp) return v.toDate();
    if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    return DateTime.now();
  }

  factory FollowupModel.fromMap(Map<String, dynamic> map) {
    return FollowupModel(
      followUpId: map['followUpId'] ?? '',
      leadId: map['leadId'] ?? '',
      companyId: map['companyId'] ?? '',
      assignedUser: map['assignedUser'] ?? '',
      assignedUserId: map['assignedUserId'] ?? '',
      followUpDate: _parseDate(map['followUpDate']),
      remarks: map['remarks'] ?? '',
      status: map['status'] ?? 'Upcoming',
      createdAt: _parseDate(map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'followUpId': followUpId,
      'leadId': leadId,
      'companyId': companyId,
      'assignedUser': assignedUser,
      'assignedUserId': assignedUserId,
      'followUpDate': Timestamp.fromDate(followUpDate),
      'remarks': remarks,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  FollowupModel copyWith({
    String? followUpId,
    String? leadId,
    String? companyId,
    String? assignedUser,
    String? assignedUserId,
    DateTime? followUpDate,
    String? remarks,
    String? status,
    DateTime? createdAt,
  }) {
    return FollowupModel(
      followUpId: followUpId ?? this.followUpId,
      leadId: leadId ?? this.leadId,
      companyId: companyId ?? this.companyId,
      assignedUser: assignedUser ?? this.assignedUser,
      assignedUserId: assignedUserId ?? this.assignedUserId,
      followUpDate: followUpDate ?? this.followUpDate,
      remarks: remarks ?? this.remarks,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
