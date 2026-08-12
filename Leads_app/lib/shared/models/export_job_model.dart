import 'package:cloud_firestore/cloud_firestore.dart';

class ExportJobModel {
  final String id;
  final String companyId;
  final String reportName;
  final String requestedBy;
  final String requestedByUid;
  final String requestedByRole;
  final DateTime requestedDate;
  final String status; // 'Queued', 'Processing', 'Completed', 'Failed', 'Cancelled'
  final String fileType; // 'Excel (.xlsx)', 'CSV (.csv)', 'PDF (.pdf)'
  final int progress; // 0 to 100
  final String? downloadUrl;
  final String? fileSize;
  final String? errorMessage;

  const ExportJobModel({
    required this.id,
    required this.companyId,
    required this.reportName,
    required this.requestedBy,
    required this.requestedByUid,
    required this.requestedByRole,
    required this.requestedDate,
    required this.status,
    required this.fileType,
    this.progress = 0,
    this.downloadUrl,
    this.fileSize,
    this.errorMessage,
  });

  ExportJobModel copyWith({
    String? id,
    String? companyId,
    String? reportName,
    String? requestedBy,
    String? requestedByUid,
    String? requestedByRole,
    DateTime? requestedDate,
    String? status,
    String? fileType,
    int? progress,
    String? downloadUrl,
    String? fileSize,
    String? errorMessage,
  }) {
    return ExportJobModel(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      reportName: reportName ?? this.reportName,
      requestedBy: requestedBy ?? this.requestedBy,
      requestedByUid: requestedByUid ?? this.requestedByUid,
      requestedByRole: requestedByRole ?? this.requestedByRole,
      requestedDate: requestedDate ?? this.requestedDate,
      status: status ?? this.status,
      fileType: fileType ?? this.fileType,
      progress: progress ?? this.progress,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      fileSize: fileSize ?? this.fileSize,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  factory ExportJobModel.fromMap(Map<String, dynamic> map) {
    return ExportJobModel(
      id: map['id'] ?? '',
      companyId: map['companyId'] ?? '',
      reportName: map['reportName'] ?? '',
      requestedBy: map['requestedBy'] ?? 'System User',
      requestedByUid: map['requestedByUid'] ?? '',
      requestedByRole: map['requestedByRole'] ?? 'Employee',
      requestedDate: map['requestedDate'] != null
          ? (map['requestedDate'] is Timestamp ? (map['requestedDate'] as Timestamp).toDate() : DateTime.parse(map['requestedDate'] as String))
          : DateTime.now(),
      status: map['status'] ?? 'Queued',
      fileType: map['fileType'] ?? 'Excel (.xlsx)',
      progress: map['progress'] ?? 0,
      downloadUrl: map['downloadUrl'],
      fileSize: map['fileSize'],
      errorMessage: map['errorMessage'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'companyId': companyId,
      'reportName': reportName,
      'requestedBy': requestedBy,
      'requestedByUid': requestedByUid,
      'requestedByRole': requestedByRole,
      'requestedDate': Timestamp.fromDate(requestedDate),
      'status': status,
      'fileType': fileType,
      'progress': progress,
      'downloadUrl': downloadUrl,
      'fileSize': fileSize,
      'errorMessage': errorMessage,
    };
  }
}
