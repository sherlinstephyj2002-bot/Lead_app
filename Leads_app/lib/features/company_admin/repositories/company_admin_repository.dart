import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../../../shared/models/user_model.dart';
import '../../../shared/models/department_model.dart';
import '../../../shared/models/leave_request_model.dart';
import '../../../shared/models/expense_model.dart';
import '../../../shared/models/attendance_model.dart';
import '../../../shared/models/employee_request_model.dart';
import '../models/designation_model.dart';
import '../models/holiday_model.dart';
import '../models/shift_model.dart';
import '../models/attendance_settings_model.dart';
import '../models/overtime_settings_model.dart';
import '../models/leave_policy_model.dart';
import '../models/salary_component_model.dart';
import '../models/pf_esi_tax_settings_model.dart';
import '../models/salary_structure_model.dart';
import '../models/payroll_settings_model.dart';
import '../models/branch_model.dart';
import '../models/employee_document_model.dart';
import '../models/salary_component_audit_log_model.dart';
import '../models/salary_revision_model.dart';
import '../models/payroll_model.dart';


import '../../../constants/user_roles.dart';

class CompanyAdminRepository {
  final FirebaseFirestore _firestore;

  CompanyAdminRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // ==========================================
  // MODULE 1, 2, 3 - HR & EMPLOYEE MANAGEMENT
  // ==========================================

  Future<List<UserModel>> getCompanyUsersByRoles(String companyId, List<String> roles) async {
    final query = await _firestore
        .collection('users')
        .where('companyId', isEqualTo: companyId)
        .get();
    
    return query.docs
        .map((doc) => UserModel.fromMap(doc.data()))
        .where((user) => roles.contains(user.role) && user.status != 'deleted')
        .toList();
  }

  Future<List<UserModel>> getCompanyEmployees(String companyId) async {
    final query = await _firestore
        .collection('users')
        .where('companyId', isEqualTo: companyId)
        .get();
    
    return query.docs
        .map((doc) => UserModel.fromMap(doc.data()))
        .where((user) => user.status != 'deleted' && user.role != UserRoles.companyAdmin && user.role != UserRoles.superAdmin)
        .toList();
  }

  Future<UserModel?> getUser(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (doc.exists && doc.data() != null) {
      return UserModel.fromMap(doc.data()!);
    }
    return null;
  }

  Future<void> saveUser(UserModel user) async {
    await _firestore.collection('users').doc(user.uid).set(user.toMap());
  }

  Future<void> updateUserStatus(String uid, String status) async {
    await _firestore.collection('users').doc(uid).update({
      'status': status,
    });
  }

  Future<void> deleteUser(String uid) async {
    await _firestore.collection('users').doc(uid).delete();
  }

  // ==========================================
  // MODULE 4 - DEPARTMENT MANAGEMENT
  // ==========================================

  Future<List<DepartmentModel>> getDepartments(String companyId) async {
    final query = await _firestore
        .collection('departments')
        .where('companyId', isEqualTo: companyId)
        .get();
    return query.docs
        .map((doc) => DepartmentModel.fromMap(doc.data()))
        .where((d) => d.status != 'deleted')
        .toList();
  }

  Future<void> saveDepartment(DepartmentModel department) async {
    await _firestore
        .collection('departments')
        .doc(department.departmentId)
        .set(department.toMap());
  }

  Future<void> deleteDepartment(String departmentId) async {
    // Soft delete (Archive)
    await _firestore
        .collection('departments')
        .doc(departmentId)
        .update({
          'status': 'archived', 
          'updatedAt': Timestamp.fromDate(DateTime.now())
        });
  }

  Future<void> restoreDepartment(String departmentId) async {
    await _firestore
        .collection('departments')
        .doc(departmentId)
        .update({
          'status': 'active', 
          'updatedAt': Timestamp.fromDate(DateTime.now())
        });
  }

  Future<void> permanentlyDeleteDepartment(String departmentId) async {
    await _firestore.collection('departments').doc(departmentId).delete();
  }

  Future<bool> isDepartmentNameDuplicate(String companyId, String name, {String? excludeId}) async {
    final query = await _firestore
        .collection('departments')
        .where('companyId', isEqualTo: companyId)
        .get();
    
    final normalizedInput = name.trim().toLowerCase();
    for (final doc in query.docs) {
      final dept = DepartmentModel.fromMap(doc.data());
      if (dept.status == 'deleted' || dept.status == 'archived') continue;
      if (excludeId != null && dept.departmentId == excludeId) continue;
      if (dept.departmentName.trim().toLowerCase() == normalizedInput) {
        return true;
      }
    }
    return false;
  }

  // ==========================================
  // MODULE 5 - DESIGNATION MANAGEMENT
  // ==========================================

  Future<List<DesignationModel>> getDesignations(String companyId) async {
    final query = await _firestore
        .collection('designations')
        .where('companyId', isEqualTo: companyId)
        .get();
    return query.docs
        .map((doc) => DesignationModel.fromMap(doc.data()))
        .where((d) => d.status != 'deleted')
        .toList();
  }

  Future<void> saveDesignation(DesignationModel designation) async {
    await _firestore
        .collection('designations')
        .doc(designation.designationId)
        .set(designation.toMap());
  }

