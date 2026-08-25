import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/company_model.dart';
import '../constants/firestore_collections.dart';

class CompanyRepository {
  final FirebaseFirestore _firestore;

  CompanyRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Fetches all registered companies from Firestore, ignoring soft-deleted entries
  Future<List<CompanyModel>> getCompanies() async {
    try {
      final snap = await _firestore
          .collection(FirestoreCollections.companies)
          .orderBy('createdAt', descending: true)
          .get();
      return snap.docs
          .map((doc) => CompanyModel.fromMap(doc.data()))
          .where((company) => company.isDeleted != true)
          .toList();
    } catch (e) {
      print("Error fetching companies from Firestore: $e");
      rethrow;
    }
  }

  /// Calculates the total user count across the entire platform using an aggregate query
  Future<int> getTotalUserCount() async {
    try {
      final snap = await _firestore.collection(FirestoreCollections.users).count().get();
      return snap.count ?? 0;
    } catch (e) {
      return 0;
    }
  }

  /// Calculates the active employee count of a company using an aggregate query
  Future<int> getEmployeeCount(String companyId) async {
    try {
      final snap1 = await _firestore
          .collection(FirestoreCollections.users)
          .where('companyId', isEqualTo: companyId)
          .count()
          .get();
      final count1 = snap1.count ?? 0;
      if (count1 > 0) return count1;

      final snap2 = await _firestore
          .collection(FirestoreCollections.users)
          .where('tenantId', isEqualTo: companyId)
          .count()
          .get();
      return snap2.count ?? 0;
    } catch (e) {
      print("Error counting employees for company $companyId: $e");
      return 0; // Fallback to 0 in case of error
    }
  }

  /// Activates or suspends a company status
  Future<void> updateCompanyStatus({
    required String companyId,
    required String status,
    required String performedBy,
  }) async {
    await _firestore.collection(FirestoreCollections.companies).doc(companyId).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': performedBy,
    });
  }

  /// Performs a soft delete on a company
  Future<void> softDeleteCompany({
    required String companyId,
    required String performedBy,
  }) async {
    await _firestore.collection(FirestoreCollections.companies).doc(companyId).update({
      'status': 'Deleted',
      'deletedAt': FieldValue.serverTimestamp(),
      'deletedBy': performedBy,
      'isDeleted': true,
    });
  }

  /// Upgrades a company's subscription plan
  Future<void> upgradeSubscription({
    required String companyId,
    required String planName,
    required String performedBy,
  }) async {
    await _firestore.collection(FirestoreCollections.companies).doc(companyId).update({
      'subscriptionPlan': planName,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': performedBy,
    });
  }

  /// Log admin operations to the platform_logs collection
  Future<void> logActivity({
    required String action,
    required String companyId,
    required String companyName,
    required String performedBy,
  }) async {
    await _firestore.collection(FirestoreCollections.platformLogs).add({
      'action': action,
      'companyId': companyId,
      'companyName': companyName,
      'performedBy': performedBy,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
}
