class LeadAttachmentModel {
  final String leadId;
  final String companyId;
  final String fileName;
  final String fileUrl;
  final DateTime uploadedAt;

  LeadAttachmentModel({
    required this.leadId,
    required this.companyId,
    required this.fileName,
    required this.fileUrl,
    required this.uploadedAt,
  });

  factory LeadAttachmentModel.fromMap(Map<String, dynamic> map) {
    return LeadAttachmentModel(
      leadId: map['leadId'] ?? '',
      companyId: map['companyId'] ?? '',
      fileName: map['fileName'] ?? '',
      fileUrl: map['fileUrl'] ?? '',
      uploadedAt: map['uploadedAt'] != null
          ? DateTime.parse(map['uploadedAt'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'leadId': leadId,
      'companyId': companyId,
      'fileName': fileName,
      'fileUrl': fileUrl,
      'uploadedAt': uploadedAt.toIso8601String(),
    };
  }
}
