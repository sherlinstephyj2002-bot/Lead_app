import 'package:cloud_firestore/cloud_firestore.dart';

class OrderAttachmentModel {
  final String orderId;
  final String companyId;
  final String fileName;
  final String fileUrl;
  final DateTime uploadedAt;

  OrderAttachmentModel({
    required this.orderId,
    required this.companyId,
    required this.fileName,
    required this.fileUrl,
    required this.uploadedAt,
  });

  factory OrderAttachmentModel.fromMap(Map<String, dynamic> map) {
    final uploadedAtValue = map['uploadedAt'];
    final uploadedAt = uploadedAtValue is DateTime
        ? uploadedAtValue
        : uploadedAtValue is Timestamp
            ? uploadedAtValue.toDate()
            : DateTime.tryParse(uploadedAtValue?.toString() ?? '') ?? DateTime.now();

    return OrderAttachmentModel(
      orderId: map['orderId'] ?? '',
      companyId: map['companyId'] ?? '',
      fileName: map['fileName'] ?? '',
      fileUrl: map['fileUrl'] ?? '',
      uploadedAt: uploadedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'orderId': orderId,
      'companyId': companyId,
      'fileName': fileName,
      'fileUrl': fileUrl,
      'uploadedAt': Timestamp.fromDate(uploadedAt),
    };
  }
}
