import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../shared/models/expense_model.dart';
import '../../../shared/providers/providers.dart';
import 'expense_form_screen.dart';
import '../../../constants/user_roles.dart';

class ExpenseDetailScreen extends ConsumerWidget {
  final ExpenseModel expense;

  const ExpenseDetailScreen({
    super.key,
    required this.expense,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final isAdmin = user?.role == UserRoles.companyAdmin;
    final isOwner = expense.employeeId == user?.uid;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final subtitleColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final cardBgColor = isDark ? Theme.of(context).cardColor : const Color(0xFFF8FAFC);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    Color badgeColor;
    Color textColor;
    IconData statusIcon;

    switch (expense.status) {
      case 'Approved':
        badgeColor = isDark ? const Color(0xFF14532D) : const Color(0xFFDCFCE7);
        textColor = isDark ? const Color(0xFF86EFAC) : const Color(0xFF15803D);
        statusIcon = Icons.check_circle_rounded;
        break;
      case 'Rejected':
        badgeColor = isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFEF2F2);
        textColor = isDark ? const Color(0xFFFCA5A5) : const Color(0xFFEF4444);
        statusIcon = Icons.cancel_rounded;
        break;
      default:
        badgeColor = isDark ? const Color(0xFF7C2D12) : const Color(0xFFFFF7ED);
        textColor = isDark ? const Color(0xFFFDBA74) : const Color(0xFFC2410C);
        statusIcon = Icons.pending_actions_rounded;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense Details'),
        actions: [
          if (isOwner && expense.status == 'Pending')
            PopupMenuButton(
              itemBuilder: (context) => [
                PopupMenuItem(
                  child: const Text('Edit'),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (ctx) => ExpenseFormScreen(
                          expenseToEdit: expense,
                        ),
                      ),
                    );
                  },
                ),
                PopupMenuItem(
                  child: const Text('Delete'),
                  onTap: () => _showDeleteConfirmation(context, ref),
                ),
              ],
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: badgeColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: textColor.withAlpha(51)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(statusIcon, color: textColor, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Status',
                              style: TextStyle(
                                fontSize: 12,
                                color: textColor.withAlpha(179),
                              ),
                            ),
                            Text(
                              expense.status,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Amount
            Text(
              'Amount',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: subtitleColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '₹${NumberFormat('#,##,###.##').format(expense.amount)}',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: titleColor,
              ),
            ),

            const SizedBox(height: 20),

            // Category
            Text(
              'Category',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: subtitleColor,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: cardBgColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: [
                  _getCategoryIcon(expense.category),
                  const SizedBox(width: 8),
                  Text(
                    expense.category,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: titleColor,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Description
            if (expense.description.isNotEmpty) ...[
              Text(
                'Description',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: subtitleColor,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cardBgColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: borderColor),
                ),
                child: Text(
                  expense.description,
                  style: TextStyle(
                    fontSize: 14,
                    color: subtitleColor,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Employee
            Text(
              'Submitted By',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: subtitleColor,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: cardBgColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.person_outline_rounded,
                    size: 16,
                    color: subtitleColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    expense.employeeName,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: titleColor,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Created date
            Text(
              'Submitted',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: subtitleColor,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: cardBgColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.access_time_rounded,
                    size: 16,
                    color: subtitleColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    DateFormat('dd MMM yyyy, hh:mm a')
                        .format(expense.createdAt),
                    style: TextStyle(
                      fontSize: 14,
                      color: subtitleColor,
                    ),
                  ),
                ],
              ),
            ),

            // Receipt section
            if (expense.receiptUrl != null && expense.receiptUrl!.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                'Receipt',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: subtitleColor,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: borderColor),
                  color: cardBgColor,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: Image.network(
                    expense.receiptUrl!,
                    height: 200,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 200,
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.image_not_supported_rounded,
                          size: 48,
                          color: Color(0xFFCBD5E1),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Admin approval section
            if (isAdmin && expense.status == 'Pending') ...[
              Text(
                'Admin Actions',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Approve Expense?'),
                            content: const Text(
                              'Are you sure you want to approve this expense claim?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                onPressed: () async {
                                  await ref
                                      .read(expensesProvider.notifier)
                                      .updateExpenseStatus(
                                        expense.expenseId,
                                        'Approved',
                                      );
                                  if (context.mounted) {
                                    Navigator.pop(ctx);
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Expense approved successfully!',
                                            ),
                                          ),
                                        );
                                  }
                                },
                                child: const Text('Approve'),
                              ),
                            ],
                          ),
                        );
                      },
                      icon: const Icon(Icons.check_rounded),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                      ),
                      label: const Text('Approve'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Reject Expense?'),
                            content: const Text(
                              'Are you sure you want to reject this expense claim?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                onPressed: () async {
                                  await ref
                                      .read(expensesProvider.notifier)
                                      .updateExpenseStatus(
                                        expense.expenseId,
                                        'Rejected',
                                      );
                                  if (context.mounted) {
                                    Navigator.pop(ctx);
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Expense rejected.',
                                            ),
                                          ),
                                        );
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                ),
                                child: const Text('Reject'),
                              ),
                            ],
                          ),
                        );
                      },
                      icon: const Icon(Icons.close_rounded),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      label: const Text('Reject'),
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

  Icon _getCategoryIcon(String category) {
    switch (category) {
      case 'Travel':
        return const Icon(
          Icons.directions_car_rounded,
          size: 18,
          color: Color(0xFF475569),
        );
      case 'Food':
        return const Icon(
          Icons.restaurant_rounded,
          size: 18,
          color: Color(0xFF475569),
        );
      case 'Material':
        return const Icon(
          Icons.build_rounded,
          size: 18,
          color: Color(0xFF475569),
        );
      default:
        return const Icon(
          Icons.description_rounded,
          size: 18,
          color: Color(0xFF475569),
        );
    }
  }

  void _showDeleteConfirmation(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Expense?'),
        content: const Text(
          'Are you sure you want to delete this expense claim? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await ref.read(expensesProvider.notifier).deleteExpense(expense.expenseId);
                if (context.mounted) {
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Expense deleted successfully!'),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
