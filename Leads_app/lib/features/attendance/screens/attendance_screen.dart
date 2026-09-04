import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../shared/models/attendance_model.dart';
import '../../../shared/providers/providers.dart';
import '../../../constants/user_roles.dart';
import 'leave_list_screen.dart';
import '../../company_admin/providers/company_admin_providers.dart';
import '../../../shared/utils/app_notification.dart';
import '../../../shared/services/app_error_handler.dart';

import '../../../shared/services/attendance_automation_service.dart';

class AttendanceScreen extends ConsumerStatefulWidget {
  const AttendanceScreen({super.key});

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen> {
  bool _isLocating = false;
  Timer? _ticker;
  Duration _elapsed = Duration.zero;

  void _startTimer(DateTime checkInTime) {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _elapsed = DateTime.now().difference(checkInTime);
        });
      }
    });
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(d.inHours);
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return "$hours:$minutes:$seconds";
  }

  Future<void> _handleCheckIn() async {
    setState(() {
      _isLocating = true;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw 'Location services are disabled. Please enable GPS/Location in settings.';
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw 'Location permission denied.';
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw 'Location permissions are permanently denied. Please enable them in system settings.';
      }

      if (mounted) {
        AppNotification.showInfo(context, 'Fetching current GPS coordinates...');
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      String address = "Lat: ${position.latitude.toStringAsFixed(4)}, Lng: ${position.longitude.toStringAsFixed(4)}";
      if (!kIsWeb) {
        try {
          List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
          if (placemarks.isNotEmpty) {
            Placemark place = placemarks.first;
            final parts = [
              if (place.name != null && place.name!.isNotEmpty && place.name != place.street) place.name,
              if (place.street != null && place.street!.isNotEmpty) place.street,
              if (place.subLocality != null && place.subLocality!.isNotEmpty) place.subLocality,
              if (place.locality != null && place.locality!.isNotEmpty) place.locality,
              if (place.administrativeArea != null && place.administrativeArea!.isNotEmpty) place.administrativeArea,
              if (place.postalCode != null && place.postalCode!.isNotEmpty) place.postalCode,
            ];
            address = parts.join(', ');
          }
        } catch (e) {
          debugPrint('Geocoding failed: $e');
        }
      }

      await ref.read(attendanceProvider.notifier).checkInUser(
        position.latitude,
        position.longitude,
        address,
      );
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Location Error', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
            content: Text(e.toString(), style: const TextStyle(fontFamily: 'Inter')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLocating = false;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(attendanceProvider.notifier).loadLogs();
      ref.read(leavesProvider.notifier).loadLeaves();
      final user = ref.read(authProvider).user;
      if (user != null && user.companyId.isNotEmpty) {
        AttendanceAutomationService.evaluateCompanyAutomation(user.companyId);
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final attendanceState = ref.watch(attendanceProvider);
    final authState = ref.watch(authProvider);
    final user = authState.user;

    if (user == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final canRecordAttendance = UserRoles.allowsPersonalAttendance(user.role);
    final logs = attendanceState.logs;
    final totalPresent = logs.where((l) => l.status == 'Present' || l.status == 'Late').length;
    final totalLate = logs.where((l) => l.status == 'Late').length;

    double avgHours = 0;
    final validHours = logs.where((l) => l.workHours != null).map((e) => e.workHours!).toList();
    if (validHours.isNotEmpty) {
      avgHours = validHours.reduce((a, b) => a + b) / validHours.length;
    }

    // Start or stop live timer ticker based on state
    final todayLog = attendanceState.todayLog;
    if (todayLog != null && todayLog.checkOutTime == null) {
      if (_ticker == null) {
        _elapsed = DateTime.now().difference(todayLog.checkInTime);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _startTimer(todayLog.checkInTime);
        });
      }
    } else {
      _ticker?.cancel();
      _ticker = null;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    const primaryColor = Color(0xFF5B4CF0);
    final outlineVariantColor = isDark ? const Color(0xFF334155) : const Color(0xFFC8C4D8);
    final onSurfaceColor = isDark ? Colors.white : const Color(0xFF191C1F);
    final onSurfaceVariantColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF474555);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: isDark ? Theme.of(context).scaffoldBackgroundColor : const Color(0xFFF8F9FD),
        appBar: AppBar(
          title: const Text(
            "Attendance & Leaves",
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Colors.white,
            ),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
          backgroundColor: Colors.transparent,
          elevation: 0,
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryColor, Color(0xFF5B4CF0)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
              boxShadow: [
                BoxShadow(
                  color: Color(0x2D5B4CF0),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
          ),
          actions: [
            IconButton(
              onPressed: () {
                ref.read(attendanceProvider.notifier).loadLogs();
                ref.read(leavesProvider.notifier).loadLeaves();
              },
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            )
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: "Daily Log", icon: Icon(Icons.history_toggle_off_rounded)),
              Tab(text: "Leaves", icon: Icon(Icons.time_to_leave_rounded)),
            ],
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            labelStyle: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold),
          ),
        ),
        body: TabBarView(
          children: [
            // Tab 1: Daily Log Content
            Column(
              children: [
                /// TODAY CARD (Redesigned Check-in / Check-out status)
                if (canRecordAttendance)
                  Padding(
                    padding: const EdgeInsets.all(16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? Theme.of(context).cardColor : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: outlineVariantColor.withOpacity(0.3)),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF111827).withOpacity(0.02),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Today's Attendance",
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: onSurfaceColor,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: todayLog == null
                                    ? const Color(0xFFFEF2F2)
                                    : (todayLog.checkOutTime == null
                                        ? const Color(0xFFDCFCE7)
                                        : const Color(0xFFF1F5F9)),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: todayLog == null
                                      ? const Color(0xFFFCA5A5).withOpacity(0.3)
                                      : (todayLog.checkOutTime == null
                                          ? const Color(0xFF86EFAC).withOpacity(0.3)
                                          : outlineVariantColor.withOpacity(0.3)),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: todayLog == null
                                          ? const Color(0xFFBA1A1A)
                                          : (todayLog.checkOutTime == null
                                              ? const Color(0xFF006C49)
                                              : onSurfaceVariantColor),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    todayLog == null
                                        ? "Checked Out"
                                        : (todayLog.checkOutTime == null ? "Checked In" : "Completed"),
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: todayLog == null
                                          ? const Color(0xFFBA1A1A)
                                          : (todayLog.checkOutTime == null
                                              ? const Color(0xFF006C49)
                                              : onSurfaceVariantColor),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Prominent Live working timer
                        if (todayLog != null && todayLog.checkOutTime == null) ...[
                          Text(
                            _formatDuration(_elapsed),
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "ACTIVE WORKING TIMER",
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: onSurfaceVariantColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ] else if (todayLog != null && todayLog.checkOutTime != null) ...[
                          const Icon(Icons.check_circle_rounded, color: Color(0xFF006C49), size: 48),
                          const SizedBox(height: 8),
                          const Text(
                            "Today's shift has been completed",
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF006C49),
                            ),
                          ),
                        ] else ...[
                          Icon(Icons.timer_outlined, color: outlineVariantColor, size: 48),
                          const SizedBox(height: 8),
                          Text(
                            "Shift not started yet",
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: onSurfaceVariantColor,
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),

                        // Details section (In / Out times, Location)
                        if (todayLog != null) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              Column(
                                children: [
                                  Text("CHECK IN TIME", style: TextStyle(fontFamily: 'Inter', fontSize: 10, color: onSurfaceVariantColor, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Text(DateFormat('hh:mm a').format(todayLog.checkInTime), style: TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.bold, color: onSurfaceColor)),
                                ],
                              ),
                              Container(width: 1, height: 24, color: outlineVariantColor.withOpacity(0.3)),
                              Column(
                                children: [
                                  Text("CHECK OUT TIME", style: TextStyle(fontFamily: 'Inter', fontSize: 10, color: onSurfaceVariantColor, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Text(
                                    todayLog.checkOutTime != null ? DateFormat('hh:mm a').format(todayLog.checkOutTime!) : '--:--',
                                    style: TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.bold, color: onSurfaceColor),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          if (todayLog.address != null) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: outlineVariantColor.withOpacity(0.15)),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.location_on_outlined, color: primaryColor, size: 16),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      todayLog.address!,
                                      style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: onSurfaceVariantColor),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 20),
                        ],

                        // Action Buttons
                        if (todayLog == null)
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _isLocating ? null : _handleCheckIn,
                              icon: _isLocating
                                  ? const SizedBox(
                                      height: 16,
                                      width: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Icon(Icons.login_rounded, size: 18),
                              label: Text(_isLocating ? "Fetching GPS..." : "Check In Now", style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          )
                        else if (todayLog.checkOutTime == null)
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                await ref.read(attendanceProvider.notifier).checkOutUser();
                              },
                              icon: const Icon(Icons.logout_rounded, size: 18),
                              label: const Text("Perform Check Out", style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFBA1A1A),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                if (attendanceState.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Text(
                      attendanceState.errorMessage!,
                      style: const TextStyle(color: Color(0xFFBA1A1A), fontFamily: 'Inter', fontSize: 12),
                    ),
                  ),

                // SUMMARY METRICS ROW
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildSummaryBox(
                          context,
                          "Present Today",
                          "$totalPresent",
                          const Color(0xFF006C49),
                          const Color(0xFFDCFCE7),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildSummaryBox(
                          context,
                          "Late Arrivals",
                          "$totalLate",
                          const Color(0xFFEAB308),
                          const Color(0xFFFEF9C3),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildSummaryBox(
                          context,
                          "Avg Hours/Day",
                          "${avgHours.toStringAsFixed(1)}h",
                          primaryColor,
                          const Color(0xFFE8E4FF),
                        ),
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Monthly History",
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: onSurfaceColor,
                      ),
                    ),
                  ),
                ),

                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () => ref.read(attendanceProvider.notifier).loadLogs(),
                    child: attendanceState.isLoading
                        ? const Center(
                            child: CircularProgressIndicator(),
                          )
                        : logs.isEmpty
                            ? ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                children: [
                                  SizedBox(height: MediaQuery.of(context).size.height * 0.15),
                                  Center(
                                    child: Text(
                                      "No attendance records yet",
                                      style: TextStyle(fontFamily: 'Inter', color: onSurfaceVariantColor),
                                    ),
                                  ),
                                ],
                              )
                            : ListView.separated(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                itemCount: logs.length,
                                separatorBuilder: (_, _) => const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  final log = logs[index];
                                  return _buildAttendanceLogCard(context, log);
                                },
                              ),
                  ),
                ),
              ],
            ),
            // Tab 2: Leaves Content
            const LeaveListWidget(showAppBar: false),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryBox(
    BuildContext context,
    String label,
    String value,
    Color textColor,
    Color bgTint,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Theme.of(context).cardColor : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFC8C4D8).withOpacity(0.3)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 10,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF474555),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceLogCard(
    BuildContext context,
    AttendanceModel log,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Color statusColor;
    Color statusBg;

    switch (log.status) {
      case 'Present':
        statusColor = isDark ? const Color(0xFF86EFAC) : const Color(0xFF006C49);
        statusBg = isDark ? const Color(0xFF14532D) : const Color(0xFFDCFCE7);
        break;
      case 'Late':
        statusColor = isDark ? const Color(0xFFFDE047) : const Color(0xFFEAB308);
        statusBg = isDark ? const Color(0xFF713F12) : const Color(0xFFFEF9C3);
        break;
      case 'Half Day':
        statusColor = isDark ? const Color(0xFF93C5FD) : Colors.blue;
        statusBg = isDark ? const Color(0xFF1E3A8A) : Colors.blue.shade50;
        break;
      case 'PendingCorrection':
        statusColor = isDark ? const Color(0xFFF0ABFC) : Colors.purple;
        statusBg = isDark ? const Color(0xFF581C87) : Colors.purple.shade50;
        break;
      default:
        statusColor = isDark ? const Color(0xFFFCA5A5) : const Color(0xFFBA1A1A);
        statusBg = isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFEF2F2);
    }

    final date = DateFormat('dd MMM yyyy').format(log.checkInTime);
    final day = DateFormat('EEEE').format(log.checkInTime);
    final checkIn = DateFormat('hh:mm a').format(log.checkInTime);
    final checkOut = log.checkOutTime != null ? DateFormat('hh:mm a').format(log.checkOutTime!) : '--';

    return Container(
      decoration: BoxDecoration(
        color: isDark ? Theme.of(context).cardColor : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFC8C4D8).withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black26 : const Color(0xFF111827).withOpacity(0.01),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      date,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isDark ? Colors.white : const Color(0xFF1B1B24),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      day,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        color: Color(0xFF64748B),
                        fontSize: 11,
                      ),
                    ),
                    if (log.shiftName != null && log.shiftName!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Shift: ${log.shiftName}',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withOpacity(0.2)),
                  ),
                  child: Text(
                    log.status,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                      fontFamily: 'Inter',
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24, color: Color(0xFFF1F5F9)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildTimeCol("CHECK IN", checkIn, Icons.login_rounded, const Color(0xFF007834)),
                _buildTimeCol("CHECK OUT", checkOut, Icons.logout_rounded, const Color(0xFF5B4CF0)),
              ],
            ),
            if (log.address != null) ...[
              const Divider(height: 24, color: Color(0xFFF1F5F9)),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF64748B)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      log.address!,
                      style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ),
                ],
              )
            ],
            if (log.status != 'PendingCorrection' && log.status != 'Present') ...[
              const Divider(height: 24, color: Color(0xFFF1F5F9)),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _showCorrectionRequestDialog(context, log),
                  icon: const Icon(Icons.edit_note_rounded, size: 16),
                  label: const Text('Request Correction', style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }

  void _showCorrectionRequestDialog(BuildContext context, AttendanceModel log) {
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Request Attendance Correction', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Specify the reason for correcting this attendance log (e.g., missed check-out, server delay, outside geofence correction).',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontFamily: 'Inter'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonCtrl,
              decoration: InputDecoration(
                labelText: 'Correction Reason',
                hintText: 'Enter reason here...',
                hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13, fontFamily: 'Inter'),
                labelStyle: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: Color(0xFF64748B)),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: const Color(0xFFC8C4D8).withOpacity(0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF5B4CF0), width: 1.5),
                ),
              ),
              maxLines: 3,
              style: const TextStyle(fontFamily: 'Inter', fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5B4CF0),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              final reason = reasonCtrl.text.trim();
              if (reason.isEmpty) {
                AppNotification.showError(context, 'Please enter a correction reason.');
                return;
              }
              Navigator.pop(ctx);
              
              final user = ref.read(authProvider).user;
              if (user == null) return;

              try {
                await FirebaseFirestore.instance.collection('attendance').doc(log.attendanceId).update({
                  'status': 'PendingCorrection',
                  'correctionReason': reason,
                });

                final adminRepo = ref.read(companyAdminRepositoryProvider);
                await adminRepo.logEmployeeActivity(
                  companyId: user.companyId,
                  employeeId: user.uid,
                  action: 'Attendance Correction requested for log ${log.attendanceId}: "$reason"',
                  performedBy: user.name,
                );

                await ref.read(attendanceProvider.notifier).loadLogs();

                if (context.mounted) {
                  AppNotification.showSuccess(context, 'Correction request submitted successfully.');
                }
              } catch (e) {
                if (context.mounted) {
                  AppNotification.showError(context, AppErrorHandler.parseError(e));
                }
              }
            },
            child: const Text('Submit Request', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeCol(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 6),
        Text(
          title,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 9,
            color: Color(0xFF64748B),
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1B1B24),
          ),
        ),
      ],
    );
  }
}
