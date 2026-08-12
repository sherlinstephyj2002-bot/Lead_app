import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/providers/permissions_provider.dart';
import '../../../shared/models/followup_model.dart';
import '../../../shared/models/lead_model.dart';

import '../../../constants/user_roles.dart';
import '../../../features/company_admin/providers/company_admin_providers.dart';

class FollowupListScreen extends ConsumerStatefulWidget {
  const FollowupListScreen({super.key});

  @override
  ConsumerState<FollowupListScreen> createState() => _FollowupListScreenState();
}

class _FollowupListScreenState extends ConsumerState<FollowupListScreen> {
  String _selectedFilterChip = 'All';
  String _selectedEmployeeId = 'All';
  final List<String> _filterChips = ['All', 'Upcoming', 'Completed', 'Missed'];
  String _searchQuery = '';
  final _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showCompleteNotesDialog(BuildContext context, WidgetRef ref, FollowupModel followup) {
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

  void _showAddFollowupBottomSheet(BuildContext context, WidgetRef ref) {
    final leads = ref.read(leadsProvider).value ?? [];
    final activeLeads = leads.where((l) => l.status != 'Converted' && l.status != 'Closed').toList();

    String? selectedLeadId = activeLeads.isNotEmpty ? activeLeads.first.leadId : null;
    DateTime selectedDate = DateTime.now();
    TimeOfDay selectedTime = TimeOfDay.now();
    final remarksController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    if (activeLeads.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active leads available to schedule a follow-up.')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (stContext, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Schedule Follow-up',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(sheetContext),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
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
                        setSheetState(() => selectedLeadId = val);
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
                                  setSheetState(() => selectedDate = picked);
                                }
                              },
                              icon: const Icon(Icons.calendar_today_rounded, size: 16),
                              label: Text(DateFormat('dd MMM yyyy').format(selectedDate)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
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
                                  setSheetState(() => selectedTime = picked);
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
                  const Text('Follow-up Notes / Remarks *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF64748B))),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: remarksController,
                    maxLines: 3,
                    decoration: const InputDecoration(hintText: 'Call customer to confirm quotation...'),
                    validator: (val) => val == null || val.trim().isEmpty ? 'Please enter notes' : null,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isSaving ? null : () async {
                        if (!formKey.currentState!.validate() || selectedLeadId == null) return;
                        setSheetState(() => isSaving = true);
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

                          if (sheetContext.mounted) {
                            Navigator.pop(sheetContext);
                          }
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Follow-up scheduled successfully.')),
                            );
                          }
                        } catch (e, stackTrace) {
                          debugPrint('Follow-up Error: $e');
                          debugPrint(stackTrace.toString());
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(e.toString())),
                            );
                          }
                        } finally {
                          if (sheetContext.mounted) {
                            setSheetState(() => isSaving = false);
                          }
                        }
                      },
                      child: isSaving
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Schedule Follow-up'),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showReassignFollowupDialog(BuildContext context, WidgetRef ref, FollowupModel followup) {
    final employees = ref.read(adminEmployeesProvider).value ?? [];
    if (employees.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No employees found to reassign.')),
      );
      return;
    }

    String? selectedUid = followup.assignedUserId.isNotEmpty ? followup.assignedUserId : employees.first.uid;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Reassign Follow-up', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Select an authorized employee to assign this follow-up:', style: TextStyle(fontSize: 13, color: Color(0xFF475569))),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: employees.any((e) => e.uid == selectedUid) ? selectedUid : null,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Assigned Employee', prefixIcon: Icon(Icons.person_outline)),
                items: employees.map((emp) {
                  return DropdownMenuItem<String>(
                    value: emp.uid,
                    child: Text('${emp.name} (${emp.employeeId ?? emp.email})', style: const TextStyle(fontSize: 13)),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setDialogState(() => selectedUid = val);
                },
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
                if (selectedUid == null) return;
                final targetEmp = employees.firstWhere((e) => e.uid == selectedUid);
                await ref.read(followupsProvider.notifier).reassignFollowup(
                  followup.followUpId,
                  targetEmp.name,
                  targetEmp.uid,
                );
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Follow-up reassigned to ${targetEmp.name}.')),
                  );
                }
              },
              child: const Text('Reassign'),
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
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Search follow-ups...',
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
                  Text('Follow-ups', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                  Text('Manage your customer schedules', style: TextStyle(fontSize: 12, color: Colors.white70)),
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
          await ref.read(followupsProvider.notifier).loadFollowups();
          await ref.read(leadsProvider.notifier).loadLeads();
        },
        child: followupsState.when(
          data: (followups) {
            final leads = leadsState.value ?? [];

            // Reminders / Todays statistics
            final today = DateTime.now();
            final todayUpcoming = followups.where((f) =>
                f.status == 'Upcoming' &&
                f.followUpDate.year == today.year &&
                f.followUpDate.month == today.month &&
                f.followUpDate.day == today.day
            ).toList();

            final missedCount = followups.where((f) => f.status == 'Missed').length;

            // Filter
            var filtered = followups;
            if (_selectedFilterChip != 'All') {
              filtered = followups.where((f) => f.status == _selectedFilterChip).toList();
            }

            // Search by remarks or lead/customer name
            if (_searchQuery.isNotEmpty) {
              filtered = filtered.where((f) {
                final lead = leads.firstWhere((l) => l.leadId == f.leadId, orElse: () => LeadModel(
                  leadId: '', companyId: '', customerName: 'N/A', mobileNumber: '', companyName: '',
                  location: '', requirement: '', leadSource: '', assignedTo: '', assignedToId: '',
                  status: '', createdAt: DateTime.now(), updatedAt: DateTime.now()
                ));
                return f.remarks.toLowerCase().contains(_searchQuery) ||
                    lead.customerName.toLowerCase().contains(_searchQuery) ||
                    lead.companyName.toLowerCase().contains(_searchQuery);
              }).toList();
            }

            return Column(
              children: [
                if (missedCount > 0)
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFCA5A5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'You have $missedCount missed follow-up schedule(s). Tap "Missed" filter to review.',
                            style: const TextStyle(color: Color(0xFF991B1B), fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),

                if (todayUpcoming.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today_rounded, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Today's Schedule",
                                style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary, fontSize: 13),
                              ),
                              Text(
                                "You have ${todayUpcoming.length} upcoming customer call(s) scheduled for today.",
                                style: const TextStyle(color: Color(0xFF475569), fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                // Filter Chips Row
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: _filterChips.map((chipName) {
                      final isSelected = _selectedFilterChip == chipName;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: FilterChip(
                          selected: isSelected,
                          label: Text(chipName),
                          onSelected: (selected) {
                            setState(() {
                              _selectedFilterChip = chipName;
                            });
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),

                // Listing
                Expanded(
                  child: filtered.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                            Icon(Icons.event_busy_rounded, size: 60, color: Colors.grey[300]),
                            const SizedBox(height: 12),
                            const Center(
                              child: Text('No follow-ups found', style: TextStyle(color: Colors.grey)),
                            ),
                          ],
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          itemCount: filtered.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final followup = filtered[index];
                            final lead = leads.firstWhere(
                              (l) => l.leadId == followup.leadId,
                              orElse: () => LeadModel(
                                leadId: '', companyId: '', customerName: 'N/A', mobileNumber: '', companyName: '',
                                location: '', requirement: '', leadSource: '', assignedTo: '', assignedToId: '',
                                status: '', createdAt: DateTime.now(), updatedAt: DateTime.now()
                              ),
                            );

                            return InkWell(
                              onTap: () => context.push('/followup-detail/${followup.followUpId}'),
                              borderRadius: BorderRadius.circular(16),
                              child: _buildFollowupCard(context, followup, lead),
                            );
                          },
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
                Center(child: Text('Error loading followups: $err')),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: ref.watch(permissionServiceProvider).hasPermission('followup_create')
          ? FloatingActionButton.extended(
              heroTag: 'followupFab',
              onPressed: () => _showAddFollowupBottomSheet(context, ref),
              label: const Text('New Follow-up'),
              icon: const Icon(Icons.add_rounded),
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
            )
          : null,
    );
  }

  Widget _buildFollowupCard(BuildContext context, FollowupModel followup, LeadModel lead) {
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
      default: // Upcoming
        badgeColor = const Color(0xFFFFF7ED);
        textColor = const Color(0xFFC2410C);
    }

    final isUpcoming = followup.status == 'Upcoming';

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lead.customerName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E293B)),
                      ),
                      if (lead.companyName.isNotEmpty && lead.companyName != 'N/A')
                        Text(
                          lead.companyName,
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: badgeColor, borderRadius: BorderRadius.circular(6)),
                  child: Text(
                    followup.status,
                    style: TextStyle(color: textColor, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            if (followup.assignedUser.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.person_outline_rounded, size: 14, color: Color(0xFF64748B)),
                  const SizedBox(width: 4),
                  Text('Assigned to: ${followup.assignedUser}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                ],
              ),
            ],
            const Divider(height: 20, color: Color(0xFFF1F5F9)),
            Row(
              children: [
                const Icon(Icons.access_time_rounded, size: 16, color: Color(0xFF94A3B8)),
                const SizedBox(width: 6),
                Text(
                  DateFormat('dd MMM yyyy • hh:mm a').format(followup.followUpDate),
                  style: const TextStyle(fontSize: 13, color: Color(0xFF475569), fontWeight: FontWeight.w500),
                ),
              ],
            ),
            if (followup.remarks.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.notes_rounded, size: 16, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      followup.remarks,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                    ),
                  ),
                ],
              ),
            ],
            if (isUpcoming || ref.watch(authProvider).user?.role == UserRoles.companyAdmin) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  if (ref.watch(authProvider).user?.role == UserRoles.companyAdmin) ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showReassignFollowupDialog(context, ref, followup),
                        icon: const Icon(Icons.person_add_alt_1_rounded, size: 15),
                        label: const Text('Reassign'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF5B4CF0),
                          side: const BorderSide(color: Color(0xFF5B4CF0)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    if (isUpcoming) const SizedBox(width: 10),
                  ],
                  if (isUpcoming)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _showCompleteNotesDialog(context, ref, followup),
                        icon: const Icon(Icons.check_circle_outline, size: 15),
                        label: const Text('Complete'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
