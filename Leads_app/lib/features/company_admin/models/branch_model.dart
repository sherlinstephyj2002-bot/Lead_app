import 'package:cloud_firestore/cloud_firestore.dart';

class BranchModel {
  final String branchId;
  final String companyId;
  final String branchName;
  final String branchCode;
  final String? branchManagerId;
  final String email;
  final String phone;
  final String address;
  final String city;
  final String state;
  final String country;
  final String postalCode;
  final String status; // active, archived
  final DateTime createdAt;
  final DateTime updatedAt;

  BranchModel({
    required this.branchId,
    required this.companyId,
    required this.branchName,
    required this.branchCode,
    this.branchManagerId,
    required this.email,
    required this.phone,
    required this.address,
    required this.city,
    required this.state,
    required this.country,
    required this.postalCode,
    this.status = 'active',
    required this.createdAt,
    required this.updatedAt,
  });

  factory BranchModel.fromMap(Map<String, dynamic> map) {
    return BranchModel(
      branchId: map['branchId'] ?? '',
      companyId: map['companyId'] ?? '',
      branchName: map['branchName'] ?? '',
      branchCode: map['branchCode'] ?? '',
      branchManagerId: map['branchManagerId'],
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      address: map['address'] ?? '',
      city: map['city'] ?? '',
      state: map['state'] ?? '',
      country: map['country'] ?? '',
      postalCode: map['postalCode'] ?? '',
      status: map['status'] ?? 'active',
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? (map['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'branchId': branchId,
      'companyId': companyId,
      'branchName': branchName,
      'branchCode': branchCode,
      'branchManagerId': branchManagerId,
      'email': email,
      'phone': phone,
      'address': address,
      'city': city,
      'state': state,
      'country': country,
      'postalCode': postalCode,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  BranchModel copyWith({
    String? branchId,
    String? companyId,
    String? branchName,
    String? branchCode,
    String? branchManagerId,
    String? email,
    String? phone,
    String? address,
    String? city,
    String? state,
    String? country,
    String? postalCode,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BranchModel(
      branchId: branchId ?? this.branchId,
      companyId: companyId ?? this.companyId,
      branchName: branchName ?? this.branchName,
      branchCode: branchCode ?? this.branchCode,
      branchManagerId: branchManagerId ?? this.branchManagerId,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      city: city ?? this.city,
      state: state ?? this.state,
      country: country ?? this.country,
      postalCode: postalCode ?? this.postalCode,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
