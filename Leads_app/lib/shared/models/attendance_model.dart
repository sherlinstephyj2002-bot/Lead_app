import 'package:cloud_firestore/cloud_firestore.dart';

class AttendanceModel {
  final String attendanceId;
  final String companyId;
  final String employeeId;
  final String employeeName;
  final DateTime checkInTime;
  final DateTime? checkOutTime;
  final double? latitude;
  final double? longitude;
  final String? address;
  final double? checkoutLatitude;
  final double? checkoutLongitude;
  final String? checkoutAddress;
  final double? workHours;
  final String status; // 'Present', 'Late', 'Half Day', 'Absent', 'PendingCorrection', etc.
  final DateTime createdAt;
  final String? shiftId;
  final String? shiftName;
  final String? shiftCode;
  final double? overtimeHours;
  final bool? earlyExit;
  final String? correctionReason;

  AttendanceModel({
    required this.attendanceId,
    required this.companyId,
    required this.employeeId,
    required this.employeeName,
    required this.checkInTime,
    this.checkOutTime,
    this.latitude,
    this.longitude,
    this.address,
    this.checkoutLatitude,
    this.checkoutLongitude,
    this.checkoutAddress,
    this.workHours,
    required this.status,
    required this.createdAt,
    this.shiftId,
    this.shiftName,
    this.shiftCode,
    this.overtimeHours,
    this.earlyExit,
    this.correctionReason,
  });

  static DateTime _parseDate(dynamic v) {
    if (v == null) return DateTime.now();
    if (v is Timestamp) return v.toDate();
    if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    return DateTime.now();
  }

  static DateTime? _parseDateNullable(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is String) return DateTime.tryParse(v);
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    return null;
  }

  factory AttendanceModel.fromMap(Map<String, dynamic> map) {
    return AttendanceModel(
      attendanceId: map['attendanceId'] ?? '',
      companyId: map['companyId'] ?? '',
      employeeId: map['employeeId'] ?? '',
      employeeName: map['employeeName'] ?? '',
      checkInTime: _parseDate(map['checkInTime']),
      checkOutTime: _parseDateNullable(map['checkOutTime']),
      latitude: map['latitude'] != null ? (map['latitude'] as num).toDouble() : null,
      longitude: map['longitude'] != null ? (map['longitude'] as num).toDouble() : null,
      address: map['address'],
      checkoutLatitude: map['checkoutLatitude'] != null ? (map['checkoutLatitude'] as num).toDouble() : null,
      checkoutLongitude: map['checkoutLongitude'] != null ? (map['checkoutLongitude'] as num).toDouble() : null,
      checkoutAddress: map['checkoutAddress'],
      workHours: map['workHours'] != null ? (map['workHours'] as num).toDouble() : null,
      status: map['status'] ?? 'Present',
      createdAt: _parseDate(map['createdAt']),
      shiftId: map['shiftId'],
      shiftName: map['shiftName'],
      shiftCode: map['shiftCode'],
      overtimeHours: map['overtimeHours'] != null ? (map['overtimeHours'] as num).toDouble() : null,
      earlyExit: map['earlyExit'],
      correctionReason: map['correctionReason'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'attendanceId': attendanceId,
      'companyId': companyId,
      'employeeId': employeeId,
      'employeeName': employeeName,
      'checkInTime': Timestamp.fromDate(checkInTime),
      'checkOutTime': checkOutTime != null ? Timestamp.fromDate(checkOutTime!) : null,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'checkoutLatitude': checkoutLatitude,
      'checkoutLongitude': checkoutLongitude,
      'checkoutAddress': checkoutAddress,
      'workHours': workHours,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'shiftId': shiftId,
      'shiftName': shiftName,
      'shiftCode': shiftCode,
      'overtimeHours': overtimeHours,
      'earlyExit': earlyExit,
      'correctionReason': correctionReason,
    };
  }

  AttendanceModel copyWith({
    String? attendanceId,
    String? companyId,
    String? employeeId,
    String? employeeName,
    DateTime? checkInTime,
    DateTime? checkOutTime,
    double? latitude,
    double? longitude,
    String? address,
    double? checkoutLatitude,
    double? checkoutLongitude,
    String? checkoutAddress,
    double? workHours,
    String? status,
    DateTime? createdAt,
    String? shiftId,
    String? shiftName,
    String? shiftCode,
    double? overtimeHours,
    bool? earlyExit,
    String? correctionReason,
  }) {
    return AttendanceModel(
      attendanceId: attendanceId ?? this.attendanceId,
      companyId: companyId ?? this.companyId,
      employeeId: employeeId ?? this.employeeId,
      employeeName: employeeName ?? this.employeeName,
      checkInTime: checkInTime ?? this.checkInTime,
      checkOutTime: checkOutTime ?? this.checkOutTime,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
      checkoutLatitude: checkoutLatitude ?? this.checkoutLatitude,
      checkoutLongitude: checkoutLongitude ?? this.checkoutLongitude,
      checkoutAddress: checkoutAddress ?? this.checkoutAddress,
      workHours: workHours ?? this.workHours,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      shiftId: shiftId ?? this.shiftId,
      shiftName: shiftName ?? this.shiftName,
      shiftCode: shiftCode ?? this.shiftCode,
      overtimeHours: overtimeHours ?? this.overtimeHours,
      earlyExit: earlyExit ?? this.earlyExit,
      correctionReason: correctionReason ?? this.correctionReason,
    );
  }
}
