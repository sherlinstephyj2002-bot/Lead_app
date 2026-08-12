import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/user_model.dart';
import '../models/employee_request_model.dart';
import '../models/app_notification_model.dart';
import '../../constants/firestore_collections.dart';
import '../../constants/user_roles.dart';

class UserRepository {
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  UserRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<UserModel?> getUser(String uid) async {
    final doc = await _firestore.collection(FirestoreCollections.users).doc(uid).get();
    if (doc.exists && doc.data() != null) {
      return UserModel.fromMap(doc.data()!);
    }
    return null;
  }

  Future<void> saveUser(UserModel user) async {
    await _firestore.collection(FirestoreCollections.users).doc(user.uid).set(
          user.toMap(),
          SetOptions(merge: true),
        );
  }

  Stream<UserModel?> userStream(String uid) {
    return _firestore
        .collection(FirestoreCollections.users)
        .doc(uid)
        .snapshots()
        .map((doc) {
      if (doc.exists && doc.data() != null) {
        return UserModel.fromMap(doc.data()!);
      }
      return null;
    });
  }

  Future<void> updateEmployee(UserModel user) async {
    await _firestore.collection(FirestoreCollections.users).doc(user.uid).update({
      'name': user.name,
      'role': UserModel.denormalizeRole(user.role),
      'phoneNumber': user.phoneNumber,
    });
  }

  Future<void> removeEmployee(String uid) async {
    await _firestore.collection(FirestoreCollections.users).doc(uid).delete();
  }

  Future<List<UserModel>> getCompanyEmployees(String companyId) async {
    final query = await _firestore
        .collection(FirestoreCollections.users)
        .where('companyId', isEqualTo: companyId)
        .get();
    final allUsers = query.docs.map((doc) => UserModel.fromMap(doc.data())).toList();
    return allUsers.where((u) => u.role != UserRoles.companyAdmin && u.role != UserRoles.superAdmin).toList();
  }

  Future<String> uploadProfileImage(
    String uid,
    String fileName,
    Uint8List fileBytes,
  ) async {
    final safeFileName = fileName.replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_');
    final storagePath = 'profiles/$uid/${DateTime.now().millisecondsSinceEpoch}_$safeFileName';
    final ref = _storage.ref(storagePath);
    final uploadTask = await ref.putData(fileBytes);
    return await uploadTask.ref.getDownloadURL();
  }

  Future<void> updateUserProfile(
    String uid, {
    required String name,
    String? phoneNumber,
    String? profileImageUrl,
    String? companyName,
    String? role,
    String? email,
  }) async {
    final Map<String, dynamic> data = {
      'name': name,
    };
    if (phoneNumber != null) {
      data['phoneNumber'] = phoneNumber;
    }
    if (profileImageUrl != null) {
      data['profileImageUrl'] = profileImageUrl;
    }
    if (companyName != null) {
      data['companyName'] = companyName;
    }
    if (role != null) {
      data['role'] = UserModel.denormalizeRole(role);
    }
    if (email != null) {
      data['email'] = email;
    }
    await _firestore.collection(FirestoreCollections.users).doc(uid).set(data, SetOptions(merge: true));
  }

  Future<void> createEmployeeRequest(EmployeeRequestModel request) async {
    await _firestore
        .collection(FirestoreCollections.employeeRequests)
        .doc(request.requestId)
        .set(request.toMap());
  }

  Future<List<EmployeeRequestModel>> getPendingEmployeeRequests(String companyId) async {
    final query = await _firestore
        .collection(FirestoreCollections.employeeRequests)
        .where('companyId', isEqualTo: companyId)
        .where('status', isEqualTo: 'Pending')
        .get();
    return query.docs.map((doc) => EmployeeRequestModel.fromMap(doc.data())).toList();
  }

