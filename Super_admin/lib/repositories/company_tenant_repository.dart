import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../constants/firestore_collections.dart';

class CompanyTenantRepository {
  final FirebaseFirestore _firestore;

  CompanyTenantRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Fetches all users for a given companyId (strictly filtered)
  Future<List<UserModel>> getCompanyUsers(String companyId) async {
    try {
      final snap = await _firestore
          .collection(FirestoreCollections.users)
          .where('companyId', isEqualTo: companyId)
          .get();

      return snap.docs.map((doc) {
        final data = doc.data();
        data['uid'] = doc.id;
        return UserModel.fromMap(data);
      }).toList();
    } catch (e) {
      return [];
    }
  }

  /// Fetches department records for a companyId
  Future<List<Map<String, dynamic>>> getCompanyDepartments(String companyId) async {
    try {
      final snap = await _firestore
          .collection('departments')
          .where('companyId', isEqualTo: companyId)
          .get();
      return snap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
    } catch (e) {
      return [];
    }
  }

  /// Fetches attendance records for a companyId
  Future<List<Map<String, dynamic>>> getCompanyAttendance(String companyId) async {
    try {
      final snap = await _firestore
          .collection(FirestoreCollections.attendance)
          .where('companyId', isEqualTo: companyId)
          .get();
      return snap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
    } catch (e) {
      return [];
    }
  }

  /// Fetches leave records for a companyId
  Future<List<Map<String, dynamic>>> getCompanyLeaves(String companyId) async {
    try {
      final snap = await _firestore
          .collection(FirestoreCollections.leaves)
          .where('companyId', isEqualTo: companyId)
          .get();
      return snap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
    } catch (e) {
      return [];
    }
  }

  /// Fetches lead records for a companyId
  Future<List<Map<String, dynamic>>> getCompanyLeads(String companyId) async {
    try {
      final snap = await _firestore
          .collection(FirestoreCollections.leads)
          .where('companyId', isEqualTo: companyId)
          .get();
      return snap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
    } catch (e) {
      return [];
    }
  }

  /// Fetches order records for a companyId
  Future<List<Map<String, dynamic>>> getCompanyOrders(String companyId) async {
    try {
      final snap = await _firestore
          .collection(FirestoreCollections.orders)
          .where('companyId', isEqualTo: companyId)
          .get();
      return snap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
    } catch (e) {
      return [];
    }
  }

  /// Fetches payroll/payslips for a companyId
  Future<List<Map<String, dynamic>>> getCompanyPayslips(String companyId) async {
    try {
      final snap = await _firestore
          .collection('salary_payslips')
          .where('companyId', isEqualTo: companyId)
          .get();
      return snap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
    } catch (e) {
      return [];
    }
  }

  /// Fetches document metadata for a companyId
  Future<List<Map<String, dynamic>>> getCompanyDocuments(String companyId) async {
    try {
      final snap = await _firestore
          .collection('employee_documents')
          .where('companyId', isEqualTo: companyId)
          .get();
      return snap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
    } catch (e) {
      return [];
    }
  }

  /// Fetches company audit logs
  Future<List<Map<String, dynamic>>> getCompanyAuditLogs(String companyId) async {
    try {
      final snap = await _firestore
          .collection(FirestoreCollections.platformLogs)
          .where('companyId', isEqualTo: companyId)
          .get();
      return snap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
    } catch (e) {
      return [];
    }
  }
}
