import 'package:cloud_firestore/cloud_firestore.dart';

class EmployeeDocumentModel {
  final String documentId;
  final String companyId;
  final String employeeId;
  final String documentType; // Aadhaar, PAN, Passport, Driving License, Photo, Resume, Educational Certificate, Experience Certificate, Address Proof, Bank Passbook, Cancelled Cheque, Offer Letter, Contract, Other
  final String documentName;
  final String storagePath;
  final String fileUrl;
  final String uploadedBy;
  final DateTime uploadedAt;
  final String status; // active, archived

  // Identity Details fields
  final String? documentNumber;
  final String? nameOnDocument;

  // Verification workflow fields
  final String verificationStatus; // pending, verified, rejected, expired, missing
  final String? verifiedBy;
  final String? verifiedByName;
  final DateTime? verifiedAt;
  final String? rejectionReason;
  final String? rejectedBy;
  final String? rejectedByName;
  final DateTime? rejectedAt;
  final DateTime? expiryDate;

  EmployeeDocumentModel({
    required this.documentId,
    required this.companyId,
    required this.employeeId,
    required this.documentType,
    required this.documentName,
    required this.storagePath,
    required this.fileUrl,
    required this.uploadedBy,
    required this.uploadedAt,
    this.status = 'active',
    this.documentNumber,
    this.nameOnDocument,
    this.verificationStatus = 'pending',
    this.verifiedBy,
    this.verifiedByName,
    this.verifiedAt,
    this.rejectionReason,
    this.rejectedBy,
    this.rejectedByName,
    this.rejectedAt,
    this.expiryDate,
  });

  factory EmployeeDocumentModel.fromMap(Map<String, dynamic> map) {
    return EmployeeDocumentModel(
      documentId: map['documentId'] ?? '',
      companyId: map['companyId'] ?? '',
      employeeId: map['employeeId'] ?? '',
      documentType: map['documentType'] ?? 'Other',
      documentName: map['documentName'] ?? '',
      storagePath: map['storagePath'] ?? '',
      fileUrl: map['fileUrl'] ?? '',
      uploadedBy: map['uploadedBy'] ?? '',
      uploadedAt: map['uploadedAt'] != null
          ? (map['uploadedAt'] as Timestamp).toDate()
          : DateTime.now(),
      status: map['status'] ?? 'active',
      documentNumber: map['documentNumber'],
      nameOnDocument: map['nameOnDocument'],
      verificationStatus: map['verificationStatus'] ?? 'pending',
      verifiedBy: map['verifiedBy'],
      verifiedByName: map['verifiedByName'],
      verifiedAt: map['verifiedAt'] != null
          ? (map['verifiedAt'] as Timestamp).toDate()
          : null,
      rejectionReason: map['rejectionReason'],
      rejectedBy: map['rejectedBy'],
      rejectedByName: map['rejectedByName'],
      rejectedAt: map['rejectedAt'] != null
          ? (map['rejectedAt'] as Timestamp).toDate()
          : null,
      expiryDate: map['expiryDate'] != null
          ? (map['expiryDate'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'documentId': documentId,
      'companyId': companyId,
      'employeeId': employeeId,
      'documentType': documentType,
      'documentName': documentName,
      'storagePath': storagePath,
      'fileUrl': fileUrl,
      'uploadedBy': uploadedBy,
      'uploadedAt': Timestamp.fromDate(uploadedAt),
      'status': status,
      'documentNumber': documentNumber,
      'nameOnDocument': nameOnDocument,
      'verificationStatus': verificationStatus,
      'verifiedBy': verifiedBy,
      'verifiedByName': verifiedByName,
      'verifiedAt': verifiedAt != null ? Timestamp.fromDate(verifiedAt!) : null,
      'rejectionReason': rejectionReason,
      'rejectedBy': rejectedBy,
      'rejectedByName': rejectedByName,
      'rejectedAt': rejectedAt != null ? Timestamp.fromDate(rejectedAt!) : null,
      'expiryDate': expiryDate != null ? Timestamp.fromDate(expiryDate!) : null,
    };
  }

  EmployeeDocumentModel copyWith({
    String? documentId,
    String? companyId,
    String? employeeId,
    String? documentType,
    String? documentName,
    String? storagePath,
    String? fileUrl,
    String? uploadedBy,
    DateTime? uploadedAt,
    String? status,
    String? documentNumber,
    String? nameOnDocument,
    String? verificationStatus,
    String? verifiedBy,
    String? verifiedByName,
    DateTime? verifiedAt,
    String? rejectionReason,
    String? rejectedBy,
    String? rejectedByName,
    DateTime? rejectedAt,
    DateTime? expiryDate,
  }) {
    return EmployeeDocumentModel(
      documentId: documentId ?? this.documentId,
      companyId: companyId ?? this.companyId,
      employeeId: employeeId ?? this.employeeId,
      documentType: documentType ?? this.documentType,
      documentName: documentName ?? this.documentName,
      storagePath: storagePath ?? this.storagePath,
      fileUrl: fileUrl ?? this.fileUrl,
      uploadedBy: uploadedBy ?? this.uploadedBy,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      status: status ?? this.status,
      documentNumber: documentNumber ?? this.documentNumber,
      nameOnDocument: nameOnDocument ?? this.nameOnDocument,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      verifiedBy: verifiedBy ?? this.verifiedBy,
      verifiedByName: verifiedByName ?? this.verifiedByName,
      verifiedAt: verifiedAt ?? this.verifiedAt,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      rejectedBy: rejectedBy ?? this.rejectedBy,
      rejectedByName: rejectedByName ?? this.rejectedByName,
      rejectedAt: rejectedAt ?? this.rejectedAt,
      expiryDate: expiryDate ?? this.expiryDate,
    );
  }
}
