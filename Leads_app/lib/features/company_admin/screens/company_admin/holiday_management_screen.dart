import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:worktrack/shared/providers/providers.dart';
import 'package:worktrack/constants/user_roles.dart';
import 'package:worktrack/shared/models/app_notification_model.dart';
import 'package:worktrack/shared/repositories/user_repository.dart';
import 'package:worktrack/features/company_admin/models/holiday_model.dart';
import 'package:worktrack/features/company_admin/providers/company_admin_providers.dart';
import 'package:worktrack/features/calendar/models/calendar_view_type.dart';
import 'package:worktrack/features/calendar/providers/calendar_provider.dart';
import 'package:worktrack/features/calendar/widgets/calendar_header_widget.dart';
import 'package:worktrack/features/calendar/widgets/calendar_sidebar_widget.dart';
import 'package:worktrack/features/calendar/widgets/calendar_month_view.dart';
import 'package:worktrack/features/calendar/widgets/calendar_week_view.dart';
import 'package:worktrack/features/calendar/widgets/calendar_day_view.dart';
import 'package:worktrack/features/calendar/widgets/calendar_agenda_view.dart';

class HolidayManagementScreen extends ConsumerStatefulWidget {
  const HolidayManagementScreen({super.key});

  @override
  ConsumerState<HolidayManagementScreen> createState() => _HolidayManagementScreenState();
}

