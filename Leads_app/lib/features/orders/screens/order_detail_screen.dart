import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/providers/permissions_provider.dart';
import '../../../shared/models/order_model.dart';
import '../../../shared/models/expense_model.dart';
import '../../../shared/models/task_model.dart';
import '../../../shared/models/user_model.dart';
import '../../../shared/services/pdf_service.dart';
import '../../../shared/services/file_download_service.dart';

class OrderDetailScreen extends ConsumerStatefulWidget {
  final String orderId;
  final OrderModel? initialOrder;

  const OrderDetailScreen({super.key, required this.orderId, this.initialOrder});

  @override
  ConsumerState<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends ConsumerState<OrderDetailScreen> {
  late OrderModel _order;
  bool _isLoaded = false;
  List<Map<String, dynamic>> _orderActivities = [];

  @override
  void initState() {
    super.initState();
    if (widget.initialOrder != null) {
      _order = widget.initialOrder!;
      _isLoaded = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadOrderActivities();
      });
    }
  }

  Future<void> _loadOrderActivities() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('orderActivities')
          .where('orderId', isEqualTo: _order.orderId)
          .get();
      if (!mounted) return;
      final list = snap.docs.map((d) => d.data()).toList();
      list.sort((a, b) {
        final aTime = (a['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        final bTime = (b['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        return bTime.compareTo(aTime);
      });
      setState(() {
        _orderActivities = list;
      });
    } catch (e) {
      debugPrint('Error loading order activities: $e');
    }
  }

  Future<void> _fetchOrderDetails() async {
    var orders = ref.read(ordersProvider).value;
    if (orders == null) {
      await ref.read(ordersProvider.notifier).loadOrders();
      orders = ref.read(ordersProvider).value;
    }

    if (orders != null) {
      try {
        final found = orders.firstWhere((o) => o.orderId == widget.orderId);
        if (!mounted) return;
        setState(() {
          _order = found;
          _isLoaded = true;
        });
        await _loadOrderActivities();
      } catch (_) {}
    }
  }

  void _updateStatus(String status) async {
    final permService = ref.read(permissionServiceProvider);
    if (status == 'Closed' || status == 'Delivered' || status == 'Completed') {
      if (!permService.hasPermission('order_close') && !permService.hasPermission('order.close')) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Access Denied: You do not have permission to close orders.', style: TextStyle(fontFamily: 'Outfit')), backgroundColor: Colors.red),
        );
        return;
      }
    } else if (status == 'Cancelled') {
      if (!permService.hasPermission('order_cancel') && !permService.hasPermission('order.cancel')) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Access Denied: You do not have permission to cancel orders.', style: TextStyle(fontFamily: 'Outfit')), backgroundColor: Colors.red),
        );
        return;
      }
    } else {
      if (!permService.hasPermission('order_edit') && !permService.hasPermission('order.edit')) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Access Denied: You do not have permission to edit orders.', style: TextStyle(fontFamily: 'Outfit')), backgroundColor: Colors.red),
        );
        return;
      }
    }

    try {
      await ref.read(ordersProvider.notifier).updateOrderStatus(_order.orderId, status);
      final user = ref.read(authProvider).user;
      if (user != null) {
        final Map<String, dynamic> activity = {
          'activityId': const Uuid().v4(),
          'orderId': _order.orderId,
          'companyId': _order.companyId,
          'activityType': 'Status Change',
          'description': 'Order status changed to $status',
          'performedBy': user.name,
          'performedById': user.uid,
          'createdAt': Timestamp.now(),
        };
        await FirebaseFirestore.instance.collection('orderActivities').doc(activity['activityId']).set(activity);
      }
      if (!mounted) return;
      await _fetchOrderDetails();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Order status updated to $status', style: const TextStyle(fontFamily: 'Outfit')), behavior: SnackBarBehavior.floating),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update status: $e', style: const TextStyle(fontFamily: 'Outfit')), backgroundColor: Colors.red),
      );
    }
  }

  void _deleteOrderDialog() {
    final permService = ref.read(permissionServiceProvider);
    if (!permService.hasPermission('order_delete') && !permService.hasPermission('order.delete')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Access Denied: You do not have permission to delete orders.', style: TextStyle(fontFamily: 'Outfit')), backgroundColor: Colors.red),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Order', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete order ${_order.orderId}? This action cannot be undone.', style: const TextStyle(fontFamily: 'Outfit')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(fontFamily: 'Outfit'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(ordersProvider.notifier).deleteOrder(_order.orderId);
                if (mounted) {
                  context.pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Order ${_order.orderId} deleted.'), behavior: SnackBarBehavior.floating),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete order: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Delete', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _addNoteDialog() {
    final noteController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Add Note', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
        content: TextField(
          controller: noteController,
          maxLines: 3,
          style: const TextStyle(fontFamily: 'Outfit'),
          decoration: const InputDecoration(hintText: 'Enter order note...', hintStyle: TextStyle(color: Color(0xFF94A3B8))),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel', style: TextStyle(fontFamily: 'Outfit'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5B4CF0), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: () async {
              final noteText = noteController.text.trim();
              if (noteText.isNotEmpty) {
                final user = ref.read(authProvider).user;
                if (user == null) return;
                final Map<String, dynamic> activity = {
                  'activityId': const Uuid().v4(),
                  'orderId': _order.orderId,
                  'companyId': _order.companyId,
                  'activityType': 'Note',
                  'description': noteText,
                  'performedBy': user.name,
                  'performedById': user.uid,
                  'createdAt': Timestamp.now(),
                };
                await FirebaseFirestore.instance.collection('orderActivities').doc(activity['activityId']).set(activity);
                if (!mounted) return;
                Navigator.of(context).pop();
                await _loadOrderActivities();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Note saved successfully.'), behavior: SnackBarBehavior.floating),
                );
              }
            },
            child: const Text('Save', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _addDeliveryUpdateDialog() {
    final updateController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Add Delivery Update', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
        content: TextField(
          controller: updateController,
          maxLines: 3,
          style: const TextStyle(fontFamily: 'Outfit'),
          decoration: const InputDecoration(hintText: 'Enter delivery update details (e.g. Dispatched, In transit, Delayed...)', hintStyle: TextStyle(color: Color(0xFF94A3B8))),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel', style: TextStyle(fontFamily: 'Outfit'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5B4CF0), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: () async {
              final updateText = updateController.text.trim();
              if (updateText.isNotEmpty) {
                final user = ref.read(authProvider).user;
                if (user == null) return;
                final Map<String, dynamic> activity = {
                  'activityId': const Uuid().v4(),
                  'orderId': _order.orderId,
                  'companyId': _order.companyId,
                  'activityType': 'Delivery Update',
                  'description': updateText,
                  'performedBy': user.name,
                  'performedById': user.uid,
                  'createdAt': Timestamp.now(),
                };
                await FirebaseFirestore.instance.collection('orderActivities').doc(activity['activityId']).set(activity);
                if (!mounted) return;
                Navigator.of(context).pop();
                await _loadOrderActivities();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Delivery update logged successfully.'), behavior: SnackBarBehavior.floating),
                );
              }
            },
            child: const Text('Save', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _addExpenseDialog() {
    final amountController = TextEditingController();
    final descController = TextEditingController();
    String category = 'Travel';
    String? amountErrorText;
    String? descErrorText;
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Add Expense to Project', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                  style: const TextStyle(fontFamily: 'Outfit'),
                  decoration: InputDecoration(
                    labelText: 'Amount (₹) *',
                    labelStyle: const TextStyle(fontFamily: 'Outfit'),
                    errorText: amountErrorText,
                  ),
                  onChanged: (val) {
                    if (amountErrorText != null) {
                      setDialogState(() => amountErrorText = null);
                    }
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: category,
                  decoration: const InputDecoration(labelText: 'Category', labelStyle: TextStyle(fontFamily: 'Outfit')),
                  items: const [
                    DropdownMenuItem(value: 'Travel', child: Text('Travel')),
                    DropdownMenuItem(value: 'Material', child: Text('Material')),
                    DropdownMenuItem(value: 'Food', child: Text('Food')),
                    DropdownMenuItem(value: 'Others', child: Text('Others')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => category = val);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  style: const TextStyle(fontFamily: 'Outfit'),
                  decoration: InputDecoration(
                    labelText: 'Description *',
                    labelStyle: const TextStyle(fontFamily: 'Outfit'),
                    errorText: descErrorText,
                  ),
                  onChanged: (val) {
                    if (descErrorText != null) {
                      setDialogState(() => descErrorText = null);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancel', style: TextStyle(fontFamily: 'Outfit')),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5B4CF0),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: isLoading
                  ? null
                  : () async {
                      final amountRaw = amountController.text.trim();
                      final desc = descController.text.trim();
                      final amt = double.tryParse(amountRaw);

                      bool hasError = false;
                      if (amountRaw.isEmpty || amt == null || amt <= 0) {
                        setDialogState(() => amountErrorText = 'Please enter a valid amount (> 0)');
                        hasError = true;
                      } else {
                        setDialogState(() => amountErrorText = null);
                      }

                      if (desc.isEmpty) {
                        setDialogState(() => descErrorText = 'Please enter a description');
                        hasError = true;
                      } else {
                        setDialogState(() => descErrorText = null);
                      }

                      if (hasError) return;

                      setDialogState(() => isLoading = true);

                      try {
                        await ref.read(expensesProvider.notifier).addExpense(
                              amt!,
                              category,
                              desc,
                              orderId: _order.orderId,
                            );

                        final user = ref.read(authProvider).user;
                        if (user != null) {
                          final Map<String, dynamic> activity = {
                            'activityId': const Uuid().v4(),
                            'orderId': _order.orderId,
                            'companyId': _order.companyId,
                            'activityType': 'Expense',
                            'description': 'Added $category expense: ₹$amt ($desc)',
                            'performedBy': user.name,
                            'performedById': user.uid,
                            'createdAt': Timestamp.now(),
                          };
                          await FirebaseFirestore.instance
                              .collection('orderActivities')
                              .doc(activity['activityId'])
                              .set(activity);
                        }

                        if (!dialogContext.mounted) return;
                        Navigator.pop(dialogContext);

                        await _loadOrderActivities();

                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Expense logged successfully.', style: TextStyle(fontFamily: 'Outfit')),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      } catch (e) {
                        setDialogState(() => isLoading = false);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to add expense: $e', style: const TextStyle(fontFamily: 'Outfit')),
                            backgroundColor: Colors.red,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Add Expense', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _reassignEngineerDialog() {
    final employeesAsync = ref.read(companyEmployeesProvider);
    final currentUser = ref.read(authProvider).user;

    employeesAsync.whenData((employees) {
      final allAssignees = [currentUser, ...employees].whereType<UserModel>().toList();
      final uniqueAssignees = {for (var e in allAssignees) e.uid: e}.values.toList();
      if (uniqueAssignees.isEmpty) return;

      String selectedUid = _order.assignedEngineerId.isNotEmpty ? _order.assignedEngineerId : uniqueAssignees.first.uid;
      String selectedName = _order.assignedEngineer.isNotEmpty ? _order.assignedEngineer : uniqueAssignees.first.name;

      showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (dialogCtx, setDialogState) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Reassign Engineer', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Select project engineer:', style: TextStyle(fontFamily: 'Outfit', fontSize: 13, color: Color(0xFF64748B))),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedUid,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                  ),
                  items: uniqueAssignees.map((emp) => DropdownMenuItem(
                    value: emp.uid,
                    child: Text(emp.uid == currentUser?.uid ? '${emp.name} (You)' : emp.name),
                  )).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      final emp = uniqueAssignees.firstWhere((e) => e.uid == val);
                      setDialogState(() {
                        selectedUid = emp.uid;
                        selectedName = emp.name;
                      });
                    }
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5B4CF0), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                onPressed: () async {
                  Navigator.pop(ctx);
                  await ref.read(ordersProvider.notifier).reassignOrderEngineer(_order.orderId, selectedUid, selectedName);
                  if (mounted) {
                    _fetchOrderDetails();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Order reassigned to $selectedName.'), behavior: SnackBarBehavior.floating),
                    );
                  }
                },
                child: const Text('Reassign', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      );
    });
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return const Color(0xFF2563EB);
      case 'in progress':
        return const Color(0xFFD97706);
      case 'ready':
        return const Color(0xFF7C3AED);
      case 'delivered':
      case 'completed':
        return const Color(0xFF16A34A);
      case 'cancelled':
      case 'closed':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFF64748B);
    }
  }

  double _getMilestoneProgress(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return 0.25;
      case 'in progress':
        return 0.55;
      case 'ready':
        return 0.85;
      case 'delivered':
      case 'completed':
        return 1.0;
      default:
        return 0.1;
    }
  }

  String _formatCurrency(double amount) {
    final formatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    return formatter.format(amount);
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(expensesProvider);
    if (!_isLoaded) {
      final orders = ref.watch(ordersProvider).value;
      if (orders != null) {
        try {
          _order = orders.firstWhere((o) => o.orderId == widget.orderId);
          _isLoaded = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _loadOrderActivities();
          });
        } catch (_) {}
      }
    }

    if (!_isLoaded) {
      return Scaffold(
        appBar: AppBar(title: const Text('Order Details', style: TextStyle(fontFamily: 'Outfit'))),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final progress = _getMilestoneProgress(_order.status);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBgColor = isDark ? Theme.of(context).cardColor : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtitleColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: isDark ? Theme.of(context).scaffoldBackgroundColor : const Color(0xFFF7F9FB),
      appBar: AppBar(
        backgroundColor: cardBgColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: borderColor),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: titleColor),
          onPressed: () => context.pop(),
        ),
        title: Text(
          _order.orderId,
          style: TextStyle(color: titleColor, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _order.status,
                icon: Icon(Icons.keyboard_arrow_down_rounded, color: subtitleColor),
                selectedItemBuilder: (ctx) {
                  return ['Confirmed', 'In Progress', 'Ready', 'Delivered', 'Cancelled'].map((s) {
                    return Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getStatusColor(_order.status).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _order.status,
                        style: TextStyle(color: _getStatusColor(_order.status), fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
                      ),
                    );
                  }).toList();
                },
                items: const [
                  DropdownMenuItem(value: 'Confirmed', child: Text('Confirmed')),
                  DropdownMenuItem(value: 'In Progress', child: Text('In Progress')),
                  DropdownMenuItem(value: 'Ready', child: Text('Ready')),
                  DropdownMenuItem(value: 'Delivered', child: Text('Delivered')),
                  DropdownMenuItem(value: 'Cancelled', child: Text('Cancelled')),
                ],
                onChanged: (val) {
                  if (val != null) _updateStatus(val);
                },
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined, color: Color(0xFF5B4CF0)),
            tooltip: 'Export PDF Invoice',
            onPressed: () async {
              final expenses = ref.read(expensesProvider).value ?? [];
              final tasks = ref.read(tasksProvider).value ?? [];
              final orderExpenses = expenses.where((e) => e.orderId == _order.orderId).toList();
              final orderTasks = tasks.where((t) => t.orderId == _order.orderId).toList();

              final pdfBytes = await PdfService.generateInvoicePdf(
                order: _order,
                expenses: orderExpenses,
                tasks: orderTasks,
              );
              await FileDownloadService.downloadPdf(pdfBytes: pdfBytes, fileName: 'Invoice_${_order.orderId}.pdf');
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Invoice_${_order.orderId}.pdf downloaded to your Downloads folder.', style: const TextStyle(fontFamily: 'Outfit')),
                  backgroundColor: const Color(0xFF10B981),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              decoration: BoxDecoration(
                color: cardBgColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
                boxShadow: [BoxShadow(color: isDark ? Colors.black26 : const Color(0x05000000), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Project Progress', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: titleColor, fontFamily: 'Outfit')),
                      Text('${(progress * 100).toInt()}% Completed', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFD97706), fontFamily: 'Outfit')),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFD97706)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth > 700) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 5,
                        child: Column(
                          children: [
                            _buildSummaryCard(context),
                            const SizedBox(height: 16),
                            _buildEngineerCard(context),
                            const SizedBox(height: 16),
                            _buildQuickActionsCard(context),
                            const SizedBox(height: 16),
                            _buildOrderExpensesCard(context),
                            const SizedBox(height: 16),
                            _buildOrderDeliveriesCard(context),
                            const SizedBox(height: 16),
                            _buildOrderNotesCard(context),
                          ],
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        flex: 7,
                        child: _buildActivitiesCard(context),
                      ),
                    ],
                  );
                } else {
                  return Column(
                    children: [
                      _buildSummaryCard(context),
                      const SizedBox(height: 16),
                      _buildEngineerCard(context),
                      const SizedBox(height: 16),
                      _buildQuickActionsCard(context),
                      const SizedBox(height: 16),
                      _buildOrderExpensesCard(context),
                      const SizedBox(height: 16),
                      _buildOrderDeliveriesCard(context),
                      const SizedBox(height: 16),
                      _buildOrderNotesCard(context),
                      const SizedBox(height: 24),
                      _buildActivitiesCard(context),
                    ],
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBgColor = isDark ? Theme.of(context).cardColor : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);

    return Container(
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [BoxShadow(color: isDark ? Colors.black26 : const Color(0x05000000), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shopping_bag_outlined, size: 18, color: Color(0xFF5B4CF0)),
              const SizedBox(width: 8),
              Text('Order Details', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: titleColor, fontFamily: 'Outfit')),
            ],
          ),
          Divider(height: 24, color: borderColor),
          _buildInfoRow(context, Icons.work_outline_rounded, 'Project Name', _order.projectName),
          const SizedBox(height: 12),
          _buildInfoRow(context, Icons.person_outline_rounded, 'Customer Name', _order.customerName),
          const SizedBox(height: 12),
          _buildInfoRow(context, Icons.account_balance_wallet_outlined, 'Deal Value', _formatCurrency(_order.amount)),
          const SizedBox(height: 12),
          _buildInfoRow(context, Icons.calendar_month_outlined, 'Expected Completion', DateFormat('dd MMMM yyyy').format(_order.expectedCompletion)),
          const SizedBox(height: 12),
          _buildInfoRow(context, Icons.access_time_rounded, 'Order Placed On', DateFormat('dd MMM yyyy').format(_order.createdAt)),
        ],
      ),
    );
  }

  Widget _buildEngineerCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBgColor = isDark ? Theme.of(context).cardColor : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtitleColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Container(
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [BoxShadow(color: isDark ? Colors.black26 : const Color(0x05000000), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xFF5B4CF0).withValues(alpha: 0.1),
            child: const Icon(Icons.engineering_rounded, color: Color(0xFF5B4CF0)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Project Engineer', style: TextStyle(fontSize: 12, color: subtitleColor, fontFamily: 'Outfit')),
                Text(_order.assignedEngineer, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: titleColor, fontFamily: 'Outfit')),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: _reassignEngineerDialog,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF5B4CF0),
              side: const BorderSide(color: Color(0xFF5B4CF0)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Reassign', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Outfit')),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsCard(BuildContext context) {
    final permService = ref.watch(permissionServiceProvider);
    final canEdit = permService.hasPermission('order_edit') || permService.hasPermission('order.edit');
    final canClose = permService.hasPermission('order_close') || permService.hasPermission('order.close');
    final canCancel = permService.hasPermission('order_cancel') || permService.hasPermission('order.cancel');
    final canDelete = permService.hasPermission('order_delete') || permService.hasPermission('order.delete');

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBgColor = isDark ? Theme.of(context).cardColor : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);

    return Container(
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [BoxShadow(color: isDark ? Colors.black26 : const Color(0x05000000), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Quick Order Actions', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: titleColor, fontFamily: 'Outfit')),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _addExpenseDialog,
                icon: const Icon(Icons.receipt_long_outlined, size: 16),
                label: const Text('Expense', style: TextStyle(fontSize: 12, fontFamily: 'Outfit')),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              ),
              OutlinedButton.icon(
                onPressed: _addDeliveryUpdateDialog,
                icon: const Icon(Icons.local_shipping_outlined, size: 16),
                label: const Text('Delivery', style: TextStyle(fontSize: 12, fontFamily: 'Outfit')),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              ),
              OutlinedButton.icon(
                onPressed: _addNoteDialog,
                icon: const Icon(Icons.note_add_outlined, size: 16),
                label: const Text('Note', style: TextStyle(fontSize: 12, fontFamily: 'Outfit')),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              ),
              if (canEdit)
                OutlinedButton.icon(
                  onPressed: () => context.push('/order-form', extra: _order),
                  icon: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF5B4CF0)),
                  label: const Text('Edit Order', style: TextStyle(fontSize: 12, fontFamily: 'Outfit', color: Color(0xFF5B4CF0))),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                ),
              if (canClose && _order.status.toLowerCase() != 'closed' && _order.status.toLowerCase() != 'completed')
                OutlinedButton.icon(
                  onPressed: () => _updateStatus('Closed'),
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 16, color: Color(0xFF16A34A)),
                  label: const Text('Close Order', style: TextStyle(fontSize: 12, fontFamily: 'Outfit', color: Color(0xFF16A34A))),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                ),
              if (canCancel && _order.status.toLowerCase() != 'cancelled')
                OutlinedButton.icon(
                  onPressed: () => _updateStatus('Cancelled'),
                  icon: const Icon(Icons.cancel_outlined, size: 16, color: Color(0xFFD97706)),
                  label: const Text('Cancel Order', style: TextStyle(fontSize: 12, fontFamily: 'Outfit', color: Color(0xFFD97706))),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                ),
              if (canDelete)
                OutlinedButton.icon(
                  onPressed: _deleteOrderDialog,
                  icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFDC2626)),
                  label: const Text('Delete Order', style: TextStyle(fontSize: 12, fontFamily: 'Outfit', color: Color(0xFFDC2626))),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOrderExpensesCard(BuildContext context) {
    final expensesState = ref.watch(expensesProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBgColor = isDark ? Theme.of(context).cardColor : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtitleColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return expensesState.when(
      data: (allExpenses) {
        final orderExpenses = allExpenses.where((e) => e.orderId == _order.orderId).toList();
        final totalExpense = orderExpenses.fold<double>(0, (sum, e) => sum + e.amount);

        return Container(
          decoration: BoxDecoration(
            color: cardBgColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
            boxShadow: [BoxShadow(color: isDark ? Colors.black26 : const Color(0x05000000), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.receipt_long_rounded, size: 18, color: Color(0xFF5B4CF0)),
                      const SizedBox(width: 8),
                      Text('Order Expenses (${orderExpenses.length})', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: titleColor, fontFamily: 'Outfit')),
                    ],
                  ),
                  if (orderExpenses.isNotEmpty)
                    Text('Total: ₹${NumberFormat('#,##,###.##').format(totalExpense)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF5B4CF0), fontFamily: 'Outfit')),
                ],
              ),
              Divider(height: 24, color: borderColor),
              if (orderExpenses.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text('No expenses logged for this order yet.', style: TextStyle(fontSize: 13, color: subtitleColor, fontFamily: 'Outfit')),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: orderExpenses.length,
                  separatorBuilder: (_, __) => Divider(height: 16, color: borderColor),
                  itemBuilder: (ctx, idx) {
                    final exp = orderExpenses[idx];
                    return Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF5B4CF0).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.receipt_rounded, size: 16, color: Color(0xFF5B4CF0)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(exp.category, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: titleColor, fontFamily: 'Outfit')),
                              if (exp.description.isNotEmpty)
                                Text(exp.description, style: TextStyle(fontSize: 11, color: subtitleColor, fontFamily: 'Outfit'), maxLines: 1, overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('₹${NumberFormat('#,##,###.##').format(exp.amount)}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: titleColor, fontFamily: 'Outfit')),
                            const SizedBox(height: 2),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: exp.status == 'Approved'
                                    ? (isDark ? const Color(0xFF14532D) : const Color(0xFFDCFCE7))
                                    : (exp.status == 'Rejected'
                                        ? (isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFEF2F2))
                                        : (isDark ? const Color(0xFF7C2D12) : const Color(0xFFFFF7ED))),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                exp.status,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: exp.status == 'Approved'
                                      ? (isDark ? const Color(0xFF86EFAC) : const Color(0xFF15803D))
                                      : (exp.status == 'Rejected'
                                          ? (isDark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C))
                                          : (isDark ? const Color(0xFFFDBA74) : const Color(0xFFC2410C))),
                                  fontFamily: 'Outfit',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildOrderDeliveriesCard(BuildContext context) {
    final deliveries = _orderActivities.where((a) => a['activityType'] == 'Delivery Update').toList();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBgColor = isDark ? Theme.of(context).cardColor : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtitleColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Container(
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [BoxShadow(color: isDark ? Colors.black26 : const Color(0x05000000), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.local_shipping_rounded, size: 18, color: Color(0xFF2563EB)),
                  const SizedBox(width: 8),
                  Text('Delivery Updates (${deliveries.length})', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: titleColor, fontFamily: 'Outfit')),
                ],
              ),
              OutlinedButton.icon(
                onPressed: _addDeliveryUpdateDialog,
                icon: const Icon(Icons.add, size: 14),
                label: const Text('Add', style: TextStyle(fontSize: 11, fontFamily: 'Outfit')),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          Divider(height: 24, color: borderColor),
          if (deliveries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text('No delivery updates recorded yet.', style: TextStyle(fontSize: 13, color: subtitleColor, fontFamily: 'Outfit')),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: deliveries.length,
              separatorBuilder: (_, __) => Divider(height: 16, color: borderColor),
              itemBuilder: (ctx, idx) {
                final d = deliveries[idx];
                final desc = d['description'] ?? '';
                final by = d['performedBy'] ?? '';
                final time = (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.local_shipping_outlined, size: 16, color: Color(0xFF2563EB)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(desc, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: titleColor, fontFamily: 'Outfit')),
                          const SizedBox(height: 2),
                          Text('Logged by $by • ${DateFormat('dd MMM, hh:mm a').format(time)}', style: TextStyle(fontSize: 11, color: subtitleColor, fontFamily: 'Outfit')),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildOrderNotesCard(BuildContext context) {
    final notes = _orderActivities.where((a) => a['activityType'] == 'Note').toList();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBgColor = isDark ? Theme.of(context).cardColor : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtitleColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Container(
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [BoxShadow(color: isDark ? Colors.black26 : const Color(0x05000000), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.note_alt_rounded, size: 18, color: Color(0xFFD97706)),
                  const SizedBox(width: 8),
                  Text('Project Notes (${notes.length})', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: titleColor, fontFamily: 'Outfit')),
                ],
              ),
              OutlinedButton.icon(
                onPressed: _addNoteDialog,
                icon: const Icon(Icons.add, size: 14),
                label: const Text('Add', style: TextStyle(fontSize: 11, fontFamily: 'Outfit')),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          Divider(height: 24, color: borderColor),
          if (notes.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text('No project notes added yet.', style: TextStyle(fontSize: 13, color: subtitleColor, fontFamily: 'Outfit')),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: notes.length,
              separatorBuilder: (_, __) => Divider(height: 16, color: borderColor),
              itemBuilder: (ctx, idx) {
                final n = notes[idx];
                final desc = n['description'] ?? '';
                final by = n['performedBy'] ?? '';
                final time = (n['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD97706).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.edit_note_rounded, size: 16, color: Color(0xFFD97706)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('"$desc"', style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic, fontWeight: FontWeight.w500, color: titleColor, fontFamily: 'Outfit')),
                          const SizedBox(height: 2),
                          Text('By $by • ${DateFormat('dd MMM, hh:mm a').format(time)}', style: TextStyle(fontSize: 11, color: subtitleColor, fontFamily: 'Outfit')),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildActivitiesCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBgColor = isDark ? Theme.of(context).cardColor : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtitleColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Container(
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [BoxShadow(color: isDark ? Colors.black26 : const Color(0x05000000), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.history_rounded, size: 18, color: Color(0xFF5B4CF0)),
                  const SizedBox(width: 8),
                  Text('Order Activity Log', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: titleColor, fontFamily: 'Outfit')),
                ],
              ),
              Row(
                children: [
                  Text('${_orderActivities.length} logs', style: TextStyle(fontSize: 12, color: subtitleColor, fontFamily: 'Outfit')),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: _loadOrderActivities,
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(Icons.refresh_rounded, size: 16, color: subtitleColor),
                    ),
                  ),
                ],
              ),
            ],
          ),
          Divider(height: 24, color: borderColor),
          if (_orderActivities.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('No activity logs recorded yet.', style: TextStyle(fontSize: 13, color: subtitleColor, fontFamily: 'Outfit')),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _orderActivities.length,
              itemBuilder: (ctx, idx) {
                final act = _orderActivities[idx];
                final type = (act['activityType'] ?? 'Activity').toString();
                final desc = (act['description'] ?? '').toString();
                final performedBy = (act['performedBy'] ?? 'User').toString();
                final timestamp = (act['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();

                IconData actIcon = Icons.check_circle_outline_rounded;
                Color actColor = const Color(0xFF5B4CF0);

                if (type.toLowerCase().contains('delivery')) {
                  actIcon = Icons.local_shipping_rounded;
                  actColor = const Color(0xFF2563EB);
                } else if (type.toLowerCase().contains('note')) {
                  actIcon = Icons.edit_note_rounded;
                  actColor = const Color(0xFFD97706);
                } else if (type.toLowerCase().contains('expense')) {
                  actIcon = Icons.receipt_rounded;
                  actColor = const Color(0xFF10B981);
                } else if (type.toLowerCase().contains('status')) {
                  actIcon = Icons.swap_horiz_rounded;
                  actColor = const Color(0xFF7C3AED);
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: actColor.withValues(alpha: 0.1),
                        child: Icon(actIcon, size: 14, color: actColor),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(type, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: titleColor, fontFamily: 'Outfit')),
                                Text(DateFormat('dd MMM, hh:mm a').format(timestamp), style: TextStyle(fontSize: 11, color: subtitleColor, fontFamily: 'Outfit')),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(desc, style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569), fontFamily: 'Outfit')),
                            const SizedBox(height: 2),
                            Text('By $performedBy', style: TextStyle(fontSize: 11, color: subtitleColor, fontFamily: 'Outfit')),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, IconData icon, String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subtitleColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final valueColor = isDark ? Colors.white : const Color(0xFF1E293B);

    return Row(
      children: [
        Icon(icon, size: 16, color: subtitleColor),
        const SizedBox(width: 8),
        Text('$label: ', style: TextStyle(fontSize: 13, color: subtitleColor, fontFamily: 'Outfit')),
        Expanded(
          child: Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: valueColor, fontFamily: 'Outfit')),
        ),
      ],
    );
  }
}
