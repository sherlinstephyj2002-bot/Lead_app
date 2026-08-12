import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/providers/permissions_provider.dart';
import '../../../shared/models/lead_model.dart';
import '../../../shared/models/followup_model.dart';
import '../../../shared/models/user_model.dart';
import '../../../shared/utils/csv_export_helper.dart';
import '../../../shared/services/file_download_service.dart';

class LeadListScreen extends ConsumerStatefulWidget {
  const LeadListScreen({super.key});

  @override
  ConsumerState<LeadListScreen> createState() => _LeadListScreenState();
}

class _LeadListScreenState extends ConsumerState<LeadListScreen> {
  String _selectedFilterChip = 'All Leads';
  final List<String> _filterChips = ['All Leads', 'New', 'Follow Up', 'Quotation Sent', 'Converted', 'Closed'];
  String _searchQuery = '';
  final _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSearching = false;
  bool _isLoadingMore = false;

  bool _isSelectionMode = false;
  final Set<String> _selectedLeadIds = {};

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    Future.microtask(() {
      ref.read(leadsProvider.notifier).loadLeads(reset: true);
      ref.read(followupsProvider.notifier).loadFollowups();
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _isLoadingMore) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    if (currentScroll >= maxScroll - 200) {
      final notifier = ref.read(leadsProvider.notifier);
      if (notifier.hasMoreLeads) {
        _loadMoreLeads();
      }
    }
  }

  Future<void> _loadMoreLeads() async {
    setState(() => _isLoadingMore = true);
    await ref.read(leadsProvider.notifier).loadMoreLeads();
    if (mounted) {
      setState(() => _isLoadingMore = false);
    }
  }

