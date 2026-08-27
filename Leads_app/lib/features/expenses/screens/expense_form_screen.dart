import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../shared/models/expense_model.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/utils/app_notification.dart';

class ExpenseFormScreen extends ConsumerStatefulWidget {
  final ExpenseModel? expenseToEdit;

  const ExpenseFormScreen({
    super.key,
    this.expenseToEdit,
  });

  @override
  ConsumerState<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ExpenseFormScreenState extends ConsumerState<ExpenseFormScreen> {
  late TextEditingController _amountController;
  late TextEditingController _descController;
  String _selectedCategory = 'Travel';
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;

  final List<String> _categories = [
    'Travel',
    'Food',
    'Material',
    'Others',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.expenseToEdit != null) {
      _amountController = TextEditingController(
        text: widget.expenseToEdit!.amount.toString(),
      );
      _descController = TextEditingController(
        text: widget.expenseToEdit!.description,
      );
      _selectedCategory = widget.expenseToEdit!.category;
      _selectedDate = widget.expenseToEdit!.createdAt;
    } else {
      _amountController = TextEditingController();
      _descController = TextEditingController();
      _selectedDate = DateTime.now();
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).colorScheme.primary,
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.expenseToEdit != null ? 'Edit Expense' : 'Add Expense Claim',
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Amount field
            Text(
              'Amount (₹) *',
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _amountController,
              onChanged: (val) => setState(() {}),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                hintText: 'Enter amount',
                prefixText: '₹ ',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Category dropdown
            Text(
              'Category *',
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              items: _categories
                  .map((cat) => DropdownMenuItem(
                        value: cat,
                        child: Row(
                          children: [
                            _getCategoryIcon(cat),
                            const SizedBox(width: 8),
                            Text(cat),
                          ],
                        ),
                      ))
                  .toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedCategory = val);
                }
              },
            ),

            const SizedBox(height: 16),

            // Expense Date field
            Text(
              'Expense Date *',
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: () => _selectDate(context),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      DateFormat('dd MMM yyyy').format(_selectedDate),
                      style: const TextStyle(fontSize: 15, color: Color(0xFF1E293B)),
                    ),
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Description field
            Text(
              'Description / Notes *',
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _descController,
              onChanged: (val) => setState(() {}),
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Describe your expense...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Submit button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ||
                        _amountController.text.isEmpty ||
                        _descController.text.isEmpty
                    ? null
                    : () async {
                        setState(() => _isLoading = true);
                        try {
                          final amount =
                              double.tryParse(_amountController.text) ?? 0;

                          if (widget.expenseToEdit != null) {
                            await ref.read(expensesProvider.notifier).editExpense(
                              widget.expenseToEdit!.expenseId,
                              amount,
                              _selectedCategory,
                              _descController.text.trim(),
                              expenseDate: _selectedDate,
                            );

                            if (context.mounted) {
                              Navigator.pop(context);
                              AppNotification.showSuccess(
                                context,
                                'Expense claim updated successfully!',
                              );
                            }
                          } else {
                            await ref.read(expensesProvider.notifier).addExpense(
                              amount,
                              _selectedCategory,
                              _descController.text.trim(),
                              expenseDate: _selectedDate,
                            );

                            if (context.mounted) {
                              Navigator.pop(context);
                              AppNotification.showSuccess(
                                context,
                                'Expense claim submitted successfully!',
                              );
                            }
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e')),
                            );
                          }
                        } finally {
                          if (mounted) {
                            setState(() => _isLoading = false);
                          }
                        }
                      },
                child: _isLoading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Text(widget.expenseToEdit != null
                        ? 'Update Expense'
                        : 'Submit Claim'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Icon _getCategoryIcon(String category) {
    switch (category) {
      case 'Travel':
        return const Icon(Icons.directions_car_rounded, size: 18);
      case 'Food':
        return const Icon(Icons.restaurant_rounded, size: 18);
      case 'Material':
        return const Icon(Icons.build_rounded, size: 18);
      default:
        return const Icon(Icons.description_rounded, size: 18);
    }
  }
}
