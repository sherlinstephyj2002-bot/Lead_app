import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/providers/providers.dart';
import '../models/salary_payslip_model.dart';
import '../repositories/salary_payslip_repository.dart';

final salaryPayslipRepositoryProvider = Provider<SalaryPayslipRepository>((ref) {
  return SalaryPayslipRepository(firestore: ref.watch(firestoreProvider));
});

class SalaryPayslipState {
  final List<SalaryPayslipModel> payslips;
  final bool isLoading;
  final String? error;

  SalaryPayslipState({
    required this.payslips,
    this.isLoading = false,
    this.error,
  });

  SalaryPayslipState copyWith({
    List<SalaryPayslipModel>? payslips,
    bool? isLoading,
    String? error,
  }) {
    return SalaryPayslipState(
      payslips: payslips ?? this.payslips,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

class SalaryPayslipNotifier extends StateNotifier<SalaryPayslipState> {
  final SalaryPayslipRepository _repo;
  final Ref _ref;

  SalaryPayslipNotifier(this._repo, this._ref)
      : super(SalaryPayslipState(payslips: []));

  Future<void> loadPayslips({int? month, int? year, String? employeeId, String? status}) async {
    final user = _ref.read(authProvider).user;
    if (user == null) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final list = await _repo.getPayslips(
        user.companyId,
        month: month,
        year: year,
        employeeId: employeeId,
        status: status,
      );
      state = state.copyWith(payslips: list, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> generatePayslip(SalaryPayslipModel payslip) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repo.savePayslip(payslip);
      await loadPayslips();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> savePayslip(SalaryPayslipModel payslip) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repo.savePayslip(payslip);
      await loadPayslips();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> deletePayslip(String payslipId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repo.deletePayslip(payslipId);
      await loadPayslips();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<List<SalaryPayslipModel>> getEmployeePayslips(String employeeId) async {
    final user = _ref.read(authProvider).user;
    if (user == null) return [];
    try {
      return await _repo.getEmployeePayslips(user.companyId, employeeId);
    } catch (e) {
      return [];
    }
  }
}

final salaryPayslipProvider =
    StateNotifierProvider<SalaryPayslipNotifier, SalaryPayslipState>((ref) {
  final repo = ref.watch(salaryPayslipRepositoryProvider);
  return SalaryPayslipNotifier(repo, ref);
});

final adminSalaryPayslipProvider = salaryPayslipProvider;
