import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../shared/providers/permissions_provider.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/models/lead_model.dart';
import '../../../shared/models/followup_model.dart';
import '../../../shared/models/lead_activity_model.dart';
import '../../../shared/models/lead_attachment_model.dart';

class LeadDetailScreen extends ConsumerStatefulWidget {
  final String leadId;
  final LeadModel? initialLead;

  const LeadDetailScreen({super.key, required this.leadId, this.initialLead});

  @override
  ConsumerState<LeadDetailScreen> createState() => _LeadDetailScreenState();
}

class _LeadDetailScreenState extends ConsumerState<LeadDetailScreen> {
  late LeadModel _lead;
  bool _isLoaded = false;
  final TextEditingController _quickNoteController = TextEditingController();
  List<LeadAttachmentModel> _attachments = [];

  @override
  void initState() {
    super.initState();
    if (widget.initialLead != null) {
      _lead = widget.initialLead!;
      _isLoaded = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadLeadRelatedData();
        _loadAttachments();
      });
    }
  }

  @override
  void dispose() {
    _quickNoteController.dispose();
    super.dispose();
  }

  Future<void> _loadAttachments() async {
    try {
      final user = ref.read(authProvider).user;
      if (user == null) return;
      final snap = await FirebaseFirestore.instance
          .collection('leadAttachments')
          .where('leadId', isEqualTo: _lead.leadId)
          .get();
      if (!mounted) return;
      setState(() {
        _attachments = snap.docs.map((d) => LeadAttachmentModel.fromMap(d.data())).toList();
      });
    } catch (_) {}
  }

  Future<void> _loadLeadRelatedData() async {
    if (!_isLoaded) return;
    final user = ref.read(authProvider).user;
    if (user == null) return;

    await ref.read(followupsProvider.notifier).loadFollowups();
    await ref.read(leadActivityProvider.notifier).loadActivities(user.companyId, _lead.leadId);
  }

  void _fetchLeadDetails() async {
    final leads = ref.read(leadsProvider).value;
    if (leads != null) {
      try {
        final found = leads.firstWhere((l) => l.leadId == widget.leadId);
        setState(() {
          _lead = found;
          _isLoaded = true;
        });
        await _loadLeadRelatedData();
      } catch (_) {}
    }
  }

  void _updateStatus(String newStatus) async {
    await ref.read(leadsProvider.notifier).updateLeadStatus(_lead.leadId, newStatus);
    _fetchLeadDetails();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Lead status updated to $newStatus', style: const TextStyle(fontFamily: 'Outfit')), behavior: SnackBarBehavior.floating),
    );
  }

  void _confirmDeleteLead() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Lead?', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to remove ${_lead.customerName}? This action cannot be undone.', style: const TextStyle(fontFamily: 'Outfit')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(leadsProvider.notifier).deleteLead(_lead.leadId);
              if (mounted) {
                context.pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Lead deleted successfully.'), behavior: SnackBarBehavior.floating),
                );
              }
            },
            child: const Text('Delete Lead', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _submitQuickNote() async {
    final text = _quickNoteController.text.trim();
    if (text.isEmpty) return;

    final user = ref.read(authProvider).user;
    if (user == null) return;

    final activity = LeadActivityModel(
      activityId: const Uuid().v4(),
      leadId: _lead.leadId,
      companyId: user.companyId,
      activityType: 'Note',
      description: text,
      performedBy: user.name,
      performedById: user.uid,
      createdAt: DateTime.now(),
    );

    await ref.read(leadActivityProvider.notifier).addActivity(activity);
    _quickNoteController.clear();
    FocusScope.of(context).unfocus();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Note added to activity timeline.'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'new':
        return const Color(0xFF2563EB);
      case 'follow up':
        return const Color(0xFFD97706);
      case 'quotation sent':
        return const Color(0xFF7C3AED);
      case 'converted':
      case 'won':
        return const Color(0xFF16A34A);
      case 'closed':
      case 'lost':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFF64748B);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoaded) {
      final leads = ref.watch(leadsProvider).value;
      if (leads != null) {
        try {
          _lead = leads.firstWhere((l) => l.leadId == widget.leadId);
          _isLoaded = true;
          _loadLeadRelatedData();
          _loadAttachments();
        } catch (_) {}
      }
    }

    if (!_isLoaded) {
      return Scaffold(
        appBar: AppBar(title: const Text('Lead Details', style: TextStyle(fontFamily: 'Outfit'))),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final activitiesState = ref.watch(leadActivityProvider);
    final followupsState = ref.watch(followupsProvider);

    final leadFollowups = (followupsState.value ?? []).where((f) => f.leadId == _lead.leadId).toList();
    final leadActivities = activitiesState.value ?? [];

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBgColor = isDark ? Theme.of(context).scaffoldBackgroundColor : const Color(0xFFF7F9FB);
    final cardBgColor = isDark ? Theme.of(context).cardColor : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtitleColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final dividerColor = isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9);
    final inputBgColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);

    return Scaffold(
      backgroundColor: scaffoldBgColor,
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
          _lead.customerName,
          style: TextStyle(color: titleColor, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
        ),
        actions: [
          Builder(
            builder: (context) {
              final permService = ref.watch(permissionServiceProvider);
              final canEdit = permService.hasPermission('lead_edit') || permService.hasPermission('lead.edit');
              final canDelete = permService.hasPermission('lead_delete') || permService.hasPermission('lead.delete');
              final canConvert = (permService.hasPermission('lead_convert_order') || permService.hasPermission('lead.convert.order')) &&
                  (permService.hasPermission('order_create') || permService.hasPermission('order.create'));

              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Status Dropdown / Badge
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    child: canEdit
                        ? DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _lead.status,
                              icon: Icon(Icons.keyboard_arrow_down_rounded, color: subtitleColor),
                              dropdownColor: cardBgColor,
                              selectedItemBuilder: (ctx) {
                                return ['New', 'Follow Up', 'Quotation Sent', 'Converted', 'Closed'].map((s) {
                                  return Container(
                                    alignment: Alignment.center,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(_lead.status).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      _lead.status,
                                      style: TextStyle(color: _getStatusColor(_lead.status), fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
                                    ),
                                  );
                                }).toList();
                              },
                              items: [
                                DropdownMenuItem(value: 'New', child: Text('New', style: TextStyle(color: titleColor))),
                                DropdownMenuItem(value: 'Follow Up', child: Text('Follow Up', style: TextStyle(color: titleColor))),
                                DropdownMenuItem(value: 'Quotation Sent', child: Text('Quotation Sent', style: TextStyle(color: titleColor))),
                                DropdownMenuItem(value: 'Converted', child: Text('Converted', style: TextStyle(color: titleColor))),
                                DropdownMenuItem(value: 'Closed', child: Text('Closed', style: TextStyle(color: titleColor))),
                              ],
                              onChanged: (val) {
                                if (val != null) _updateStatus(val);
                              },
                            ),
                          )
                        : Container(
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getStatusColor(_lead.status).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _lead.status,
                              style: TextStyle(color: _getStatusColor(_lead.status), fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
                            ),
                          ),
                  ),

                  // Convert to Order CTA (if canConvert)
                  if (canConvert && _lead.status.toLowerCase() != 'converted' && _lead.status.toLowerCase() != 'won')
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ElevatedButton.icon(
                        onPressed: () => context.push('/order-form', extra: _lead),
                        icon: const Icon(Icons.shopping_cart_checkout_rounded, size: 16),
                        label: const Text('Convert', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'Outfit')),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF16A34A),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),

                  // Delete Lead Action
                  if (canDelete)
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444)),
                      tooltip: 'Delete Lead',
                      onPressed: _confirmDeleteLead,
                    ),
                  const SizedBox(width: 8),
                ],
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 750;
            if (isWide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // LEFT COLUMN: Details Cards
                  Expanded(
                    flex: 5,
                    child: Column(
                      children: [
                        _buildCustomerCard(cardBgColor, titleColor, subtitleColor, borderColor, dividerColor),
                        const SizedBox(height: 16),
                        _buildScopeCard(cardBgColor, titleColor, subtitleColor, borderColor, dividerColor),
                        const SizedBox(height: 16),
                        _buildOwnerCard(cardBgColor, titleColor, subtitleColor, borderColor),
                        const SizedBox(height: 16),
                        _buildAttachmentsCard(cardBgColor, titleColor, subtitleColor, borderColor, dividerColor),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  // RIGHT COLUMN: Timeline & Quick Logger
                  Expanded(
                    flex: 7,
                    child: _buildTimelineSection(leadActivities, leadFollowups, cardBgColor, titleColor, subtitleColor, borderColor, dividerColor, inputBgColor),
                  ),
                ],
              );
            } else {
              return Column(
                children: [
                  _buildCustomerCard(cardBgColor, titleColor, subtitleColor, borderColor, dividerColor),
                  const SizedBox(height: 16),
                  _buildScopeCard(cardBgColor, titleColor, subtitleColor, borderColor, dividerColor),
                  const SizedBox(height: 16),
                  _buildOwnerCard(cardBgColor, titleColor, subtitleColor, borderColor),
                  const SizedBox(height: 16),
                  _buildAttachmentsCard(cardBgColor, titleColor, subtitleColor, borderColor, dividerColor),
                  const SizedBox(height: 24),
                  _buildTimelineSection(leadActivities, leadFollowups, cardBgColor, titleColor, subtitleColor, borderColor, dividerColor, inputBgColor),
                ],
              );
            }
          },
        ),
      ),
    );
  }

  Widget _buildCustomerCard(Color cardBg, Color titleColor, Color subtitleColor, Color borderColor, Color dividerColor) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: const [BoxShadow(color: Color(0x05000000), blurRadius: 10, offset: Offset(0, 4))],
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
                  const Icon(Icons.person_outline_rounded, size: 18, color: Color(0xFF5B4CF0)),
                  const SizedBox(width: 8),
                  Text('Customer Information', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: titleColor, fontFamily: 'Outfit')),
                ],
              ),
              Builder(
                builder: (context) {
                  final permService = ref.watch(permissionServiceProvider);
                  final canEdit = permService.hasPermission('lead_edit') || permService.hasPermission('lead.edit');
                  if (!canEdit) return const SizedBox.shrink();
                  return IconButton(
                    icon: Icon(Icons.edit_outlined, size: 18, color: subtitleColor),
                    onPressed: () => context.push('/lead-form', extra: _lead),
                  );
                },
              ),
            ],
          ),
          Divider(height: 24, color: dividerColor),
          _buildInfoRow(Icons.person_rounded, 'Name', _lead.customerName, titleColor, subtitleColor),
          const SizedBox(height: 12),
          _buildInfoRow(Icons.phone_rounded, 'Mobile', _lead.mobileNumber, titleColor, subtitleColor),
          if (_lead.email != null && _lead.email!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildInfoRow(Icons.mail_rounded, 'Email', _lead.email!, titleColor, subtitleColor),
          ],
          if (_lead.companyName.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildInfoRow(Icons.business_rounded, 'Company', _lead.companyName, titleColor, subtitleColor),
          ],
          if (_lead.location.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildInfoRow(Icons.location_on_rounded, 'Location', _lead.location, titleColor, subtitleColor),
          ],
        ],
      ),
    );
  }

  Widget _buildScopeCard(Color cardBg, Color titleColor, Color subtitleColor, Color borderColor, Color dividerColor) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: const [BoxShadow(color: Color(0x05000000), blurRadius: 10, offset: Offset(0, 4))],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.description_outlined, size: 18, color: Color(0xFF5B4CF0)),
              const SizedBox(width: 8),
              Text('Requirement & Source', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: titleColor, fontFamily: 'Outfit')),
            ],
          ),
          Divider(height: 24, color: dividerColor),
          Text('Requirement Scope:', style: TextStyle(fontSize: 12, color: subtitleColor, fontFamily: 'Outfit')),
          const SizedBox(height: 4),
          Text(_lead.requirement.isNotEmpty ? _lead.requirement : 'N/A', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: titleColor, fontFamily: 'Outfit')),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Lead Source:', style: TextStyle(fontSize: 12, color: subtitleColor, fontFamily: 'Outfit')),
                  const SizedBox(height: 2),
                  Text(_lead.leadSource, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF5B4CF0), fontFamily: 'Outfit')),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Created On:', style: TextStyle(fontSize: 12, color: subtitleColor, fontFamily: 'Outfit')),
                  const SizedBox(height: 2),
                  Text(DateFormat('dd MMM yyyy').format(_lead.createdAt), style: TextStyle(fontSize: 13, color: titleColor, fontFamily: 'Outfit')),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOwnerCard(Color cardBg, Color titleColor, Color subtitleColor, Color borderColor) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: const [BoxShadow(color: Color(0x05000000), blurRadius: 10, offset: Offset(0, 4))],
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xFF5B4CF0).withValues(alpha: 0.1),
            child: const Icon(Icons.person_pin_rounded, color: Color(0xFF5B4CF0)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Assigned Representative', style: TextStyle(fontSize: 12, color: subtitleColor, fontFamily: 'Outfit')),
                Text(_lead.assignedTo, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: titleColor, fontFamily: 'Outfit')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentsCard(Color cardBg, Color titleColor, Color subtitleColor, Color borderColor, Color dividerColor) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: const [BoxShadow(color: Color(0x05000000), blurRadius: 10, offset: Offset(0, 4))],
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
                  const Icon(Icons.attach_file_rounded, size: 18, color: Color(0xFF5B4CF0)),
                  const SizedBox(width: 8),
                  Text('Documents & Attachments', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: titleColor, fontFamily: 'Outfit')),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.cloud_upload_outlined, size: 20, color: Color(0xFF5B4CF0)),
                onPressed: () async {
                  final result = await FilePicker.pickFiles();
                  if (result != null && result.files.isNotEmpty) {
                    final file = result.files.first;
                    final user = ref.read(authProvider).user;
                    if (user == null) return;
                    
                    final attachment = LeadAttachmentModel(
                      leadId: _lead.leadId,
                      companyId: user.companyId,
                      fileName: file.name,
                      fileUrl: 'https://example.com/attachments/${file.name}',
                      uploadedAt: DateTime.now(),
                    );
                    await FirebaseFirestore.instance.collection('leadAttachments').add(attachment.toMap());
                    await _loadAttachments();
                  }
                },
              ),
            ],
          ),
          Divider(height: 16, color: dividerColor),
          if (_attachments.isEmpty)
            Text('No documents attached yet.', style: TextStyle(fontSize: 12, color: subtitleColor, fontFamily: 'Outfit'))
          else
            Column(
              children: _attachments.map((att) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.insert_drive_file_outlined, color: Color(0xFF5B4CF0)),
                  title: Text(att.fileName, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: titleColor, fontFamily: 'Outfit')),
                  subtitle: Text('Uploaded ${DateFormat('dd MMM').format(att.uploadedAt)}', style: TextStyle(fontSize: 11, color: subtitleColor)),
                  trailing: IconButton(
                    icon: Icon(Icons.open_in_new_rounded, size: 16, color: subtitleColor),
                    onPressed: () => launchUrl(Uri.parse(att.fileUrl)),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildTimelineSection(
    List<LeadActivityModel> activities,
    List<FollowupModel> followups,
    Color cardBg,
    Color titleColor,
    Color subtitleColor,
    Color borderColor,
    Color dividerColor,
    Color inputBg,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: const [BoxShadow(color: Color(0x05000000), blurRadius: 10, offset: Offset(0, 4))],
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
                  Text('Activity Timeline & Logs', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: titleColor, fontFamily: 'Outfit')),
                ],
              ),
              Text('${activities.length + followups.length} entries', style: TextStyle(fontSize: 12, color: subtitleColor, fontFamily: 'Outfit')),
            ],
          ),
          Divider(height: 24, color: dividerColor),

          // Timeline Log Entries
          if (activities.isEmpty && followups.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('No timeline activities logged yet.', style: TextStyle(fontSize: 13, color: subtitleColor, fontFamily: 'Outfit')),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: activities.length,
              itemBuilder: (ctx, idx) {
                final act = activities[idx];
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: const Color(0xFF5B4CF0).withValues(alpha: 0.1),
                        child: const Icon(Icons.chat_bubble_outline_rounded, size: 14, color: Color(0xFF5B4CF0)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(act.activityType, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: titleColor, fontFamily: 'Outfit')),
                                Text(DateFormat('dd MMM, hh:mm a').format(act.createdAt), style: TextStyle(fontSize: 11, color: subtitleColor, fontFamily: 'Outfit')),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(act.description, style: TextStyle(fontSize: 13, color: subtitleColor, fontFamily: 'Outfit')),
                            const SizedBox(height: 2),
                            Text('Logged by ${act.performedBy}', style: TextStyle(fontSize: 11, color: subtitleColor, fontFamily: 'Outfit')),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

          Divider(height: 24, color: dividerColor),

          // Quick Note Logger Box
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _quickNoteController,
                  style: TextStyle(color: titleColor, fontSize: 13, fontFamily: 'Outfit'),
                  decoration: InputDecoration(
                    hintText: 'Type a quick activity note...',
                    hintStyle: TextStyle(color: subtitleColor, fontSize: 13, fontFamily: 'Outfit'),
                    filled: true,
                    fillColor: inputBg,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF5B4CF0), width: 1.5)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _submitQuickNote,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5B4CF0),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Icon(Icons.send_rounded, size: 18),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, Color titleColor, Color subtitleColor) {
    return Row(
      children: [
        Icon(icon, size: 16, color: subtitleColor),
        const SizedBox(width: 8),
        Text('$label: ', style: TextStyle(fontSize: 13, color: subtitleColor, fontFamily: 'Outfit')),
        Expanded(
          child: Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: titleColor, fontFamily: 'Outfit')),
        ),
      ],
    );
  }
}
