import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/utils/app_notification.dart';

class ESSLeaveScreen extends ConsumerWidget {
  const ESSLeaveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = ref.watch(authProvider).user;
    final leavesAsync = ref.watch(leavesProvider);

    final userLeaves = (leavesAsync.value ?? [])
        .where((l) => l.employeeId == user?.uid)
        .toList();

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
        elevation: 0,
        title: const Text(
          'My Leave Management',
          style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showApplyLeaveDialog(context, ref),
        backgroundColor: const Color(0xFF5B4CF0),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Apply For Leave', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Leave Balance Cards Row
            Row(
              children: [
                Expanded(child: _buildBalanceCard(context, 'Casual Leave', '6.0 Left', '12 Total', const Color(0xFF5B4CF0), isDark)),
                const SizedBox(width: 12),
                Expanded(child: _buildBalanceCard(context, 'Sick Leave', '4.5 Left', '7 Total', const Color(0xFF0284C7), isDark)),
                const SizedBox(width: 12),
                Expanded(child: _buildBalanceCard(context, 'Earned Leave', '4.0 Left', '15 Total', const Color(0xFF10B981), isDark)),
              ],
            ),
            const SizedBox(height: 20),

            // Leave History Feed
            Text(
              'LEAVE APPLICATION HISTORY',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 10),

            if (userLeaves.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isDark ? Theme.of(context).cardColor : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: const Center(child: Text('No leave applications recorded.', style: TextStyle(color: Colors.grey, fontFamily: 'Outfit'))),
              )
            else
              Column(
                children: userLeaves.map((l) {
                  final startStr = DateFormat('dd MMM yyyy').format(l.startDate);
                  final endStr = DateFormat('dd MMM yyyy').format(l.endDate);
                  final daysCount = l.endDate.difference(l.startDate).inDays + 1;

                  Color statusColor;
                  switch (l.status.toLowerCase()) {
                    case 'approved':
                      statusColor = Colors.green;
                      break;
                    case 'rejected':
                      statusColor = Colors.red;
                      break;
                    case 'cancelled':
                      statusColor = Colors.grey;
                      break;
                    default:
                      statusColor = Colors.orange;
                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
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
                            Text(
                              l.type.isNotEmpty ? l.type : 'Leave',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Outfit',
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                l.status.toUpperCase(),
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Duration: $startStr to $endStr ($daysCount Days)',
                          style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Reason: ${l.reason}',
                          style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                        ),
                        if (l.status.toLowerCase() == 'pending') ...[
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Cancel Leave Application', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
                                    content: const Text('Are you sure you want to cancel this pending leave request?', style: TextStyle(fontFamily: 'Outfit')),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                                        onPressed: () => Navigator.pop(ctx, true),
                                        child: const Text('Yes, Cancel'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  await ref.read(leavesProvider.notifier).updateStatus(l.leaveId, 'Cancelled');
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Leave application cancelled successfully.')),
                                    );
                                  }
                                }
                              },
                              icon: const Icon(Icons.cancel_outlined, size: 14, color: Colors.orange),
                              label: const Text('Cancel Application', style: TextStyle(color: Colors.orange, fontSize: 11)),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceCard(BuildContext context, String title, String left, String total, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? Theme.of(context).cardColor : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(
            left,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Outfit', color: isDark ? Colors.white : const Color(0xFF0F172A)),
          ),
          const SizedBox(height: 2),
          Text(total, style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
        ],
      ),
    );
  }

  void _showApplyLeaveDialog(BuildContext context, WidgetRef ref) {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    final reasonCtrl = TextEditingController();
    String leaveType = 'Casual Leave';
    DateTime startDate = DateTime.now().add(const Duration(days: 1));
    DateTime endDate = DateTime.now().add(const Duration(days: 1));

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Apply For Leave', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: leaveType,
                    items: ['Casual Leave', 'Sick Leave', 'Earned Leave', 'Work From Home (WFH)', 'Optional Holiday']
                        .map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontFamily: 'Outfit'))))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setModalState(() => leaveType = v);
                    },
                    decoration: const InputDecoration(labelText: 'Leave Type *'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: startDate,
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (picked != null) {
                              setModalState(() {
                                startDate = picked;
                                if (endDate.isBefore(startDate)) endDate = startDate;
                              });
                            }
                          },
                          icon: const Icon(Icons.calendar_today_rounded, size: 14),
                          label: Text(DateFormat('dd MMM').format(startDate), style: const TextStyle(fontFamily: 'Outfit', fontSize: 12)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text('to', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: endDate.isBefore(startDate) ? startDate : endDate,
                              firstDate: startDate,
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (picked != null) {
                              setModalState(() => endDate = picked);
                            }
                          },
                          icon: const Icon(Icons.calendar_today_rounded, size: 14),
                          label: Text(DateFormat('dd MMM').format(endDate), style: const TextStyle(fontFamily: 'Outfit', fontSize: 12)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: reasonCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Reason for Leave *', hintText: 'Enter reason for applying leave...'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(fontFamily: 'Outfit'))),
              ElevatedButton(
                onPressed: () async {
                  if (reasonCtrl.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a reason for leave.')));
                    return;
                  }
                  if (endDate.isBefore(startDate)) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('End date cannot be before start date.')));
                    return;
                  }

                  Navigator.pop(ctx);
                  await ref.read(leavesProvider.notifier).applyForLeave(
                        type: leaveType,
                        startDate: startDate,
                        endDate: endDate,
                        reason: reasonCtrl.text.trim(),
                      );
                  if (context.mounted) {
                    AppNotification.showSuccess(context, 'Leave application submitted successfully!');
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5B4CF0), foregroundColor: Colors.white),
                child: const Text('Submit Application', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }
}
