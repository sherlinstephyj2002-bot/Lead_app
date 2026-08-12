import 'package:cloud_firestore/cloud_firestore.dart';

class HolidayModel {
  final String holidayId;
  final String companyId;
  final String? branchId;
  final String holidayName;
  final DateTime holidayDate;
  final String holidayType; // National / Company / Branch / Festival / Optional
  final String description;
  final bool isRecurring;
  final String status; // active, suspended, archived, deleted
  final DateTime createdAt;
  final DateTime updatedAt;

  HolidayModel({
    required this.holidayId,
    required this.companyId,
    this.branchId,
    required this.holidayName,
    required this.holidayDate,
    required this.holidayType,
    this.description = '',
    this.isRecurring = false,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory HolidayModel.fromMap(Map<String, dynamic> map) {
    return HolidayModel(
      holidayId: map['holidayId'] ?? '',
      companyId: map['companyId'] ?? '',
      branchId: map['branchId'],
      holidayName: map['holidayName'] ?? '',
      holidayDate: map['holidayDate'] != null
          ? (map['holidayDate'] is Timestamp 
              ? (map['holidayDate'] as Timestamp).toDate() 
              : DateTime.parse(map['holidayDate'] as String))
          : DateTime.now(),
      holidayType: map['holidayType'] ?? 'National',
      description: map['description'] ?? '',
      isRecurring: map['isRecurring'] ?? false,
      status: map['status'] ?? 'active',
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] is Timestamp 
              ? (map['createdAt'] as Timestamp).toDate() 
              : DateTime.parse(map['createdAt'] as String))
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? (map['updatedAt'] is Timestamp 
              ? (map['updatedAt'] as Timestamp).toDate() 
              : DateTime.parse(map['updatedAt'] as String))
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'holidayId': holidayId,
      'companyId': companyId,
      'branchId': branchId,
      'holidayName': holidayName,
      'holidayDate': Timestamp.fromDate(holidayDate),
      'holidayType': holidayType,
      'description': description,
      'isRecurring': isRecurring,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  HolidayModel copyWith({
    String? holidayId,
    String? companyId,
    String? branchId,
    String? holidayName,
    DateTime? holidayDate,
    String? holidayType,
    String? description,
    bool? isRecurring,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return HolidayModel(
      holidayId: holidayId ?? this.holidayId,
      companyId: companyId ?? this.companyId,
      branchId: branchId ?? this.branchId,
      holidayName: holidayName ?? this.holidayName,
      holidayDate: holidayDate ?? this.holidayDate,
      holidayType: holidayType ?? this.holidayType,
      description: description ?? this.description,
      isRecurring: isRecurring ?? this.isRecurring,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
