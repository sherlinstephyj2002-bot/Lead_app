import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:worktrack/shared/providers/providers.dart';
import 'package:worktrack/features/company_admin/models/shift_model.dart';
import 'package:worktrack/features/company_admin/providers/company_admin_providers.dart';

class ShiftManagementScreen extends ConsumerStatefulWidget {
  const ShiftManagementScreen({super.key});

  @override
  ConsumerState<ShiftManagementScreen> createState() => _ShiftManagementScreenState();
}

class _ShiftManagementScreenState extends ConsumerState<ShiftManagementScreen> {
  String _selectedStatusFilter = 'All';
  String _searchQuery = '';
  int _currentPage = 0;
  final int _itemsPerPage = 6;
  late TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shiftsAsync = ref.watch(adminShiftsProvider);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? Theme.of(context).scaffoldBackgroundColor : const Color(0xFFF7F8FC);
    final cardBg = isDark ? Theme.of(context).cardColor : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final borderCol = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        title: const Text('Work Shift Management', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF5B4CF0))),
        backgroundColor: cardBg,
        foregroundColor: titleColor,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: borderCol, height: 1),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF5B4CF0)),
            onPressed: () => ref.read(adminShiftsProvider.notifier).loadShifts(),
          ),
        ],
      ),
      body: shiftsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error loading shifts: $err', style: const TextStyle(color: Colors.red))),
        data: (shifts) {
          // Local Filter & Search
          final filteredShifts = shifts.where((shift) {
            // Status Filter
            if (_selectedStatusFilter != 'All') {
              if (_selectedStatusFilter == 'Active' && shift.status.toLowerCase() != 'active') return false;
              if (_selectedStatusFilter == 'Suspended' && shift.status.toLowerCase() != 'suspended') return false;
              if (_selectedStatusFilter == 'Archived' && shift.status.toLowerCase() != 'archived') return false;
            }
            // Search Query
            if (_searchQuery.isNotEmpty) {
              final q = _searchQuery.toLowerCase();
              return shift.shiftName.toLowerCase().contains(q) ||
                  shift.shiftCode.toLowerCase().contains(q);
            }
            return true;
          }).toList();

          // Pagination
          final totalItems = filteredShifts.length;
          final totalPages = (totalItems / _itemsPerPage).ceil();
          if (_currentPage >= totalPages && totalPages > 0) {
            _currentPage = totalPages - 1;
          }
          final startIndex = _currentPage * _itemsPerPage;
          final endIndex = startIndex + _itemsPerPage > totalItems ? totalItems : startIndex + _itemsPerPage;
          final paginatedShifts = totalItems > 0 ? filteredShifts.sublist(startIndex, endIndex) : <ShiftModel>[];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header & Action Row
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isCompact = constraints.maxWidth < 600;
                    if (isCompact) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Company Work Shifts',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF1E293B)),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Configure shift timings, break periods, overtime thresholds and weekly off rules.',
                            style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => _showShiftForm(context, existingShift: null),
                              icon: const Icon(Icons.add_rounded, size: 18),
                              label: const Text('Add Shift', style: TextStyle(fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF5B4CF0),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ],
                      );
                    }
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Company Work Shifts',
                                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF1E293B)),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Configure shift timings, break periods, overtime thresholds and weekly off rules.',
                                style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton.icon(
                          onPressed: () => _showShiftForm(context, existingShift: null),
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('Add Shift', style: TextStyle(fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF5B4CF0),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),

                // Search & Filter Card
                LayoutBuilder(
                  builder: (context, searchConstraints) {
                    final isCompactSearch = searchConstraints.maxWidth < 500;
                    final searchField = TextFormField(
                      controller: _searchController,
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val;
                          _currentPage = 0;
                        });
                      },
                      style: TextStyle(fontSize: 14, color: isDark ? Colors.white : const Color(0xFF1E293B)),
                      decoration: InputDecoration(
                        hintText: 'Search shifts by name or code...',
                        hintStyle: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF94A3B8), fontSize: 13),
                        prefixIcon: Icon(Icons.search_rounded, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), size: 20),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    _searchQuery = '';
                                    _currentPage = 0;
                                  });
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: borderCol),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: borderCol),
                        ),
                      ),
                    );

                    final statusFilter = Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderCol),
                      ),
                      child: DropdownButton<String>(
                        value: _selectedStatusFilter,
                        dropdownColor: cardBg,
                        underline: const SizedBox(),
                        isExpanded: isCompactSearch,
                        icon: Icon(Icons.arrow_drop_down_rounded, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                        style: TextStyle(color: isDark ? Colors.white : const Color(0xFF1E293B), fontWeight: FontWeight.bold, fontSize: 13),
                        items: ['All', 'Active', 'Suspended', 'Archived'].map((String val) {
                          return DropdownMenuItem<String>(
                            value: val,
                            child: Text('Status: $val'),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _selectedStatusFilter = val;
                              _currentPage = 0;
                            });
                          }
                        },
                      ),
                    );

                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderCol),
                      ),
                      child: isCompactSearch
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                searchField,
                                const SizedBox(height: 12),
                                statusFilter,
                              ],
                            )
                          : Row(
                              children: [
                                Expanded(child: searchField),
                                const SizedBox(width: 16),
                                statusFilter,
                              ],
                            ),
                    );
                  },
                ),
                const SizedBox(height: 24),

                // Card Grid View
                if (totalItems == 0)
                  Container(
                    height: 200,
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderCol),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.schedule_rounded, size: 48, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                          const SizedBox(height: 12),
                          Text('No work shifts found matching criteria.', style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                        ],
                      ),
                    ),
                  )
                else ...[
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final cols = constraints.maxWidth > 900 ? 3 : (constraints.maxWidth > 600 ? 2 : 1);
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: paginatedShifts.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: cols,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 1.35,
                        ),
                        itemBuilder: (context, idx) {
                          final shift = paginatedShifts[idx];

                          Color statusBg;
                          Color statusText;
                          switch (shift.status.toLowerCase()) {
                            case 'active':
                              statusBg = isDark ? const Color(0xFF064E3B) : const Color(0xFFDCFCE7);
                              statusText = isDark ? const Color(0xFF34D399) : const Color(0xFF007834);
                              break;
                            case 'suspended':
                              statusBg = isDark ? const Color(0xFF78350F) : const Color(0xFFFEF3C7);
                              statusText = isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706);
                              break;
                            default:
                              statusBg = isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9);
                              statusText = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
                          }

                          return Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: borderCol),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF5B4CF0).withValues(alpha: isDark ? 0.2 : 0.08),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(Icons.schedule_rounded, color: Color(0xFF5B4CF0), size: 20),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            shift.shiftName,
                                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? Colors.white : const Color(0xFF1E293B)),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            shift.shiftCode,
                                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: statusBg,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        shift.status.toUpperCase(),
                                        style: TextStyle(color: statusText, fontSize: 9, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Timing: ${shift.startTime} - ${shift.endTime} (${shift.workingHours} hrs)',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF1E293B)),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Break: ${shift.breakDurationMinutes} mins • Grace: ${shift.gracePeriodMinutes} mins',
                                  style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Text('OT Allowed: ', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                                    Icon(
                                      shift.overtimeAllowed ? Icons.check_circle_rounded : Icons.cancel_rounded,
                                      color: shift.overtimeAllowed ? (isDark ? const Color(0xFF34D399) : const Color(0xFF007834)) : const Color(0xFFBA1A1A),
                                      size: 14,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'Offs: ${shift.weeklyOffDays.join(", ")}',
                                        style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const Spacer(),
                                Divider(color: borderCol, height: 1),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.people_rounded, color: Color(0xFF0D9488), size: 18),
                                      onPressed: () => _showBulkAssignDialog(context, shift),
                                      constraints: const BoxConstraints(),
                                      padding: EdgeInsets.zero,
                                      tooltip: 'Assign to Employees',
                                    ),
                                    const SizedBox(width: 16),
                                    IconButton(
                                      icon: const Icon(Icons.edit_rounded, color: Color(0xFF5B4CF0), size: 18),
                                      onPressed: () => _showShiftForm(context, existingShift: shift),
                                      constraints: const BoxConstraints(),
                                      padding: EdgeInsets.zero,
                                      tooltip: 'Edit Shift',
                                    ),
                                    const SizedBox(width: 16),
                                    if (shift.status.toLowerCase() == 'archived')
                                      IconButton(
                                        icon: const Icon(Icons.settings_backup_restore_rounded, color: Color(0xFF007834), size: 18),
                                        onPressed: () => _confirmRestore(context, shift.shiftId, shift.shiftName),
                                        constraints: const BoxConstraints(),
                                        padding: EdgeInsets.zero,
                                        tooltip: 'Restore Shift',
                                      )
                                    else
                                      IconButton(
                                        icon: const Icon(Icons.archive_outlined, color: Color(0xFFBA1A1A), size: 18),
                                        onPressed: () => _confirmArchive(context, shift.shiftId, shift.shiftName),
                                        constraints: const BoxConstraints(),
                                        padding: EdgeInsets.zero,
                                        tooltip: 'Archive Shift',
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  // Pagination controls
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      Text(
                        'Showing ${startIndex + 1} to $endIndex of $totalItems shifts',
                        style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          OutlinedButton(
                            onPressed: _currentPage > 0
                                ? () {
                                    setState(() {
                                      _currentPage--;
                                    });
                                  }
                                : null,
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFFE2E8F0)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text('Previous'),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF5B4CF0).withOpacity(0.08),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${_currentPage + 1}',
                              style: const TextStyle(color: Color(0xFF5B4CF0), fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton(
                            onPressed: _currentPage < totalPages - 1
                                ? () {
                                    setState(() {
                                      _currentPage++;
                                    });
                                  }
                                : null,
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFFE2E8F0)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text('Next'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  void _showShiftForm(BuildContext context, {ShiftModel? existingShift}) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: existingShift?.shiftName ?? '');
    final codeCtrl = TextEditingController(text: existingShift?.shiftCode ?? '');
    final startCtrl = TextEditingController(text: existingShift?.startTime ?? '09:00');
    final endCtrl = TextEditingController(text: existingShift?.endTime ?? '18:00');
    final breakCtrl = TextEditingController(text: existingShift?.breakDurationMinutes.toString() ?? '60');
    final graceCtrl = TextEditingController(text: existingShift?.gracePeriodMinutes.toString() ?? '15');
    final halfDayCtrl = TextEditingController(text: existingShift?.halfDayThresholdHours.toString() ?? '4.0');
    final hrsCtrl = TextEditingController(text: existingShift?.workingHours.toString() ?? '8.0');
    final otStartCtrl = TextEditingController(text: existingShift?.overtimeStartAfterHours.toString() ?? '9.0');
    
    bool overtimeAllowed = existingShift?.overtimeAllowed ?? false;
    String selectedStatus = existingShift?.status ?? 'active';

    final daysOfWeek = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    List<String> selectedOffDays = existingShift != null 
        ? List<String>.from(existingShift.weeklyOffDays) 
        : ['Sunday'];

    bool isSubmitting = false;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(existingShift == null ? 'Add Work Shift' : 'Edit Work Shift'),
              content: SizedBox(
                width: 480,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: nameCtrl,
                          decoration: const InputDecoration(labelText: 'Shift Name *', prefixIcon: Icon(Icons.badge_outlined)),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: codeCtrl,
                          decoration: const InputDecoration(labelText: 'Shift Code *', prefixIcon: Icon(Icons.qr_code_rounded)),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Code is required' : null,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: startCtrl,
                                decoration: const InputDecoration(labelText: 'Start Time *', hintText: '09:00', prefixIcon: Icon(Icons.login_rounded)),
                                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: endCtrl,
                                decoration: const InputDecoration(labelText: 'End Time *', hintText: '18:00', prefixIcon: Icon(Icons.logout_rounded)),
                                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: breakCtrl,
                                decoration: const InputDecoration(labelText: 'Break Duration (mins) *', prefixIcon: Icon(Icons.free_breakfast_outlined)),
                                keyboardType: TextInputType.number,
                                validator: (v) => (v == null || int.tryParse(v) == null) ? 'Required' : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: graceCtrl,
                                decoration: const InputDecoration(labelText: 'Grace Period (mins) *', prefixIcon: Icon(Icons.av_timer_rounded)),
                                keyboardType: TextInputType.number,
                                validator: (v) => (v == null || int.tryParse(v) == null) ? 'Required' : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: hrsCtrl,
                                decoration: const InputDecoration(labelText: 'Daily Net Hours *', prefixIcon: Icon(Icons.hourglass_bottom_rounded)),
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                validator: (v) => (v == null || double.tryParse(v) == null) ? 'Required' : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: halfDayCtrl,
                                decoration: const InputDecoration(labelText: 'Half Day Threshold (hrs) *', prefixIcon: Icon(Icons.hourglass_empty_rounded)),
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                validator: (v) => (v == null || double.tryParse(v) == null) ? 'Required' : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SwitchListTile(
                          title: const Text('Overtime Allowed', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          value: overtimeAllowed,
                          onChanged: (val) {
                            setModalState(() {
                              overtimeAllowed = val;
                            });
                          },
                          contentPadding: EdgeInsets.zero,
                        ),
                        if (overtimeAllowed) ...[
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: otStartCtrl,
                            decoration: const InputDecoration(labelText: 'Overtime Starts After Hours *', prefixIcon: Icon(Icons.more_time_rounded)),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            validator: (v) => (v == null || double.tryParse(v) == null) ? 'Required' : null,
                          ),
                        ],
                        const SizedBox(height: 16),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text('Weekly Off Days', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF475569))),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8.0,
                          children: daysOfWeek.map((day) {
                            final isOff = selectedOffDays.contains(day);
                            return FilterChip(
                              label: Text(day.substring(0, 3)),
                              selected: isOff,
                              onSelected: (val) {
                                setModalState(() {
                                  if (val) {
                                    selectedOffDays.add(day);
                                  } else {
                                    selectedOffDays.remove(day);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          initialValue: selectedStatus,
                          decoration: const InputDecoration(labelText: 'Status', prefixIcon: Icon(Icons.info_outline_rounded)),
                          items: const [
                            DropdownMenuItem(value: 'active', child: Text('Active')),
                            DropdownMenuItem(value: 'suspended', child: Text('Suspended')),
                            DropdownMenuItem(value: 'archived', child: Text('Archived (Soft Delete)')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setModalState(() {
                                selectedStatus = val;
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: isSubmitting ? null : () => Navigator.pop(ctx), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (formKey.currentState!.validate()) {
                            final user = ref.read(authProvider).user;
                            if (user == null) return;

                            setModalState(() { isSubmitting = true; });

                            final newShift = ShiftModel(
                              shiftId: existingShift?.shiftId ?? const Uuid().v4(),
                              companyId: user.companyId,
                              shiftName: nameCtrl.text.trim(),
                              shiftCode: codeCtrl.text.trim(),
                              startTime: startCtrl.text.trim(),
                              endTime: endCtrl.text.trim(),
                              breakDurationMinutes: int.parse(breakCtrl.text.trim()),
                              workingHours: double.parse(hrsCtrl.text.trim()),
                              gracePeriodMinutes: int.parse(graceCtrl.text.trim()),
                              halfDayThresholdHours: double.parse(halfDayCtrl.text.trim()),
                              overtimeAllowed: overtimeAllowed,
                              overtimeStartAfterHours: overtimeAllowed ? double.parse(otStartCtrl.text.trim()) : 0.0,
                              weeklyOffDays: selectedOffDays,
                              status: selectedStatus,
                              createdAt: existingShift?.createdAt ?? DateTime.now(),
                              updatedAt: DateTime.now(),
                            );

                            try {
                              final result = await ref.read(adminShiftsProvider.notifier).saveShift(newShift);
                              if (context.mounted) {
                                if (result == 'success') {
                                  Navigator.pop(ctx);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Work Shift saved successfully.'), backgroundColor: Colors.green),
                                  );
                                } else {
                                  setModalState(() { isSubmitting = false; });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(result), backgroundColor: Colors.red),
                                  );
                                }
                              }
                            } catch (e) {
                              if (context.mounted) {
                                setModalState(() { isSubmitting = false; });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Failed to save shift: $e'), backgroundColor: Colors.red),
                                );
                              }
                            }
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showBulkAssignDialog(BuildContext context, ShiftModel shift) {
    // Load active employees
    final emps = ref.read(adminEmployeesProvider).value ?? [];
    final selectedEmployeeIds = <String>{};

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text('Assign Shift: ${shift.shiftName}'),
              content: SizedBox(
                width: double.maxFinite,
                child: emps.isEmpty
                    ? const Text('No active employees found.')
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: emps.length,
                        itemBuilder: (context, index) {
                          final emp = emps[index];
                          final isSelected = selectedEmployeeIds.contains(emp.uid);
                          return CheckboxListTile(
                            activeColor: const Color(0xFF4F46E5),
                            title: Text(emp.name),
                            subtitle: Text(emp.department ?? 'No Department'),
                            value: isSelected,
                            onChanged: (val) {
                              setModalState(() {
                                if (val == true) {
                                  selectedEmployeeIds.add(emp.uid);
                                } else {
                                  selectedEmployeeIds.remove(emp.uid);
                                }
                              });
                            },
                          );
                        },
                      ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: selectedEmployeeIds.isEmpty
                      ? null
                      : () async {
                          Navigator.pop(ctx);
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (loaderCtx) => const Center(child: CircularProgressIndicator()),
                          );

                          try {
                            for (final id in selectedEmployeeIds) {
                              await ref.read(adminEmployeesProvider.notifier).assignShift(id, shift.shiftId);
                            }
                            if (context.mounted) Navigator.pop(context); // Dismiss loader
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Shift assigned successfully.'), backgroundColor: Colors.green),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) Navigator.pop(context); // Dismiss loader
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Failed to assign shifts: $e'), backgroundColor: Colors.red),
                              );
                            }
                          }
                        },
                  child: const Text('Assign'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmArchive(BuildContext context, String id, String name) {
    bool isProcessing = false;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setConfirmState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.archive_outlined, color: Colors.orange),
              SizedBox(width: 8),
              Text('Archive Shift'),
            ],
          ),
          content: Text('Are you sure you want to archive work shift "$name"? New employee assignments will be prevented.'),
          actions: [
            TextButton(onPressed: isProcessing ? null : () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              onPressed: isProcessing
                  ? null
                  : () async {
                      setConfirmState(() { isProcessing = true; });
                      try {
                        await ref.read(adminShiftsProvider.notifier).deleteShift(id);
                        if (context.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Shift archived successfully.'), backgroundColor: Colors.green),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          setConfirmState(() { isProcessing = false; });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to archive shift: $e'), backgroundColor: Colors.red),
                          );
                        }
                      }
                    },
              child: isProcessing
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Archive', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmRestore(BuildContext context, String id, String name) {
    bool isProcessing = false;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setConfirmState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.settings_backup_restore_rounded, color: Colors.green),
              SizedBox(width: 8),
              Text('Restore Shift'),
            ],
          ),
          content: Text('Are you sure you want to restore shift "$name" back to active status?'),
          actions: [
            TextButton(onPressed: isProcessing ? null : () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              onPressed: isProcessing
                  ? null
                  : () async {
                      setConfirmState(() { isProcessing = true; });
                      try {
                        await ref.read(adminShiftsProvider.notifier).restoreShift(id);
                        if (context.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Shift restored successfully.'), backgroundColor: Colors.green),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          setConfirmState(() { isProcessing = false; });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to restore shift: $e'), backgroundColor: Colors.red),
                          );
                        }
                      }
                    },
              child: isProcessing
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Restore', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
