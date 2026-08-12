import 'package:cloud_firestore/cloud_firestore.dart';

class LeadModel {
  final String leadId;
  final String companyId;
  final String customerName;
  final String mobileNumber;
  final String companyName;
  final String? email;
  final String location;
  final String requirement;
  final String? remarks;
  final String leadSource;
  final String assignedTo;
  final String assignedToId;
  final String status; // 'New', 'Follow Up', 'Quotation Sent', 'Won', 'Lost'
  final DateTime createdAt;
  final DateTime updatedAt;

  LeadModel({
    required this.leadId,
    required this.companyId,
    required this.customerName,
    required this.mobileNumber,
    required this.companyName,
    this.email,
    required this.location,
    required this.requirement,
    this.remarks,
    required this.leadSource,
    required this.assignedTo,
    required this.assignedToId,
    required this.status,
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

  factory LeadModel.fromMap(Map<String, dynamic> map) {
    return LeadModel(
      leadId: map['leadId'] ?? '',
      companyId: map['companyId'] ?? '',
      customerName: map['customerName'] ?? '',
      mobileNumber: map['mobileNumber'] ?? '',
      companyName: map['companyName'] ?? '',
      email: map['email'],
      location: map['location'] ?? '',
      requirement: map['requirement'] ?? '',
      remarks: map['remarks'],
      leadSource: map['leadSource'] ?? 'Direct',
      assignedTo: map['assignedTo'] ?? '',
      assignedToId: map['assignedToId'] ?? '',
      status: map['status'] ?? 'New',
      createdAt: _parseDate(map['createdAt']),
      updatedAt: _parseDate(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'leadId': leadId,
      'companyId': companyId,
      'customerName': customerName,
      'mobileNumber': mobileNumber,
      'companyName': companyName,
      'email': email,
      'location': location,
      'requirement': requirement,
      'remarks': remarks,
      'leadSource': leadSource,
      'assignedTo': assignedTo,
      'assignedToId': assignedToId,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  LeadModel copyWith({
    String? leadId,
    String? companyId,
    String? customerName,
    String? mobileNumber,
    String? companyName,
    String? email,
    String? location,
    String? requirement,
    String? remarks,
    String? leadSource,
    String? assignedTo,
    String? assignedToId,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return LeadModel(
      leadId: leadId ?? this.leadId,
      companyId: companyId ?? this.companyId,
      customerName: customerName ?? this.customerName,
      mobileNumber: mobileNumber ?? this.mobileNumber,
      companyName: companyName ?? this.companyName,
      email: email ?? this.email,
      location: location ?? this.location,
      requirement: requirement ?? this.requirement,
      remarks: remarks ?? this.remarks,
      leadSource: leadSource ?? this.leadSource,
      assignedTo: assignedTo ?? this.assignedTo,
      assignedToId: assignedToId ?? this.assignedToId,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
