import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

class AuditLogService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collectionName = 'audit_logs';

  /// Log a security or authentication audit event
  static Future<void> logEvent({
    required String companyId,
    required String action,
    required String triggeredBy, // 'Employee', 'Company Admin', 'System'
    String? employeeId,
    String? userId,
    Map<String, dynamic>? details,
  }) async {
    try {
      final id = const Uuid().v4();
      final now = DateTime.now();

      await _firestore.collection(_collectionName).doc(id).set({
        'id': id,
        'companyId': companyId,
        'employeeId': employeeId ?? '',
        'userId': userId ?? '',
        'action': action,
        'triggeredBy': triggeredBy,
        'details': details ?? {},
        'timestamp': FieldValue.serverTimestamp(),
        'createdAt': now.toIso8601String(),
      });
    } catch (e) {
      debugPrint('[AUDIT_LOG_SERVICE] Failed to log audit event: $e');
    }
  }
}
