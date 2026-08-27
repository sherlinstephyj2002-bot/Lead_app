import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../shared/models/user_model.dart';
import '../../../shared/models/employee_request_model.dart';
import '../../../shared/models/app_notification_model.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/widgets/subscription_upgrade_dialog.dart';
import '../../../constants/user_roles.dart';
import '../../../constants/feature_flags.dart';
import '../../../shared/widgets/company_logo_avatar.dart';
import '../../company_admin/providers/company_admin_providers.dart';
import '../../company_admin/screens/company_admin/employee_profile_screen.dart';

class EmployeesScreen extends ConsumerStatefulWidget {
  const EmployeesScreen({super.key});

  @override
  ConsumerState<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends ConsumerState<EmployeesScreen> {
  String _searchQuery = '';
  String _selectedRole = 'All';
  String _selectedStatus = 'All';
  String _selectedAttendance = 'All';

  late final TextEditingController _searchCtrl;

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final currentUser = authState.user;
    final employeesAsync = ref.watch(employeesProvider);

    final isAdmin = currentUser?.role == UserRoles.companyAdmin;
    final isHr = currentUser?.role == UserRoles.hr;
    final canAddOrRemove = isAdmin || isHr;

    final attendanceToday = ref.watch(companyAttendanceTodayProvider).value ?? [];

    const primaryColor = Color(0xFF5B4CF0);
    const outlineVariantColor = Color(0xFFC8C4D8);

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Theme.of(context).scaffoldBackgroundColor : const Color(0xFFF8F9FD),
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Employees',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'Manage your team members',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                color: Colors.white70,
              ),
            ),
          ],
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
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: () => ref.read(employeesProvider.notifier).loadEmployees(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Field
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                });
              },
              decoration: InputDecoration(
                hintText: 'Search by name, email, or employee ID...',
                hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13, fontFamily: 'Inter'),
                prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18, color: Color(0xFF64748B)),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: outlineVariantColor.withOpacity(0.3), width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: primaryColor, width: 1.5),
                ),
              ),
            ),
          ),

          // Filters Row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildFilterChip(
                  label: 'Role: $_selectedRole',
                  options: ['All', 'Employee', 'HR', 'Company Admin'],
                  selected: _selectedRole,
                  onSelected: (val) {
                    setState(() {
                      _selectedRole = val;
                    });
                  },
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  label: 'Status: $_selectedStatus',
                  options: ['All', 'Active', 'Inactive'],
                  selected: _selectedStatus,
                  onSelected: (val) {
                    setState(() {
                      _selectedStatus = val;
                    });
                  },
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  label: 'Attendance: $_selectedAttendance',
                  options: ['All', 'Present', 'Absent'],
                  selected: _selectedAttendance,
                  onSelected: (val) {
                    setState(() {
                      _selectedAttendance = val;
                    });
                  },
                ),
              ],
            ),
          ),

          // Employees List
          Expanded(
            child: employeesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 48, color: Colors.red),
                    const SizedBox(height: 12),
                    Text('Failed to load employees:\n$err', textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'Inter')),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => ref.read(employeesProvider.notifier).loadEmployees(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Retry', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
              data: (employees) {
                if (employees.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_outline_rounded, size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        const Text(
                          'No employees yet',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1B1B24), fontFamily: 'Inter'),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Employees who register with your\ncompany ID will appear here.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: Color(0xFF64748B), fontFamily: 'Inter'),
                        ),
                      ],
                    ),
                  );
                }

                final filtered = employees.where((emp) {
                  // Search query
                  if (_searchQuery.isNotEmpty) {
                    final query = _searchQuery.toLowerCase();
                    final nameMatch = emp.name.toLowerCase().contains(query);
                    final emailMatch = emp.email.toLowerCase().contains(query);
                    final idMatch = (emp.employeeId ?? '').toLowerCase().contains(query);
                    if (!nameMatch && !emailMatch && !idMatch) return false;
                  }

                  // Role filter
                  if (_selectedRole != 'All') {
                    final roleName = UserModel.denormalizeRole(emp.role);
                    if (roleName != _selectedRole) return false;
                  }

                  // Status filter
                  if (_selectedStatus != 'All') {
                    final isActive = emp.status.toLowerCase() == 'active';
                    if (_selectedStatus == 'Active' && !isActive) return false;
                    if (_selectedStatus == 'Inactive' && isActive) return false;
                  }

                  // Attendance filter
                  if (_selectedAttendance != 'All') {
                    final isPresent = attendanceToday.any((log) => log.employeeId == emp.uid);
                    if (_selectedAttendance == 'Present' && !isPresent) return false;
                    if (_selectedAttendance == 'Absent' && isPresent) return false;
                  }

                  return true;
                }).toList();

                if (filtered.isEmpty) {
                  return const Center(
                    child: Text(
                      'No employees match the selected filters.',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 14, fontFamily: 'Inter'),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () => ref.read(employeesProvider.notifier).loadEmployees(),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final emp = filtered[index];
                      final isPresent = attendanceToday.any((log) => log.employeeId == emp.uid);
                      return _EmployeeCard(
                        employee: emp,
                        isPresent: isPresent,
                        isAdmin: isAdmin,
                        isHr: isHr,
                        currentUserId: currentUser?.uid ?? '',
                        onEdit: () => _showEditSheet(context, ref, emp),
                        onDelete: () => _confirmDelete(context, ref, emp, currentUser),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: canAddOrRemove
          ? FloatingActionButton.extended(
              heroTag: 'employeeFab',
              onPressed: () => _showEditSheet(context, ref, null),
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              icon: const Icon(Icons.person_add_rounded),
              label: Text(
                isHr ? 'Request Employee' : 'Add Employee',
                style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Inter'),
              ),
            )
          : null,
    );
  }

  void _showEditSheet(BuildContext context, WidgetRef ref, UserModel? existing) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => EmployeeFormSheet(existing: existing, ref: ref),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, UserModel emp, UserModel? currentUser) {
    final isHr = currentUser?.role == UserRoles.hr;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(isHr ? 'Request Employee Removal' : 'Remove Employee', style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
        content: Text(
          isHr
              ? 'Request administrator approval to remove "${emp.name}" from your company?'
              : 'Remove "${emp.name}" from your company? Their data will remain in the system but they will lose access.',
          style: const TextStyle(fontFamily: 'Inter', fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              if (isHr && currentUser != null) {
                final userRepo = ref.read(userRepositoryProvider);
                final requestId = const Uuid().v4();
                final req = EmployeeRequestModel(
                  requestId: requestId,
                  companyId: currentUser.companyId,
                  requestedBy: currentUser.email,
                  requestedByName: currentUser.name,
                  requestType: 'DELETE_EMPLOYEE',
                  status: 'Pending',
                  createdAt: DateTime.now(),
                  employeeId: emp.uid,
                  employeeName: emp.name,
                );

                final notificationId = const Uuid().v4();
                final notif = AppNotificationModel(
                  notificationId: notificationId,
                  companyId: currentUser.companyId,
                  title: 'Employee Approval Request',
                  body: '${currentUser.name} requested to delete employee "${emp.name}".',
                  notificationType: 'EMPLOYEE_REQUEST',
                  isRead: false,
                  createdAt: DateTime.now(),
                  targetType: 'ROLE',
                  targetRole: UserRoles.companyAdmin,
                  actorUserId: currentUser.uid,
                  actorName: currentUser.name,
                  relatedModule: 'EMPLOYEE',
                  relatedEntityId: emp.uid,
                );

                await userRepo.createEmployeeRequest(req);
                await userRepo.createNotification(notif);

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Removal request for "${emp.name}" submitted to administrator.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } else {
                await ref.read(employeesProvider.notifier).removeEmployee(emp.uid);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('"${emp.name}" removed from team.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFBA1A1A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(isHr ? 'Request' : 'Remove', style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required List<String> options,
    required String selected,
    required ValueChanged<String> onSelected,
  }) {
    final isDefault = selected == 'All';
    return PopupMenuButton<String>(
      onSelected: onSelected,
      itemBuilder: (context) => options
          .map((opt) => PopupMenuItem(
                value: opt,
                child: Row(
                  children: [
                    if (opt == selected)
                      const Icon(Icons.check_rounded, color: Color(0xFF5B4CF0), size: 18)
                    else
                      const SizedBox(width: 18),
                    const SizedBox(width: 8),
                    Text(opt, style: const TextStyle(fontFamily: 'Inter', fontSize: 13)),
                  ],
                ),
              ))
          .toList(),
      child: Chip(
        label: Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDefault ? const Color(0xFF474555) : const Color(0xFF5B4CF0),
          ),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: isDefault ? Colors.white : const Color(0xFFE3DFFF),
        side: BorderSide(
          color: isDefault ? const Color(0xFFC8C4D8).withOpacity(0.4) : const Color(0xFF5B4CF0).withOpacity(0.3),
          width: 1,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Employee Card
// ─────────────────────────────────────────────
class _EmployeeCard extends StatelessWidget {
  final UserModel employee;
  final bool isPresent;
  final bool isAdmin;
  final bool isHr;
  final String currentUserId;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _EmployeeCard({
    required this.employee,
    required this.isPresent,
    required this.isAdmin,
    required this.isHr,
    required this.currentUserId,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF5B4CF0);
    const secondaryColor = Color(0xFF006C49);
    const errorColor = Color(0xFFBA1A1A);
    const onSurfaceColor = Color(0xFF191C1F);
    const onSurfaceVariantColor = Color(0xFF474555);
    const outlineVariantColor = Color(0xFFC8C4D8);

    final roleColors = <String, Color>{
      UserRoles.companyAdmin: primaryColor,
      UserRoles.hr: secondaryColor,
      UserRoles.employee: const Color(0xFF64748B),
    };
    final roleColor = roleColors[employee.role] ?? const Color(0xFF475569);
    final isSelf = employee.uid == currentUserId;
    final canManage = isAdmin || isHr;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: outlineVariantColor.withOpacity(0.3), width: 1),
      ),
      color: Colors.white,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF111827).withOpacity(0.02),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => EmployeeProfileScreen(employee: employee),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                // Avatar representation
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: roleColor.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: CompanyLogoAvatar(
                    user: employee,
                    companyId: employee.companyId,
                    radius: 24,
                    backgroundColor: Colors.transparent,
                    iconColor: roleColor,
                  ),
                ),
                const SizedBox(width: 14),
                // Info block
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            employee.name,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: onSurfaceColor,
                            ),
                          ),
                          if (isSelf) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8E4FF),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'YOU',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 8,
                                  color: primaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (employee.designation != null && employee.designation!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          '${employee.designation}${employee.department != null && employee.department!.isNotEmpty ? " (${employee.department})" : ""}',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            color: onSurfaceVariantColor,
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: roleColor.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              UserModel.denormalizeRole(employee.role),
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: roleColor,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isPresent ? const Color(0xFFDCFCE7) : const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isPresent ? secondaryColor.withOpacity(0.2) : errorColor.withOpacity(0.2),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 5,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    color: isPresent ? secondaryColor : errorColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  isPresent ? 'Present' : 'Absent',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: isPresent ? secondaryColor : errorColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (employee.status.toLowerCase() != 'active') ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: outlineVariantColor.withOpacity(0.3)),
                              ),
                              child: Text(
                                employee.status.toUpperCase(),
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: onSurfaceVariantColor,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (employee.role == UserRoles.employee) ...[
                        if (employee.employeeId != null && employee.employeeId!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.badge_outlined, size: 12, color: onSurfaceVariantColor),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  'ID: ${employee.employeeId}',
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 11,
                                    color: onSurfaceVariantColor,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ] else ...[
                        if (employee.email.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.email_outlined, size: 12, color: onSurfaceVariantColor),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  employee.email,
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 11,
                                    color: onSurfaceVariantColor,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                      if (employee.phoneNumber != null && employee.phoneNumber!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.phone_iphone_rounded, size: 12, color: onSurfaceVariantColor),
                            const SizedBox(width: 4),
                            Text(
                              employee.phoneNumber!,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 11,
                                color: onSurfaceVariantColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                // Pop menu actions
                if (canManage && !isSelf)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded, color: onSurfaceVariantColor),
                    onSelected: (val) {
                      if (val == 'edit') onEdit();
                      if (val == 'delete') onDelete();
                    },
                    itemBuilder: (_) => [
                      if (isAdmin)
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit_rounded, size: 16, color: primaryColor),
                              SizedBox(width: 8),
                              Text('Edit Details', style: TextStyle(fontFamily: 'Inter', fontSize: 13)),
                            ],
                          ),
                        ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_rounded, size: 16, color: errorColor),
                            SizedBox(width: 8),
                            Text('Remove', style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: errorColor)),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Employee Edit / Invite Bottom Sheet
