import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/company_model.dart';
import '../../constants/firestore_collections.dart';

class CompanyRepository {
  final FirebaseFirestore _firestore;

  CompanyRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<CompanyModel?> getCompany(String companyId) async {
    final doc = await _firestore.collection(FirestoreCollections.companies).doc(companyId).get();
    if (doc.exists && doc.data() != null) {
      return CompanyModel.fromMap(doc.data()!);
    }
    return null;
  }

  Future<void> saveCompany(CompanyModel company) async {
    await _firestore.collection(FirestoreCollections.companies).doc(company.companyId).set(company.toMap());
  }

  Future<CompanyModel?> getCompanyByName(String name) async {
    final query = await _firestore
        .collection(FirestoreCollections.companies)
        .where('name', isEqualTo: name)
        .limit(1)
        .get();
    if (query.docs.isNotEmpty) {
      return CompanyModel.fromMap(query.docs.first.data());
    }
    return null;
  }

  Stream<CompanyModel?> streamCompany(String companyId) {
    return _firestore
        .collection(FirestoreCollections.companies)
        .doc(companyId)
        .snapshots()
        .map((doc) => doc.exists && doc.data() != null
            ? CompanyModel.fromMap(doc.data()!)
            : null);
  }
}
