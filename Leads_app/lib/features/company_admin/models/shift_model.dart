import 'package:cloud_firestore/cloud_firestore.dart';

class ShiftModel {
  final String shiftId;
  final String companyId;
  final String shiftName;
  final String shiftCode;
  final String startTime; // Format: "HH:mm" (e.g. "09:00")
  final String endTime;   // Format: "HH:mm" (e.g. "18:00")
  final int breakDurationMinutes;
  final double workingHours;
  final int gracePeriodMinutes;
  final double halfDayThresholdHours;
  final bool overtimeAllowed;
  final double overtimeStartAfterHours;
  final double otLimitHours;
  final List<String> weeklyOffDays;
  final String status; // active, suspended, archived, deleted
  final DateTime createdAt;
  final DateTime updatedAt;

  // Backwards compatibility fields/getters
  int get breakDuration => breakDurationMinutes;
  int get lateToleranceMinutes => gracePeriodMinutes;
  int get lateTolerance => gracePeriodMinutes;
  int get earlyExitToleranceMinutes => 0;
  bool get overtimeEligible => overtimeAllowed;
  double get otLimit => otLimitHours;
  double get maxTotalWorkingTimeHours => overtimeAllowed ? (workingHours + otLimitHours) : workingHours;

  ShiftModel({
    required this.shiftId,
    required this.companyId,
    required this.shiftName,
    required this.shiftCode,
    required this.startTime,
    required this.endTime,
    required this.breakDurationMinutes,
    required this.workingHours,
    required this.gracePeriodMinutes,
    required this.halfDayThresholdHours,
    required this.overtimeAllowed,
    required this.overtimeStartAfterHours,
    this.otLimitHours = 2.0,
    required this.weeklyOffDays,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ShiftModel.fromMap(Map<String, dynamic> map) {
    return ShiftModel(
      shiftId: map['shiftId'] ?? '',
      companyId: map['companyId'] ?? '',
      shiftName: map['shiftName'] ?? '',
      shiftCode: map['shiftCode'] ?? '',
      startTime: map['startTime'] ?? '09:00',
      endTime: map['endTime'] ?? '18:00',
      breakDurationMinutes: map['breakDurationMinutes'] != null 
          ? (map['breakDurationMinutes'] as num).toInt() 
          : (map['breakDuration'] != null ? (map['breakDuration'] as num).toInt() : 0),
      workingHours: map['workingHours'] != null ? (map['workingHours'] as num).toDouble() : 8.0,
      gracePeriodMinutes: map['gracePeriodMinutes'] != null 
          ? (map['gracePeriodMinutes'] as num).toInt() 
          : (map['lateToleranceMinutes'] != null 
              ? (map['lateToleranceMinutes'] as num).toInt() 
              : (map['lateTolerance'] != null ? (map['lateTolerance'] as num).toInt() : 0)),
      halfDayThresholdHours: map['halfDayThresholdHours'] != null ? (map['halfDayThresholdHours'] as num).toDouble() : 4.0,
      overtimeAllowed: map['overtimeAllowed'] ?? map['overtimeEligible'] ?? false,
      overtimeStartAfterHours: map['overtimeStartAfterHours'] != null ? (map['overtimeStartAfterHours'] as num).toDouble() : 9.0,
      otLimitHours: map['otLimitHours'] != null 
          ? (map['otLimitHours'] as num).toDouble() 
          : (map['otLimit'] != null ? (map['otLimit'] as num).toDouble() : 2.0),
      weeklyOffDays: map['weeklyOffDays'] != null ? List<String>.from(map['weeklyOffDays']) : ['Sunday'],
      status: map['status'] ?? 'active',
      createdAt: map['createdAt'] != null 
          ? (map['createdAt'] is String ? DateTime.parse(map['createdAt']) : (map['createdAt'] as Timestamp).toDate())
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null 
          ? (map['updatedAt'] is String ? DateTime.parse(map['updatedAt']) : (map['updatedAt'] as Timestamp).toDate())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'shiftId': shiftId,
      'companyId': companyId,
      'shiftName': shiftName,
      'shiftCode': shiftCode,
      'startTime': startTime,
      'endTime': endTime,
      'breakDurationMinutes': breakDurationMinutes,
      'breakDuration': breakDurationMinutes, // Backwards compatibility
      'workingHours': workingHours,
      'gracePeriodMinutes': gracePeriodMinutes,
      'lateToleranceMinutes': gracePeriodMinutes, // Backwards compatibility
      'lateTolerance': gracePeriodMinutes, // Backwards compatibility
      'earlyExitToleranceMinutes': 0, // Backwards compatibility
      'halfDayThresholdHours': halfDayThresholdHours,
      'overtimeAllowed': overtimeAllowed,
      'overtimeEligible': overtimeAllowed, // Backwards compatibility
      'overtimeStartAfterHours': overtimeStartAfterHours,
      'otLimitHours': otLimitHours,
      'otLimit': otLimitHours, // Backwards compatibility
      'weeklyOffDays': weeklyOffDays,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  ShiftModel copyWith({
    String? shiftId,
    String? companyId,
    String? shiftName,
    String? shiftCode,
    String? startTime,
    String? endTime,
    int? breakDurationMinutes,
    double? workingHours,
    int? gracePeriodMinutes,
    double? halfDayThresholdHours,
    bool? overtimeAllowed,
    double? overtimeStartAfterHours,
    double? otLimitHours,
    List<String>? weeklyOffDays,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ShiftModel(
      shiftId: shiftId ?? this.shiftId,
      companyId: companyId ?? this.companyId,
      shiftName: shiftName ?? this.shiftName,
      shiftCode: shiftCode ?? this.shiftCode,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      breakDurationMinutes: breakDurationMinutes ?? this.breakDurationMinutes,
      workingHours: workingHours ?? this.workingHours,
      gracePeriodMinutes: gracePeriodMinutes ?? this.gracePeriodMinutes,
      halfDayThresholdHours: halfDayThresholdHours ?? this.halfDayThresholdHours,
      overtimeAllowed: overtimeAllowed ?? this.overtimeAllowed,
      overtimeStartAfterHours: overtimeStartAfterHours ?? this.overtimeStartAfterHours,
      otLimitHours: otLimitHours ?? this.otLimitHours,
      weeklyOffDays: weeklyOffDays ?? this.weeklyOffDays,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
