import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:worktrack/shared/providers/providers.dart';
import 'package:worktrack/shared/models/employee_request_model.dart';
import 'package:worktrack/constants/firestore_collections.dart';

class ESSResignationScreen extends ConsumerStatefulWidget {
  const ESSResignationScreen({super.key});

  @override
  ConsumerState<ESSResignationScreen> createState() => _ESSResignationScreenState();
}

class _ESSResignationScreenState extends ConsumerState<ESSResignationScreen> {
  bool _isSubmitting = false;

  void _showSubmitResignationDialog() {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    final reasonCtrl = TextEditingController();
    final noticeCtrl = TextEditingController(text: '30 Days');
    DateTime selectedRelievingDate = DateTime.now().add(const Duration(days: 30));
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.exit_to_app_rounded, color: Color(0xFFEF4444)),
              SizedBox(width: 10),
              Text('Submit Resignation', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Please fill in your resignation details. Your manager and HR team will review your notice period.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 16),

                  const Text('Notice Period', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: noticeCtrl,
                    decoration: const InputDecoration(
                      hintText: 'e.g. 30 Days / 60 Days',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.timer_outlined, size: 18),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Notice period is required' : null,
                  ),
                  const SizedBox(height: 14),

                  const Text('Intended Relieving Date', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedRelievingDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setModalState(() => selectedRelievingDate = picked);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(DateFormat('dd MMM yyyy').format(selectedRelievingDate)),
                          const Icon(Icons.calendar_today_rounded, size: 18, color: Color(0xFF5B4CF0)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  const Text('Reason for Resignation', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: reasonCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'Provide detailed reason for leaving...',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Reason is required' : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: _isSubmitting ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _isSubmitting
                  ? null
                  : () async {
                      if (formKey.currentState!.validate()) {
                        setModalState(() => _isSubmitting = true);
                        try {
                          final req = EmployeeRequestModel(
                            requestId: const Uuid().v4(),
                            companyId: user.companyId,
                            requestedBy: user.uid,
                            requestedByName: user.name,
                            employeeId: user.employeeId ?? user.uid,
                            employeeName: user.name,
                            requestType: 'RESIGNATION',
                            reason: reasonCtrl.text.trim(),
                            employeeData: {
                              'noticePeriod': noticeCtrl.text.trim(),
                              'relievingDate': selectedRelievingDate.toIso8601String(),
                            },
                            status: 'Submitted',
                            createdAt: DateTime.now(),
                          );

                          await FirebaseFirestore.instance
                              .collection(FirestoreCollections.employeeRequests)
                              .doc(req.requestId)
                              .set(req.toMap());

                          if (mounted && ctx.mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Resignation submitted successfully to HR.'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } catch (e) {
                          setModalState(() => _isSubmitting = false);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed to submit: $e'), backgroundColor: Colors.red),
                            );
                          }
                        }
                      }
                    },
              child: _isSubmitting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Submit Resignation'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _cancelResignation(EmployeeRequestModel req) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Resignation'),
        content: const Text('Are you sure you want to cancel your submitted resignation request?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, Cancel Request'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection(FirestoreCollections.employeeRequests)
            .doc(req.requestId)
            .update({
          'status': 'Cancelled',
          'updatedAt': DateTime.now(),
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Resignation request cancelled.'), backgroundColor: Colors.orange),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to cancel request: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF5B4CF0), Color(0xFF4338CA)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: const Text('Resignation & Settlement Portal', style: TextStyle(color: Colors.white, fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showSubmitResignationDialog,
        backgroundColor: const Color(0xFFEF4444),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.exit_to_app_rounded),
        label: const Text('Submit Resignation', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection(FirestoreCollections.employeeRequests)
            .where('companyId', isEqualTo: user.companyId)
            .where('requestedBy', isEqualTo: user.uid)
            .where('requestType', isEqualTo: 'RESIGNATION')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];
          final requests = docs.map((d) => EmployeeRequestModel.fromMap(d.data() as Map<String, dynamic>)).toList();

          if (requests.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.assignment_turned_in_outlined, size: 64, color: Color(0xFF94A3B8)),
                  const SizedBox(height: 16),
                  const Text('No Resignation Records Found', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  Text(
                    'You are actively employed with ${user.companyName}.',
                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) {
              final req = requests[i];
              return _buildResignationCard(context, req, isDark);
            },
          );
        },
      ),
    );
  }

  Widget _buildResignationCard(BuildContext context, EmployeeRequestModel req, bool isDark) {
    Color statusColor;
    switch (req.status.toLowerCase()) {
      case 'approved':
        statusColor = const Color(0xFF10B981);
        break;
      case 'rejected':
        statusColor = const Color(0xFFEF4444);
        break;
      case 'cancelled':
        statusColor = const Color(0xFF64748B);
        break;
      case 'submitted':
      case 'under review':
      default:
        statusColor = const Color(0xFFF59E0B);
        break;
    }

    final isPending = req.status.toLowerCase() == 'submitted' || req.status.toLowerCase() == 'pending' || req.status.toLowerCase() == 'under review';
    final relievingDateStr = req.employeeData != null && req.employeeData!['relievingDate'] != null
        ? DateFormat('dd MMM yyyy').format(DateTime.parse(req.employeeData!['relievingDate']))
        : 'Notice Period In Progress';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Theme.of(context).cardColor : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.assignment_late_outlined, color: Color(0xFFEF4444), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Relieving Date: $relievingDateStr',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Outfit'),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(req.status.toUpperCase(), style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('Reason:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
          Text(req.reason ?? 'No details provided.', style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 12),
          Divider(color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Submitted: ${DateFormat('dd MMM yyyy').format(req.createdAt)}', style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
              if (isPending)
                TextButton.icon(
                  onPressed: () => _cancelResignation(req),
                  icon: const Icon(Icons.cancel_outlined, size: 16, color: Colors.orange),
                  label: const Text('Cancel Request', style: TextStyle(color: Colors.orange, fontSize: 12)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