  Future<void> updateEmployeeRequestStatus(
    String requestId,
    String status, {
    String? approvedBy,
    DateTime? approvedAt,
    String? rejectedBy,
    DateTime? rejectedAt,
    String? reason,
  }) async {
    final Map<String, dynamic> data = {
      'status': status,
    };
    if (approvedBy != null) {
      data['approvedBy'] = approvedBy;
    }
    if (approvedAt != null) {
      data['approvedAt'] = Timestamp.fromDate(approvedAt);
    }
    if (rejectedBy != null) {
      data['rejectedBy'] = rejectedBy;
    }
    if (rejectedAt != null) {
      data['rejectedAt'] = Timestamp.fromDate(rejectedAt);
    }
    if (reason != null) {
      data['reason'] = reason;
    }

    await _firestore
        .collection(FirestoreCollections.employeeRequests)
        .doc(requestId)
        .update(data);
  }

  Future<void> createNotification(AppNotificationModel notification) async {
    await _firestore
        .collection(FirestoreCollections.notifications)
        .doc(notification.notificationId)
        .set(notification.toMap());
  }

  String _normalizeRoleStr(String? role) {
    if (role == null) return '';
    return role.toLowerCase().replaceAll(' ', '_').replaceAll('-', '_').trim();
  }

  Future<List<AppNotificationModel>> getUserNotifications({
    required String companyId,
    required String userId,
    required String role,
    String? departmentId,
  }) async {
    if (companyId.isEmpty) return [];

    final query = await _firestore
        .collection(FirestoreCollections.notifications)
        .where('companyId', isEqualTo: companyId)
        .orderBy('createdAt', descending: true)
        .get();

    final allDocs = query.docs.map((doc) => AppNotificationModel.fromMap(doc.data())).toList();
    final normUserRole = _normalizeRoleStr(role);

    return allDocs.where((n) {
      final tType = n.targetType.toUpperCase();

      // 1. Company-wide targeting
      if (tType == 'COMPANY') {
        return true;
      }

      // 2. Specific User targeting
      if (tType == 'USER') {
        return n.targetUserId == userId;
      }

      // 3. Specific Role targeting
      if (tType == 'ROLE') {
        if (n.targetRole == null || n.targetRole!.isEmpty) return false;
        return _normalizeRoleStr(n.targetRole) == normUserRole;
      }

      // 4. Specific Department targeting
      if (tType == 'DEPARTMENT') {
        if (departmentId == null || departmentId.isEmpty) return false;
        return n.targetDepartmentId == departmentId;
      }

      // Fallback for legacy notifications without explicit targetType
      if (normUserRole == 'company_admin' || normUserRole == 'super_admin') {
        return true;
      }

      return false;
    }).toList();
  }

  Future<List<AppNotificationModel>> getNotifications(String companyId) async {
    final query = await _firestore
        .collection(FirestoreCollections.notifications)
        .where('companyId', isEqualTo: companyId)
        .orderBy('createdAt', descending: true)
        .get();
    return query.docs.map((doc) => AppNotificationModel.fromMap(doc.data())).toList();
  }

  Future<void> markNotificationRead(String notificationId) async {
    await _firestore
        .collection(FirestoreCollections.notifications)
        .doc(notificationId)
        .update({'isRead': true});
  }

  Future<void> deleteNotification(String notificationId) async {
    await _firestore
        .collection(FirestoreCollections.notifications)
        .doc(notificationId)
        .delete();
  }

  Future<void> markAllNotificationsRead(String companyId) async {
    final query = await _firestore
        .collection(FirestoreCollections.notifications)
        .where('companyId', isEqualTo: companyId)
        .where('isRead', isEqualTo: false)
        .get();
    final batch = _firestore.batch();
    for (final doc in query.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  Future<void> clearAllNotifications(String companyId) async {
    final query = await _firestore
        .collection(FirestoreCollections.notifications)
        .where('companyId', isEqualTo: companyId)
        .get();
    final batch = _firestore.batch();
    for (final doc in query.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}
