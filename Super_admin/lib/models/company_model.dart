import 'package:cloud_firestore/cloud_firestore.dart';

class CompanyModel {
  final String companyId;
  final String name;
  final String subscriptionPlan; // 'Free', 'Standard', 'Enterprise'
  final String status; // 'Active', 'Suspended', 'Deleted'
  final DateTime createdAt;
  final double? geofenceLat;
  final double? geofenceLng;
  final double? geofenceRadius;
  
  // Detailed SaaS profile registration fields
  final String companyType;
  final String businessEmail;
  final String companyMobile;
  final String country;
  final String state;
  final String city;
  final String address;
  final String zip;
  final String timeZone;
  final String? logoUrl;
  final String gstVat;
  final String website;

  // Audit and Management Fields
  final DateTime? updatedAt;
  final String? updatedBy;
  final DateTime? deletedAt;
  final String? deletedBy;
  final bool? isDeleted;

  CompanyModel({
    required this.companyId,
    required this.name,
    required this.subscriptionPlan,
    required this.status,
    required this.createdAt,
    this.geofenceLat,
    this.geofenceLng,
    this.geofenceRadius,
    this.companyType = '',
    this.businessEmail = '',
    this.companyMobile = '',
    this.country = '',
    this.state = '',
    this.city = '',
    this.address = '',
    this.zip = '',
    this.timeZone = '',
    this.logoUrl,
    this.gstVat = '',
    this.website = '',
    this.updatedAt,
    this.updatedBy,
    this.deletedAt,
    this.deletedBy,
    this.isDeleted = false,
  });

  factory CompanyModel.fromMap(Map<String, dynamic> map) {
    return CompanyModel(
      companyId: map['companyId'] ?? '',
      name: map['name'] ?? '',
      subscriptionPlan: map['subscriptionPlan'] ?? 'Free',
      status: map['status'] ?? 'Active',
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      geofenceLat: map['geofenceLat'] != null ? (map['geofenceLat'] as num).toDouble() : null,
      geofenceLng: map['geofenceLng'] != null ? (map['geofenceLng'] as num).toDouble() : null,
      geofenceRadius: map['geofenceRadius'] != null ? (map['geofenceRadius'] as num).toDouble() : null,
      companyType: map['companyType'] ?? '',
      businessEmail: map['businessEmail'] ?? '',
      companyMobile: map['companyMobile'] ?? '',
      country: map['country'] ?? '',
      state: map['state'] ?? '',
      city: map['city'] ?? '',
      address: map['address'] ?? '',
      zip: map['zip'] ?? '',
      timeZone: map['timeZone'] ?? '',
      logoUrl: map['logoUrl'],
      gstVat: map['gstVat'] ?? '',
      website: map['website'] ?? '',
      updatedAt: map['updatedAt'] != null ? (map['updatedAt'] as Timestamp).toDate() : null,
      updatedBy: map['updatedBy'],
      deletedAt: map['deletedAt'] != null ? (map['deletedAt'] as Timestamp).toDate() : null,
      deletedBy: map['deletedBy'],
      isDeleted: map['isDeleted'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'companyId': companyId,
      'name': name,
      'subscriptionPlan': subscriptionPlan,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'geofenceLat': geofenceLat,
      'geofenceLng': geofenceLng,
      'geofenceRadius': geofenceRadius,
      'companyType': companyType,
      'businessEmail': businessEmail,
      'companyMobile': companyMobile,
      'country': country,
      'state': state,
      'city': city,
      'address': address,
      'zip': zip,
      'timeZone': timeZone,
      'logoUrl': logoUrl,
      'gstVat': gstVat,
      'website': website,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'updatedBy': updatedBy,
      'deletedAt': deletedAt != null ? Timestamp.fromDate(deletedAt!) : null,
      'deletedBy': deletedBy,
      'isDeleted': isDeleted,
    };
  }

  CompanyModel copyWith({
    String? companyId,
    String? name,
    String? subscriptionPlan,
    String? status,
    DateTime? createdAt,
    double? geofenceLat,
    double? geofenceLng,
    double? geofenceRadius,
    String? companyType,
    String? businessEmail,
    String? companyMobile,
    String? country,
    String? state,
    String? city,
    String? address,
    String? zip,
    String? timeZone,
    String? logoUrl,
    String? gstVat,
    String? website,
    DateTime? updatedAt,
    String? updatedBy,
    DateTime? deletedAt,
    String? deletedBy,
    bool? isDeleted,
  }) {
    return CompanyModel(
      companyId: companyId ?? this.companyId,
      name: name ?? this.name,
      subscriptionPlan: subscriptionPlan ?? this.subscriptionPlan,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      geofenceLat: geofenceLat ?? this.geofenceLat,
      geofenceLng: geofenceLng ?? this.geofenceLng,
      geofenceRadius: geofenceRadius ?? this.geofenceRadius,
      companyType: companyType ?? this.companyType,
      businessEmail: businessEmail ?? this.businessEmail,
      companyMobile: companyMobile ?? this.companyMobile,
      country: country ?? this.country,
      state: state ?? this.state,
      city: city ?? this.city,
      address: address ?? this.address,
      zip: zip ?? this.zip,
      timeZone: timeZone ?? this.timeZone,
      logoUrl: logoUrl ?? this.logoUrl,
      gstVat: gstVat ?? this.gstVat,
      website: website ?? this.website,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
      deletedAt: deletedAt ?? this.deletedAt,
      deletedBy: deletedBy ?? this.deletedBy,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}
