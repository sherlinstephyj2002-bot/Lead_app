import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:worktrack/shared/providers/providers.dart';
import 'package:worktrack/features/company_admin/models/attendance_settings_model.dart';
import 'package:worktrack/features/company_admin/providers/company_admin_providers.dart';

class AttendanceSettingsScreen extends ConsumerStatefulWidget {
  const AttendanceSettingsScreen({super.key});

  @override
  ConsumerState<AttendanceSettingsScreen> createState() => _AttendanceSettingsScreenState();
}

class _AttendanceSettingsScreenState extends ConsumerState<AttendanceSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _lateCtrl = TextEditingController();
  final _earlyCtrl = TextEditingController();
  final _minWorkingHoursCtrl = TextEditingController();
  final _halfDayHoursCtrl = TextEditingController();
  final _otStartCtrl = TextEditingController();
  final _maxOtCtrl = TextEditingController();
  final _radiusCtrl = TextEditingController();

  bool _gpsRequired = false;
  bool _selfieRequired = false;
  bool _geofenceEnabled = false;
  bool _allowAttendanceCorrection = true;
  final List<String> _weekendDays = [];

  final List<String> _daysOfWeek = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

  @override
  void dispose() {
    _lateCtrl.dispose();
    _earlyCtrl.dispose();
    _minWorkingHoursCtrl.dispose();
    _halfDayHoursCtrl.dispose();
    _otStartCtrl.dispose();
    _maxOtCtrl.dispose();
    _radiusCtrl.dispose();
    super.dispose();
  }

  void _populateFields(AttendanceSettingsModel s) {
    _lateCtrl.text = s.lateGraceMinutes.toString();
    _earlyCtrl.text = s.earlyExitGraceMinutes.toString();
    _minWorkingHoursCtrl.text = s.minimumWorkingHours.toString();
    _halfDayHoursCtrl.text = s.halfDayHours.toString();
    _otStartCtrl.text = s.overtimeStartAfterHours.toString();
    _maxOtCtrl.text = s.maximumOvertimeHours.toString();
    _radiusCtrl.text = s.geofenceRadius?.toString() ?? '';

    _gpsRequired = s.gpsRequired;
    _selfieRequired = s.selfieRequired;
    _geofenceEnabled = s.geofenceEnabled;
    _allowAttendanceCorrection = s.allowAttendanceCorrection;
    
    _weekendDays.clear();
    _weekendDays.addAll(s.weekendDays);
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(adminAttendanceSettingsProvider);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? Theme.of(context).scaffoldBackgroundColor : const Color(0xFFF7F8FC);
    final cardBg = isDark ? Theme.of(context).cardColor : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final borderCol = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        title: const Text('Attendance Rules', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF5B4CF0))),
        backgroundColor: cardBg,
        foregroundColor: titleColor,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: borderCol, height: 1),
        ),
      ),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error loading settings: $err')),
        data: (settings) {
          // Populate fields only once when loading completes
          if (_lateCtrl.text.isEmpty && _formKey.currentState == null) {
            _populateFields(settings);
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Policy Configurations',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF1E293B)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Configure company check-in limits, grace periods, geofences and verify employee identity.',
                    style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 24),

                  // 1. General Rules Section
                  _buildSectionCard(
                    title: 'General Limits & Grace Periods',
                    icon: Icons.timer_rounded,
                    color: const Color(0xFF5B4CF0),
                    context: context,
                    children: [
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isCompact = constraints.maxWidth < 450;
                          final lateField = TextFormField(
                            controller: _lateCtrl,
                            decoration: InputDecoration(
                              labelText: 'Late Entry Grace (mins)',
                              prefixIcon: const Icon(Icons.av_timer_rounded, color: Color(0xFF5B4CF0)),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              isDense: true,
                            ),
                            keyboardType: TextInputType.number,
                            validator: (v) => (v == null || int.tryParse(v) == null) ? 'Required' : null,
                          );

                          final earlyField = TextFormField(
                            controller: _earlyCtrl,
                            decoration: InputDecoration(
                              labelText: 'Early Exit Grace (mins)',
                              prefixIcon: const Icon(Icons.av_timer_rounded, color: Color(0xFF5B4CF0)),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              isDense: true,
                            ),
                            keyboardType: TextInputType.number,
                            validator: (v) => (v == null || int.tryParse(v) == null) ? 'Required' : null,
                          );

                          if (isCompact) {
                            return Column(
                              children: [
                                lateField,
                                const SizedBox(height: 12),
                                earlyField,
                              ],
                            );
                          }

                          return Row(
                            children: [
                              Expanded(child: lateField),
                              const SizedBox(width: 16),
                              Expanded(child: earlyField),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isCompact = constraints.maxWidth < 450;
                          final minHoursField = TextFormField(
                            controller: _minWorkingHoursCtrl,
                            decoration: InputDecoration(
                              labelText: 'Min Working Hours',
                              prefixIcon: const Icon(Icons.work_outline_rounded, color: Color(0xFF5B4CF0)),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              isDense: true,
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            validator: (v) => (v == null || double.tryParse(v) == null) ? 'Required' : null,
                          );

                          final halfDayField = TextFormField(
                            controller: _halfDayHoursCtrl,
                            decoration: InputDecoration(
                              labelText: 'Half Day Working Limit',
                              prefixIcon: const Icon(Icons.hourglass_bottom_rounded, color: Color(0xFF5B4CF0)),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              isDense: true,
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            validator: (v) => (v == null || double.tryParse(v) == null) ? 'Required' : null,
                          );

                          if (isCompact) {
                            return Column(
                              children: [
                                minHoursField,
                                const SizedBox(height: 12),
                                halfDayField,
                              ],
                            );
                          }

                          return Row(
                            children: [
                              Expanded(child: minHoursField),
                              const SizedBox(width: 16),
                              Expanded(child: halfDayField),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isCompact = constraints.maxWidth < 450;
                          final otStartField = TextFormField(
                            controller: _otStartCtrl,
                            decoration: InputDecoration(
                              labelText: 'OT Starts After Hours',
                              prefixIcon: const Icon(Icons.watch_later_outlined, color: Color(0xFF5B4CF0)),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              isDense: true,
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            validator: (v) => (v == null || double.tryParse(v) == null) ? 'Required' : null,
                          );

                          final maxOtField = TextFormField(
                            controller: _maxOtCtrl,
                            decoration: InputDecoration(
                              labelText: 'Max OT Hours Limit',
                              prefixIcon: const Icon(Icons.av_timer_outlined, color: Color(0xFF5B4CF0)),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              isDense: true,
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            validator: (v) => (v == null || double.tryParse(v) == null) ? 'Required' : null,
                          );

                          if (isCompact) {
                            return Column(
                              children: [
                                otStartField,
                                const SizedBox(height: 12),
                                maxOtField,
                              ],
                            );
                          }

                          return Row(
                            children: [
                              Expanded(child: otStartField),
                              const SizedBox(width: 16),
                              Expanded(child: maxOtField),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // 2. Weekend Rules Section
                  _buildSectionCard(
                    title: 'Weekly Off Schedule (Weekends)',
                    icon: Icons.calendar_month_rounded,
                    color: const Color(0xFF0EA5E9),
                    context: context,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _daysOfWeek.map((day) {
                          final isSelected = _weekendDays.contains(day);
                          return FilterChip(
                            label: Text(day),
                            selected: isSelected,
                            selectedColor: const Color(0xFF5B4CF0).withValues(alpha: 0.12),
                            checkmarkColor: const Color(0xFF5B4CF0),
                            labelStyle: TextStyle(
                              color: isSelected ? const Color(0xFF5B4CF0) : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              fontSize: 13,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(color: isSelected ? const Color(0xFF5B4CF0) : borderCol),
                            ),
                            onSelected: (val) {
                              setState(() {
                                if (val) {
                                  _weekendDays.add(day);
                                } else {
                                  _weekendDays.remove(day);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // 3. Geofence & GPS Section
                  _buildSectionCard(
                    title: 'GeoFence & Verification Rules',
                    icon: Icons.location_on_rounded,
                    color: const Color(0xFF007834),
                    context: context,
                    children: [
                      SwitchListTile(
                        activeColor: const Color(0xFF5B4CF0),
                        activeTrackColor: const Color(0xFF5B4CF0).withValues(alpha: 0.3),
                        inactiveThumbColor: isDark ? const Color(0xFF64748B) : Colors.white,
                        inactiveTrackColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        contentPadding: EdgeInsets.zero,
                        title: Text('Mandatory Geofence Check-In', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : const Color(0xFF1E293B))),
                        subtitle: Text('Enforce employee checking-in within office geofence coordinates only.', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                        value: _geofenceEnabled,
                        onChanged: (val) {
                          setState(() {
                            _geofenceEnabled = val;
                          });
                        },
                      ),
                      if (_geofenceEnabled) ...[
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _radiusCtrl,
                          decoration: InputDecoration(
                            labelText: 'Allowed Radius (meters)',
                            prefixIcon: const Icon(Icons.radar_rounded, color: Color(0xFF5B4CF0)),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (v) => (_geofenceEnabled && (v == null || double.tryParse(v) == null)) ? 'Required' : null,
                        ),
                      ],
                      Divider(height: 32, color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                      SwitchListTile(
                        activeColor: const Color(0xFF5B4CF0),
                        activeTrackColor: const Color(0xFF5B4CF0).withValues(alpha: 0.3),
                        inactiveThumbColor: isDark ? const Color(0xFF64748B) : Colors.white,
                        inactiveTrackColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        contentPadding: EdgeInsets.zero,
                        title: Text('GPS Location Verification Required', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : const Color(0xFF1E293B))),
                        subtitle: Text('Require employee device location services to check in.', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                        value: _gpsRequired,
                        onChanged: (val) {
                          setState(() {
                            _gpsRequired = val;
                          });
                        },
                      ),
                      Divider(height: 32, color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                      SwitchListTile(
                        activeColor: const Color(0xFF5B4CF0),
                        activeTrackColor: const Color(0xFF5B4CF0).withValues(alpha: 0.3),
                        inactiveThumbColor: isDark ? const Color(0xFF64748B) : Colors.white,
                        inactiveTrackColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        contentPadding: EdgeInsets.zero,
                        title: Text('Selfie Verification Required', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : const Color(0xFF1E293B))),
                        subtitle: Text('Require employee to upload check-in selfie photo.', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                        value: _selfieRequired,
                        onChanged: (val) {
                          setState(() {
                            _selfieRequired = val;
                          });
                        },
                      ),
                      Divider(height: 32, color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                      SwitchListTile(
                        activeColor: const Color(0xFF5B4CF0),
                        activeTrackColor: const Color(0xFF5B4CF0).withValues(alpha: 0.3),
                        inactiveThumbColor: isDark ? const Color(0xFF64748B) : Colors.white,
                        inactiveTrackColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        contentPadding: EdgeInsets.zero,
                        title: Text('Allow Attendance Correction', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : const Color(0xFF1E293B))),
                        subtitle: Text('Allow employees to request status correction for missed or late check-ins.', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                        value: _allowAttendanceCorrection,
                        onChanged: (val) {
                          setState(() {
                            _allowAttendanceCorrection = val;
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Save Button
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (_formKey.currentState!.validate()) {
                          final user = ref.read(authProvider).user;
                          if (user == null) return;

                          final radInput = double.tryParse(_radiusCtrl.text);

                          final newSettings = AttendanceSettingsModel(
                            companyId: user.companyId,
                            minimumWorkingHours: double.parse(_minWorkingHoursCtrl.text.trim()),
                            halfDayHours: double.parse(_halfDayHoursCtrl.text.trim()),
                            lateGraceMinutes: int.parse(_lateCtrl.text.trim()),
                            earlyExitGraceMinutes: int.parse(_earlyCtrl.text.trim()),
                            overtimeStartAfterHours: double.parse(_otStartCtrl.text.trim()),
                            maximumOvertimeHours: double.parse(_maxOtCtrl.text.trim()),
                            gpsRequired: _gpsRequired,
                            selfieRequired: _selfieRequired,
                            geofenceEnabled: _geofenceEnabled,
                            geofenceRadius: radInput,
                            allowAttendanceCorrection: _allowAttendanceCorrection,
                            weekendDays: _weekendDays,
                            status: settings.status,
                            createdAt: settings.createdAt,
                            updatedAt: DateTime.now(),
                          );

                          await ref.read(adminAttendanceSettingsProvider.notifier).saveSettings(newSettings);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Attendance rules updated successfully.'), backgroundColor: Colors.green),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF5B4CF0),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text('Update Attendance Policies', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
    required BuildContext context,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: isDark ? Theme.of(context).cardColor : Colors.white,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
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
                  color: color.withValues(alpha: isDark ? 0.2 : 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? Colors.white : const Color(0xFF1E293B)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    ),
  );
}
}