  Future<void> deleteDesignation(String designationId) async {
    // Soft delete (Archive)
    await _firestore
        .collection('designations')
        .doc(designationId)
        .update({
          'status': 'archived',
          'updatedAt': Timestamp.fromDate(DateTime.now())
        });
  }

  Future<void> restoreDesignation(String designationId) async {
    await _firestore
        .collection('designations')
        .doc(designationId)
        .update({
          'status': 'active',
          'updatedAt': Timestamp.fromDate(DateTime.now())
        });
  }

  Future<void> permanentlyDeleteDesignation(String designationId) async {
    await _firestore.collection('designations').doc(designationId).delete();
  }

  Future<bool> isDesignationNameDuplicate(String companyId, String name, {String? excludeId}) async {
    final query = await _firestore
        .collection('designations')
        .where('companyId', isEqualTo: companyId)
        .get();
    
    final normalizedInput = name.trim().toLowerCase();
    for (final doc in query.docs) {
      final desig = DesignationModel.fromMap(doc.data());
      if (desig.status == 'deleted' || desig.status == 'archived') continue;
      if (excludeId != null && desig.designationId == excludeId) continue;
      if (desig.designationName.trim().toLowerCase() == normalizedInput) {
        return true;
      }
    }
    return false;
  }

  // ==========================================
  // MODULE 6 - COMPANY HOLIDAYS
  // ==========================================

  Future<List<HolidayModel>> getHolidays(String companyId) async {
    final query = await _firestore
        .collection('holidays')
        .where('companyId', isEqualTo: companyId)
        .get();
    return query.docs
        .map((doc) => HolidayModel.fromMap(doc.data()))
        .where((h) => h.status != 'deleted')
        .toList();
  }

  Future<void> saveHoliday(HolidayModel holiday) async {
    await _firestore
        .collection('holidays')
        .doc(holiday.holidayId)
        .set(holiday.toMap());
  }

  Future<void> deleteHoliday(String holidayId) async {
    // Soft delete / Archive
    await _firestore
        .collection('holidays')
        .doc(holidayId)
        .update({
          'status': 'archived',
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        });
  }

  Future<void> restoreHoliday(String holidayId) async {
    await _firestore
        .collection('holidays')
        .doc(holidayId)
        .update({
          'status': 'active',
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        });
  }

  // ==========================================
  // MODULE 7 - WORK SHIFT MANAGEMENT
  // ==========================================

  Future<List<ShiftModel>> getShifts(String companyId) async {
    final query = await _firestore
        .collection('work_shifts')
        .where('companyId', isEqualTo: companyId)
        .get();
    return query.docs
        .map((doc) => ShiftModel.fromMap(doc.data()))
        .where((s) => s.status != 'deleted')
        .toList();
  }

  Future<void> saveShift(ShiftModel shift) async {
    await _firestore
        .collection('work_shifts')
        .doc(shift.shiftId)
        .set(shift.toMap());
  }

  Future<void> deleteShift(String shiftId) async {
    // Soft delete / Archive
    await _firestore
        .collection('work_shifts')
        .doc(shiftId)
        .update({
          'status': 'archived',
          'updatedAt': DateTime.now().toIso8601String(),
        });
  }

  Future<void> restoreShift(String shiftId) async {
    await _firestore
        .collection('work_shifts')
        .doc(shiftId)
        .update({
          'status': 'active',
          'updatedAt': DateTime.now().toIso8601String(),
        });
  }

  Future<bool> isShiftNameDuplicate(String companyId, String name, {String? excludeId}) async {
    final query = await _firestore
        .collection('work_shifts')
        .where('companyId', isEqualTo: companyId)
        .get();
    final normalizedInput = name.trim().toLowerCase();
    for (final doc in query.docs) {
      final shift = ShiftModel.fromMap(doc.data());
      if (shift.status == 'deleted' || shift.status == 'archived') continue;
      if (excludeId != null && shift.shiftId == excludeId) continue;
      if (shift.shiftName.trim().toLowerCase() == normalizedInput) {
        return true;
      }
    }
    return false;
  }

  Future<bool> isShiftCodeDuplicate(String companyId, String code, {String? excludeId}) async {
    final query = await _firestore
        .collection('work_shifts')
        .where('companyId', isEqualTo: companyId)
        .get();
    final normalizedInput = code.trim().toLowerCase();
    for (final doc in query.docs) {
      final shift = ShiftModel.fromMap(doc.data());
      if (shift.status == 'deleted' || shift.status == 'archived') continue;
      if (excludeId != null && shift.shiftId == excludeId) continue;
      if (shift.shiftCode.trim().toLowerCase() == normalizedInput) {
        return true;
      }
    }
    return false;
  }

  Future<void> assignShiftToEmployee(String employeeId, String? shiftId) async {
    await _firestore.collection('users').doc(employeeId).update({
      'shiftId': shiftId,
    });
  }

  // ==========================================
  // MODULE 8 - ATTENDANCE RULES
  // ==========================================

  Future<AttendanceSettingsModel> getAttendanceSettings(String companyId) async {
    final doc = await _firestore.collection('attendance_settings').doc(companyId).get();
    if (doc.exists && doc.data() != null) {
      return AttendanceSettingsModel.fromMap(doc.data()!, companyId);
    }
    return AttendanceSettingsModel(companyId: companyId, createdAt: DateTime.now(), updatedAt: DateTime.now());
  }

