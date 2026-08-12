import 'package:cloud_firestore/cloud_firestore.dart';

class AttendanceSettingsModel {
  final String companyId;
  final double minimumWorkingHours;
  final double halfDayHours;
  final int lateGraceMinutes;
  final int earlyExitGraceMinutes;
  final double overtimeStartAfterHours;
  final double maximumOvertimeHours;
  final bool gpsRequired;
  final bool selfieRequired;
  final bool geofenceEnabled;
  final double? geofenceRadius;
  final bool allowAttendanceCorrection;
  final List<String> weekendDays;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Backwards compatibility getters and fields
  int get lateEntryMinutes => lateGraceMinutes;
  int get earlyExitMinutes => earlyExitGraceMinutes;
  String get halfDayRules => 'Work less than $halfDayHours hours';
  String get absentRules => 'Work less than $minimumWorkingHours hours';
  List<String> get weekendRules => weekendDays;
  bool get gpsMandatory => gpsRequired;
  bool get approvalRequired => false;
  double? get geofenceLat => null;
  double? get geofenceLng => null;

  AttendanceSettingsModel({
    required this.companyId,
    this.minimumWorkingHours = 8.0,
    this.halfDayHours = 4.0,
    this.lateGraceMinutes = 15,
    this.earlyExitGraceMinutes = 15,
    this.overtimeStartAfterHours = 9.0,
    this.maximumOvertimeHours = 4.0,
    this.gpsRequired = false,
    this.selfieRequired = false,
    this.geofenceEnabled = false,
    this.geofenceRadius,
    this.allowAttendanceCorrection = true,
    this.weekendDays = const ['Sunday'],
    this.status = 'active',
    required this.createdAt,
    required this.updatedAt,
  });

  factory AttendanceSettingsModel.fromMap(Map<String, dynamic> map, String companyId) {
    return AttendanceSettingsModel(
      companyId: companyId,
      minimumWorkingHours: map['minimumWorkingHours'] != null ? (map['minimumWorkingHours'] as num).toDouble() : 8.0,
      halfDayHours: map['halfDayHours'] != null ? (map['halfDayHours'] as num).toDouble() : 4.0,
      lateGraceMinutes: map['lateGraceMinutes'] != null 
          ? (map['lateGraceMinutes'] as num).toInt() 
          : (map['lateEntryMinutes'] != null ? (map['lateEntryMinutes'] as num).toInt() : 15),
      earlyExitGraceMinutes: map['earlyExitGraceMinutes'] != null 
          ? (map['earlyExitGraceMinutes'] as num).toInt() 
          : (map['earlyExitMinutes'] != null ? (map['earlyExitMinutes'] as num).toInt() : 15),
      overtimeStartAfterHours: map['overtimeStartAfterHours'] != null ? (map['overtimeStartAfterHours'] as num).toDouble() : 9.0,
      maximumOvertimeHours: map['maximumOvertimeHours'] != null ? (map['maximumOvertimeHours'] as num).toDouble() : 4.0,
      gpsRequired: map['gpsRequired'] ?? map['gpsMandatory'] ?? false,
      selfieRequired: map['selfieRequired'] ?? false,
      geofenceEnabled: map['geofenceEnabled'] ?? false,
      geofenceRadius: map['geofenceRadius'] != null ? (map['geofenceRadius'] as num).toDouble() : null,
      allowAttendanceCorrection: map['allowAttendanceCorrection'] ?? true,
      weekendDays: map['weekendDays'] != null 
          ? List<String>.from(map['weekendDays']) 
          : (map['weekendRules'] != null ? List<String>.from(map['weekendRules']) : const ['Sunday']),
      status: map['status'] ?? 'active',
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] is Timestamp ? (map['createdAt'] as Timestamp).toDate() : DateTime.parse(map['createdAt']))
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? (map['updatedAt'] is Timestamp ? (map['updatedAt'] as Timestamp).toDate() : DateTime.parse(map['updatedAt']))
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'companyId': companyId,
      'minimumWorkingHours': minimumWorkingHours,
      'halfDayHours': halfDayHours,
      'lateGraceMinutes': lateGraceMinutes,
      'lateEntryMinutes': lateGraceMinutes, // Backwards compatibility
      'earlyExitGraceMinutes': earlyExitGraceMinutes,
      'earlyExitMinutes': earlyExitGraceMinutes, // Backwards compatibility
      'overtimeStartAfterHours': overtimeStartAfterHours,
      'maximumOvertimeHours': maximumOvertimeHours,
      'gpsRequired': gpsRequired,
      'gpsMandatory': gpsRequired, // Backwards compatibility
      'selfieRequired': selfieRequired,
      'geofenceEnabled': geofenceEnabled,
      'geofenceRadius': geofenceRadius,
      'allowAttendanceCorrection': allowAttendanceCorrection,
      'weekendDays': weekendDays,
      'weekendRules': weekendDays, // Backwards compatibility
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  AttendanceSettingsModel copyWith({
    String? companyId,
    double? minimumWorkingHours,
    double? halfDayHours,
    int? lateGraceMinutes,
    int? earlyExitGraceMinutes,
    double? overtimeStartAfterHours,
    double? maximumOvertimeHours,
    bool? gpsRequired,
    bool? selfieRequired,
    bool? geofenceEnabled,
    double? geofenceRadius,
    bool? allowAttendanceCorrection,
    List<String>? weekendDays,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AttendanceSettingsModel(
      companyId: companyId ?? this.companyId,
      minimumWorkingHours: minimumWorkingHours ?? this.minimumWorkingHours,
      halfDayHours: halfDayHours ?? this.halfDayHours,
      lateGraceMinutes: lateGraceMinutes ?? this.lateGraceMinutes,
      earlyExitGraceMinutes: earlyExitGraceMinutes ?? this.earlyExitGraceMinutes,
      overtimeStartAfterHours: overtimeStartAfterHours ?? this.overtimeStartAfterHours,
      maximumOvertimeHours: maximumOvertimeHours ?? this.maximumOvertimeHours,
      gpsRequired: gpsRequired ?? this.gpsRequired,
      selfieRequired: selfieRequired ?? this.selfieRequired,
      geofenceEnabled: geofenceEnabled ?? this.geofenceEnabled,
      geofenceRadius: geofenceRadius ?? this.geofenceRadius,
      allowAttendanceCorrection: allowAttendanceCorrection ?? this.allowAttendanceCorrection,
      weekendDays: weekendDays ?? this.weekendDays,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
