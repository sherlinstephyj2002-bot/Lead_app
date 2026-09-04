import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/providers/permissions_provider.dart';
import '../../../constants/user_roles.dart';
import '../../../shared/utils/app_notification.dart';
import '../../../shared/services/app_error_handler.dart';

class QuickActionsSheet extends ConsumerStatefulWidget {
  const QuickActionsSheet({super.key});

  @override
  ConsumerState<QuickActionsSheet> createState() => _QuickActionsSheetState();
}

class _QuickActionsSheetState extends ConsumerState<QuickActionsSheet> {
  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final isAdmin = user?.role == UserRoles.companyAdmin;
    final permService = ref.watch(permissionServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? Theme.of(context).cardColor : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final subtitleColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final maxHeight = MediaQuery.of(context).size.height * 0.85;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.only(top: 10, bottom: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: Icon(Icons.close, color: subtitleColor),
                  onPressed: () => Navigator.pop(context),
                ),
                Column(
                  children: [
                    Text(
                      'Quick Actions',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: titleColor),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'What would you like to do?',
                      style: TextStyle(fontSize: 13, color: subtitleColor),
                    ),
                  ],
                ),
                const SizedBox(width: 48),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Scrollable Content
          Flexible(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Grid actions (4x2)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      childAspectRatio: 2.3,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      children: [
                        if (UserRoles.canAccessLeads(user?.role))
                          _buildGridItem(
                            context,
                            icon: Icons.person_add_alt_1_rounded,
                            color: const Color(0xFF818CF8),
                            title: 'Add Lead',
                            subtitle: 'Add a new lead\nto your pipeline',
                            onTap: () {
                              final navigator = Navigator.of(context);
                              navigator.pop();
                              navigator.context.push('/lead-form');
                            },
                          )
                        else
                          _buildGridItem(
                            context,
                            icon: Icons.person_add_rounded,
                            color: const Color(0xFF818CF8),
                            title: 'Add Employee',
                            subtitle: 'Add employee to\nyour company',
                            onTap: () {
                              final navigator = Navigator.of(context);
                              navigator.pop();
                              navigator.context.push('/company-admin/employees');
                            },
                          ),
                        if (permService.hasPermission('order_create') || permService.hasPermission('order.create'))
                          _buildGridItem(
                            context,
                            icon: Icons.assignment_turned_in_rounded,
                            color: const Color(0xFF34D399),
                            title: 'Create Order',
                            subtitle: 'Create a new order\nfor a customer',
                            onTap: () {
                              final navigator = Navigator.of(context);
                              navigator.pop();
                              navigator.context.push('/order-form');
                            },
                          ),
                        _buildGridItem(
                          context,
                          icon: UserRoles.allowsPersonalAttendance(user?.role)
                              ? Icons.calendar_today_rounded
                              : Icons.fingerprint_rounded,
                          color: const Color(0xFF60A5FA),
                          title: UserRoles.allowsPersonalAttendance(user?.role)
                              ? 'Mark Attendance'
                              : 'Attendance Logs',
                          subtitle: UserRoles.allowsPersonalAttendance(user?.role)
                              ? 'Check in or\ncheck out'
                              : 'View company\nattendance logs',
                          onTap: () {
                            final navigator = Navigator.of(context);
                            navigator.pop();
                            if (UserRoles.allowsPersonalAttendance(user?.role)) {
                              navigator.context.push('/attendance');
                            } else {
                              navigator.context.push('/reports?tab=2');
                            }
                          },
                        ),
                        if (UserRoles.canAccessLeads(user?.role))
                          _buildGridItem(
                            context,
                            icon: Icons.notifications_active_rounded,
                            color: const Color(0xFFFBBF24),
                            title: 'Add Follow-up',
                            subtitle: 'Schedule a follow-up\nfor a lead',
                            onTap: () {
                              final navigator = Navigator.of(context);
                              navigator.pop();
                              _showAddFollowupDialog(navigator.context);
                            },
                          )
                        else
                          _buildGridItem(
                            context,
                            icon: Icons.payments_rounded,
                            color: const Color(0xFFFBBF24),
                            title: 'Payroll Summary',
                            subtitle: 'Manage company\npayroll runs',
                            onTap: () {
                              final navigator = Navigator.of(context);
                              navigator.pop();
                              navigator.context.push('/company-admin/payroll');
                            },
                          ),
                        _buildGridItem(
                          context,
                          icon: Icons.checklist_rounded,
                          color: const Color(0xFFF472B6),
                          title: 'Add Task',
                          subtitle: 'Create a new task\nfor yourself or team',
                          onTap: () {
                            final navigator = Navigator.of(context);
                            navigator.pop();
                            _showAddTaskDialog(navigator.context, isAdmin: isAdmin);
                          },
                        ),
                        _buildGridItem(
                          context,
                          icon: Icons.account_balance_wallet_rounded,
                          color: const Color(0xFF2DD4BF),
                          title: 'Add Expense',
                          subtitle: 'Submit a new\nexpense claim',
                          onTap: () {
                            final navigator = Navigator.of(context);
                            navigator.pop();
                            _showAddExpenseDialog(navigator.context);
                          },
                        ),
                        _buildGridItem(
                          context,
                          icon: Icons.note_add_rounded,
                          color: const Color(0xFF34D399),
                          title: 'Add Note',
                          subtitle: 'Add a note or\nupdate on any lead',
                          onTap: () {
                            final navigator = Navigator.of(context);
                            navigator.pop();
                            _showSimpleToast(navigator.context,
                                'Notes can be added directly in Lead details screen.');
                          },
                        ),
                        _buildGridItem(
                          context,
                          icon: Icons.cloud_upload_rounded,
                          color: const Color(0xFF6366F1),
                          title: 'Upload Document',
                          subtitle: 'Upload file or\ndocument',
                          onTap: () {
                            final navigator = Navigator.of(context);
                            navigator.pop();
                            _showSimpleToast(
                                navigator.context, 'File upload coming in next release.');
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridItem(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final subtitleColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final circleBg = isDark ? const Color(0xFF334155) : Colors.white;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.15 : 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: isDark ? 0.3 : 0.15), width: 1),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: circleBg,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: color.withValues(alpha: 0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2)),
                ],
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: titleColor),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 9,
                        color: subtitleColor,
                        height: 1.1),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSimpleToast(BuildContext context, String message) {
    AppNotification.showInfo(context, message);
  }

  void _showAddFollowupDialog(BuildContext context) {
    final leads = ref.read(leadsProvider).value ?? [];
    final activeLeads = leads.where((l) => l.status != 'Converted' && l.status != 'Closed').toList();

    String? selectedLeadId = activeLeads.isNotEmpty ? activeLeads.first.leadId : null;
    DateTime selectedDate = DateTime.now();
    TimeOfDay selectedTime = TimeOfDay.now();
    final remarksController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    if (activeLeads.isEmpty) {
      _showSimpleToast(context, 'No active leads available to schedule a follow-up.');
      return;
    }

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (stContext, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Schedule Follow-up'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Select Client Lead *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF64748B))),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: selectedLeadId,
                    decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                    items: activeLeads.map((l) => DropdownMenuItem(
                      value: l.leadId,
                      child: Text('${l.customerName} (${l.requirement})'),
                    )).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => selectedLeadId = val);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Select Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF64748B))),
                            const SizedBox(height: 6),
                            OutlinedButton.icon(
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: selectedDate,
                                  firstDate: DateTime.now().subtract(const Duration(days: 1)),
                                  lastDate: DateTime.now().add(const Duration(days: 365)),
                                );
                                if (picked != null) {
                                  setDialogState(() => selectedDate = picked);
                                }
                              },
                              icon: const Icon(Icons.calendar_today_rounded, size: 16),
                              label: Text(DateFormat('dd MMM').format(selectedDate)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Select Time', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF64748B))),
                            const SizedBox(height: 6),
                            OutlinedButton.icon(
                              onPressed: () async {
                                final picked = await showTimePicker(
                                  context: context,
                                  initialTime: selectedTime,
                                );
                                if (picked != null) {
                                  setDialogState(() => selectedTime = picked);
                                }
                              },
                              icon: const Icon(Icons.access_time_rounded, size: 16),
                              label: Text(selectedTime.format(context)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('Follow-up Notes *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF64748B))),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: remarksController,
                    maxLines: 2,
                    decoration: const InputDecoration(hintText: 'Call to confirm details...'),
                    validator: (val) => val == null || val.trim().isEmpty ? 'Please enter notes' : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isSaving ? null : () async {
                if (!formKey.currentState!.validate() || selectedLeadId == null) return;
                setDialogState(() => isSaving = true);
                try {
                  final followUpDateTime = DateTime(
                    selectedDate.year,
                    selectedDate.month,
                    selectedDate.day,
                    selectedTime.hour,
                    selectedTime.minute,
                  );

                  await ref.read(followupsProvider.notifier).addFollowup(
                    selectedLeadId!,
                    followUpDateTime,
                    remarksController.text.trim(),
                  );

                  if (dialogCtx.mounted) {
                    Navigator.pop(dialogCtx);
                  }
                  if (context.mounted) {
                    AppNotification.showSuccess(context, 'Follow-up scheduled successfully.');
                  }
                } catch (e, stackTrace) {
                  debugPrint('Follow-up Error: $e');
                  debugPrint(stackTrace.toString());
                  if (context.mounted) {
                    AppNotification.showError(context, AppErrorHandler.parseError(e));
                  }
                } finally {
                  if (dialogCtx.mounted) {
                    setDialogState(() => isSaving = false);
                  }
                }
              },
              child: isSaving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Schedule'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddTaskDialog(BuildContext context, {required bool isAdmin}) {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    DateTime selectedDue = DateTime.now().add(const Duration(days: 1));
    bool isLoading = false;

    final user = ref.read(authProvider).user;
    String selectedEmpId = user?.uid ?? '';
    String selectedEmpName = user?.name ?? '';

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Add Task'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(
                        labelText: 'Task Title *',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ref.watch(companyEmployeesProvider).when(
                      data: (employees) {
                        final currentUser = ref.watch(authProvider).user;
                        final allAssignees = [
                          if (currentUser != null) currentUser,
                          ...employees,
                        ];
                        final uniqueAssignees = {for (var e in allAssignees) e.uid: e}.values.toList();
                        
                        if (selectedEmpId.isEmpty && uniqueAssignees.isNotEmpty) {
                          selectedEmpId = uniqueAssignees.first.uid;
                          selectedEmpName = uniqueAssignees.first.name;
                        }

                        return DropdownButtonFormField<String>(
                          value: selectedEmpId.isEmpty ? null : selectedEmpId,
                          decoration: InputDecoration(
                            labelText: 'Assign To *',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          items: uniqueAssignees.map((emp) => DropdownMenuItem(
                            value: emp.uid,
                            child: Text(emp.uid == currentUser?.uid ? '${emp.name} (You)' : emp.name),
                          )).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              final selected = uniqueAssignees.firstWhere((e) => e.uid == val);
                              setDialogState(() {
                                selectedEmpId = selected.uid;
                                selectedEmpName = selected.name;
                              });
                            }
                          },
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (err, _) => Text('Error loading employees: $err', style: const TextStyle(color: Colors.red)),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: selectedDue,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          setDialogState(() => selectedDue = picked);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFF64748B)),
                            const SizedBox(width: 8),
                            Text(
                              'Due: ${selectedDue.day}/${selectedDue.month}/${selectedDue.year}',
                              style: const TextStyle(color: Color(0xFF1E293B), fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          if (titleController.text.trim().isEmpty) return;
                          setDialogState(() => isLoading = true);

                          await ref.read(tasksProvider.notifier).addTask(
                                titleController.text.trim(),
                                descController.text.trim(),
                                selectedDue,
                                selectedEmpName,
                                selectedEmpId,
                              );

                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                          }
                          if (context.mounted) {
                            _showSimpleToast(context,
                                'Task "${titleController.text.trim()}" added successfully.');
                          }
                        },
                  child: isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Add Task'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddExpenseDialog(BuildContext context) {
    final amountController = TextEditingController();
    final descController = TextEditingController();
    String selectedCategory = 'Travel';
    const categories = ['Travel', 'Food', 'Material', 'Others'];
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: const Text('Add Expense'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Amount (₹)',
                        prefixText: '₹ ',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedCategory,
                      decoration: InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      items: categories
                          .map((c) =>
                              DropdownMenuItem(value: c, child: Text(c)))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setDialogState(() => selectedCategory = v);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          final amountText = amountController.text.trim();
                          final amount = double.tryParse(amountText);
                          if (amount == null || amount <= 0) return;

                          setDialogState(() => isLoading = true);

                          await ref.read(expensesProvider.notifier).addExpense(
                                amount,
                                selectedCategory,
                                descController.text.trim(),
                              );

                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                          }
                          if (context.mounted) {
                            _showSimpleToast(context,
                                'Expense of ₹$amountText submitted for approval.');
                          }
                        },
                  child: isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Submit'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
