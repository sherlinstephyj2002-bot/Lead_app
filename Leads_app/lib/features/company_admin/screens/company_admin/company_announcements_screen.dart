import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../../../../shared/providers/providers.dart';
import '../../providers/company_admin_providers.dart';

class CompanyAnnouncementsScreen extends ConsumerStatefulWidget {
  const CompanyAnnouncementsScreen({super.key});

  @override
  ConsumerState<CompanyAnnouncementsScreen> createState() => _CompanyAnnouncementsScreenState();
}

class _CompanyAnnouncementsScreenState extends ConsumerState<CompanyAnnouncementsScreen> {
  bool _isSending = false;

  void _showNewAnnouncementDialog() {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    final titleCtrl = TextEditingController();
    final messageCtrl = TextEditingController();
    String audience = 'All Employees';
    String? selectedDepartmentId;

    final depts = ref.read(adminDepartmentsProvider).value ?? [];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.campaign_rounded, color: Color(0xFF5B4CF0)),
                SizedBox(width: 10),
                Text('New Announcement', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(labelText: 'Title *', hintText: 'Enter announcement title...'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: messageCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Message *', hintText: 'Enter announcement details...'),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    value: audience,
                    decoration: const InputDecoration(labelText: 'Target Audience'),
                    items: ['All Employees', 'Specific Department']
                        .map((a) => DropdownMenuItem(value: a, child: Text(a)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setModalState(() => audience = v);
                    },
                  ),
                  if (audience == 'Specific Department') ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedDepartmentId,
                      decoration: const InputDecoration(labelText: 'Select Department'),
                      items: depts
                          .map((d) => DropdownMenuItem(value: d.departmentId, child: Text(d.departmentName)))
                          .toList(),
                      onChanged: (v) => setModalState(() => selectedDepartmentId = v),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: _isSending ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(fontFamily: 'Outfit')),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5B4CF0),
                  foregroundColor: Colors.white,
                ),
                onPressed: _isSending
                    ? null
                    : () async {
                        if (titleCtrl.text.trim().isEmpty || messageCtrl.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Title and message are required.')),
                          );
                          return;
                        }

                        setModalState(() => _isSending = true);
                        try {
                          final notifId = const Uuid().v4();
                          await FirebaseFirestore.instance.collection('notifications').doc(notifId).set({
                            'id': notifId,
                            'companyId': user.companyId,
                            'title': titleCtrl.text.trim(),
                            'message': messageCtrl.text.trim(),
                            'audience': audience,
                            'departmentId': selectedDepartmentId,
                            'createdBy': user.name,
                            'createdAt': Timestamp.fromDate(DateTime.now()),
                            'isRead': false,
                          });

                          await ref.read(companyAdminRepositoryProvider).logEmployeeActivity(
                            companyId: user.companyId,
                            employeeId: user.uid,
                            action: 'Sent announcement: ${titleCtrl.text.trim()}',
                            performedBy: user.name,
                          );

                          if (context.mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Announcement dispatched successfully!'), backgroundColor: Colors.green),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            setModalState(() => _isSending = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed to send announcement: $e'), backgroundColor: Colors.red),
                            );
                          }
                        }
                      },
                child: _isSending
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Send Announcement', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = ref.watch(authProvider).user;

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
        elevation: 0,
        title: const Text(
          'Company Announcements',
          style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showNewAnnouncementDialog,
        backgroundColor: const Color(0xFF5B4CF0),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.campaign_rounded),
        label: const Text('New Announcement', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .where('companyId', isEqualTo: user.companyId)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.campaign_outlined, size: 54, color: isDark ? Colors.white38 : Colors.black26),
                  const SizedBox(height: 12),
                  Text(
                    'No company announcements dispatched yet.',
                    style: TextStyle(fontFamily: 'Outfit', fontSize: 14, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16.0),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final notif = docs[index].data();
              final title = notif['title'] ?? 'Announcement';
              final message = notif['message'] ?? '';
              final audience = notif['audience'] ?? 'All Employees';
              final createdBy = notif['createdBy'] ?? 'Admin';
              final ts = notif['createdAt'] is Timestamp ? (notif['createdAt'] as Timestamp).toDate() : DateTime.now();
              final timeStr = DateFormat('dd MMM yyyy, hh:mm a').format(ts);

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
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF5B4CF0).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            audience.toUpperCase(),
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF5B4CF0)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      message,
                      style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('By $createdBy', style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                        Text(timeStr, style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
