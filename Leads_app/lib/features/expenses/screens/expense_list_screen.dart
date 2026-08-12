import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/models/expense_model.dart';
import 'expense_detail_screen.dart';
import '../../../constants/user_roles.dart';
import 'expense_form_screen.dart';

class ExpenseListScreen extends ConsumerStatefulWidget {
  const ExpenseListScreen({super.key});

  @override
  ConsumerState<ExpenseListScreen> createState() => _ExpenseListScreenState();
}

class _ExpenseListScreenState extends ConsumerState<ExpenseListScreen> {
  String _selectedFilter = 'All';
  final List<String> _filterChips = ['All', 'Pending', 'Approved', 'Rejected'];
  String _searchQuery = '';
  final _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final expensesState = ref.watch(expensesProvider);
    final user = ref.watch(authProvider).user;
    final isAdmin = user?.role == UserRoles.companyAdmin;

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Search expenses...',
                  hintStyle: TextStyle(color: Colors.white60),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
                onChanged: (val) {
                  setState(() => _searchQuery = val.toLowerCase());
                },
              )
            : const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Expenses', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                  Text('Manage expense claims', style: TextStyle(fontSize: 12, color: Colors.white70)),
                ],
              ),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close_rounded : Icons.search_rounded),
            onPressed: () {
              setState(() {
                if (_isSearching) {
                  _searchQuery = '';
                  _searchController.clear();
                }
                _isSearching = !_isSearching;
              });
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(expensesProvider.notifier).loadExpenses();
        },
        child: expensesState.when(
          data: (expenses) {
            // Role-scoped: employees see only their own
            var visible = isAdmin
                ? expenses
                : expenses.where((e) => e.employeeId == user?.uid).toList();

            if (_selectedFilter != 'All') {
              visible = visible.where((e) => e.status == _selectedFilter).toList();
            }

            if (_searchQuery.isNotEmpty) {
              visible = visible
                  .where((e) =>
                      e.description.toLowerCase().contains(_searchQuery) ||
                      e.category.toLowerCase().contains(_searchQuery) ||
                      e.employeeName.toLowerCase().contains(_searchQuery))
                  .toList();
            }

            // Summary row for admin
            final totalPending = expenses
                .where((e) => e.status == 'Pending')
                .fold<double>(0, (sum, e) => sum + e.amount);

            return Column(
              children: [
                if (isAdmin && totalPending > 0)
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFED7AA)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.pending_actions_rounded, color: Color(0xFFC2410C), size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '${expenses.where((e) => e.status == 'Pending').length} pending claims — Total ₹${NumberFormat('#,##,###.##').format(totalPending)}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFC2410C),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: _filterChips.map((chip) {
                      final isSelected = _selectedFilter == chip;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          selected: isSelected,
                          label: Text(chip),
                          onSelected: (_) => setState(() => _selectedFilter = chip),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                Expanded(
                  child: visible.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                            const Icon(Icons.account_balance_wallet_rounded,
                                size: 60, color: Color(0xFFE2E8F0)),
                            const SizedBox(height: 12),
                            const Center(
                              child: Text('No expense claims found',
                                  style: TextStyle(color: Colors.grey)),
                            ),
                          ],
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          itemCount: visible.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) => GestureDetector(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (ctx) => ExpenseDetailScreen(
                                    expense: visible[index],
                                  ),
                                ),
                              );
                            },
                            child: _buildExpenseCard(
                              context,
                              visible[index],
                              isAdmin,
                            ),
                          ),
                        ),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                Center(child: Text('Error loading expenses: $err')),
              ],
            ),
          ),
        ),
      ),      floatingActionButton: FloatingActionButton.extended(
        heroTag: "expenseFab",
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (ctx) => const ExpenseFormScreen(),
            ),
          );
        },
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Expense'),
      ),    );
  }

  Widget _buildExpenseCard(
      BuildContext context, ExpenseModel expense, bool isAdmin) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Color badgeColor;
    Color textColor;
    IconData categoryIcon;

    switch (expense.status) {
      case 'Approved':
        badgeColor = isDark ? const Color(0xFF14532D) : const Color(0xFFDCFCE7);
        textColor = isDark ? const Color(0xFF86EFAC) : const Color(0xFF15803D);
        break;
      case 'Rejected':
        badgeColor = isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFEF2F2);
        textColor = isDark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C);
        break;
      default:
        badgeColor = isDark ? const Color(0xFF7C2D12) : const Color(0xFFFFF7ED);
        textColor = isDark ? const Color(0xFFFDBA74) : const Color(0xFFC2410C);
    }

    switch (expense.category) {
      case 'Travel':
        categoryIcon = Icons.directions_car_rounded;
        break;
      case 'Food':
        categoryIcon = Icons.restaurant_rounded;
        break;
      case 'Material':
        categoryIcon = Icons.construction_rounded;
        break;
      default:
        categoryIcon = Icons.receipt_long_rounded;
    }

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: isDark ? Theme.of(context).cardColor : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(categoryIcon,
                          size: 18, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          expense.category,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: isDark ? Colors.white : const Color(0xFF1E293B),
                          ),
                        ),
                        Text(
                          expense.employeeName,
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹${NumberFormat('#,##,###.##').format(expense.amount)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      padding:
                          const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                          color: badgeColor,
                          borderRadius: BorderRadius.circular(6)),
                      child: Text(
                        expense.status,
                        style: TextStyle(
                            color: textColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (expense.description.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.notes_rounded,
                      size: 14, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      expense.description,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.calendar_today_rounded,
                    size: 12, color: Color(0xFF94A3B8)),
                const SizedBox(width: 4),
                Text(
                  DateFormat('dd MMM yyyy').format(expense.createdAt),
                  style: const TextStyle(
                      fontSize: 11, color: Color(0xFF94A3B8)),
                ),
              ],
            ),

            // Admin approve/reject buttons on Pending expenses
            if (isAdmin && expense.status == 'Pending') ...[
              const Divider(height: 20, color: Color(0xFFF1F5F9)),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await ref
                            .read(expensesProvider.notifier)
                            .updateExpenseStatus(expense.expenseId, 'Approved');
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Expense approved.')),
                          );
                        }
                      },
                      icon: const Icon(Icons.check_rounded, size: 14),
                      label: const Text('Approve'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF10B981),
                        side: const BorderSide(color: Color(0xFF10B981)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await ref
                            .read(expensesProvider.notifier)
                            .updateExpenseStatus(expense.expenseId, 'Rejected');
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Expense rejected.')),
                          );
                        }
                      },
                      icon: const Icon(Icons.close_rounded, size: 14),
                      label: const Text('Reject'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFEF4444),
                        side: const BorderSide(color: Color(0xFFEF4444)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
