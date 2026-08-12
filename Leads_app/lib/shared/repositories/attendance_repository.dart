import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/attendance_model.dart';
import '../../constants/firestore_collections.dart';

class AttendanceRepository {
  final FirebaseFirestore _firestore;

  AttendanceRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // =========================
  // Get Attendance Logs (TEST VERSION)
  // =========================
  Future<List<AttendanceModel>> getAttendanceLogs(
    String companyId, {
    String? employeeId,
  }) async {
    try {
      Query query = _firestore
          .collection(FirestoreCollections.attendance)
          .where('companyId', isEqualTo: companyId);

      if (employeeId != null) {
        query = query.where('employeeId', isEqualTo: employeeId);
      }

      final snap = await query.get();

      final list = snap.docs
          .map(
            (doc) => AttendanceModel.fromMap(
              doc.data() as Map<String, dynamic>,
            ),
          )
          .toList();

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
      final startOfDay = DateTime(
        now.year,
        now.month,
        now.day,
      );

      final endOfDay = DateTime(
        now.year,
        now.month,
        now.day,
        23,
        59,
        59,
      );

      final snap = await _firestore
          .collection(FirestoreCollections.attendance)
          .where('companyId', isEqualTo: companyId)
          .where('employeeId', isEqualTo: employeeId)
          .where(
            'checkInTime',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
          )
          .where(
            'checkInTime',
            isLessThanOrEqualTo: Timestamp.fromDate(endOfDay),
          )
          .limit(1)
          .get();

      if (snap.docs.isEmpty) {
        return null;
      }

      return AttendanceModel.fromMap(
        snap.docs.first.data(),
      );
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