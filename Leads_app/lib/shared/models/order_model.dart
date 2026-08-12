import 'package:cloud_firestore/cloud_firestore.dart';

class OrderModel {
  final String orderId;
  final String? leadId;
  final String companyId;
  final String customerName;
  final String projectName;
  final double amount;
  final String status; // 'Confirmed', 'Material Ordered', 'Installation', 'Completed', 'Closed', 'Cancelled'
  final DateTime expectedCompletion;
  final DateTime? completedOn;
  final DateTime? cancelledOn;
  final String assignedEngineer;
  final String assignedEngineerId;
  final DateTime createdAt;
  final DateTime updatedAt;

  OrderModel({
    required this.orderId,
    this.leadId,
    required this.companyId,
    required this.customerName,
    required this.projectName,
    required this.amount,
    required this.status,
    required this.expectedCompletion,
    this.completedOn,
    this.cancelledOn,
    required this.assignedEngineer,
    required this.assignedEngineerId,
    required this.createdAt,
    required this.updatedAt,
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

  factory OrderModel.fromMap(Map<String, dynamic> map) {
    return OrderModel(
      orderId: map['orderId'] ?? '',
      leadId: map['leadId'],
      companyId: map['companyId'] ?? '',
      customerName: map['customerName'] ?? '',
      projectName: map['projectName'] ?? '',
      amount: map['amount'] != null ? (map['amount'] as num).toDouble() : 0.0,
      status: map['status'] ?? 'Confirmed',
      expectedCompletion: _parseDate(map['expectedCompletion']),
      completedOn: _parseDateNullable(map['completedOn']),
      cancelledOn: _parseDateNullable(map['cancelledOn']),
      assignedEngineer: map['assignedEngineer'] ?? '',
      assignedEngineerId: map['assignedEngineerId'] ?? '',
      createdAt: _parseDate(map['createdAt']),
      updatedAt: _parseDate(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'orderId': orderId,
      'leadId': leadId,
      'companyId': companyId,
      'customerName': customerName,
      'projectName': projectName,
      'amount': amount,
      'status': status,
      'expectedCompletion': Timestamp.fromDate(expectedCompletion),
      'completedOn': completedOn != null ? Timestamp.fromDate(completedOn!) : null,
      'cancelledOn': cancelledOn != null ? Timestamp.fromDate(cancelledOn!) : null,
      'assignedEngineer': assignedEngineer,
      'assignedEngineerId': assignedEngineerId,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  OrderModel copyWith({
    String? orderId,
    String? leadId,
    String? companyId,
    String? customerName,
    String? projectName,
    double? amount,
    String? status,
    DateTime? expectedCompletion,
    DateTime? completedOn,
    DateTime? cancelledOn,
    String? assignedEngineer,
    String? assignedEngineerId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return OrderModel(
      orderId: orderId ?? this.orderId,
      leadId: leadId ?? this.leadId,
      companyId: companyId ?? this.companyId,
      customerName: customerName ?? this.customerName,
      projectName: projectName ?? this.projectName,
      amount: amount ?? this.amount,
      status: status ?? this.status,
      expectedCompletion: expectedCompletion ?? this.expectedCompletion,
      completedOn: completedOn ?? this.completedOn,
      cancelledOn: cancelledOn ?? this.cancelledOn,
      assignedEngineer: assignedEngineer ?? this.assignedEngineer,
      assignedEngineerId: assignedEngineerId ?? this.assignedEngineerId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
