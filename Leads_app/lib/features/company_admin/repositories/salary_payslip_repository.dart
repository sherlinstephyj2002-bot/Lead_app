import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/salary_payslip_model.dart';

/// Standalone repository for the salary_payslips Firestore collection.
/// Completely separate from CompanyAdminRepository.
class SalaryPayslipRepository {
  final FirebaseFirestore _db;

  SalaryPayslipRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('salary_payslips');

  // ── READ ────────────────────────────────────────────

  /// Returns payslips for a company, optionally filtered.
  Future<List<SalaryPayslipModel>> getPayslips(
    String companyId, {
    int? month,
    int? year,
    String? employeeId,
    String? status,
  }) async {
    Query<Map<String, dynamic>> query =
        _col.where('companyId', isEqualTo: companyId);

    if (month != null) query = query.where('month', isEqualTo: month);
    if (year != null) query = query.where('year', isEqualTo: year);
    if (employeeId != null && employeeId.isNotEmpty) {
      query = query.where('employeeId', isEqualTo: employeeId);
    }
    if (status != null && status.isNotEmpty) {
      query = query.where('status', isEqualTo: status);
    }

    final snap = await query.get();
    final list =
        snap.docs.map((d) => SalaryPayslipModel.fromMap(d.data())).toList();
    list.sort((a, b) {
      final yearCmp = b.year.compareTo(a.year);
      if (yearCmp != 0) return yearCmp;
      final monthCmp = b.month.compareTo(a.month);
      if (monthCmp != 0) return monthCmp;
      return a.employeeName.compareTo(b.employeeName);
    });
    return list;
  }

  /// Returns a single payslip by ID.
  Future<SalaryPayslipModel?> getPayslipById(String payslipId) async {
    final doc = await _col.doc(payslipId).get();
    if (!doc.exists) return null;
    return SalaryPayslipModel.fromMap(doc.data()!);
  }

  /// All payslips for one employee, sorted newest first.
  Future<List<SalaryPayslipModel>> getEmployeePayslips(
      String companyId, String employeeId) async {
    return getPayslips(companyId, employeeId: employeeId);
  }

  // ── WRITE ───────────────────────────────────────────

  /// Creates or updates a payslip document.
  Future<void> savePayslip(SalaryPayslipModel payslip) async {
    await _col.doc(payslip.payslipId).set(payslip.toMap());
  }

  /// Updates only the status field.
  Future<void> updateStatus(String payslipId, String status) async {
    await _col.doc(payslipId).update({
      'status': status,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  // ── DELETE ──────────────────────────────────────────

  Future<void> deletePayslip(String payslipId) async {
    await _col.doc(payslipId).delete();
  }

  // ── STATS ───────────────────────────────────────────

  /// Returns {total, thisMonth, draft, generated} counts.
  Future<Map<String, int>> getPayslipStats(
      String companyId, int month, int year) async {
    final allSnap =
        await _col.where('companyId', isEqualTo: companyId).get();
    final all = allSnap.docs.map((d) => d.data()).toList();

    final thisMonth = all
        .where((d) => d['month'] == month && d['year'] == year)
        .length;
    final draft =
        all.where((d) => d['status'] == 'Draft').length;
    final generated =
        all.where((d) => d['status'] == 'Generated').length;

    return {
      'total': all.length,
      'thisMonth': thisMonth,
      'draft': draft,
      'generated': generated,
    };
  }
}

