import 'package:flutter/material.dart';
import '../models/company_model.dart';
import '../repositories/company_repository.dart';

class CompanyProvider with ChangeNotifier {
  final CompanyRepository _companyRepository;

  List<CompanyModel> _companies = [];
  Map<String, int> _employeeCounts = {};
  int _totalUsersCount = 0;
  bool _isLoading = false;
  bool _isUpdating = false;
  String? _errorMessage;

  // Search and Filters
  String _searchQuery = '';
  String _statusFilter = 'All'; // 'All', 'Active', 'Suspended'
  String _subscriptionFilter = 'All'; // 'All', 'Free', 'Standard', 'Enterprise'

  // Pagination
  int _currentPage = 0;
  int _rowsPerPage = 10;

  CompanyProvider(this._companyRepository);

  // Getters
  List<CompanyModel> get companies => _companies;
  int get totalUsersCount => _totalUsersCount;
  bool get isLoading => _isLoading;
  bool get isUpdating => _isUpdating;
  String? get errorMessage => _errorMessage;

  String get searchQuery => _searchQuery;
  String get statusFilter => _statusFilter;
  String get subscriptionFilter => _subscriptionFilter;

  int get currentPage => _currentPage;
  int get rowsPerPage => _rowsPerPage;

  int getEmployeeCount(String companyId) {
    return _employeeCounts[companyId] ?? 0;
  }

  // Setters with notifyListeners
  void setSearchQuery(String query) {
    _searchQuery = query;
    _currentPage = 0; // Reset page on filter change
    notifyListeners();
  }

  void setStatusFilter(String status) {
    _statusFilter = status;
    _currentPage = 0; // Reset page on filter change
    notifyListeners();
  }

  void setSubscriptionFilter(String subscription) {
    _subscriptionFilter = subscription;
    _currentPage = 0; // Reset page on filter change
    notifyListeners();
  }

  void setCurrentPage(int page) {
    _currentPage = page;
    notifyListeners();
  }

  void setRowsPerPage(int rows) {
    _rowsPerPage = rows;
    _currentPage = 0; // Reset to page 0
    notifyListeners();
  }

  /// Refetches companies and their employee counts
  Future<void> fetchCompanies() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final fetchedCompanies = await _companyRepository.getCompanies();
      final userCount = await _companyRepository.getTotalUserCount();
      final counts = <String, int>{};
      
      for (final comp in fetchedCompanies) {
        final count = await _companyRepository.getEmployeeCount(comp.companyId);
        counts[comp.companyId] = count;
      }

      _companies = fetchedCompanies;
      _employeeCounts = counts;
      _totalUsersCount = userCount;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Activates a company, logs the action, and refreshes the data
  Future<bool> activateCompany({
    required String companyId,
    required String companyName,
    required String performedBy,
  }) async {
    _isUpdating = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _companyRepository.updateCompanyStatus(
        companyId: companyId,
        status: 'Active',
        performedBy: performedBy,
      );
      await _companyRepository.logActivity(
        action: 'Activate Company',
        companyId: companyId,
        companyName: companyName,
        performedBy: performedBy,
      );
      await fetchCompanies();
      _isUpdating = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isUpdating = false;
      notifyListeners();
      return false;
    }
  }

  /// Suspends a company, logs the action, and refreshes the data
  Future<bool> suspendCompany({
    required String companyId,
    required String companyName,
    required String performedBy,
  }) async {
    _isUpdating = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _companyRepository.updateCompanyStatus(
        companyId: companyId,
        status: 'Suspended',
        performedBy: performedBy,
      );
      await _companyRepository.logActivity(
        action: 'Suspend Company',
        companyId: companyId,
        companyName: companyName,
        performedBy: performedBy,
      );
      await fetchCompanies();
      _isUpdating = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isUpdating = false;
      notifyListeners();
      return false;
    }
  }

  /// Soft deletes a company, logs the action, and refreshes the data
  Future<bool> deleteCompany({
    required String companyId,
    required String companyName,
    required String performedBy,
  }) async {
    _isUpdating = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _companyRepository.softDeleteCompany(
        companyId: companyId,
        performedBy: performedBy,
      );
      await _companyRepository.logActivity(
        action: 'Delete Company',
        companyId: companyId,
        companyName: companyName,
        performedBy: performedBy,
      );
      await fetchCompanies();
      _isUpdating = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isUpdating = false;
      notifyListeners();
      return false;
    }
  }

  /// Upgrades a company's subscription plan, logs the action, and refreshes the data
  Future<bool> upgradeCompanyPlan({
    required String companyId,
    required String companyName,
    required String planName,
    required String performedBy,
  }) async {
    _isUpdating = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _companyRepository.upgradeSubscription(
        companyId: companyId,
        planName: planName,
        performedBy: performedBy,
      );
      await _companyRepository.logActivity(
        action: 'Upgrade Plan',
        companyId: companyId,
        companyName: companyName,
        performedBy: performedBy,
      );
      await fetchCompanies();
      _isUpdating = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isUpdating = false;
      notifyListeners();
      return false;
    }
  }

  /// Returns the filtered list of companies based on search and filters
  List<CompanyModel> get filteredCompanies {
    return _companies.where((company) {
      // 1. Search Query (name or ID)
      final nameMatches = company.name.toLowerCase().contains(_searchQuery.toLowerCase());
      final idMatches = company.companyId.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesSearch = _searchQuery.isEmpty || nameMatches || idMatches;

      // 2. Status Filter
      final matchesStatus = _statusFilter == 'All' || 
          company.status.toLowerCase().trim() == _statusFilter.toLowerCase().trim();

      // 3. Subscription Filter
      final matchesSubscription = _subscriptionFilter == 'All' || 
          company.subscriptionPlan.toLowerCase().trim() == _subscriptionFilter.toLowerCase().trim();

      return matchesSearch && matchesStatus && matchesSubscription;
    }).toList();
  }
}
