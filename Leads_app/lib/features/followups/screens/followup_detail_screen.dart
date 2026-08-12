import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/models/followup_model.dart';
import '../../../shared/models/lead_model.dart';

class FollowupDetailScreen extends ConsumerStatefulWidget {
  final String followupId;
  const FollowupDetailScreen({super.key, required this.followupId});

  @override
  ConsumerState<FollowupDetailScreen> createState() => _FollowupDetailScreenState();
}

class _ProfileHeaderDivider extends StatelessWidget {
  final String label;
  const _ProfileHeaderDivider({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF64748B))),
          const SizedBox(width: 8),
          const Expanded(child: Divider(height: 1, color: Color(0xFFE2E8F0))),
        ],
      ),
    );
  }
}

class _FollowupDetailScreenState extends ConsumerState<FollowupDetailScreen> {
  void _showRescheduleDialog(BuildContext context, FollowupModel followup) {
    DateTime selectedDate = followup.followUpDate;
    TimeOfDay selectedTime = TimeOfDay.fromDateTime(followup.followUpDate);
    final remarksController = TextEditingController(text: followup.remarks);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (stContext, setDialogState) => AlertDialog(
          title: const Text('Reschedule Follow-up'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Select Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF64748B))),
                  const SizedBox(height: 4),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime.now().subtract(const Duration(days: 305)),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setDialogState(() {
                          selectedDate = picked;
                        });
                      }
                    },
                    icon: const Icon(Icons.calendar_today_rounded, size: 16),
                    label: Text(DateFormat('dd MMM yyyy').format(selectedDate)),
                  ),
                  const SizedBox(height: 12),
                  const Text('Select Time', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF64748B))),
                  const SizedBox(height: 4),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: selectedTime,
                      );
                      if (picked != null) {
                        setDialogState(() {
                          selectedTime = picked;
                        });
                      }
                    },
                    icon: const Icon(Icons.access_time_rounded, size: 16),
                    label: Text(selectedTime.format(context)),
                  ),
                  const SizedBox(height: 12),
                  const Text('Remarks', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF64748B))),
                  const SizedBox(height: 4),
                  TextFormField(
                    controller: remarksController,
                    maxLines: 3,
                    decoration: const InputDecoration(hintText: 'Add rescheduling notes...'),
                    validator: (val) => val == null || val.trim().isEmpty ? 'Please enter remarks' : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final newDateTime = DateTime(
                  selectedDate.year,
                  selectedDate.month,
                  selectedDate.day,
                  selectedTime.hour,
                  selectedTime.minute,
                );

                await ref.read(followupsProvider.notifier).rescheduleFollowup(
                  followup.followUpId,
                  newDateTime,
                  remarksController.text.trim(),
                );

                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Follow-up rescheduled successfully.')),
                  );
                }
              },
              child: const Text('Reschedule'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCompleteDialog(BuildContext context, FollowupModel followup) {
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Complete Follow-up'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Add outcome notes for this client call:',
              style: TextStyle(fontSize: 13, color: Color(0xFF475569)),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Customer requested quotation by email...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await ref.read(followupsProvider.notifier).updateFollowupStatus(
                followup.followUpId,
                'Completed',
                completionNotes: notesController.text.trim(),
              );

              if (dialogContext.mounted) {
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Follow-up marked as Completed.')),
                );
              }
            },
            child: const Text('Save Outcome'),
          ),
        ],
      ),
    );
  }

  void _mockCallClient(BuildContext context, LeadModel lead) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.phone_in_talk_rounded, color: Colors.green, size: 40),
            ),
            const SizedBox(height: 16),
            Text(
              lead.customerName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF1E293B)),
            ),
            if (lead.companyName.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                lead.companyName,
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              lead.mobileNumber,
              style: TextStyle(fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.primary, fontSize: 14),
            ),
            const Divider(height: 32),
            const Text(
              'Simulating outgoing cellular call...',
              style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('End Simulated Call', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final followupsState = ref.watch(followupsProvider);
    final leadsState = ref.watch(leadsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Follow-up File', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: followupsState.when(
        data: (list) {
          final followup = list.firstWhere(
            (f) => f.followUpId == widget.followupId,
            orElse: () => FollowupModel(
              followUpId: '', leadId: '', companyId: '', assignedUser: '', assignedUserId: '',
              followUpDate: DateTime.now(), remarks: '', status: 'Upcoming', createdAt: DateTime.now(),
            ),
          );

          if (followup.followUpId.isEmpty) {
            return const Center(child: Text('Follow-up record not found.'));
          }

          final leads = leadsState.value ?? [];
          final lead = leads.firstWhere(
            (l) => l.leadId == followup.leadId,
            orElse: () => LeadModel(
              leadId: '', companyId: '', customerName: 'N/A', mobileNumber: 'N/A', companyName: 'N/A',
              location: 'N/A', requirement: 'N/A', leadSource: '', assignedTo: '', assignedToId: '',
              status: '', createdAt: DateTime.now(), updatedAt: DateTime.now(),
            ),
          );

          Color badgeColor;
          Color textColor;
          switch (followup.status) {
            case 'Completed':
              badgeColor = const Color(0xFFDCFCE7);
              textColor = const Color(0xFF15803D);
              break;
            case 'Missed':
              badgeColor = const Color(0xFFFEF2F2);
              textColor = const Color(0xFFB91C1C);
              break;
            default:
              badgeColor = const Color(0xFFFFF7ED);
              textColor = const Color(0xFFC2410C);
          }

          final isUpcoming = followup.status == 'Upcoming';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header status card
                Card(
                  elevation: 0,
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('SCHEDULE DATE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8))),
                            const SizedBox(height: 4),
                            Text(
                              DateFormat('dd MMM yyyy').format(followup.followUpDate),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E293B)),
                            ),
                            Text(
                              DateFormat('hh:mm a').format(followup.followUpDate),
                              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(color: badgeColor, borderRadius: BorderRadius.circular(8)),
                          child: Text(
                            followup.status.toUpperCase(),
                            style: TextStyle(color: textColor, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Lead Client Information Card
                const _ProfileHeaderDivider(label: 'CLIENT FILE'),
                Card(
                  elevation: 0,
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(lead.customerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E293B))),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (lead.companyName != 'N/A') Text(lead.companyName, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.phone_rounded, size: 14, color: Color(0xFF64748B)),
                                  const SizedBox(width: 6),
                                  Text(lead.mobileNumber, style: const TextStyle(fontSize: 13, color: Color(0xFF475569))),
                                ],
                              ),
                            ],
                          ),
                          trailing: IconButton(
                            icon: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), shape: BoxShape.circle),
                              child: const Icon(Icons.phone_rounded, color: Colors.green, size: 20),
                            ),
                            onPressed: () => _mockCallClient(context, lead),
                          ),
                        ),
                        const Divider(height: 20, color: Color(0xFFF1F5F9)),
                        const Text('Requirement Details', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8))),
                        const SizedBox(height: 4),
                        Text(lead.requirement, style: const TextStyle(fontSize: 13, color: Color(0xFF475569))),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Schedule details/remarks card
                const _ProfileHeaderDivider(label: 'SCHEDULE NOTES'),
                Card(
                  elevation: 0,
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Remarks Log', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8))),
                        const SizedBox(height: 6),
                        Text(
                          followup.remarks.isEmpty ? 'No notes provided.' : followup.remarks,
                          style: const TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.4),
                        ),
                        const Divider(height: 24, color: Color(0xFFF1F5F9)),
                        Row(
                          children: [
                            const Icon(Icons.person_outline_rounded, size: 14, color: Color(0xFF94A3B8)),
                            const SizedBox(width: 6),
                            Text('Scheduled by ${followup.assignedUser}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 36),

                // Actions Button Row
                if (isUpcoming) ...[
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showRescheduleDialog(context, followup),
                          icon: const Icon(Icons.edit_calendar_rounded, size: 16),
                          label: const Text('Reschedule'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Theme.of(context).colorScheme.primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _showCompleteDialog(context, followup),
                          icon: const Icon(Icons.check_circle_rounded, size: 16),
                          label: const Text('Complete'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: lead.leadId.isNotEmpty
                        ? () => context.push('/lead-detail/${lead.leadId}', extra: lead)
                        : null,
                    icon: const Icon(Icons.folder_open_rounded, size: 16),
                    label: const Text('View Full Lead File'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF64748B),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error loading follow-up detail: $err')),
      ),
    );
  }
}
