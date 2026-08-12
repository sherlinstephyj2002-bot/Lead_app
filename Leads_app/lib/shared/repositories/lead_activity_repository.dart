import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/lead_activity_model.dart';

class LeadActivityRepository {
  final FirebaseFirestore _firestore;

  LeadActivityRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // Save activity
  Future<void> addActivity(LeadActivityModel activity) async {
    await _firestore
        .collection('leadActivities')
        .doc(activity.activityId)
        .set(activity.toMap());
  }

  // Get activities for one lead
  Future<List<LeadActivityModel>> getActivities(
      String companyId,
      String leadId,
      ) async {
    final snap = await _firestore
        .collection('leadActivities')
        .where('companyId', isEqualTo: companyId)
        .where('leadId', isEqualTo: leadId)
        .get();

    final list = snap.docs
        .map((d) => LeadActivityModel.fromMap(d.data()))
        .toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }
}