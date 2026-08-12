import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/leave_model.dart';
import '../../constants/firestore_collections.dart';

class LeaveRepository {
  final FirebaseFirestore _firestore;

  LeaveRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<void> applyLeave(LeaveModel leave) async {
    await _firestore
        .collection(FirestoreCollections.leaves)
        .doc(leave.leaveId)
        .set(leave.toMap());
  }

  Future<List<LeaveModel>> getCompanyLeaves(String companyId) async {
    final query = await _firestore
        .collection(FirestoreCollections.leaves)
        .where('companyId', isEqualTo: companyId)
        .get();
    
    final list = query.docs.map((doc) => LeaveModel.fromMap(doc.data())).toList();
    // Sort in memory to avoid missing index errors during testing
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Future<List<LeaveModel>> getEmployeeLeaves(String companyId, String employeeId) async {
    final query = await _firestore
        .collection(FirestoreCollections.leaves)
        .where('companyId', isEqualTo: companyId)
        .where('employeeId', isEqualTo: employeeId)
        .get();
        
    final list = query.docs.map((doc) => LeaveModel.fromMap(doc.data())).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Future<void> updateLeaveStatus(
    String leaveId,
    String status,
    String approvedBy,
    String approvedByName,
  ) async {
    await _firestore.collection(FirestoreCollections.leaves).doc(leaveId).update({
      'status': status,
      'approvedBy': approvedBy,
      'approvedByName': approvedByName,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }
}
