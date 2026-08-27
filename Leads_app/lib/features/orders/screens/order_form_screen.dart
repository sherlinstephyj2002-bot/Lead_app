import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/models/lead_model.dart';
import '../../../shared/models/order_model.dart';
import '../../../shared/models/user_model.dart';
import '../../../shared/utils/app_notification.dart';

class OrderFormScreen extends ConsumerStatefulWidget {
  final LeadModel? wonLead;
  final OrderModel? orderToEdit;

  const OrderFormScreen({super.key, this.wonLead, this.orderToEdit});

  @override
  ConsumerState<OrderFormScreen> createState() => _OrderFormScreenState();
}

class _OrderFormScreenState extends ConsumerState<OrderFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _customerController;
  late TextEditingController _projectController;
  late TextEditingController _amountController;
  DateTime _expectedCompletion = DateTime.now().add(const Duration(days: 7));
  
  String _selectedEngineer = '';
  String _selectedEngineerId = '';

  @override
  void initState() {
    super.initState();
    if (widget.orderToEdit != null) {
      _customerController = TextEditingController(text: widget.orderToEdit!.customerName);
      _projectController = TextEditingController(text: widget.orderToEdit!.projectName);
      _amountController = TextEditingController(text: widget.orderToEdit!.amount > 0 ? widget.orderToEdit!.amount.toString() : '');
      _expectedCompletion = widget.orderToEdit!.expectedCompletion;
      _selectedEngineer = widget.orderToEdit!.assignedEngineer;
      _selectedEngineerId = widget.orderToEdit!.assignedEngineerId;
    } else {
      _customerController = TextEditingController(text: widget.wonLead?.customerName ?? '');
      _projectController = TextEditingController(text: widget.wonLead?.requirement ?? '');
      _amountController = TextEditingController();
      
      if (widget.wonLead != null) {
        _selectedEngineer = widget.wonLead!.assignedTo;
        _selectedEngineerId = widget.wonLead!.assignedToId;
      } else {
        final user = ref.read(authProvider).user;
        _selectedEngineer = user?.name ?? '';
        _selectedEngineerId = user?.uid ?? '';
      }
    }
  }

  @override
  void dispose() {
    _customerController.dispose();
    _projectController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      final amount = double.tryParse(_amountController.text) ?? 0.0;
      
      if (widget.orderToEdit != null) {
        // Editing an existing order
        final updatedOrder = widget.orderToEdit!.copyWith(
          customerName: _customerController.text.trim(),
          projectName: _projectController.text.trim(),
          amount: amount,
          expectedCompletion: _expectedCompletion,
          assignedEngineer: _selectedEngineer,
          assignedEngineerId: _selectedEngineerId,
          updatedAt: DateTime.now(),
        );
        await ref.read(ordersProvider.notifier).updateOrder(updatedOrder);
        if (mounted) {
          context.pop();
          AppNotification.showSuccess(context, 'Order updated successfully');
        }
      } else if (widget.wonLead != null) {
        // Converting a Lead to an Order
        await ref.read(ordersProvider.notifier).convertLeadToOrder(
          widget.wonLead!,
          amount,
          _expectedCompletion,
        );
        if (mounted) {
          context.pop(); // Pop form
          context.pop(); // Pop lead details screen back to leads list
          AppNotification.showSuccess(context, 'Lead converted to Order successfully');
        }
      } else {
        // Creating a standalone order
        final user = ref.read(authProvider).user;
        if (user == null) return;

        final newOrder = OrderModel(
          orderId: 'ORD-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}',
          leadId: null,
          companyId: user.companyId,
          customerName: _customerController.text.trim(),
          projectName: _projectController.text.trim(),
          amount: amount,
          status: 'Confirmed',
          expectedCompletion: _expectedCompletion,
          assignedEngineer: _selectedEngineer,
          assignedEngineerId: _selectedEngineerId,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await ref.read(ordersProvider.notifier).createOrder(newOrder);
        if (mounted) {
          context.pop();
          AppNotification.showSuccess(context, 'Order saved successfully');
        }
      }
    }
  }

  InputDecoration _buildStitchInputDecoration({
    required String hint,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fillBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderCol = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: fillBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: borderCol),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: borderCol),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
        borderSide: BorderSide(color: Color(0xFF5B4CF0), width: 2),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFEF4444)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFEF4444), width: 2),
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labelColor = isDark ? Colors.white : const Color(0xFF334155);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: RichText(
        text: TextSpan(
          text: label,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: labelColor, fontFamily: 'Outfit'),
          children: const [
            TextSpan(text: ' *', style: TextStyle(color: Color(0xFF5B4CF0), fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isConversion = widget.wonLead != null;
    final currentUser = ref.watch(authProvider).user;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? Theme.of(context).scaffoldBackgroundColor : const Color(0xFFF7F9FB);
    final cardBg = isDark ? Theme.of(context).cardColor : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final borderCol = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: cardBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: borderCol),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: titleColor),
          onPressed: () => context.pop(),
        ),
        title: Text(
          isConversion ? 'Convert to Order' : 'New Order',
          style: TextStyle(color: titleColor, fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              children: [
                if (isConversion)
                  Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E3A8A) : const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isDark ? const Color(0xFF2563EB) : const Color(0xFFBFDBFE)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline_rounded, color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF2563EB)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'You are converting the won lead for "${widget.wonLead!.customerName}" into a trackable order.',
                            style: TextStyle(color: isDark ? const Color(0xFFBFDBFE) : const Color(0xFF1E40AF), fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Main Form Card Container
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderCol),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x08000000),
                        blurRadius: 16,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Customer Name Field
                        _buildFieldLabel('Customer Name'),
                        TextFormField(
                          controller: _customerController,
                          enabled: !isConversion,
                          decoration: _buildStitchInputDecoration(
                            hint: 'Enter customer name',
                            prefixIcon: const Icon(Icons.person_outline_rounded, color: Color(0xFF94A3B8), size: 20),
                          ),
                          validator: (val) => val == null || val.trim().isEmpty ? 'Please enter customer name' : null,
                        ),
                        const SizedBox(height: 20),

                        // Project Name Field
                        _buildFieldLabel('Project / Order Name'),
                        TextFormField(
                          controller: _projectController,
                          enabled: !isConversion,
                          decoration: _buildStitchInputDecoration(
                            hint: 'e.g. Multiplex Audio Upgrade',
                            prefixIcon: const Icon(Icons.work_outline_rounded, color: Color(0xFF94A3B8), size: 20),
                          ),
                          validator: (val) => val == null || val.trim().isEmpty ? 'Please specify project name' : null,
                        ),
                        const SizedBox(height: 20),

                        // Order Amount Field (₹)
                        _buildFieldLabel('Order Amount (₹)'),
                        TextFormField(
                          controller: _amountController,
                          keyboardType: TextInputType.number,
                          decoration: _buildStitchInputDecoration(
                            hint: 'Enter deal value (e.g. 245000)',
                            prefixIcon: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              child: Text('₹', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                            ),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) return 'Please enter order amount';
                            if (double.tryParse(val.trim()) == null) return 'Please enter a valid number';
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),

                        // Layout for Date and Engineer Assignment
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final isWide = constraints.maxWidth > 550;
                            return Column(
                              children: [
                                if (isWide) ...[
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Completion Date
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            _buildFieldLabel('Expected Completion Date'),
                                            InkWell(
                                              onTap: () async {
                                                final date = await showDatePicker(
                                                  context: context,
                                                  initialDate: _expectedCompletion,
                                                  firstDate: DateTime.now(),
                                                  lastDate: DateTime.now().add(const Duration(days: 365)),
                                                );
                                                if (date != null) {
                                                  setState(() => _expectedCompletion = date);
                                                }
                                              },
                                              child: IgnorePointer(
                                                child: TextFormField(
                                                  controller: TextEditingController(
                                                    text: DateFormat('dd MMMM yyyy').format(_expectedCompletion),
                                                  ),
                                                  decoration: _buildStitchInputDecoration(
                                                    hint: 'Select Date',
                                                    prefixIcon: const Icon(Icons.calendar_month_rounded, color: Color(0xFF94A3B8), size: 20),
                                                    suffixIcon: const Icon(Icons.calendar_today_rounded, color: Color(0xFF94A3B8), size: 18),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      // Engineer Assignment
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            _buildFieldLabel('Assign Project Engineer'),
                                            ref.watch(companyEmployeesProvider).when(
                                              data: (employees) {
                                                final allAssignees = [currentUser, ...employees].whereType<UserModel>().toList();
                                                final uniqueAssignees = {for (var e in allAssignees) e.uid: e}.values.toList();

                                                if (!uniqueAssignees.any((e) => e.uid == _selectedEngineerId)) {
                                                  final firstAssignee = uniqueAssignees.isNotEmpty ? uniqueAssignees.first : null;
                                                  _selectedEngineerId = firstAssignee?.uid ?? '';
                                                  _selectedEngineer = firstAssignee?.name ?? '';
                                                }

                                                return DropdownButtonFormField<String>(
                                                  value: _selectedEngineerId.isEmpty && uniqueAssignees.isNotEmpty ? uniqueAssignees.first.uid : _selectedEngineerId,
                                                  decoration: _buildStitchInputDecoration(
                                                    hint: 'Select engineer',
                                                    prefixIcon: const Icon(Icons.engineering_rounded, color: Color(0xFF94A3B8), size: 20),
                                                  ),
                                                  isExpanded: true,
                                                  items: uniqueAssignees.map((emp) => DropdownMenuItem(
                                                    value: emp.uid,
                                                    child: Text(
                                                      emp.uid == currentUser?.uid ? '${emp.name} (You)' : emp.name,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  )).toList(),
                                                  onChanged: (val) {
                                                    if (val != null) {
                                                      final selected = uniqueAssignees.firstWhere((e) => e.uid == val);
                                                      setState(() {
                                                        _selectedEngineerId = selected.uid;
                                                        _selectedEngineer = selected.name;
                                                      });
                                                    }
                                                  },
                                                );
                                              },
                                              loading: () => const Center(child: CircularProgressIndicator()),
                                              error: (err, _) => Text('Error: $err', style: const TextStyle(color: Colors.red)),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ] else ...[
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildFieldLabel('Expected Completion Date'),
                                      InkWell(
                                        onTap: () async {
                                          final date = await showDatePicker(
                                            context: context,
                                            initialDate: _expectedCompletion,
                                            firstDate: DateTime.now(),
                                            lastDate: DateTime.now().add(const Duration(days: 365)),
                                          );
                                          if (date != null) {
                                            setState(() => _expectedCompletion = date);
                                          }
                                        },
                                        child: IgnorePointer(
                                          child: TextFormField(
                                            controller: TextEditingController(
                                              text: DateFormat('dd MMMM yyyy').format(_expectedCompletion),
                                            ),
                                            decoration: _buildStitchInputDecoration(
                                              hint: 'Select Date',
                                              prefixIcon: const Icon(Icons.calendar_month_rounded, color: Color(0xFF94A3B8), size: 20),
                                              suffixIcon: const Icon(Icons.calendar_today_rounded, color: Color(0xFF94A3B8), size: 18),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 20),
                                      _buildFieldLabel('Assign Project Engineer'),
                                      ref.watch(companyEmployeesProvider).when(
                                        data: (employees) {
                                          final allAssignees = [currentUser, ...employees].whereType<UserModel>().toList();
                                          final uniqueAssignees = {for (var e in allAssignees) e.uid: e}.values.toList();

                                          if (!uniqueAssignees.any((e) => e.uid == _selectedEngineerId)) {
                                            final firstAssignee = uniqueAssignees.isNotEmpty ? uniqueAssignees.first : null;
                                            _selectedEngineerId = firstAssignee?.uid ?? '';
                                            _selectedEngineer = firstAssignee?.name ?? '';
                                          }

                                          return DropdownButtonFormField<String>(
                                            value: _selectedEngineerId.isEmpty && uniqueAssignees.isNotEmpty ? uniqueAssignees.first.uid : _selectedEngineerId,
                                            decoration: _buildStitchInputDecoration(
                                              hint: 'Select engineer',
                                              prefixIcon: const Icon(Icons.engineering_rounded, color: Color(0xFF94A3B8), size: 20),
                                            ),
                                            isExpanded: true,
                                            items: uniqueAssignees.map((emp) => DropdownMenuItem(
                                              value: emp.uid,
                                              child: Text(
                                                emp.uid == currentUser?.uid ? '${emp.name} (You)' : emp.name,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            )).toList(),
                                            onChanged: (val) {
                                              if (val != null) {
                                                final selected = uniqueAssignees.firstWhere((e) => e.uid == val);
                                                setState(() {
                                                  _selectedEngineerId = selected.uid;
                                                  _selectedEngineer = selected.name;
                                                });
                                              }
                                            },
                                          );
                                        },
                                        loading: () => const Center(child: CircularProgressIndicator()),
                                        error: (err, _) => Text('Error: $err', style: const TextStyle(color: Colors.red)),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            );
                          },
                        ),

                        const SizedBox(height: 32),
                        const Divider(height: 1, color: Color(0xFFF1F5F9)),
                        const SizedBox(height: 24),

                        // Form Actions
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton(
                              onPressed: () => context.pop(),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF64748B),
                                side: const BorderSide(color: Color(0xFFCBD5E1)),
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600, fontFamily: 'Outfit')),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              onPressed: _submitForm,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF5B4CF0),
                                foregroundColor: Colors.white,
                                elevation: 4,
                                shadowColor: const Color(0xFF5B4CF0).withValues(alpha: 0.3),
                                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: Text(
                                isConversion ? 'Confirm Order' : 'Create Order',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
