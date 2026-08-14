import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../shared/models/attendance_model.dart';
import '../../../shared/providers/providers.dart';
import '../../company_admin/providers/company_admin_providers.dart';

class StaffAttendanceScreen extends ConsumerStatefulWidget {
  const StaffAttendanceScreen({super.key});

  @override
  ConsumerState<StaffAttendanceScreen> createState() =>
      _StaffAttendanceScreenState();
}

class _StaffAttendanceScreenState
    extends ConsumerState<StaffAttendanceScreen> {
  DateTime _selectedDate = DateTime.now();
  String _selectedEmployeeId = '';
  String _searchQuery = '';
  final _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Search employees...',
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
                  Text('Staff Attendance',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                  Text('View team attendance records',
                      style: TextStyle(fontSize: 12, color: Colors.white70)),
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
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Date picker
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    DateFormat('dd MMM yyyy').format(_selectedDate),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime.now().subtract(
                          const Duration(days: 365),
                        ),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setState(() => _selectedDate = picked);
                      }
                    },
                    icon: const Icon(Icons.calendar_today_rounded, size: 16),
                    label: const Text('Change'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Employee list with attendance status
            // Employee list with attendance status
            ref.watch(companyEmployeesProvider).when(
              data: (employees) {
                final logsAsync = ref.watch(companyAttendanceTodayProvider);

                return logsAsync.when(
                  data: (logs) {
                    var filtered = employees;

                    if (_searchQuery.isNotEmpty) {
                      filtered = filtered
                          .where((e) =>
                              e.name.toLowerCase().contains(_searchQuery) ||
                              e.email.toLowerCase().contains(_searchQuery))
                          .toList();
                    }

                    if (filtered.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(32),
                        alignment: Alignment.center,
                        child: Column(
                          children: [
                            const Icon(
                              Icons.people_outline_rounded,
                              size: 60,
                              color: Color(0xFFE2E8F0),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'No employees found',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final employee = filtered[index];
                        final match = logs.where((log) =>
                            (log.employeeId == employee.uid ||
                             log.employeeId == employee.employeeId ||
                             log.userEmployeeId == employee.uid ||
                             log.userEmployeeId == employee.employeeId) &&
                            log.checkInTime.year == _selectedDate.year &&
                            log.checkInTime.month == _selectedDate.month &&
                            log.checkInTime.day == _selectedDate.day);
                        final logOnSelectedDate = match.isNotEmpty ? match.first : null;

                        // Check if employee has an approved leave request on the selected date
                        final leaves = ref.watch(leaveRequestsProvider).value ?? [];
                        final hasLeave = leaves.any((leave) =>
                            leave.employeeId == employee.uid &&
                            leave.status == 'Approved' &&
                            !_selectedDate.isBefore(leave.fromDate) &&
                            !_selectedDate.isAfter(leave.toDate));

                        // Check if selected date is a holiday for this company/branch
                        final holidays = ref.watch(adminHolidaysProvider).value ?? [];
                        final isHoliday = holidays.any((h) =>
                            h.status == 'active' &&
                            h.holidayDate.year == _selectedDate.year &&
                            h.holidayDate.month == _selectedDate.month &&
                            h.holidayDate.day == _selectedDate.day &&
                            (h.branchId == null || h.branchId!.isEmpty || h.branchId == employee.branchId));

                        return _buildStaffAttendanceCard(
                          context,
                          employee,
                          logOnSelectedDate,
                          hasLeave,
                          isHoliday,
                        );
                      },
                    );
                  },
                  loading: () => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  error: (err, _) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Error loading logs: $err',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ),
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(),
              ),
              error: (err, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Error loading employees: $err',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _markEmployeePresent(dynamic employee) async {
    final now = _selectedDate;
    final checkInTime = DateTime(now.year, now.month, now.day, 9, 0); // 9:00 AM
    final checkOutTime = DateTime(now.year, now.month, now.day, 18, 0); // 6:00 PM
    
    final newLog = AttendanceModel(
      attendanceId: const Uuid().v4(),
      companyId: employee.companyId,
      employeeId: employee.uid,
      employeeName: employee.name,
      checkInTime: checkInTime,
      checkOutTime: checkOutTime,
      latitude: 0.0,
      longitude: 0.0,
      address: 'Marked present by Admin',
      checkoutLatitude: 0.0,
      checkoutLongitude: 0.0,
      checkoutAddress: 'Marked present by Admin',
      workHours: 9.0,
      status: 'Present',
      createdAt: DateTime.now(),
    );

    try {
      final repo = ref.read(attendanceRepositoryProvider);
      await repo.checkIn(newLog);
      ref.invalidate(companyAttendanceTodayProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${employee.name} marked as present.')),
        );
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Error'),
            content: Text('Failed to save attendance: $e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  Widget _buildStaffAttendanceCard(
    BuildContext context,
    dynamic employee,
    AttendanceModel? log,
    bool isOnLeave,
    bool isHoliday,
  ) {
    final checkedIn = log != null;
    final statusColor = checkedIn
        ? (log.status == 'Late' ? Colors.orange : Colors.green)
        : (isOnLeave 
            ? Colors.blue 
            : (isHoliday ? Colors.teal : Colors.red));
    final statusText = checkedIn 
        ? log.status 
        : (isOnLeave 
            ? 'On Leave' 
            : (isHoliday ? 'Holiday' : 'Absent'));
    final statusIcon = checkedIn
        ? (log.status == 'Late' ? Icons.watch_later_rounded : Icons.check_circle_rounded)
        : (isOnLeave 
            ? Icons.time_to_leave_rounded 
            : (isHoliday ? Icons.calendar_month_rounded : Icons.cancel_rounded));

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFFE2E8F0),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    employee.name[0].toUpperCase(),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        employee.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            employee.role ?? 'Employee',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                          if (log != null && log.shiftName != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                log.shiftName!,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF3B82F6),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(statusIcon, size: 14, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        statusText,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (checkedIn) ...[
              const Divider(height: 16, color: Color(0xFFF1F5F9)),
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Icons.login_rounded,
                            size: 14, color: Color(0xFF94A3B8)),
                        const SizedBox(width: 6),
                        Text(
                          'Check-in: ${DateFormat('hh:mm a').format(log.checkInTime)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Icons.logout_rounded,
                            size: 14, color: Color(0xFF94A3B8)),
                        const SizedBox(width: 6),
                        Text(
                          log.checkOutTime != null
                              ? 'Check-out: ${DateFormat('hh:mm a').format(log.checkOutTime!)}'
                              : 'Check-out: Still working',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.schedule_rounded,
                      size: 14, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 6),
                  Text(
                    log.workHours != null
                        ? 'Hours: ${log.workHours!.toStringAsFixed(2)}h'
                        : 'Hours: --',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
              if (log.address != null && log.address!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.location_on, size: 14, color: Color(0xFF94A3B8)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'In Location: ${log.address!}',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                    ),
                  ],
                ),
              ],
              if (log.checkoutAddress != null && log.checkoutAddress!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF94A3B8)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Out Location: ${log.checkoutAddress!}',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                    ),
                  ],
                ),
              ],
            ],
            if (!checkedIn)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: ElevatedButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Mark Present'),
                        content: Text(
                          'Mark ${employee.name} as present for ${DateFormat('dd MMM yyyy').format(_selectedDate)}?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              _markEmployeePresent(employee);
                            },
                            child: const Text('Mark Present'),
                          ),
                        ],
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 36),
                    backgroundColor: Colors.green,
                  ),
                  child: const Text('Mark Present', style: TextStyle(color: Colors.white)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
