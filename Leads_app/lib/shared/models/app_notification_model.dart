import 'package:cloud_firestore/cloud_firestore.dart';

class AppNotificationModel {
  final String notificationId;
  final String companyId;
  final String title;
  final String body;
  final String notificationType; // "EMPLOYEE_CREATED", "LEAVE_REQUEST", "TASK_ASSIGNED", etc.
  final bool isRead;
  final DateTime createdAt;

  // Targeting Metadata
  final String targetType; // 'COMPANY', 'USER', 'ROLE', 'DEPARTMENT'
  final String? targetUserId;
  final String? targetRole;
  final String? targetDepartmentId;

  // Context Metadata
  final String? actorUserId;
  final String? actorName;
  final String? relatedModule; // 'EMPLOYEE', 'LEAVE', 'ATTENDANCE', 'PAYROLL', 'LEAD', 'TASK', 'REPORTS', 'SETTINGS'
  final String? relatedEntityId;

  AppNotificationModel({
    required this.notificationId,
    required this.companyId,
    required this.title,
    required this.body,
    required this.notificationType,
    required this.isRead,
    required this.createdAt,
    this.targetType = 'COMPANY',
    this.targetUserId,
    this.targetRole,
    this.targetDepartmentId,
    this.actorUserId,
    this.actorName,
    this.relatedModule,
    this.relatedEntityId,
  });

  factory AppNotificationModel.fromMap(Map<String, dynamic> map) {
    return AppNotificationModel(
      notificationId: map['notificationId'] ?? '',
      companyId: map['companyId'] ?? '',
      title: map['title'] ?? '',
      body: map['body'] ?? '',
      notificationType: map['notificationType'] ?? '',
      isRead: map['isRead'] ?? false,
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      targetType: map['targetType'] ?? 'COMPANY',
      targetUserId: map['targetUserId'],
      targetRole: map['targetRole'],
      targetDepartmentId: map['targetDepartmentId'],
      actorUserId: map['actorUserId'],
      actorName: map['actorName'],
      relatedModule: map['relatedModule'],
      relatedEntityId: map['relatedEntityId'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'notificationId': notificationId,
      'companyId': companyId,
      'title': title,
      'body': body,
      'notificationType': notificationType,
      'isRead': isRead,
      'createdAt': Timestamp.fromDate(createdAt),
      'targetType': targetType,
      'targetUserId': targetUserId,
      'targetRole': targetRole,
      'targetDepartmentId': targetDepartmentId,
      'actorUserId': actorUserId,
      'actorName': actorName,
      'relatedModule': relatedModule,
      'relatedEntityId': relatedEntityId,
    };
  }
}
