import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/lead_model.dart';
import '../models/followup_model.dart';
import '../models/lead_attachment_model.dart';
import '../../constants/firestore_collections.dart';

class LeadPageResult {
  final List<LeadModel> leads;
  final QueryDocumentSnapshot<Map<String, dynamic>>? lastDoc;

  LeadPageResult(this.leads, this.lastDoc);
}

class LeadRepository {
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  LeadRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<LeadPageResult> getLeadsPage(
    String companyId, {
    int limit = 15,
    QueryDocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) async {
    try {
      var query = _firestore
          .collection(FirestoreCollections.leads)
          .where('companyId', isEqualTo: companyId)
          .orderBy('createdAt', descending: true)
          .limit(limit);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snap = await query.get();
      final leads = snap.docs.map((d) => LeadModel.fromMap(d.data())).toList();
      return LeadPageResult(leads, snap.docs.isNotEmpty ? snap.docs.last : null);
    } catch (e) {
      print("LEADS PAGINATION ERROR:");
      print(e);
      rethrow;
    }
  }

  Future<void> saveLead(LeadModel lead) async {
    await _firestore.collection(FirestoreCollections.leads).doc(lead.leadId).set(lead.toMap());
  }

  Future<void> deleteLead(String leadId) async {
    await _firestore.collection(FirestoreCollections.leads).doc(leadId).delete();
  }

  Future<List<LeadAttachmentModel>> getLeadAttachments(String companyId, String leadId) async {
    final snap = await _firestore
        .collection('leadAttachments')
        .where('companyId', isEqualTo: companyId)
        .where('leadId', isEqualTo: leadId)
        .orderBy('uploadedAt', descending: true)
        .get();

    return snap.docs
        .map((d) => LeadAttachmentModel.fromMap(d.data()))
        .toList();
  }

  Future<LeadAttachmentModel> uploadLeadAttachment(
    String companyId,
    String leadId,
    String fileName,
    Uint8List fileBytes,
  ) async {
    final storagePath = 'leads/$companyId/$leadId/${DateTime.now().millisecondsSinceEpoch}_$fileName';
    final ref = _storage.ref(storagePath);
    final uploadTask = await ref.putData(fileBytes);
    final url = await uploadTask.ref.getDownloadURL();

    final attachment = LeadAttachmentModel(
      leadId: leadId,
      companyId: companyId,
      fileName: fileName,
      fileUrl: url,
      uploadedAt: DateTime.now(),
    );

    await _firestore
        .collection('leadAttachments')
        .doc('${leadId}_${attachment.uploadedAt.millisecondsSinceEpoch}')
        .set(attachment.toMap());

    return attachment;
  }

  Future<List<FollowupModel>> getFollowups(String companyId) async {
    final snap = await _firestore
        .collection(FirestoreCollections.followUps)
        .where('companyId', isEqualTo: companyId)
        .orderBy('followUpDate', descending: false)
        .get();
    return snap.docs.map((d) => FollowupModel.fromMap(d.data())).toList();
  }

  Future<void> saveFollowup(FollowupModel followup) async {
    await _firestore.collection(FirestoreCollections.followUps).doc(followup.followUpId).set(followup.toMap());
  }

  Future<void> updateLeadStatus(String leadId, String status) async {
    await _firestore
        .collection(FirestoreCollections.leads)
        .doc(leadId)
        .update({
      'status': status,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }
}