  Future<void> saveAttendanceSettings(AttendanceSettingsModel settings) async {
    await _firestore
        .collection('attendance_settings')
        .doc(settings.companyId)
        .set(settings.toMap());
  }

  // ==========================================
  // MODULE 9 - OVERTIME SETTINGS
  // ==========================================

  Future<OvertimeSettingsModel> getOvertimeSettings(String companyId) async {
    final doc = await _firestore.collection('overtime_settings').doc(companyId).get();
    if (doc.exists && doc.data() != null) {
      return OvertimeSettingsModel.fromMap(doc.data()!, companyId);
    }
    return OvertimeSettingsModel(companyId: companyId);
  }

  Future<void> saveOvertimeSettings(OvertimeSettingsModel settings) async {
    await _firestore
        .collection('overtime_settings')
        .doc(settings.companyId)
        .set(settings.toMap());
  }

  // ==========================================
  // MODULE 10 - LEAVE POLICY
  // ==========================================

  Future<LeavePolicyModel> getLeavePolicy(String companyId) async {
    final doc = await _firestore.collection('leave_policies').doc(companyId).get();
    if (doc.exists && doc.data() != null) {
      return LeavePolicyModel.fromMap(doc.data()!, companyId);
    }
    return LeavePolicyModel(companyId: companyId, policies: {});
  }

  Future<void> saveLeavePolicy(LeavePolicyModel policy) async {
    await _firestore
        .collection('leave_policies')
        .doc(policy.companyId)
        .set(policy.toMap());
  }

  // ==========================================
  // MODULE 11 - SALARY COMPONENTS
  // ==========================================

  Future<List<SalaryComponentModel>> getSalaryComponents(String companyId) async {
    final query = await _firestore
        .collection('salary_components')
        .where('companyId', isEqualTo: companyId)
        .get();

    if (query.docs.isEmpty) {
      final standardEarnings = [
        {'name': 'Basic', 'type': 'Earning', 'calculationType': 'Flat', 'value': 15000.0},
        {'name': 'HRA', 'type': 'Earning', 'calculationType': 'Percentage', 'value': 40.0},
        {'name': 'DA', 'type': 'Earning', 'calculationType': 'Flat', 'value': 0.0},
        {'name': 'Medical', 'type': 'Earning', 'calculationType': 'Flat', 'value': 1250.0},
        {'name': 'Food', 'type': 'Earning', 'calculationType': 'Flat', 'value': 0.0},
        {'name': 'Travel', 'type': 'Earning', 'calculationType': 'Flat', 'value': 1600.0},
        {'name': 'Bonus', 'type': 'Earning', 'calculationType': 'Flat', 'value': 0.0},
        {'name': 'Incentive', 'type': 'Earning', 'calculationType': 'Flat', 'value': 0.0},
        {'name': 'Other Earnings', 'type': 'Earning', 'calculationType': 'Flat', 'value': 0.0},
      ];

      final standardDeductions = [
        {'name': 'PF', 'type': 'Deduction', 'calculationType': 'Percentage', 'value': 12.0},
        {'name': 'ESI', 'type': 'Deduction', 'calculationType': 'Percentage', 'value': 0.75},
        {'name': 'Professional Tax', 'type': 'Deduction', 'calculationType': 'Flat', 'value': 200.0},
        {'name': 'TDS', 'type': 'Deduction', 'calculationType': 'Flat', 'value': 0.0},
        {'name': 'Other Deductions', 'type': 'Deduction', 'calculationType': 'Flat', 'value': 0.0},
      ];

      final List<SalaryComponentModel> seeded = [];
      final batch = _firestore.batch();
      
      for (final comp in [...standardEarnings, ...standardDeductions]) {
        final id = const Uuid().v4();
        final model = SalaryComponentModel(
          componentId: id,
          componentName: comp['name'] as String,
          componentType: comp['type'] as String,
          calculationType: comp['calculationType'] as String,
          defaultValue: comp['value'] as double,
          companyId: companyId,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          status: 'active',
        );
        batch.set(_firestore.collection('salary_components').doc(id), model.toMap());
        seeded.add(model);
      }
      await batch.commit();
      return seeded;
    }

    return query.docs.map((doc) => SalaryComponentModel.fromMap(doc.data())).toList();
  }

  Future<void> saveSalaryComponent(SalaryComponentModel component) async {
    await _firestore
        .collection('salary_components')
        .doc(component.componentId)
        .set(component.toMap());
  }

  Future<void> deleteSalaryComponent(String componentId) async {
    await _firestore.collection('salary_components').doc(componentId).delete();
  }

