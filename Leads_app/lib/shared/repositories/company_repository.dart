import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/company_model.dart';
import '../../constants/firestore_collections.dart';
import '../../constants/feature_flags.dart';

class CompanyRepository {
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  CompanyRepository({FirebaseFirestore? firestore, FirebaseStorage? storage})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

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

  Future<String> uploadCompanyLogo(String companyId, Uint8List fileBytes) async {
    if (!FeatureFlags.enableImageUpload) {
      throw Exception('File upload is currently disabled.');
    }
    final storagePath = 'company_logos/$companyId/logo.png';
    final ref = _storage.ref(storagePath);
    final uploadTask = await ref.putData(
      fileBytes,
      SettableMetadata(contentType: 'image/png'),
    );
    return await uploadTask.ref.getDownloadURL();
  }

  Future<void> deleteCompanyLogo(String companyId) async {
    final storagePath = 'company_logos/$companyId/logo.png';
    final ref = _storage.ref(storagePath);
    try {
      await ref.delete();
    } catch (e) {
      // Ignore if file doesn't exist
      print("Error deleting company logo: $e");
    }
  }
}