class _HolidayManagementScreenState extends ConsumerState<HolidayManagementScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _listSearchQuery = '';
  String _selectedTypeFilter = 'All';
  String _selectedBranchFilter = 'All';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    Future.microtask(() {
      ref.read(adminHolidaysProvider.notifier).loadHolidays();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showAddHolidayModal(BuildContext context, {HolidayModel? existingHoliday, DateTime? initialDate}) {
    final currentUser = ref.read(authProvider).user;
    final nameCtrl = TextEditingController(text: existingHoliday?.holidayName ?? '');
    final descCtrl = TextEditingController(text: existingHoliday?.description ?? '');
    DateTime selectedStartDate = existingHoliday?.holidayDate ?? initialDate ?? DateTime.now();
    DateTime selectedEndDate = existingHoliday?.holidayDate ?? initialDate ?? DateTime.now();
    String selectedType = existingHoliday?.holidayType ?? 'National';
    String? selectedBranchId = existingHoliday?.branchId;
    bool isRecurring = existingHoliday?.isRecurring ?? false;
    bool notifyEmployees = true;
    bool isSaving = false;

    final branches = ref.read(adminBranchesProvider).value ?? [];

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  const Icon(Icons.nature_people_rounded, color: Color(0xFFEF4444), size: 24),
                  const SizedBox(width: 8),
                  Text(
                    existingHoliday == null ? 'Add New Holiday' : 'Edit Holiday',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Inter', fontSize: 18),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 480,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Holiday Name *',
                          hintText: 'E.g., Independence Day',
                          prefixIcon: Icon(Icons.badge_outlined),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        value: selectedType,
                        decoration: const InputDecoration(
                          labelText: 'Holiday Type *',
                          prefixIcon: Icon(Icons.star_outline_rounded),
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'National', child: Text('National Holiday')),
                          DropdownMenuItem(value: 'Company', child: Text('Company Holiday')),
                          DropdownMenuItem(value: 'Branch', child: Text('Branch/Regional Holiday')),
                          DropdownMenuItem(value: 'Festival', child: Text('Festival Holiday')),
                          DropdownMenuItem(value: 'Optional', child: Text('Optional Holiday')),
                        ],
                        onChanged: (val) {
                          if (val != null) setModalState(() => selectedType = val);
                        },
                      ),
                      const SizedBox(height: 14),

                      // Dates Selection
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final date = await showDatePicker(
                                  context: context,
                                  initialDate: selectedStartDate,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2035),
                                );
                                if (date != null) {
                                  setModalState(() {
                                    selectedStartDate = date;
                                    if (selectedEndDate.isBefore(selectedStartDate)) {
                                      selectedEndDate = selectedStartDate;
                                    }
                                  });
                                }
                              },
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Start Date *',
                                  prefixIcon: Icon(Icons.calendar_today_rounded),
                                  border: OutlineInputBorder(),
                                ),
                                child: Text(DateFormat('dd MMM yyyy').format(selectedStartDate), style: const TextStyle(fontFamily: 'Inter', fontSize: 13)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final date = await showDatePicker(
                                  context: context,
                                  initialDate: selectedEndDate,
                                  firstDate: selectedStartDate,
                                  lastDate: DateTime(2035),
                                );
                                if (date != null) {
                                  setModalState(() => selectedEndDate = date);
                                }
                              },
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'End Date *',
                                  prefixIcon: Icon(Icons.event_rounded),
                                  border: OutlineInputBorder(),
                                ),
                                child: Text(DateFormat('dd MMM yyyy').format(selectedEndDate), style: const TextStyle(fontFamily: 'Inter', fontSize: 13)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Branch Selection
                      DropdownButtonFormField<String?>(
                        value: selectedBranchId,
                        decoration: const InputDecoration(
                          labelText: 'Applicable Branch / Region (Optional)',
                          prefixIcon: Icon(Icons.location_city_rounded),
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('All Branches / Corporate')),
                          ...branches.map((b) => DropdownMenuItem(value: b.branchId, child: Text(b.branchName))),
                        ],
                        onChanged: (val) => setModalState(() => selectedBranchId = val),
                      ),
                      const SizedBox(height: 14),

                      TextField(
                        controller: descCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Description / Notes',
                          hintText: 'Add details about this holiday...',
                          prefixIcon: Icon(Icons.description_outlined),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),

                      SwitchListTile(
                        title: const Text('Repeat Every Year', style: TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w600)),
                        subtitle: const Text('Automatically adds this holiday annually', style: TextStyle(fontSize: 12)),
                        value: isRecurring,
                        activeColor: const Color(0xFF5B4CF0),
                        onChanged: (val) => setModalState(() => isRecurring = val),
                      ),

                      SwitchListTile(
                        title: const Text('Notify Employees', style: TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w600)),
                        subtitle: const Text('Send notification to all affected employees', style: TextStyle(fontSize: 12)),
                        value: notifyEmployees,
                        activeColor: const Color(0xFF5B4CF0),
                        onChanged: (val) => setModalState(() => notifyEmployees = val),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(ctx),
                  child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B), fontFamily: 'Inter')),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5B4CF0),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (nameCtrl.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please enter a holiday name.'), backgroundColor: Colors.red),
                            );
                            return;
                          }

                          setModalState(() => isSaving = true);

                          try {
                            final companyId = (currentUser?.companyId != null && currentUser!.companyId.isNotEmpty)
                                ? currentUser.companyId
                                : (existingHoliday?.companyId ?? '');

                            final newHoliday = HolidayModel(
                              holidayId: existingHoliday?.holidayId ?? const Uuid().v4(),
                              companyId: companyId,
                              branchId: selectedBranchId,
                              holidayName: nameCtrl.text.trim(),
                              holidayDate: selectedStartDate,
                              holidayType: selectedType,
                              description: descCtrl.text.trim(),
                              isRecurring: isRecurring,
                              status: 'active',
                              createdAt: existingHoliday?.createdAt ?? DateTime.now(),
                              updatedAt: DateTime.now(),
                            );

                            await ref.read(adminHolidaysProvider.notifier).saveHoliday(newHoliday);

                            if (notifyEmployees && currentUser != null && currentUser.companyId.isNotEmpty) {
                              try {
                                final notif = AppNotificationModel(
                                  notificationId: const Uuid().v4(),
                                  companyId: currentUser.companyId,
                                  title: 'Holiday Update: ${newHoliday.holidayName}',
                                  body: '${newHoliday.holidayName} (${newHoliday.holidayType}) scheduled on ${DateFormat('dd MMM yyyy').format(newHoliday.holidayDate)}.',
                                  notificationType: 'HOLIDAY_ANNOUNCEMENT',
                                  isRead: false,
                                  createdAt: DateTime.now(),
                                  targetType: 'COMPANY',
                                  actorUserId: currentUser.uid,
                                  actorName: currentUser.name,
                                  relatedModule: 'SETTINGS',
                                  relatedEntityId: newHoliday.holidayId,
                                );
                                await ref.read(userRepositoryProvider).createNotification(notif);
                              } catch (_) {}
                            }

                            if (mounted && ctx.mounted) {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('${newHoliday.holidayName} saved successfully.'), backgroundColor: Colors.green),
                              );
                            }
                          } catch (e) {
                            setModalState(() => isSaving = false);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Failed to save holiday: $e'), backgroundColor: Colors.red),
                              );
                            }
                          }
                        },
                  child: isSaving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(existingHoliday == null ? 'Save Holiday' : 'Update Holiday', style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Inter')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _handleDeleteHoliday(HolidayModel holiday) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Holiday', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Inter')),
        content: Text('Are you sure you want to delete "${holiday.holidayName}"?', style: const TextStyle(fontFamily: 'Inter')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ref.read(adminHolidaysProvider.notifier).deleteHoliday(holiday.holidayId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${holiday.holidayName} deleted.'), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(authProvider).user;
    final canManageHolidays = UserRoles.canManageHolidays(currentUser?.role);
    final isAdmin = canManageHolidays;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final holidaysAsync = ref.watch(adminHolidaysProvider);

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
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Holiday Management & Calendar',
              style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 17, color: Colors.white),
            ),
            Text(
              'Enterprise unified holiday schedule, events & company calendar',
              style: TextStyle(fontSize: 11, color: Color(0xFFC7D2FE)),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh Calendar',
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: () {
              ref.read(adminHolidaysProvider.notifier).loadHolidays();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Calendar reloaded.'), backgroundColor: Colors.green),
              );
            },
          ),
          if (isAdmin) ...[
            const SizedBox(width: 4),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: ElevatedButton.icon(
                onPressed: () => _showAddHolidayModal(context),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add Holiday', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Inter')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF5B4CF0),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: const Color(0xFFC7D2FE),
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Inter', fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.calendar_month_rounded, size: 18), text: 'Enterprise Calendar'),
            Tab(icon: Icon(Icons.list_alt_rounded, size: 18), text: 'Holiday Records List'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCalendarTab(isDark),
          _buildHolidayListTab(holidaysAsync, isAdmin, isDark),
        ],
      ),
    );
  }

  Widget _buildCalendarTab(bool isDark) {
    final state = ref.watch(calendarProvider);
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth > 900;
          return Column(
            children: [
              const CalendarHeaderWidget(),
              const SizedBox(height: 16),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isDesktop) ...[
                      const CalendarSidebarWidget(),
                      const SizedBox(width: 16),
                    ],
                    Expanded(
                      child: _buildCurrentView(state.viewType),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCurrentView(CalendarViewType viewType) {
    switch (viewType) {
      case CalendarViewType.month:
        return const CalendarMonthView();
      case CalendarViewType.week:
        return const CalendarWeekView();
      case CalendarViewType.day:
        return const CalendarDayView();
      case CalendarViewType.agenda:
        return const CalendarAgendaView();
    }
  }

  Widget _buildHolidayListTab(AsyncValue<List<HolidayModel>> holidaysAsync, bool isAdmin, bool isDark) {
    return holidaysAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error loading holidays: $e')),
      data: (holidays) {
        final branches = ref.watch(adminBranchesProvider).value ?? [];
        final branchMap = {for (var b in branches) b.branchId: b.branchName};

        final filtered = holidays.where((h) {
          if (_selectedTypeFilter != 'All' && h.holidayType.toLowerCase() != _selectedTypeFilter.toLowerCase()) return false;
          if (_selectedBranchFilter != 'All' && (h.branchId ?? '') != _selectedBranchFilter) return false;
          if (_listSearchQuery.trim().isNotEmpty) {
            final q = _listSearchQuery.trim().toLowerCase();
            final name = h.holidayName.toLowerCase();
            final desc = h.description.toLowerCase();
            final type = h.holidayType.toLowerCase();
            return name.contains(q) || desc.contains(q) || type.contains(q);
          }
          return true;
        }).toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search & Filter Header
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      onChanged: (v) => setState(() => _listSearchQuery = v),
                      decoration: const InputDecoration(
                        hintText: 'Search Holiday Name, Type or Description...',
                        prefixIcon: Icon(Icons.search_rounded),
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  DropdownButton<String>(
                    value: _selectedTypeFilter,
                    items: const [
                      DropdownMenuItem(value: 'All', child: Text('All Types')),
                      DropdownMenuItem(value: 'National', child: Text('National')),
                      DropdownMenuItem(value: 'Company', child: Text('Company')),
                      DropdownMenuItem(value: 'Branch', child: Text('Branch')),
                      DropdownMenuItem(value: 'Festival', child: Text('Festival')),
                      DropdownMenuItem(value: 'Optional', child: Text('Optional')),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _selectedTypeFilter = v);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (filtered.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(40.0),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.event_busy_rounded, size: 48, color: Color(0xFF64748B)),
                        SizedBox(height: 12),
                        Text(
                          'No Company Holidays Found',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Inter', color: Color(0xFF191C1F)),
                        ),
                        SizedBox(height: 4),
                        Text('Add a new holiday or clear filters to view recorded holidays.', style: TextStyle(fontSize: 13, color: Color(0xFF64748B), fontFamily: 'Inter')),
                      ],
                    ),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, idx) {
                    final holiday = filtered[idx];
                    final branchName = holiday.branchId != null ? (branchMap[holiday.branchId] ?? 'Branch (${holiday.branchId})') : 'All Branches / Corporate';

                    Color typeColor;
                    switch (holiday.holidayType.toLowerCase()) {
                      case 'national':
                        typeColor = const Color(0xFF3B82F6);
                        break;
                      case 'company':
                        typeColor = const Color(0xFFEF4444);
                        break;
                      case 'branch':
                        typeColor = const Color(0xFF8B5CF6);
                        break;
                      case 'festival':
                        typeColor = const Color(0xFFF59E0B);
                        break;
                      default:
                        typeColor = const Color(0xFF10B981);
                        break;
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? Theme.of(context).cardColor : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: typeColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.nature_people_rounded, color: typeColor, size: 24),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(holiday.holidayName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? Colors.white : const Color(0xFF1E293B), fontFamily: 'Inter')),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: typeColor.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: typeColor.withValues(alpha: 0.3)),
                                      ),
                                      child: Text(holiday.holidayType.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: typeColor)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${DateFormat('EEEE, dd MMMM yyyy').format(holiday.holidayDate)} • $branchName',
                                  style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontFamily: 'Inter'),
                                ),
                                if (holiday.description.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(holiday.description, style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF64748B) : const Color(0xFF475569), fontFamily: 'Inter')),
                                ],
                              ],
                            ),
                          ),
                          if (isAdmin) ...[
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, color: Color(0xFF5B4CF0)),
                              onPressed: () => _showAddHolidayModal(context, existingHoliday: holiday),
                              tooltip: 'Edit Holiday',
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                              onPressed: () => _handleDeleteHoliday(holiday),
                              tooltip: 'Delete Holiday',
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}