  void _bulkDeleteConfirm() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Bulk Delete', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete ${_selectedLeadIds.length} lead(s)? This action is permanent.', style: const TextStyle(fontFamily: 'Outfit')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: () async {
              Navigator.pop(ctx);
              final idsToDelete = _selectedLeadIds.toList();
              setState(() {
                _isSelectionMode = false;
                _selectedLeadIds.clear();
              });
              await ref.read(leadsProvider.notifier).bulkDeleteLeads(idsToDelete);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Leads deleted successfully.'), behavior: SnackBarBehavior.floating),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _bulkStatusDialog() {
    String status = 'New';
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Bulk Change Status', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Select new status for selected leads:', style: TextStyle(fontFamily: 'Outfit', fontSize: 13, color: Color(0xFF64748B))),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: status,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                ),
                items: const [
                  DropdownMenuItem(value: 'New', child: Text('New')),
                  DropdownMenuItem(value: 'Follow Up', child: Text('Follow Up')),
                  DropdownMenuItem(value: 'Quotation Sent', child: Text('Quotation Sent')),
                  DropdownMenuItem(value: 'Converted', child: Text('Converted')),
                  DropdownMenuItem(value: 'Closed', child: Text('Closed')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setDialogState(() => status = val);
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
                final idsToUpdate = _selectedLeadIds.toList();
                setState(() {
                  _isSelectionMode = false;
                  _selectedLeadIds.clear();
                });
                await ref.read(leadsProvider.notifier).bulkUpdateStatus(idsToUpdate, status);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Updated status for ${idsToUpdate.length} leads.'), behavior: SnackBarBehavior.floating),
                  );
                }
              },
              child: const Text('Update', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _bulkAssignDialog() {
    final employeesAsync = ref.read(companyEmployeesProvider);
    final currentUser = ref.read(authProvider).user;
    
    employeesAsync.whenData((employees) {
      final allAssignees = [currentUser, ...employees].whereType<UserModel>().toList();
      final uniqueAssignees = {for (var e in allAssignees) e.uid: e}.values.toList();
      
      if (uniqueAssignees.isEmpty) return;
      
      String selectedUid = uniqueAssignees.first.uid;
      String selectedName = uniqueAssignees.first.name;

      showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (dialogCtx, setDialogState) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Bulk Assign Leads', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Select team member to assign:', style: TextStyle(fontFamily: 'Outfit', fontSize: 13, color: Color(0xFF64748B))),
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
                  final idsToAssign = _selectedLeadIds.toList();
                  setState(() {
                    _isSelectionMode = false;
                    _selectedLeadIds.clear();
                  });
                  await ref.read(leadsProvider.notifier).bulkAssignLeads(idsToAssign, selectedUid, selectedName);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Assigned ${idsToAssign.length} leads to $selectedName.'), behavior: SnackBarBehavior.floating),
                    );
                  }
                },
                child: const Text('Assign', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      );
    });
  }

  void _exportLeadsToCsv(List<LeadModel> leads) async {
    final List<List<dynamic>> rows = [
      ['Lead ID', 'Customer Name', 'Mobile Number', 'Company Name', 'Email', 'Location', 'Requirement', 'Status', 'Lead Source', 'Assigned To', 'Created At'],
    ];

    for (final l in leads) {
      rows.add([
        CsvExportHelper.formatId(l.leadId),
        CsvExportHelper.sanitizeText(l.customerName),
        CsvExportHelper.formatPhone(l.mobileNumber),
        CsvExportHelper.sanitizeText(l.companyName),
        l.email ?? '',
        CsvExportHelper.sanitizeText(l.location),
        CsvExportHelper.sanitizeText(l.requirement),
        CsvExportHelper.sanitizeText(l.status),
        CsvExportHelper.sanitizeText(l.leadSource),
        CsvExportHelper.sanitizeText(l.assignedTo),
        CsvExportHelper.formatDateTime(l.createdAt),
      ]);
    }

    final csvData = const ListToCsvConverter().convert(rows);
    await FileDownloadService.downloadCsv(csvContent: csvData, fileName: 'Leads_Report.csv');
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Leads_Report.csv downloaded (${leads.length} leads).'),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _pickAndImportCsv() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final fileBytes = result.files.first.bytes;
        if (fileBytes != null) {
          final csvString = utf8.decode(fileBytes);
          final fields = const CsvToListConverter().convert(csvString);

          if (fields.length < 2) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('CSV file appears empty or invalid header.'), behavior: SnackBarBehavior.floating),
            );
            return;
          }

          final headers = fields.first.map((e) => e.toString().trim().toLowerCase()).toList();
          final dataRows = fields.sublist(1);

          final List<Map<String, String?>> parsedRows = [];
          for (final row in dataRows) {
            if (row.isEmpty) continue;
            final map = <String, String?>{};
            for (int i = 0; i < headers.length && i < row.length; i++) {
              map[headers[i]] = row[i]?.toString().trim();
            }
            parsedRows.add(map);
          }

          await ref.read(leadsProvider.notifier).importLeadsFromCsv(parsedRows);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Successfully imported ${parsedRows.length} leads from CSV.'), behavior: SnackBarBehavior.floating),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to import CSV: $e'), behavior: SnackBarBehavior.floating),
        );
      }
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

  void _confirmDeleteSingleLead(LeadModel lead) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Lead?', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to remove ${lead.customerName}? This action cannot be undone.', style: const TextStyle(fontFamily: 'Outfit')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(leadsProvider.notifier).deleteLead(lead.leadId);
              if (mounted) {
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

  @override
  Widget build(BuildContext context) {
    final leadsState = ref.watch(leadsProvider);
    final followupsAsync = ref.watch(followupsProvider);

    final Map<String, FollowupModel> nextFollowupMap = {};
    followupsAsync.whenData((followups) {
      for (final f in followups) {
        if (f.status == 'Upcoming' || f.status == 'Pending') {
          if (!nextFollowupMap.containsKey(f.leadId) || f.followUpDate.isBefore(nextFollowupMap[f.leadId]!.followUpDate)) {
            nextFollowupMap[f.leadId] = f;
          }
        }
      }
    });

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBgColor = isDark ? Theme.of(context).cardColor : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtitleColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: isDark ? Theme.of(context).scaffoldBackgroundColor : const Color(0xFFF7F9FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFF5B4CF0),
        elevation: 0,
        toolbarHeight: 64,
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.white, fontFamily: 'Outfit'),
                decoration: const InputDecoration(
                  hintText: 'Search leads by customer, company, phone...',
                  hintStyle: TextStyle(color: Colors.white70, fontFamily: 'Outfit'),
                  border: InputBorder.none,
                ),
                onChanged: (val) => setState(() => _searchQuery = val),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Lead Management', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'Outfit')),
                  const SizedBox(height: 2),
                  Text('Manage, track, and convert your company\'s leads.', style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12, fontFamily: 'Outfit')),
                ],
              ),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search, color: Colors.white),
            onPressed: () {
              setState(() {
                if (_isSearching) {
                  _isSearching = false;
                  _searchQuery = '';
                  _searchController.clear();
                } else {
                  _isSearching = true;
                }
              });
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
            onSelected: (val) {
              if (val == 'import') {
                _pickAndImportCsv();
              } else if (val == 'export') {
                final currentLeads = leadsState.value ?? [];
                _exportLeadsToCsv(currentLeads);
              }
            },
            itemBuilder: (ctx) => const [
              PopupMenuItem(value: 'import', child: Row(children: [Icon(Icons.file_upload_outlined, size: 18, color: Color(0xFF5B4CF0)), SizedBox(width: 8), Text('Import CSV')])),
              PopupMenuItem(value: 'export', child: Row(children: [Icon(Icons.file_download_outlined, size: 18, color: Color(0xFF5B4CF0)), SizedBox(width: 8), Text('Export CSV')])),
            ],
          ),
        ],
      ),
      floatingActionButton: ref.watch(permissionServiceProvider).hasPermission('lead_create')
          ? FloatingActionButton.extended(
              heroTag: 'leadFab',
              onPressed: () => context.push('/lead-form'),
              backgroundColor: const Color(0xFF5B4CF0),
              foregroundColor: Colors.white,
              elevation: 4,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Lead', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
            )
          : null,
      body: leadsState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Error: $err', style: const TextStyle(color: Color(0xFFEF4444))),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => ref.read(leadsProvider.notifier).loadLeads(reset: true),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (allLeads) {
          final totalCount = allLeads.length;
          final newCount = allLeads.where((l) => l.status.toLowerCase() == 'new').length;
          final followUpCount = allLeads.where((l) => l.status.toLowerCase() == 'follow up').length;
          final convertedCount = allLeads.where((l) => l.status.toLowerCase() == 'converted').length;
          final closedCount = allLeads.where((l) => l.status.toLowerCase() == 'closed').length;

          var filteredLeads = allLeads.where((l) {
            final matchesSearch = l.customerName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                l.companyName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                l.mobileNumber.contains(_searchQuery) ||
                l.location.toLowerCase().contains(_searchQuery.toLowerCase());

            if (!matchesSearch) return false;

            if (_selectedFilterChip == 'All Leads') return true;
            return l.status.toLowerCase() == _selectedFilterChip.toLowerCase();
          }).toList();

          return RefreshIndicator(
            onRefresh: () async {
              await ref.read(leadsProvider.notifier).loadLeads(reset: true);
            },
            child: CustomScrollView(
              controller: _scrollController,
              slivers: [
                // METRIC CARDS HEADER
                SliverToBoxAdapter(
                  child: Container(
                    color: cardBgColor,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildKpiCard('Total Leads', totalCount.toString(), Icons.people_outline_rounded, const Color(0xFF5B4CF0), cardBgColor, borderColor, subtitleColor),
                          const SizedBox(width: 12),
                          _buildKpiCard('New', newCount.toString(), Icons.fiber_new_rounded, const Color(0xFF2563EB), cardBgColor, borderColor, subtitleColor),
                          const SizedBox(width: 12),
                          _buildKpiCard('Follow Up', followUpCount.toString(), Icons.event_repeat_rounded, const Color(0xFFD97706), cardBgColor, borderColor, subtitleColor),
                          const SizedBox(width: 12),
                          _buildKpiCard('Converted', convertedCount.toString(), Icons.check_circle_outline_rounded, const Color(0xFF16A34A), cardBgColor, borderColor, subtitleColor),
                          const SizedBox(width: 12),
                          _buildKpiCard('Closed', closedCount.toString(), Icons.cancel_outlined, const Color(0xFFDC2626), cardBgColor, borderColor, subtitleColor),
                        ],
                      ),
                    ),
                  ),
                ),

                // STATUS TAB FILTER BAR
                SliverToBoxAdapter(
                  child: Container(
                    color: cardBgColor,
                    padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _filterChips.map((chip) {
                          final isSelected = _selectedFilterChip == chip;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(chip, style: TextStyle(
                                fontFamily: 'Outfit',
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                color: isSelected ? Colors.white : subtitleColor,
                              )),
                              selected: isSelected,
                              selectedColor: const Color(0xFF5B4CF0),
                              backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              onSelected: (val) {
                                if (val) setState(() => _selectedFilterChip = chip);
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),

                // BULK ACTION TOOLBAR (if selection mode active)
                if (_isSelectionMode)
                  SliverToBoxAdapter(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF5B4CF0).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF5B4CF0).withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          Text('${_selectedLeadIds.length} Selected', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF5B4CF0), fontFamily: 'Outfit')),
                          const Spacer(),
                          IconButton(icon: const Icon(Icons.swap_horiz_rounded, color: Color(0xFF5B4CF0)), tooltip: 'Change Status', onPressed: _bulkStatusDialog),
                          IconButton(icon: const Icon(Icons.person_add_alt_1_rounded, color: Color(0xFF5B4CF0)), tooltip: 'Assign', onPressed: _bulkAssignDialog),
                          IconButton(icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444)), tooltip: 'Delete', onPressed: _bulkDeleteConfirm),
                          IconButton(icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)), onPressed: () => setState(() { _isSelectionMode = false; _selectedLeadIds.clear(); })),
                        ],
                      ),
                    ),
                  ),

                // LEAD LIST ITEMS
                if (filteredLeads.isEmpty)
                  SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inbox_rounded, size: 64, color: Colors.grey.shade300),
                          const SizedBox(height: 12),
                          const Text('No leads found', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF64748B), fontFamily: 'Outfit')),
                          const SizedBox(height: 4),
                          const Text('Try adjusting filters or tap + Add Lead', style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8), fontFamily: 'Outfit')),
                        ],
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          if (index == filteredLeads.length) {
                            return _isLoadingMore
                                ? const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()))
                                : const SizedBox.shrink();
                          }

                          final lead = filteredLeads[index];
                          final isSelected = _selectedLeadIds.contains(lead.leadId);
                          final followup = nextFollowupMap[lead.leadId];
                          final initials = lead.customerName.isNotEmpty
                              ? lead.customerName.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join('').toUpperCase()
                              : 'L';

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: cardBgColor,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: isSelected ? const Color(0xFF5B4CF0) : borderColor, width: isSelected ? 2 : 1),
                              boxShadow: [
                                BoxShadow(color: isDark ? Colors.black26 : const Color(0x06000000), blurRadius: 10, offset: const Offset(0, 4)),
                              ],
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onLongPress: () {
                                setState(() {
                                  _isSelectionMode = true;
                                  _selectedLeadIds.add(lead.leadId);
                                });
                              },
                              onTap: () {
                                if (_isSelectionMode) {
                                  setState(() {
                                    if (isSelected) {
                                      _selectedLeadIds.remove(lead.leadId);
                                      if (_selectedLeadIds.isEmpty) _isSelectionMode = false;
                                    } else {
                                      _selectedLeadIds.add(lead.leadId);
                                    }
                                  });
                                } else {
                                  context.push('/lead-detail/${lead.leadId}', extra: lead);
                                }
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Row 1: Avatar, Name, Status, Options
                                    Row(
                                      children: [
                                        if (_isSelectionMode)
                                          Checkbox(
                                            value: isSelected,
                                            activeColor: const Color(0xFF5B4CF0),
                                            onChanged: (val) {
                                              setState(() {
                                                if (val == true) {
                                                  _selectedLeadIds.add(lead.leadId);
                                                } else {
                                                  _selectedLeadIds.remove(lead.leadId);
                                                  if (_selectedLeadIds.isEmpty) _isSelectionMode = false;
                                                }
                                              });
                                            },
                                          )
                                        else
                                          CircleAvatar(
                                            radius: 20,
                                            backgroundColor: const Color(0xFF5B4CF0).withValues(alpha: 0.1),
                                            child: Text(initials, style: const TextStyle(color: Color(0xFF5B4CF0), fontWeight: FontWeight.bold, fontFamily: 'Outfit')),
                                          ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(lead.customerName, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: titleColor, fontFamily: 'Outfit')),
                                              if (lead.companyName.isNotEmpty)
                                                Text(lead.companyName, style: TextStyle(fontSize: 13, color: subtitleColor, fontFamily: 'Outfit')),
                                            ],
                                          ),
                                        ),
                                        // Status Pill Badge
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: _getStatusColor(lead.status).withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            lead.status,
                                            style: TextStyle(color: _getStatusColor(lead.status), fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
                                          ),
                                        ),
                                        Builder(
                                            builder: (context) {
                                              final permService = ref.watch(permissionServiceProvider);
                                              final canEdit = permService.hasPermission('lead_edit') || permService.hasPermission('lead.edit');
                                              final canDelete = permService.hasPermission('lead_delete') || permService.hasPermission('lead.delete');
                                              final canConvert = (permService.hasPermission('lead_convert_order') || permService.hasPermission('lead.convert.order')) &&
                                                  (permService.hasPermission('order_create') || permService.hasPermission('order.create'));

                                              if (!canEdit && !canDelete && !canConvert) return const SizedBox.shrink();

                                              return PopupMenuButton<String>(
                                                icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF94A3B8)),
                                                onSelected: (val) {
                                                  if (val == 'edit') {
                                                    context.push('/lead-form', extra: lead);
                                                  } else if (val == 'convert') {
                                                    context.push('/order-form', extra: lead);
                                                  } else if (val == 'delete') {
                                                    _confirmDeleteSingleLead(lead);
                                                  }
                                                },
                                                itemBuilder: (ctx) => [
                                                  if (canEdit)
                                                    const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_outlined, size: 18), SizedBox(width: 8), Text('Edit')])),
                                                  if (canConvert)
                                                    const PopupMenuItem(value: 'convert', child: Row(children: [Icon(Icons.shopping_cart_checkout_rounded, size: 18, color: Color(0xFF16A34A)), SizedBox(width: 8), Text('Convert to Order')])),
                                                  if (canDelete)
                                                    const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFDC2626)), SizedBox(width: 8), Text('Delete')])),
                                                ],
                                              );
                                            },
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),

                                    // Location & Contact
                                    Row(
                                      children: [
                                        if (lead.location.isNotEmpty) ...[
                                          const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF94A3B8)),
                                          const SizedBox(width: 4),
                                          Text(lead.location, style: TextStyle(fontSize: 12, color: subtitleColor, fontFamily: 'Outfit')),
                                          const SizedBox(width: 16),
                                        ],
                                        const Icon(Icons.phone_outlined, size: 14, color: Color(0xFF94A3B8)),
                                        const SizedBox(width: 4),
                                        Text(lead.mobileNumber, style: TextStyle(fontSize: 12, color: subtitleColor, fontFamily: 'Outfit')),
                                      ],
                                    ),

                                    // Next Followup Banner (if scheduled)
                                    if (followup != null) ...[
                                      const SizedBox(height: 12),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: isDark ? const Color(0xFF451A03) : const Color(0xFFFEF3C7),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.event_note_rounded, size: 14, color: Color(0xFFD97706)),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                'Next Follow-up: ${DateFormat('dd MMM yyyy, hh:mm a').format(followup.followUpDate)}',
                                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E), fontFamily: 'Outfit'),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],

                                    const SizedBox(height: 12),
                                    Divider(height: 1, color: borderColor),
                                    const SizedBox(height: 8),

                                    // Assignee & Date Footer
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(Icons.person_outline_rounded, size: 14, color: Color(0xFF94A3B8)),
                                            const SizedBox(width: 4),
                                            Text(lead.assignedTo, style: TextStyle(fontSize: 12, color: subtitleColor, fontFamily: 'Outfit')),
                                          ],
                                        ),
                                        Text(
                                          DateFormat('dd MMM').format(lead.createdAt),
                                          style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontFamily: 'Outfit'),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                        childCount: filteredLeads.length + 1,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildKpiCard(String label, String count, IconData icon, Color accentColor, Color cardBgColor, Color borderColor, Color subtitleColor) {
    return Container(
      width: 120,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(color: const Color(0x04000000), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, size: 18, color: accentColor),
              Text(count, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: accentColor, fontFamily: 'Outfit')),
            ],
          ),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(fontSize: 11, color: subtitleColor, fontFamily: 'Outfit')),
        ],
      ),
    );
  }
}
