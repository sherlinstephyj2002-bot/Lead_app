import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../repositories/company_tenant_repository.dart';
import '../constants/user_roles.dart';

class CompanyTenantProvider with ChangeNotifier {
  final CompanyTenantRepository _repository;

  String? _currentCompanyId;
  bool _isLoading = false;
  String? _errorMessage;

  List<UserModel> _allUsers = [];
  List<Map<String, dynamic>> _departments = [];
  List<Map<String, dynamic>> _attendanceRecords = [];
  List<Map<String, dynamic>> _leaveRecords = [];
  List<Map<String, dynamic>> _leadRecords = [];
  List<Map<String, dynamic>> _orderRecords = [];
  List<Map<String, dynamic>> _payslipRecords = [];
  List<Map<String, dynamic>> _documentRecords = [];
  List<Map<String, dynamic>> _auditLogs = [];

  // Employee Directory Filters
  String _employeeSearchQuery = '';
  String _employeeDeptFilter = 'All';
  String _employeeDesignationFilter = 'All';
  String _employeeRoleFilter = 'All';
  String _employeeBranchFilter = 'All';
  String _employeeStatusFilter = 'All';

  CompanyTenantProvider(this._repository);

  // Getters
  String? get currentCompanyId => _currentCompanyId;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  List<Map<String, dynamic>> get departments => _departments;
  List<Map<String, dynamic>> get attendanceRecords => _attendanceRecords;
  List<Map<String, dynamic>> get leaveRecords => _leaveRecords;
  List<Map<String, dynamic>> get leadRecords => _leadRecords;
  List<Map<String, dynamic>> get orderRecords => _orderRecords;
  List<Map<String, dynamic>> get payslipRecords => _payslipRecords;
  List<Map<String, dynamic>> get documentRecords => _documentRecords;
  List<Map<String, dynamic>> get auditLogs => _auditLogs;

  String get employeeSearchQuery => _employeeSearchQuery;
  String get employeeDeptFilter => _employeeDeptFilter;
  String get employeeDesignationFilter => _employeeDesignationFilter;
  String get employeeRoleFilter => _employeeRoleFilter;
  String get employeeBranchFilter => _employeeBranchFilter;
  String get employeeStatusFilter => _employeeStatusFilter;

  /// Regular employees list (excluding Company Admin and Super Admin)
  List<UserModel> get employees {
    return _allUsers.where((u) {
      final role = u.role.toLowerCase();
      return role != UserRoles.superAdmin && role != UserRoles.companyAdmin;
    }).toList();
  }

  /// Filtered employee list based on directory search & filter criteria
  List<UserModel> get filteredEmployees {
    return employees.where((emp) {
      final matchesSearch = _employeeSearchQuery.isEmpty ||
          emp.name.toLowerCase().contains(_employeeSearchQuery.toLowerCase()) ||
          emp.email.toLowerCase().contains(_employeeSearchQuery.toLowerCase()) ||
          (emp.employeeId ?? '').toLowerCase().contains(_employeeSearchQuery.toLowerCase());

      final matchesDept = _employeeDeptFilter == 'All' ||
          (emp.department ?? '').toLowerCase() == _employeeDeptFilter.toLowerCase();

      final matchesDesignation = _employeeDesignationFilter == 'All' ||
          (emp.designation ?? '').toLowerCase() == _employeeDesignationFilter.toLowerCase();

      final matchesRole = _employeeRoleFilter == 'All' ||
          emp.role.toLowerCase() == _employeeRoleFilter.toLowerCase();

      final matchesBranch = _employeeBranchFilter == 'All' ||
          (emp.branch ?? '').toLowerCase() == _employeeBranchFilter.toLowerCase();

      final matchesStatus = _employeeStatusFilter == 'All' ||
          (emp.status ?? 'Active').toLowerCase() == _employeeStatusFilter.toLowerCase();

      return matchesSearch && matchesDept && matchesDesignation && matchesRole && matchesBranch && matchesStatus;
    }).toList();
  }

  /// Company Admins & HR Users
  List<UserModel> get companyAdminsAndHr {
    return _allUsers.where((u) {
      final role = u.role.toLowerCase();
      return role == UserRoles.companyAdmin ||
          role == UserRoles.hr ||
          role == 'hr_executive' ||
          role == 'hr executive';
    }).toList();
  }

  // Filter Setters
  void setEmployeeSearchQuery(String query) {
    _employeeSearchQuery = query;
    notifyListeners();
  }

  void setEmployeeDeptFilter(String dept) {
    _employeeDeptFilter = dept;
    notifyListeners();
  }

  void setEmployeeDesignationFilter(String desig) {
    _employeeDesignationFilter = desig;
    notifyListeners();
  }

  void setEmployeeRoleFilter(String role) {
    _employeeRoleFilter = role;
    notifyListeners();
  }

  void setEmployeeBranchFilter(String branch) {
    _employeeBranchFilter = branch;
    notifyListeners();
  }

  void setEmployeeStatusFilter(String status) {
    _employeeStatusFilter = status;
    notifyListeners();
  }

  /// Loads all tenant data for the given companyId
  Future<void> loadCompanyTenantData(String companyId) async {
    _currentCompanyId = companyId;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _repository.getCompanyUsers(companyId),
        _repository.getCompanyDepartments(companyId),
        _repository.getCompanyAttendance(companyId),
        _repository.getCompanyLeaves(companyId),
        _repository.getCompanyLeads(companyId),
        _repository.getCompanyOrders(companyId),
        _repository.getCompanyPayslips(companyId),
        _repository.getCompanyDocuments(companyId),
        _repository.getCompanyAuditLogs(companyId),
      ]);

      _allUsers = results[0] as List<UserModel>;
      _departments = results[1] as List<Map<String, dynamic>>;
      _attendanceRecords = results[2] as List<Map<String, dynamic>>;
      _leaveRecords = results[3] as List<Map<String, dynamic>>;
      _leadRecords = results[4] as List<Map<String, dynamic>>;
      _orderRecords = results[5] as List<Map<String, dynamic>>;
      _payslipRecords = results[6] as List<Map<String, dynamic>>;
      _documentRecords = results[7] as List<Map<String, dynamic>>;
      _auditLogs = results[8] as List<Map<String, dynamic>>;

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Refreshes tenant data
  Future<void> refresh() async {
    if (_currentCompanyId != null) {
      await loadCompanyTenantData(_currentCompanyId!);
    }
  }
}
