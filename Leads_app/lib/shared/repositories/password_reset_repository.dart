import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/password_reset_request_model.dart';
import '../models/password_reset_audit_log_model.dart';

class PasswordResetRepository {
  final FirebaseFirestore _firestore;

  PasswordResetRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  static const String requestsCollection = 'password_reset_requests';
  static const String auditCollection = 'password_reset_audit_logs';

  /// Save new password reset request
  Future<void> createRequest(PasswordResetRequestModel request) async {
    await _firestore
        .collection(requestsCollection)
        .doc(request.requestId)
        .set(request.toMap());
  }

  /// Get request by requestId
  Future<PasswordResetRequestModel?> getRequestById(String requestId) async {
    try {
      final doc = await _firestore.collection(requestsCollection).doc(requestId).get();
      if (doc.exists && doc.data() != null) {
        return PasswordResetRequestModel.fromMap(doc.data()!);
      }
    } catch (e) {
      debugPrint('[PASSWORD_RESET_REPO] Get request by ID error: $e');
    }
    return null;
  }

  /// Stream request by requestId for real-time updates
  Stream<PasswordResetRequestModel?> streamRequestById(String requestId) {
    return _firestore
        .collection(requestsCollection)
        .doc(requestId)
        .snapshots()
        .map((doc) => doc.exists && doc.data() != null
            ? PasswordResetRequestModel.fromMap(doc.data()!)
            : null);
  }

  /// Get active pending request for a specific employee (to prevent duplicate requests)
  Future<PasswordResetRequestModel?> getPendingRequestForEmployee(
    String companyId,
    String employeeUid,
  ) async {
    try {
      final snapshot = await _firestore
          .collection(requestsCollection)
          .where('companyId', isEqualTo: companyId)
          .where('employeeUid', isEqualTo: employeeUid)
          .get();

      final activeStatuses = {'Pending', 'PENDING', 'In Review', 'IN_REVIEW', 'Contacted', 'CONTACTED'};

      for (final doc in snapshot.docs) {
        final req = PasswordResetRequestModel.fromMap(doc.data());
        if (activeStatuses.contains(req.status)) {
          if (!req.isExpired) {
            return req;
          } else {
            // Auto-mark expired request in DB
            await doc.reference.update({'status': 'Expired'});
          }
        }
      }
    } catch (e) {
      debugPrint('[PASSWORD_RESET_REPO] Check pending request error: $e');
    }
    return null;
  }

  /// Fetch all requests for a company
  Future<List<PasswordResetRequestModel>> getCompanyRequests(String companyId) async {
    try {
      final snapshot = await _firestore
          .collection(requestsCollection)
          .where('companyId', isEqualTo: companyId)
          .get();

      final list = <PasswordResetRequestModel>[];
      for (final doc in snapshot.docs) {
        final req = PasswordResetRequestModel.fromMap(doc.data());
        if (req.status == 'Pending' && req.isExpired) {
          await doc.reference.update({'status': 'Expired'});
          list.add(req.copyWith(status: 'Expired'));
        } else {
          list.add(req);
        }
      }

      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    } catch (e) {
      debugPrint('[PASSWORD_RESET_REPO] Get company requests error: $e');
      return [];
    }
  }

  /// Update existing request
  Future<void> updateRequest(PasswordResetRequestModel request) async {
    await _firestore
        .collection(requestsCollection)
        .doc(request.requestId)
        .update(request.toMap());
  }

  /// Create audit log entry
  Future<void> createAuditLog(PasswordResetAuditLogModel log) async {
    await _firestore
        .collection(auditCollection)
        .doc(log.logId)
        .set(log.toMap());
  }

  /// Fetch audit logs for a company
  Future<List<PasswordResetAuditLogModel>> getAuditLogs(String companyId) async {
    try {
      final snapshot = await _firestore
          .collection(auditCollection)
          .where('companyId', isEqualTo: companyId)
          .get();

      final list = snapshot.docs
          .map((doc) => PasswordResetAuditLogModel.fromMap(doc.data()))
          .toList();
      list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return list;
    } catch (e) {
      debugPrint('[PASSWORD_RESET_REPO] Get audit logs error: $e');
      return [];
    }
  }
}