  Future<void> archiveSalaryComponent(String componentId) async {
    await _firestore.collection('salary_components').doc(componentId).update({
      'status': 'archived',
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<void> restoreSalaryComponent(String componentId) async {
    await _firestore.collection('salary_components').doc(componentId).update({
      'status': 'active',
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<void> logSalaryComponentActivity({
    required String companyId,
    required String componentId,
    required String componentName,
    required String action,
    required String performedBy,
    required String details,
  }) async {
    final logId = const Uuid().v4();
    final log = SalaryComponentAuditLogModel(
      logId: logId,
      companyId: companyId,
      componentId: componentId,
      componentName: componentName,
      action: action,
      details: details,
      performedBy: performedBy,
      timestamp: DateTime.now(),
    );
    await _firestore.collection('salary_component_audit_logs').doc(logId).set(log.toMap());
  }

  Future<List<SalaryComponentAuditLogModel>> getSalaryComponentAuditLogs(String companyId) async {
    final query = await _firestore
        .collection('salary_component_audit_logs')
        .where('companyId', isEqualTo: companyId)
        .orderBy('timestamp', descending: true)
        .get();
    return query.docs.map((doc) => SalaryComponentAuditLogModel.fromMap(doc.data())).toList();
  }

  // ==========================================
  // SALARY STRUCTURES
  // ==========================================

  Future<List<SalaryStructureModel>> getSalaryStructures(String companyId) async {
    final query = await _firestore
        .collection('salary_structures')
        .where('companyId', isEqualTo: companyId)
        .where('status', isNotEqualTo: 'deleted')
        .get();
    return query.docs.map((doc) => SalaryStructureModel.fromMap(doc.data())).toList();
  }

  Future<void> saveSalaryStructure(SalaryStructureModel structure) async {
    await _firestore
        .collection('salary_structures')
        .doc(structure.structureId)
        .set(structure.toMap());
  }

  Future<void> softDeleteSalaryStructure(String structureId) async {
    await _firestore.collection('salary_structures').doc(structureId).update({
      'status': 'deleted',
    });
  }

  Future<void> assignSalaryStructure(String employeeId, String? structureId, String? structureName) async {
    await _firestore.collection('users').doc(employeeId).update({
      'salaryStructureId': structureId,
      'salaryStructureName': structureName,
    });
  }

  // ==========================================
  // SALARY REVISION HISTORY
  // ==========================================

  /// Saves a salary revision snapshot for an employee.
  Future<void> saveSalaryRevision(SalaryRevisionModel revision) async {
    await _firestore
        .collection('salary_revisions')
        .doc(revision.revisionId)
        .set(revision.toMap());
  }

  /// Gets all salary revisions for a specific employee, sorted by effectiveDate desc.
  Future<List<SalaryRevisionModel>> getEmployeeSalaryRevisions(
      String companyId, String employeeId) async {
    final query = await _firestore
        .collection('salary_revisions')
        .where('companyId', isEqualTo: companyId)
        .where('employeeId', isEqualTo: employeeId)
        .get();

    final list = query.docs
        .map((doc) => SalaryRevisionModel.fromMap(doc.data()))
        .toList();
    list.sort((a, b) => b.effectiveDate.compareTo(a.effectiveDate));
    return list;
  }

  /// Gets all salary revisions for a company, sorted by effectiveDate desc.
  Future<List<SalaryRevisionModel>> getCompanySalaryRevisions(
      String companyId) async {
    final query = await _firestore
        .collection('salary_revisions')
        .where('companyId', isEqualTo: companyId)
        .get();

    final list = query.docs
        .map((doc) => SalaryRevisionModel.fromMap(doc.data()))
        .toList();
    list.sort((a, b) => b.effectiveDate.compareTo(a.effectiveDate));
    return list;
  }

  // ==========================================
  // MODULE 12 - PF / ESI / PROFESSIONAL TAX
  // ==========================================

  Future<PfEsiTaxSettingsModel> getPfEsiTaxSettings(String companyId) async {
    final doc = await _firestore.collection('pf_esi_tax_settings').doc(companyId).get();
    if (doc.exists && doc.data() != null) {
      return PfEsiTaxSettingsModel.fromMap(doc.data()!, companyId);
    }
    return PfEsiTaxSettingsModel(companyId: companyId);
  }

  Future<void> savePfEsiTaxSettings(PfEsiTaxSettingsModel settings) async {
    await _firestore
        .collection('pf_esi_tax_settings')
        .doc(settings.companyId)
        .set(settings.toMap());
  }

  // ==========================================
  // MODULE 13 - PAYROLL SETTINGS
  // ==========================================

  Future<PayrollSettingsModel> getPayrollSettings(String companyId) async {
    final doc = await _firestore.collection('payroll_settings').doc(companyId).get();
    if (doc.exists && doc.data() != null) {
      return PayrollSettingsModel.fromMap(doc.data()!, companyId);
    }
    return PayrollSettingsModel(companyId: companyId);
  }

  Future<void> savePayrollSettings(PayrollSettingsModel settings) async {
    await _firestore
        .collection('payroll_settings')
        .doc(settings.companyId)
        .set(settings.toMap());
  }

  // ==========================================
  // MODULE 15 - OVERRIDE APPROVAL
  // ==========================================

  Future<List<LeaveRequestModel>> getPendingLeaves(String companyId) async {
    final query = await _firestore
        .collection('leave_requests')
        .where('companyId', isEqualTo: companyId)
        .where('status', isEqualTo: 'Pending')
        .get();
    return query.docs.map((doc) => LeaveRequestModel.fromMap(doc.data())).toList();
  }

  Future<List<ExpenseModel>> getPendingExpenses(String companyId) async {
    final query = await _firestore
        .collection('expenses')
        .where('companyId', isEqualTo: companyId)
        .where('status', isEqualTo: 'Pending')
        .get();
    return query.docs.map((doc) => ExpenseModel.fromMap(doc.data())).toList();
  }

  Future<List<AttendanceModel>> getPendingAttendanceCorrections(String companyId) async {
    final query = await _firestore
        .collection('attendance')
        .where('companyId', isEqualTo: companyId)
        .where('status', isEqualTo: 'PendingCorrection')
        .get();
    return query.docs.map((doc) => AttendanceModel.fromMap(doc.data())).toList();
  }

  Future<List<EmployeeRequestModel>> getPendingEmployeeRequests(String companyId) async {
    final query = await _firestore
        .collection('employee_requests')
        .where('companyId', isEqualTo: companyId)
        .where('status', isEqualTo: 'Pending')
        .get();
    return query.docs.map((doc) => EmployeeRequestModel.fromMap(doc.data())).toList();
  }

  Future<void> approveLeave(String leaveId, String adminUid, String adminName) async {
    await _firestore.collection('leave_requests').doc(leaveId).update({
      'status': 'Approved',
      'approvedBy': adminUid,
      'approvedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> rejectLeave(String leaveId, String adminUid, String adminName) async {
    await _firestore.collection('leave_requests').doc(leaveId).update({
      'status': 'Rejected',
      'approvedBy': adminUid,
      'approvedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> approveExpense(String expenseId, String adminUid, String adminName) async {
    await _firestore.collection('expenses').doc(expenseId).update({
      'status': 'Approved',
      'approvedBy': adminUid,
      'approvedByName': adminName,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> rejectExpense(String expenseId, String adminUid, String adminName) async {
    await _firestore.collection('expenses').doc(expenseId).update({
      'status': 'Rejected',
      'approvedBy': adminUid,
      'approvedByName': adminName,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateAttendanceCorrection(String attendanceId, String status) async {
    await _firestore.collection('attendance').doc(attendanceId).update({
      'status': status,
    });
  }

  Future<void> logEmployeeActivity({
    required String companyId,
    required String employeeId,
    required String action,
    required String performedBy,
  }) async {
    final activityId = const Uuid().v4();
    await _firestore.collection('user_activities').doc(activityId).set({
      'activityId': activityId,
      'companyId': companyId,
      'employeeId': employeeId,
      'action': action,
      'performedBy': performedBy,
      'timestamp': Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<List<Map<String, dynamic>>> getEmployeeActivities(String companyId, String employeeId) async {
    final query = await _firestore
        .collection('user_activities')
        .where('companyId', isEqualTo: companyId)
        .where('employeeId', isEqualTo: employeeId)
        .get();
    final list = query.docs.map((d) => d.data()).toList();
    list.sort((a, b) {
      final aTs = a['timestamp'] is Timestamp
          ? (a['timestamp'] as Timestamp).toDate()
          : DateTime.fromMillisecondsSinceEpoch(0);
      final bTs = b['timestamp'] is Timestamp
          ? (b['timestamp'] as Timestamp).toDate()
          : DateTime.fromMillisecondsSinceEpoch(0);
      return bTs.compareTo(aTs);
    });
    return list;
  }

  // ==========================================
  // BRANCH MANAGEMENT METHODS
  // ==========================================

  Future<List<BranchModel>> getBranches(String companyId) async {
    final query = await _firestore
        .collection('branches')
        .where('companyId', isEqualTo: companyId)
        .get();
    return query.docs
        .map((doc) => BranchModel.fromMap(doc.data()))
        .toList();
  }

  Future<void> saveBranch(BranchModel branch) async {
    await _firestore
        .collection('branches')
        .doc(branch.branchId)
        .set(branch.toMap());
  }

  Future<void> archiveBranch(String branchId) async {
    await _firestore.collection('branches').doc(branchId).update({
      'status': 'archived',
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<void> restoreBranch(String branchId) async {
    await _firestore.collection('branches').doc(branchId).update({
      'status': 'active',
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<bool> isBranchNameDuplicate(String companyId, String name, {String? excludeId}) async {
    final query = await _firestore
        .collection('branches')
        .where('companyId', isEqualTo: companyId)
        .get();
    final normalized = name.trim().toLowerCase();
    for (final doc in query.docs) {
      final b = BranchModel.fromMap(doc.data());
      if (b.status == 'deleted') continue;
      if (excludeId != null && b.branchId == excludeId) continue;
      if (b.branchName.trim().toLowerCase() == normalized) {
        return true;
      }
    }
    return false;
  }

  Future<bool> isBranchCodeDuplicate(String companyId, String code, {String? excludeId}) async {
    final query = await _firestore
        .collection('branches')
        .where('companyId', isEqualTo: companyId)
        .get();
    final normalized = code.trim().toLowerCase();
    for (final doc in query.docs) {
      final b = BranchModel.fromMap(doc.data());
      if (b.status == 'deleted') continue;
      if (excludeId != null && b.branchId == excludeId) continue;
      if (b.branchCode.trim().toLowerCase() == normalized) {
        return true;
      }
    }
    return false;
  }

  // ==========================================
  // EMPLOYEE DOCUMENT MANAGEMENT METHODS
  // ==========================================

  Future<List<EmployeeDocumentModel>> getEmployeeDocuments(String companyId, String employeeId) async {
    final query = await _firestore
        .collection('employee_documents')
        .where('companyId', isEqualTo: companyId)
        .where('employeeId', isEqualTo: employeeId)
        .get();
    return query.docs
        .map((doc) => EmployeeDocumentModel.fromMap(doc.data()))
        .toList();
  }

  Future<List<EmployeeDocumentModel>> getCompanyAllEmployeeDocuments(String companyId) async {
    final query = await _firestore
        .collection('employee_documents')
        .where('companyId', isEqualTo: companyId)
        .get();
    return query.docs
        .map((doc) => EmployeeDocumentModel.fromMap(doc.data()))
        .toList();
  }

  Future<void> saveEmployeeDocument(EmployeeDocumentModel doc) async {
    await _firestore
        .collection('employee_documents')
        .doc(doc.documentId)
        .set(doc.toMap(), SetOptions(merge: true));
  }

  Future<void> updateDocumentVerification({
    required String documentId,
    required String verificationStatus,
    String? verifiedBy,
    String? verifiedByName,
    String? rejectionReason,
    String? rejectedBy,
    String? rejectedByName,
  }) async {
    final updates = <String, dynamic>{
      'verificationStatus': verificationStatus,
    };
    if (verificationStatus == 'verified') {
      updates['verifiedBy'] = verifiedBy;
      updates['verifiedByName'] = verifiedByName;
      updates['verifiedAt'] = Timestamp.fromDate(DateTime.now());
      updates['rejectionReason'] = FieldValue.delete();
    } else if (verificationStatus == 'rejected') {
      updates['rejectedBy'] = rejectedBy;
      updates['rejectedByName'] = rejectedByName;
      updates['rejectedAt'] = Timestamp.fromDate(DateTime.now());
      updates['rejectionReason'] = rejectionReason ?? 'Document rejected by HR';
    }
    await _firestore.collection('employee_documents').doc(documentId).update(updates);
  }

  Future<void> archiveEmployeeDocument(String documentId) async {
    await _firestore.collection('employee_documents').doc(documentId).update({
      'status': 'archived',
    });
  }

  Future<void> restoreEmployeeDocument(String documentId) async {
    await _firestore.collection('employee_documents').doc(documentId).update({
      'status': 'active',
    });
  }

  Future<void> deleteEmployeeDocument(String documentId) async {
    await _firestore.collection('employee_documents').doc(documentId).delete();
  }

  // ==========================================
  // MODULE 16 - PAYROLL PROCESSING
  // ==========================================

  /// Fetches all payroll records for a company in a given month/year.
  Future<List<PayrollModel>> getPayrolls(
      String companyId, int month, int year) async {
    final query = await _firestore
        .collection('payrolls')
        .where('companyId', isEqualTo: companyId)
        .where('month', isEqualTo: month)
        .where('year', isEqualTo: year)
        .get();
    return query.docs.map((doc) => PayrollModel.fromMap(doc.data())).toList();
  }

  /// Fetches all payroll records for a specific employee (history).
  Future<List<PayrollModel>> getEmployeePayrolls(
      String companyId, String employeeId) async {
    final query = await _firestore
        .collection('payrolls')
        .where('companyId', isEqualTo: companyId)
        .where('employeeId', isEqualTo: employeeId)
        .get();
    final list =
        query.docs.map((doc) => PayrollModel.fromMap(doc.data())).toList();
    list.sort((a, b) {
      final yearCmp = b.year.compareTo(a.year);
      return yearCmp != 0 ? yearCmp : b.month.compareTo(a.month);
    });
    return list;
  }

  /// Upserts a single payroll record.
  Future<void> savePayroll(PayrollModel payroll) async {
    await _firestore
        .collection('payrolls')
        .doc(payroll.payrollId)
        .set(payroll.toMap());
  }

  /// Updates only the status fields of a payroll record.
  Future<void> updatePayrollStatus(
    String payrollId,
    String status, {
    String? approvedBy,
    String? remarks,
    DateTime? approvedAt,
    DateTime? paidAt,
  }) async {
    final Map<String, dynamic> updates = {
      'status': status,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    };
    if (approvedBy != null) updates['approvedBy'] = approvedBy;
    if (remarks != null) updates['remarks'] = remarks;
    if (approvedAt != null) updates['approvedAt'] = Timestamp.fromDate(approvedAt);
    if (paidAt != null) updates['paidAt'] = Timestamp.fromDate(paidAt);
    await _firestore.collection('payrolls').doc(payrollId).update(updates);
  }

  /// Fetches attendance records for an employee within a month/year range.
  Future<List<AttendanceModel>> getAttendanceForPeriod(
      String companyId, String employeeId, int month, int year) async {
    final startDate = DateTime(year, month, 1);
    final endDate = DateTime(year, month + 1, 1);
    final query = await _firestore
        .collection('attendance')
        .where('companyId', isEqualTo: companyId)
        .where('employeeId', isEqualTo: employeeId)
        .where('checkInTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('checkInTime', isLessThan: Timestamp.fromDate(endDate))
        .get();
    return query.docs.map((doc) => AttendanceModel.fromMap(doc.data())).toList();
  }

  /// Fetches approved leave requests for an employee that overlap with the month.
  Future<List<LeaveRequestModel>> getApprovedLeavesForPeriod(
      String companyId, String employeeId, int month, int year) async {
    final startDate = DateTime(year, month, 1);
    final endDate = DateTime(year, month + 1, 0); // last day of month
    final query = await _firestore
        .collection('leave_requests')
        .where('companyId', isEqualTo: companyId)
        .where('employeeId', isEqualTo: employeeId)
        .where('status', isEqualTo: 'Approved')
        .get();
    // Filter in Dart since Firestore does not support range queries on two fields simultaneously
    return query.docs
        .map((doc) => LeaveRequestModel.fromMap(doc.data()))
        .where((leave) =>
            leave.fromDate.isBefore(endDate.add(const Duration(days: 1))) &&
            leave.toDate.isAfter(startDate.subtract(const Duration(days: 1))))
        .toList();
  }

  /// Generates payroll for all eligible employees for the given month/year.
  /// Employees who already have a payroll record for that period are skipped.
  Future<int> generateMonthlyPayroll({
    required String companyId,
    required int month,
    required int year,
    required String generatedBy,
  }) async {
    final now = DateTime.now();

    // Month label e.g. "July 2026"
    const monthNames = [
      '', 'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    final payrollPeriod = '${monthNames[month]} $year';

    // 1. Load settings
    final payrollSettings = await getPayrollSettings(companyId);
    final pfEsiSettings = await getPfEsiTaxSettings(companyId);
    final overtimeSettings = await getOvertimeSettings(companyId);
    final salaryComponents = await getSalaryComponents(companyId);

    // 2. Load all active employees with a salary structure
    final employees = await getCompanyEmployees(companyId);
    final eligibleEmployees = employees
        .where((e) =>
            e.status == 'active' &&
            e.salaryStructureId != null &&
            e.salaryStructureId!.isNotEmpty)
        .toList();

    // 3. Check existing payrolls to avoid duplicates
    final existingPayrolls = await getPayrolls(companyId, month, year);
    final existingEmployeeIds =
        existingPayrolls.map((p) => p.employeeId).toSet();

    // 4. Load all salary structures
    final allStructures = await getSalaryStructures(companyId);
    final structureMap = {
      for (final s in allStructures) s.structureId: s,
    };

    // Paid leave type identifiers (case-insensitive match)
    const paidLeaveTypes = {'annual', 'casual', 'sick'};

    int generatedCount = 0;
    final batch = _firestore.batch();

    for (final employee in eligibleEmployees) {
      // Skip if payroll already exists for this period
      if (existingEmployeeIds.contains(employee.uid)) continue;

      final structure = structureMap[employee.salaryStructureId];
      if (structure == null) continue;

      // 5a. Fetch attendance
      final attendanceRecords = await getAttendanceForPeriod(
          companyId, employee.uid, month, year);

      double presentDays = 0.0;
      double totalOvertimeHours = 0.0;
      for (final record in attendanceRecords) {
        final s = record.status.toLowerCase();
        if (s == 'present' || s == 'late') {
          presentDays += 1.0;
        } else if (s == 'half day') {
          presentDays += 0.5;
        }
        totalOvertimeHours += record.overtimeHours ?? 0.0;
      }

      // 5b. Fetch approved leaves
      final approvedLeaves = await getApprovedLeavesForPeriod(
          companyId, employee.uid, month, year);

      double paidLeaveDays = 0.0;
      double unpaidLeaveDays = 0.0;

      for (final leave in approvedLeaves) {
        // Clip leave days to this month only
        final monthStart = DateTime(year, month, 1);
        final monthEnd = DateTime(year, month + 1, 0);
        final clippedFrom =
            leave.fromDate.isBefore(monthStart) ? monthStart : leave.fromDate;
        final clippedTo =
            leave.toDate.isAfter(monthEnd) ? monthEnd : leave.toDate;
        final days =
            clippedTo.difference(clippedFrom).inDays + 1.0;

        final leaveTypeLower = leave.leaveTypeId.trim().toLowerCase();
        if (paidLeaveTypes.any((t) => leaveTypeLower.contains(t))) {
          paidLeaveDays += days;
        } else {
          unpaidLeaveDays += days;
        }
      }

      final int totalWorkingDays = payrollSettings.workingDays;
      final double paidDays = presentDays + paidLeaveDays;
      final double lopDays = (totalWorkingDays - paidDays).clamp(0.0, totalWorkingDays.toDouble());
      final double proRation = totalWorkingDays > 0
          ? (paidDays / totalWorkingDays).clamp(0.0, 1.0)
          : 1.0;

      // 5c. Pro-rate earnings
      final Map<String, double> earningsMap = {};
      double grossSalary = 0.0;

      for (final entry in structure.earnings.entries) {
        // entry.key is componentId → look up name from components
        final component = salaryComponents.firstWhere(
          (c) => c.componentId == entry.key,
          orElse: () => SalaryComponentModel(
            componentId: entry.key,
            companyId: companyId,
            componentName: entry.key,
            componentType: 'Earning',
            createdAt: now,
            updatedAt: now,
          ),
        );
        final rawAmount = entry.value;
        double amount;
        if (component.calculationType == 'Percentage') {
          // Percentage of basic
          amount = (structure.basic * rawAmount / 100) * proRation;
        } else {
          amount = rawAmount * proRation;
        }
        amount = double.parse(amount.toStringAsFixed(2));
        earningsMap[component.componentName] = amount;
        grossSalary += amount;
      }
      grossSalary = double.parse(grossSalary.toStringAsFixed(2));

      // 5d. Overtime pay
      double overtimePay = 0.0;
      if (overtimeSettings.hourlyRate > 0 && totalOvertimeHours > 0) {
        overtimePay = double.parse(
            (totalOvertimeHours * overtimeSettings.hourlyRate).toStringAsFixed(2));
      }

      // 5e. Statutory deductions
      double pfEmployee = 0.0;
      double pfEmployer = 0.0;
      double esiEmployee = 0.0;
      double esiEmployer = 0.0;
      double profTax = 0.0;

      // PF is calculated on basic salary (pro-rated)
      final proratedBasic = structure.basic * proRation;

      if (pfEsiSettings.pfEnabled) {
        pfEmployee = double.parse(
            (proratedBasic * pfEsiSettings.pfEmployeeContribution / 100)
                .toStringAsFixed(2));
        pfEmployer = double.parse(
            (proratedBasic * pfEsiSettings.pfEmployerContribution / 100)
                .toStringAsFixed(2));
      }

      // ESI applicable only if gross ≤ ₹21,000
      if (pfEsiSettings.esiEnabled && grossSalary <= 21000) {
        esiEmployee = double.parse(
            (grossSalary * pfEsiSettings.esiEmployeeContribution / 100)
                .toStringAsFixed(2));
        esiEmployer = double.parse(
            (grossSalary * pfEsiSettings.esiEmployerContribution / 100)
                .toStringAsFixed(2));
      }

      // Professional Tax via slabs
      if (pfEsiSettings.profTaxEnabled && pfEsiSettings.taxSlabs.isNotEmpty) {
        for (final slab in pfEsiSettings.taxSlabs) {
          final min = (slab['min'] as num?)?.toDouble() ?? 0;
          final max = (slab['max'] as num?)?.toDouble() ?? double.infinity;
          final tax = (slab['tax'] as num?)?.toDouble() ?? 0;
          if (grossSalary >= min && grossSalary <= max) {
            profTax = tax;
            break;
          }
        }
      }

      // 5f. Custom deductions from salary structure
      final Map<String, double> deductionsMap = {};
      double customDeductionsTotal = 0.0;

      for (final entry in structure.deductions.entries) {
        final component = salaryComponents.firstWhere(
          (c) => c.componentId == entry.key,
          orElse: () => SalaryComponentModel(
            componentId: entry.key,
            companyId: companyId,
            componentName: entry.key,
            componentType: 'Deduction',
            createdAt: now,
            updatedAt: now,
          ),
        );
        final rawAmount = entry.value;
        double amount;
        if (component.calculationType == 'Percentage') {
          amount = double.parse(
              (grossSalary * rawAmount / 100).toStringAsFixed(2));
        } else {
          amount = double.parse(rawAmount.toStringAsFixed(2));
        }
        deductionsMap[component.componentName] = amount;
        customDeductionsTotal += amount;
      }

      final double totalDeductions = double.parse(
          (pfEmployee + esiEmployee + profTax + customDeductionsTotal)
              .toStringAsFixed(2));
      final double netSalary = double.parse(
          (grossSalary + overtimePay - totalDeductions).toStringAsFixed(2));

      // 5g. Build PayrollModel
      final payrollId = const Uuid().v4();
      final payroll = PayrollModel(
        payrollId: payrollId,
        companyId: companyId,
        employeeId: employee.uid,
        employeeName: employee.name,
        designation: employee.designation,
        department: employee.department,
        month: month,
        year: year,
        payrollPeriod: payrollPeriod,
        salaryStructureId: employee.salaryStructureId,
        salaryStructureName: employee.salaryStructureName,
        totalWorkingDays: totalWorkingDays,
        presentDays: presentDays,
        paidLeaveDays: paidLeaveDays,
        unpaidLeaveDays: unpaidLeaveDays,
        paidDays: paidDays,
        lopDays: lopDays,
        earnings: earningsMap,
        deductions: deductionsMap,
        grossSalary: grossSalary,
        overtimePay: overtimePay,
        pfEmployeeAmount: pfEmployee,
        pfEmployerAmount: pfEmployer,
        esiEmployeeAmount: esiEmployee,
        esiEmployerAmount: esiEmployer,
        professionalTax: profTax,
        tdsAmount: 0.0,
        totalDeductions: totalDeductions,
        netSalary: netSalary,
        status: 'Draft',
        generatedBy: generatedBy,
        generatedAt: now,
        createdAt: now,
        updatedAt: now,
      );

      batch.set(
          _firestore.collection('payrolls').doc(payrollId), payroll.toMap());
      generatedCount++;
    }

    if (generatedCount > 0) {
      await batch.commit();
    }
    return generatedCount;
  }
}

