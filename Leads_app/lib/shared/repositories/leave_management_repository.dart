import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/leave_type_model.dart';
import '../models/leave_balance_model.dart';
import '../models/leave_request_model.dart';
import '../../constants/firestore_collections.dart';

class LeaveManagementRepository {
  final FirebaseFirestore _firestore;

  LeaveManagementRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // ==========================================
  // LEAVE TYPES
  // ==========================================

  Future<List<LeaveTypeModel>> getLeaveTypes(String companyId) async {
    final query = await _firestore
        .collection(FirestoreCollections.leaveTypes)
        .where('companyId', isEqualTo: companyId)
        .where('status', isEqualTo: 'active')
        .get();

    return query.docs.map((doc) => LeaveTypeModel.fromMap(doc.data())).toList();
  }

  Future<void> saveLeaveType(LeaveTypeModel type) async {
    await _firestore
        .collection(FirestoreCollections.leaveTypes)
        .doc(type.leaveTypeId)
        .set(type.toMap());
  }

  Future<void> archiveLeaveType(String leaveTypeId) async {
    await _firestore
        .collection(FirestoreCollections.leaveTypes)
        .doc(leaveTypeId)
        .update({'status': 'archived'});
  }

  // ==========================================
  // LEAVE BALANCES
  // ==========================================

  Future<List<LeaveBalanceModel>> getLeaveBalances(String companyId, String employeeId) async {
    final query = await _firestore
        .collection(FirestoreCollections.leaveBalances)
        .where('companyId', isEqualTo: companyId)
        .where('employeeId', isEqualTo: employeeId)
        .get();

    return query.docs.map((doc) => LeaveBalanceModel.fromMap(doc.data())).toList();
  }

  Future<void> saveLeaveBalance(LeaveBalanceModel balance) async {
    final docId = '${balance.employeeId}_${balance.leaveTypeId}';
    await _firestore
        .collection(FirestoreCollections.leaveBalances)
        .doc(docId)
        .set(balance.toMap());
  }

  // ==========================================
  // LEAVE REQUESTS
  // ==========================================

  Future<List<LeaveRequestModel>> getLeaveRequests(String companyId) async {
    final query = await _firestore
        .collection(FirestoreCollections.leaveRequests)
        .where('companyId', isEqualTo: companyId)
        .get();

    final list = query.docs.map((doc) => LeaveRequestModel.fromMap(doc.data())).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Future<List<LeaveRequestModel>> getEmployeeLeaveRequests(String companyId, String employeeId) async {
    final query = await _firestore
        .collection(FirestoreCollections.leaveRequests)
        .where('companyId', isEqualTo: companyId)
        .where('employeeId', isEqualTo: employeeId)
        .get();

    final list = query.docs.map((doc) => LeaveRequestModel.fromMap(doc.data())).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Future<List<LeaveRequestModel>> getManagerLeaveRequests(String companyId, String managerId) async {
    final query = await _firestore
        .collection(FirestoreCollections.leaveRequests)
        .where('companyId', isEqualTo: companyId)
        .where('managerId', isEqualTo: managerId)
        .get();

    final list = query.docs.map((doc) => LeaveRequestModel.fromMap(doc.data())).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Future<void> applyLeaveRequest(LeaveRequestModel request) async {
    await _firestore
        .collection(FirestoreCollections.leaveRequests)
        .doc(request.leaveRequestId)
        .set(request.toMap());
  }

  Future<void> updateLeaveRequestStatus(
    String leaveRequestId,
    String status,
    String approvedBy,
    DateTime approvedAt,
  ) async {
    await _firestore
        .collection(FirestoreCollections.leaveRequests)
        .doc(leaveRequestId)
        .update({
      'status': status,
      'approvedBy': approvedBy,
      'approvedAt': Timestamp.fromDate(approvedAt),
    });
  }

  Future<void> overrideLeaveRequest(LeaveRequestModel request) async {
    await _firestore
        .collection(FirestoreCollections.leaveRequests)
        .doc(request.leaveRequestId)
        .set(request.toMap());
  }

  Future<LeaveRequestModel?> getLeaveRequestById(String leaveRequestId) async {
    final doc = await _firestore.collection(FirestoreCollections.leaveRequests).doc(leaveRequestId).get();
    if (doc.exists && doc.data() != null) {
      return LeaveRequestModel.fromMap(doc.data()!);
    }
    return null;
  }
}
