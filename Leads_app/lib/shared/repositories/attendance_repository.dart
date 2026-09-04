import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/attendance_model.dart';
import '../../constants/firestore_collections.dart';

class AttendanceRepository {
  final FirebaseFirestore _firestore;

  AttendanceRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // =========================
  // Get Attendance Logs
  // =========================
  Future<List<AttendanceModel>> getAttendanceLogs(
    String companyId, {
    String? employeeId,
  }) async {
    try {
      final snap = await _firestore
          .collection(FirestoreCollections.attendance)
          .where('companyId', isEqualTo: companyId)
          .get();

      var list = snap.docs
          .map(
            (doc) => AttendanceModel.fromMap(
              doc.data(),
            ),
          )
          .toList();

      if (employeeId != null && employeeId.isNotEmpty) {
        list = list.where((log) =>
            log.employeeId == employeeId ||
            log.userEmployeeId == employeeId
        ).toList();
      }

      list.sort((a, b) => b.checkInTime.compareTo(a.checkInTime));
      return list;
    } catch (e) {
      print("======================================");
      print("🔥 ERROR IN getAttendanceLogs()");
      print(e);
      print("======================================");
      rethrow;
    }
  }

  // =========================
  // Get Today's Attendance Log
  // =========================
  Future<AttendanceModel?> getTodayAttendance(
    String companyId,
    String employeeId,
  ) async {
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

      QuerySnapshot<Map<String, dynamic>> snap;
      try {
        snap = await _firestore
            .collection(FirestoreCollections.attendance)
            .where('companyId', isEqualTo: companyId)
            .where(
              'checkInTime',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
            )
            .where(
              'checkInTime',
              isLessThanOrEqualTo: Timestamp.fromDate(endOfDay),
            )
            .get();
      } catch (e) {
        // Fallback to memory filtering if Firestore composite index is missing or building
        snap = await _firestore
            .collection(FirestoreCollections.attendance)
            .where('companyId', isEqualTo: companyId)
            .get();
      }

      if (snap.docs.isEmpty) return null;

      for (final doc in snap.docs) {
        final data = doc.data();
        final logEmpId = (data['employeeId'] ?? '').toString();
        final logUserEmpId = (data['userEmployeeId'] ?? data['employeeCode'] ?? '').toString();

        if (logEmpId == employeeId || logUserEmpId == employeeId) {
          final model = AttendanceModel.fromMap(data);
          if (model.checkInTime.isAfter(startOfDay.subtract(const Duration(seconds: 1))) &&
              model.checkInTime.isBefore(endOfDay.add(const Duration(seconds: 1)))) {
            return model;
          }
        }
      }

      return null;
    } catch (e) {
      print("======================================");
      print("🔥 ERROR IN getTodayAttendance()");
      print(e);
      print("======================================");
      rethrow;
    }
  }

  // =========================
  // Check In
  // =========================
  Future<void> checkIn(AttendanceModel log) async {
    try {
      await _firestore
          .collection(FirestoreCollections.attendance)
          .doc(log.attendanceId)
          .set(log.toMap());
    } catch (e) {
      print("======================================");
      print("🔥 ERROR IN checkIn()");
      print(e);
      print("======================================");
      rethrow;
    }
  }

  // =========================
  // Check Out
  // =========================
  Future<void> checkOut({
    required String attendanceId,
    required DateTime checkOutTime,
    required double workHours,
    required String status,
    double? checkoutLatitude,
    double? checkoutLongitude,
    String? checkoutAddress,
    double? overtimeHours,
    bool? earlyExit,
  }) async {
    try {
      await _firestore.collection(FirestoreCollections.attendance).doc(attendanceId).update({
        'checkOutTime': Timestamp.fromDate(checkOutTime),
        'workHours': workHours,
        'status': status,
        'checkoutLatitude': checkoutLatitude,
        'checkoutLongitude': checkoutLongitude,
        'checkoutAddress': checkoutAddress,
        'overtimeHours': overtimeHours,
        'earlyExit': earlyExit,
      });
    } catch (e) {
      print("======================================");
      print("🔥 ERROR IN checkOut()");
      print(e);
      print("======================================");
      rethrow;
    }
  }
}