// ─────────────────────────────────────────────
class EmployeeFormSheet extends StatefulWidget {
  final UserModel? existing;
  final WidgetRef ref;

  const EmployeeFormSheet({this.existing, required this.ref});

  @override
  State<EmployeeFormSheet> createState() => EmployeeFormSheetState();
}

class EmployeeFormSheetState extends State<EmployeeFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _empIdCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _personalEmailCtrl;
  late final TextEditingController _designationCtrl;
  late final TextEditingController _departmentCtrl;
  String? _selectedBranchId;
  String _selectedRole = UserRoles.employee;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
    _empIdCtrl = TextEditingController(text: widget.existing?.employeeId ?? '');
    _phoneCtrl = TextEditingController(text: widget.existing?.phoneNumber ?? '');
    _personalEmailCtrl = TextEditingController(text: widget.existing?.personalEmail ?? widget.existing?.employeeEmail ?? '');
    _designationCtrl = TextEditingController(text: widget.existing?.designation ?? '');
    _departmentCtrl = TextEditingController(text: widget.existing?.department ?? '');
    _selectedRole = UserModel.normalizeRole(widget.existing?.role ?? UserRoles.employee);
    _selectedBranchId = widget.existing?.branchId;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _empIdCtrl.dispose();
    _phoneCtrl.dispose();
    _personalEmailCtrl.dispose();
    _designationCtrl.dispose();
    _departmentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = widget.ref.read(authProvider).user;
    final isHr = currentUser?.role == UserRoles.hr;
    final isEdit = widget.existing != null;

    const primaryColor = Color(0xFF5B4CF0);

    InputDecoration _cleanInputDecoration(IconData icon, {String? hintText}) {
      return InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: Color(0xFF94A3B8)),
        prefixIcon: Icon(icon, size: 18, color: const Color(0xFF64748B)),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF5B4CF0), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
        ),
        errorStyle: const TextStyle(fontSize: 11, color: Color(0xFFEF4444), height: 1.1),
      );
    }

    Widget _buildFieldWrapper(String labelText, bool isRequired, Widget child) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 6.0),
            child: RichText(
              text: TextSpan(
                text: labelText,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF334155),
                ),
                children: [
                  if (isRequired)
                    const TextSpan(
                      text: ' *',
                      style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold),
                    )
                  else
                    const TextSpan(
                      text: ' (Optional)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.normal,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                ],
              ),
            ),
          ),
          child,
        ],
      );
    }

    Widget _buildSectionHeader(String title) {
      return Padding(
        padding: const EdgeInsets.only(top: 14.0, bottom: 10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
                color: Color(0xFF4F46E5),
              ),
            ),
            const SizedBox(height: 4),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
          ],
        ),
      );
    }

    Widget _buildRowOrStack(Widget first, Widget second, bool isDesktop) {
      if (isDesktop) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: first),
            const SizedBox(width: 16),
            Expanded(child: second),
          ],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          first,
          const SizedBox(height: 12),
          second,
        ],
      );
    }

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 540;

            final nameField = TextFormField(
              controller: _nameCtrl,
              decoration: _cleanInputDecoration(Icons.person_outline_rounded, hintText: 'Enter full name'),
              validator: (val) => (val == null || val.trim().isEmpty) ? 'Full Name is required' : null,
              style: const TextStyle(fontFamily: 'Inter', fontSize: 14),
            );

            final empIdField = !isEdit
                ? TextFormField(
                    controller: _empIdCtrl,
                    decoration: _cleanInputDecoration(Icons.badge_outlined, hintText: 'e.g. EMP001'),
                    style: const TextStyle(fontFamily: 'Inter', fontSize: 14),
                    validator: (val) => (val == null || val.trim().isEmpty) ? 'Employee ID is required' : null,
                  )
                : const SizedBox();

            final emailField = !isEdit
                ? TextFormField(
                    controller: _personalEmailCtrl,
                    decoration: _cleanInputDecoration(Icons.email_outlined, hintText: 'e.g. employee@company.com'),
                    style: const TextStyle(fontFamily: 'Inter', fontSize: 14),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'Personal Email is required';
                      if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(val.trim())) {
                        return 'Please enter a valid email address';
                      }
                      return null;
                    },
                  )
                : const SizedBox();

            final phoneField = TextFormField(
              controller: _phoneCtrl,
              decoration: _cleanInputDecoration(Icons.phone_iphone_rounded, hintText: 'e.g. 9876543210'),
              keyboardType: TextInputType.phone,
              style: const TextStyle(fontFamily: 'Inter', fontSize: 14),
            );

            final deptDropdown = Consumer(
              builder: (context, ref, child) {
                final deptsAsync = ref.watch(adminDepartmentsProvider);
                final activeDepts = (deptsAsync.value ?? []).where((d) => d.status.toLowerCase() == 'active').toList();
                final options = activeDepts.map((d) => d.name).toList();
                if (_departmentCtrl.text.isNotEmpty && !options.contains(_departmentCtrl.text)) {
                  options.insert(0, _departmentCtrl.text);
                }

                if (options.isEmpty) {
                  return TextFormField(
                    controller: _departmentCtrl,
                    decoration: _cleanInputDecoration(Icons.domain_outlined, hintText: 'Enter department name'),
                    style: const TextStyle(fontFamily: 'Inter', fontSize: 14),
                    validator: (val) => (val == null || val.trim().isEmpty) ? 'Department selection is required' : null,
                  );
                }

                return DropdownButtonFormField<String>(
                  value: options.contains(_departmentCtrl.text) ? _departmentCtrl.text : null,
                  decoration: _cleanInputDecoration(Icons.domain_outlined, hintText: 'Select Department'),
                  style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: Color(0xFF1B1B24)),
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B)),
                  items: [
                    const DropdownMenuItem<String>(value: null, child: Text('Select Department', style: TextStyle(fontFamily: 'Inter'))),
                    ...options.map((d) => DropdownMenuItem(value: d, child: Text(d, style: const TextStyle(fontFamily: 'Inter')))),
                  ],
                  validator: (val) => (val == null || val.trim().isEmpty) ? 'Department selection is required' : null,
                  onChanged: (val) {
                    setState(() => _departmentCtrl.text = val ?? '');
                  },
                );
              },
            );

            final desigDropdown = Consumer(
              builder: (context, ref, child) {
                final desigsAsync = ref.watch(adminDesignationsProvider);
                final activeDesigs = (desigsAsync.value ?? []).where((d) => d.status.toLowerCase() == 'active').toList();
                final options = activeDesigs.map((d) => d.designationName).toList();
                if (_designationCtrl.text.isNotEmpty && !options.contains(_designationCtrl.text)) {
                  options.insert(0, _designationCtrl.text);
                }

                if (options.isEmpty) {
                  return TextFormField(
                    controller: _designationCtrl,
                    decoration: _cleanInputDecoration(Icons.work_outline_rounded, hintText: 'Enter designation name'),
                    style: const TextStyle(fontFamily: 'Inter', fontSize: 14),
                    validator: (val) => (val == null || val.trim().isEmpty) ? 'Designation selection is required' : null,
                  );
                }

                return DropdownButtonFormField<String>(
                  value: options.contains(_designationCtrl.text) ? _designationCtrl.text : null,
                  decoration: _cleanInputDecoration(Icons.work_outline_rounded, hintText: 'Select Designation'),
                  style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: Color(0xFF1B1B24)),
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B)),
                  items: [
                    const DropdownMenuItem<String>(value: null, child: Text('Select Designation', style: TextStyle(fontFamily: 'Inter'))),
                    ...options.map((d) => DropdownMenuItem(value: d, child: Text(d, style: const TextStyle(fontFamily: 'Inter')))),
                  ],
                  validator: (val) => (val == null || val.trim().isEmpty) ? 'Designation selection is required' : null,
                  onChanged: (val) {
                    setState(() => _designationCtrl.text = val ?? '');
                  },
                );
              },
            );

            final branchDropdown = (!isEdit && FeatureFlags.enableBranchManagement)
                ? Consumer(
                    builder: (context, ref, child) {
                      final branchesAsync = ref.watch(adminBranchesProvider);
                      final branches = branchesAsync.value ?? [];

                      return DropdownButtonFormField<String>(
                        value: _selectedBranchId,
                        decoration: _cleanInputDecoration(Icons.location_city_rounded, hintText: 'Select Branch'),
                        style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: Color(0xFF1B1B24)),
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B)),
                        items: [
                          if (_selectedBranchId == null)
                            const DropdownMenuItem<String>(value: null, child: Text('Select Branch', style: TextStyle(fontFamily: 'Inter'))),
                          ...branches.map((b) {
                            return DropdownMenuItem(value: b.branchId, child: Text(b.branchName, style: const TextStyle(fontFamily: 'Inter')));
                          }),
                        ],
                        onChanged: (val) {
                          setState(() => _selectedBranchId = val);
                        },
                        validator: (val) => (val == null && FeatureFlags.enableBranchManagement) ? 'Branch assignment is required' : null,
                      );
                    },
                  )
                : const SizedBox();

            return Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle bar
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isEdit ? 'Edit Employee Details' : (isHr ? 'Request Employee Addition' : 'Add Employee'),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B), fontFamily: 'Inter'),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isEdit
                          ? 'Update employee name and organizational details.'
                          : (isHr
                              ? 'Submit an employee request to the company administrator for approval.'
                              : 'Enter employee details and assign organizational information.'),
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontFamily: 'Inter'),
                    ),
                    const SizedBox(height: 12),

                    // SECTION 1: EMPLOYEE INFORMATION
                    _buildSectionHeader('EMPLOYEE INFORMATION'),
                    !isEdit
                        ? _buildRowOrStack(
                            _buildFieldWrapper('Full Name', true, nameField),
                            _buildFieldWrapper('Employee ID', true, empIdField),
                            isDesktop,
                          )
                        : _buildFieldWrapper('Full Name', true, nameField),
                    const SizedBox(height: 14),
                    !isEdit
                        ? _buildRowOrStack(
                            _buildFieldWrapper('Personal Email', true, emailField),
                            _buildFieldWrapper('Phone Number', false, phoneField),
                            isDesktop,
                          )
                        : _buildFieldWrapper('Phone Number', false, phoneField),

                    // SECTION 2: ORGANIZATIONAL DETAILS
                    const SizedBox(height: 8),
                    _buildSectionHeader('ORGANIZATIONAL DETAILS'),
                    _buildRowOrStack(
                      _buildFieldWrapper('Department', true, deptDropdown),
                      _buildFieldWrapper('Designation', true, desigDropdown),
                      isDesktop,
                    ),
                    if (!isEdit && FeatureFlags.enableBranchManagement) ...[
                      const SizedBox(height: 14),
                      _buildFieldWrapper('Assign Branch', true, branchDropdown),
                    ],
                    const SizedBox(height: 24),

                    // Submit button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Text(
                                isEdit ? 'Save Changes' : (isHr ? 'Submit Request' : 'Create Employee'),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Inter'),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final currentUser = widget.ref.read(authProvider).user;
    if (currentUser == null) return;
    final isHr = currentUser.role == UserRoles.hr;

    setState(() => _isSaving = true);

    try {
      if (widget.existing == null) {
        if (isHr) {
          // HR Flow: Create a request in employee_requests and a notification
          final userRepo = widget.ref.read(userRepositoryProvider);
          final requestId = const Uuid().v4();
          
          final req = EmployeeRequestModel(
            requestId: requestId,
            companyId: currentUser.companyId,
            requestedBy: currentUser.email,
            requestedByName: currentUser.name,
            requestType: 'ADD_EMPLOYEE',
            status: 'Pending',
            createdAt: DateTime.now(),
            employeeData: {
              'name': _nameCtrl.text.trim(),
              'personalEmail': _personalEmailCtrl.text.trim(),
              'phone': _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
              'designation': _designationCtrl.text.trim().isEmpty ? null : _designationCtrl.text.trim(),
              'department': _departmentCtrl.text.trim().isEmpty ? null : _departmentCtrl.text.trim(),
              'role': _selectedRole,
              'branchId': _selectedBranchId,
            },
          );

          final notificationId = const Uuid().v4();
          final notif = AppNotificationModel(
            notificationId: notificationId,
            companyId: currentUser.companyId,
            title: 'Employee Approval Request',
            body: '${currentUser.name} requested to add a new employee: ${_nameCtrl.text.trim()}.',
            notificationType: 'EMPLOYEE_REQUEST',
            isRead: false,
            createdAt: DateTime.now(),
            targetType: 'ROLE',
            targetRole: UserRoles.companyAdmin,
            actorUserId: currentUser.uid,
            actorName: currentUser.name,
            relatedModule: 'EMPLOYEE',
          );

          await userRepo.createEmployeeRequest(req);
          await userRepo.createNotification(notif);

          if (mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Employee addition request for "${_nameCtrl.text.trim()}" submitted to Admin.'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        } else {
          // Admin Flow: Create user directly
          final companyState = widget.ref.read(companyProvider);
          final company = companyState.value;
          final activeCount = company?.activeEmployees ?? 0;
          final freeLimit = company?.freeEmployeeLimit ?? 5;
          final additionalCost = company?.pricePerEmployee ?? 50.0;

          Future<void> executeAdminCreate() async {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (ctx) => const Center(child: CircularProgressIndicator()),
            );

            try {
              final branchesAsync = widget.ref.read(adminBranchesProvider);
              final branches = branchesAsync.value ?? [];
              final branchName = branches.where((b) => b.branchId == _selectedBranchId).isNotEmpty
                  ? branches.firstWhere((b) => b.branchId == _selectedBranchId).branchName
                  : null;

              final credentials = await widget.ref.read(adminEmployeesProvider.notifier).createEmployee(
                name: _nameCtrl.text.trim(),
                employeeId: _empIdCtrl.text.trim(),
                personalEmail: _personalEmailCtrl.text.trim(),
                phoneNumber: _phoneCtrl.text.trim(),
                departmentId: null,
                department: _departmentCtrl.text.trim().isEmpty ? null : _departmentCtrl.text.trim(),
                designationId: null,
                designation: _designationCtrl.text.trim().isEmpty ? null : _designationCtrl.text.trim(),
                managerId: null,
                joiningDate: DateTime.now(),
                employmentType: 'Full-Time',
                branchId: _selectedBranchId,
                branchName: branchName,
              );

              if (mounted) Navigator.pop(context); // Dismiss loader
              if (mounted) Navigator.pop(context); // Dismiss form dialog

              if (mounted) {
                _showEmployeeCredentialsDialog(
                  context,
                  credentials['employeeId']!,
                  credentials['companyCode']!,
                  credentials['companyEmail']!,
                  credentials['tempPassword']!,
                );
                await widget.ref.read(employeesProvider.notifier).loadEmployees();
              }
            } catch (e) {
              if (mounted) Navigator.pop(context); // Dismiss loader
              final errStr = e.toString();
              if (mounted && errStr.contains('Free Plan employee limit reached')) {
                Navigator.pop(context); // Dismiss form sheet
                SubscriptionUpgradeDialog.show(
                  context,
                  title: 'Free Plan employee limit reached.',
                  message: 'You currently have 5 active employees. Upgrade your subscription to add more employees.',
                );
              } else if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to create employee: ${errStr.replaceAll("Exception: ", "")}'),
                    backgroundColor: Colors.red.shade700,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            } finally {
              if (mounted) {
                setState(() => _isSaving = false);
              }
            }
          }

          if (activeCount >= freeLimit) {
            setState(() => _isSaving = false);
            showDialog(
              context: context,
              builder: (dialogCtx) => AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                title: const Text('Free employee limit reached.', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Adding this employee will increase your monthly subscription.', style: TextStyle(fontWeight: FontWeight.w500, fontFamily: 'Inter', fontSize: 13)),
                    const SizedBox(height: 16),
                    Text('Current Employees:\n$activeCount', style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Inter', fontSize: 13)),
                    const SizedBox(height: 12),
                    Text('Additional Monthly Cost:\n₹${additionalCost.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.purple, fontFamily: 'Inter', fontSize: 13)),
                    const SizedBox(height: 16),
                    const Text('Continue?', style: TextStyle(fontFamily: 'Inter', fontSize: 13)),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(dialogCtx);
                    },
                    child: const Text('Cancel', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600)),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(dialogCtx);
                      executeAdminCreate();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5B4CF0),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Create Employee', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          } else {
            executeAdminCreate();
          }
        }
      } else {
        // Edit flow (Admin only)
        final updated = widget.existing!.copyWith(
          name: _nameCtrl.text.trim(),
          role: _selectedRole,
          phoneNumber: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
          designation: _designationCtrl.text.trim().isEmpty ? null : _designationCtrl.text.trim(),
          department: _departmentCtrl.text.trim().isEmpty ? null : _departmentCtrl.text.trim(),
        );

        await widget.ref.read(employeesProvider.notifier).updateEmployee(updated);

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Employee updated successfully.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showEmployeeCredentialsDialog(BuildContext context, String employeeId, String companyCode, String companyEmail, String password) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.green),
              SizedBox(width: 8),
              Text('Employee Created Successfully', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Inter', fontSize: 16)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'An account has been created for this employee. The employee will use these credentials for initial login and will be required to change password.',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontFamily: 'Inter', height: 1.4),
              ),
              const SizedBox(height: 16),
              const Text('Company Code', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF64748B), fontFamily: 'Inter')),
              const SizedBox(height: 4),
              SelectableText(
                companyCode,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B), fontFamily: 'Inter'),
              ),
              const SizedBox(height: 12),
              const Text('Employee ID', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF64748B), fontFamily: 'Inter')),
              const SizedBox(height: 4),
              SelectableText(
                employeeId,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF4F46E5), fontFamily: 'Inter'),
              ),
              const SizedBox(height: 12),
              const Text('Company Email', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF64748B), fontFamily: 'Inter')),
              const SizedBox(height: 4),
              SelectableText(
                companyEmail,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B), fontFamily: 'Inter'),
              ),
              const SizedBox(height: 12),
              const Text('Initial Password', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF64748B), fontFamily: 'Inter')),
              const SizedBox(height: 4),
              SelectableText(
                password,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF5B4CF0), fontFamily: 'Inter'),
              ),
              const SizedBox(height: 16),
              const Text(
                'Please provide these initial login credentials securely to the employee.',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.green, fontFamily: 'Inter', height: 1.3),
              ),
            ],
          ),
          actions: [
            TextButton.icon(
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: const Text('Copy', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600)),
              onPressed: () {
                final text = 'Company Code: $companyCode\nEmployee ID: $employeeId\nCompany Email: $companyEmail\nInitial Password: $password';
                Clipboard.setData(ClipboardData(text: text));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Credentials copied to clipboard.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5B4CF0),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('OK', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }
}
