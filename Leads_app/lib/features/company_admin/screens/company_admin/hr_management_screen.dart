import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:worktrack/shared/providers/providers.dart';
import 'package:worktrack/shared/models/user_model.dart';
import 'package:worktrack/constants/user_roles.dart';
import 'package:worktrack/features/company_admin/providers/company_admin_providers.dart';
import 'package:worktrack/shared/widgets/app_user_avatar.dart';
import 'role_permissions_screen.dart';

class HRManagementScreen extends ConsumerStatefulWidget {
  const HRManagementScreen({super.key});

  @override
  ConsumerState<HRManagementScreen> createState() => _HRManagementScreenState();
}

class _HRManagementScreenState extends ConsumerState<HRManagementScreen> {
  String _selectedRoleFilter = 'All';
  String _selectedStatusFilter = 'All';
  String _searchQuery = '';
  List<String> _companyRoles = [UserRoles.hrAdmin, UserRoles.hrExecutive];

  @override
  void initState() {
    super.initState();
    _loadCompanyRoles();
  }

  Future<void> _loadCompanyRoles() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('roles')
          .where('companyId', isEqualTo: user.companyId)
          .get();
      if (snap.docs.isNotEmpty) {
        final list = snap.docs.map((doc) => UserModel.normalizeRole(doc.data()['roleName'] as String)).toList();
        
        final systemDefaults = [
          UserRoles.hrAdmin,
          UserRoles.hrExecutive,
          UserRoles.hr,
          UserRoles.employee,
          UserRoles.companyAdmin,
          UserRoles.manager,
          UserRoles.teamLeader
        ];
        for (final sys in systemDefaults) {
          if (!list.contains(sys)) {
            list.add(sys);
          }
        }

        setState(() {
          _companyRoles = list;
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final hrUsersAsync = ref.watch(hrUsersProvider);

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Theme.of(context).scaffoldBackgroundColor : const Color(0xFFF8F9FD),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('HR & Executive Management', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF5B4CF0), fontFamily: 'Inter')),
            Text('Manage HR Administrators and Executives', style: TextStyle(fontSize: 10, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontFamily: 'Inter')),
          ],
        ),
        iconTheme: const IconThemeData(color: Color(0xFF5B4CF0)),
        backgroundColor: isDark ? Theme.of(context).cardColor : Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            height: 1.0,
          ),
        ),
        actions: [
          ElevatedButton.icon(
            onPressed: () => _showAssignHRRoleDialog(context),
            icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
            label: const Text('Assign HR Role', style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5B4CF0),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF5B4CF0)),
            onPressed: () => ref.read(hrUsersProvider.notifier).loadHRUsers(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Search Bar
            Container(
              decoration: BoxDecoration(
                color: isDark ? Theme.of(context).cardColor : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFC8C4D8).withOpacity(0.3)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF111827).withOpacity(0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                onChanged: (v) {
                  setState(() {
                    _searchQuery = v;
                  });
                },
                style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: isDark ? Colors.white : const Color(0xFF191C1F)),
                decoration: InputDecoration(
                  hintText: 'Search executives...',
                  hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, fontFamily: 'Inter'),
                  prefixIcon: Icon(Icons.search_rounded, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), size: 20),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Filter Bar
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF5B4CF0).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.filter_list_rounded, size: 14, color: Color(0xFF5B4CF0)),
                        SizedBox(width: 4),
                        Text(
                          'Filters',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF5B4CF0),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  PopupMenuButton<String>(
                    onSelected: (val) {
                      setState(() {
                        _selectedRoleFilter = val;
                      });
                    },
                    itemBuilder: (ctx) => ['All', 'HR Admin', 'HR Executive'].map((role) => PopupMenuItem(value: role, child: Text(role, style: const TextStyle(fontFamily: 'Inter')))).toList(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Text(
                            'Role: $_selectedRoleFilter',
                            style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF474555), fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.expand_more_rounded, size: 14, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF474555)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  PopupMenuButton<String>(
                    onSelected: (val) {
                      setState(() {
                        _selectedStatusFilter = val;
                      });
                    },
                    itemBuilder: (ctx) => ['All', 'Active', 'Suspended'].map((status) => PopupMenuItem(value: status, child: Text(status, style: const TextStyle(fontFamily: 'Inter')))).toList(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Text(
                            'Status: $_selectedStatusFilter',
                            style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF474555), fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.expand_more_rounded, size: 14, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF474555)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Title Row
            Row(
              children: [
                Text(
                  'Team Directory',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF191C1F),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // User List cards
            Expanded(
              child: hrUsersAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(
                  child: Text('Error loading HR users: $err', style: const TextStyle(color: Colors.red, fontFamily: 'Inter')),
                ),
                data: (users) {
                  final filteredUsers = users.where((u) {
                    if (_selectedRoleFilter != 'All') {
                      if (_selectedRoleFilter == 'HR Admin' && u.role != UserRoles.hrAdmin) return false;
                      if (_selectedRoleFilter == 'HR Executive' && u.role != UserRoles.hrExecutive) return false;
                    }
                    if (_selectedStatusFilter != 'All') {
                      if (_selectedStatusFilter == 'Active' && u.status.toLowerCase() != 'active') return false;
                      if (_selectedStatusFilter == 'Suspended' && u.status.toLowerCase() != 'suspended') return false;
                    }
                    return true;
                  }).toList();

                  final query = _searchQuery.trim().toLowerCase();
                  final displayUsers = filteredUsers.where((u) {
                    if (query.isEmpty) return true;
                    final nameMatch = u.name.toLowerCase().contains(query);
                    final emailMatch = u.email.toLowerCase().contains(query) || (u.companyEmail?.toLowerCase().contains(query) ?? false);
                    final idMatch = (u.employeeId?.toLowerCase().contains(query) ?? false);
                    final deptMatch = (u.department?.toLowerCase().contains(query) ?? false);
                    final desigMatch = (u.designation?.toLowerCase().contains(query) ?? false);
                    final roleMatch = u.role.toLowerCase().contains(query) || UserModel.denormalizeRole(u.role).toLowerCase().contains(query);
                    return nameMatch || emailMatch || idMatch || deptMatch || desigMatch || roleMatch;
                  }).toList();

                  if (displayUsers.isEmpty) {
                    return const Center(
                      child: Text(
                        'No executives found matching criteria.',
                        style: TextStyle(fontFamily: 'Inter', color: Color(0xFF64748B)),
                      ),
                    );
                  }

                  return ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    itemCount: displayUsers.length,
                    itemBuilder: (ctx, idx) => _buildHRCard(displayUsers[idx]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHRCard(UserModel user) {
    final statusColor = user.status.toLowerCase() == 'active' ? const Color(0xFF007834) : const Color(0xFFBA1A1A);
    final statusBg = user.status.toLowerCase() == 'active' ? const Color(0xFFDCFCE7) : const Color(0xFFFEF2F2);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      decoration: BoxDecoration(
        color: isDark ? Theme.of(context).cardColor : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFC8C4D8).withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF111827).withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => _viewProfile(context, user),
          borderRadius: BorderRadius.circular(16),
          hoverColor: const Color(0xFF5B4CF0).withValues(alpha: 0.04),
          splashColor: const Color(0xFF5B4CF0).withValues(alpha: 0.1),
          highlightColor: const Color(0xFF5B4CF0).withValues(alpha: 0.05),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppUserAvatar(
                  user: user,
                  radius: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF191C1F),
                        ),
                      ),
                      if (user.employeeId != null && user.employeeId!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          'ID: ${user.employeeId}',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    user.status.toUpperCase(),
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Department + Designation + System Role Metadata Badges
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (user.department != null && user.department!.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.business_rounded, size: 12, color: Color(0xFF6366F1)),
                        const SizedBox(width: 4),
                        Text(
                          'Dept: ${user.department}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF6366F1), fontFamily: 'Inter'),
                        ),
                      ],
                    ),
                  ),
                if (user.designation != null && user.designation!.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0EA5E9).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.badge_outlined, size: 12, color: Color(0xFF0EA5E9)),
                        const SizedBox(width: 4),
                        Text(
                          'Designation: ${user.designation}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0EA5E9), fontFamily: 'Inter'),
                        ),
                      ],
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF5B4CF0).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.admin_panel_settings_rounded, size: 12, color: Color(0xFF5B4CF0)),
                      const SizedBox(width: 4),
                      Text(
                        'System Role: ${UserModel.denormalizeRole(user.role)}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF5B4CF0), fontFamily: 'Inter'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Divider(height: 24, color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
            Row(
              children: [
                const Icon(Icons.email_outlined, size: 16, color: Color(0xFF64748B)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    user.email,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF474555),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (user.phoneNumber != null && user.phoneNumber!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.phone_outlined, size: 16, color: Color(0xFF64748B)),
                  const SizedBox(width: 8),
                  Text(
                    user.phoneNumber!,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF474555),
                    ),
                  ),
                ],
              ),
            ],
            Divider(height: 24, color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.admin_panel_settings_outlined, color: Color(0xFF5B4CF0), size: 20),
                  tooltip: 'Change System Role',
                  onPressed: () => _showAssignHRRoleDialog(context, targetUser: user),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF64748B), size: 20),
                  tooltip: 'More Actions',
                  onSelected: (val) {
                    if (val == 'change_role') {
                      _showAssignHRRoleDialog(context, targetUser: user);
                    } else if (val == 'remove_role') {
                      _confirmRemoveHRRole(context, user);
                    } else if (val == 'toggle_status') {
                      _confirmToggleStatus(context, user);
                    } else if (val == 'reset_password') {
                      _confirmResetPassword(context, user);
                    } else if (val == 'delete') {
                      _confirmDelete(context, user.uid, user.name);
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'change_role',
                      child: Row(
                        children: [
                          Icon(Icons.badge_rounded, color: Color(0xFF5B4CF0), size: 18),
                          SizedBox(width: 8),
                          Text('Change System Role', style: TextStyle(fontFamily: 'Inter', fontSize: 13)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'remove_role',
                      child: Row(
                        children: [
                          Icon(Icons.person_remove_outlined, color: Colors.orange, size: 18),
                          SizedBox(width: 8),
                          Text('Remove HR Role', style: TextStyle(fontFamily: 'Inter', fontSize: 13)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'toggle_status',
                      child: Row(
                        children: [
                          Icon(
                            user.status.toLowerCase() == 'active' ? Icons.block_rounded : Icons.check_circle_outline_rounded,
                            color: user.status.toLowerCase() == 'active' ? Colors.orange : Colors.green,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(user.status.toLowerCase() == 'active' ? 'Suspend Account' : 'Activate Account', style: const TextStyle(fontFamily: 'Inter', fontSize: 13)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'reset_password',
                      child: Row(
                        children: [
                          Icon(Icons.lock_reset_rounded, color: Colors.purple, size: 18),
                          SizedBox(width: 8),
                          Text('Reset Password', style: TextStyle(fontFamily: 'Inter', fontSize: 13)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_rounded, color: Colors.red, size: 18),
                          SizedBox(width: 8),
                          Text('Delete Account', style: TextStyle(color: Colors.red, fontFamily: 'Inter', fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
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

  void _confirmRemoveHRRole(BuildContext context, UserModel user) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove HR Role', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
        content: Text(
          'Are you sure you want to remove the HR System Role from ${user.name}? This will remove HR access permissions while leaving their employee profile intact.',
          style: const TextStyle(fontFamily: 'Inter', fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(fontFamily: 'Inter')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(hrUsersProvider.notifier).removeHRRole(user.uid);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('HR Role removed from ${user.name}. Profile set back to standard Employee.'), backgroundColor: Colors.orange),
                );
              }
            },
            child: const Text('Remove HR Role', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showAssignHRRoleDialog(BuildContext context, {UserModel? targetUser}) {
    final allEmployeesAsync = ref.read(adminEmployeesProvider);
    final allEmployees = allEmployeesAsync.value ?? [];

    if (allEmployees.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No company employees found. Please create employees in Employee Management first.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Deduplicate employees by UID
    final seenUids = <String>{};
    final uniqueEmployees = allEmployees.where((emp) => seenUids.add(emp.uid)).toList();

    String? selectedEmpUid = targetUser?.uid ?? (uniqueEmployees.isNotEmpty ? uniqueEmployees.first.uid : null);
    String selectedRole = UserModel.normalizeRole(
      targetUser != null 
          ? (targetUser.role == UserRoles.employee ? UserRoles.hrAdmin : targetUser.role)
          : UserRoles.hrAdmin
    );
    String searchEmpQuery = '';
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;

            final filteredEmpList = uniqueEmployees.where((emp) {
              if (searchEmpQuery.trim().isEmpty) return true;
              final q = searchEmpQuery.trim().toLowerCase();
              final matchName = emp.name.toLowerCase().contains(q);
              final matchId = (emp.employeeId ?? '').toLowerCase().contains(q);
              final matchEmail = emp.email.toLowerCase().contains(q) || (emp.companyEmail ?? '').toLowerCase().contains(q);
              final matchDept = (emp.department ?? '').toLowerCase().contains(q);
              final matchDesig = (emp.designation ?? '').toLowerCase().contains(q);
              return matchName || matchId || matchEmail || matchDept || matchDesig;
            }).toList();

            // Auto-selection & selection retention logic
            if (filteredEmpList.isEmpty) {
              selectedEmpUid = null;
            } else if (filteredEmpList.length == 1) {
              // Auto-select single matching result
              selectedEmpUid = filteredEmpList.first.uid;
            } else if (selectedEmpUid != null && !filteredEmpList.any((e) => e.uid == selectedEmpUid)) {
              // Fall back to first item if previous selection is no longer in list
              selectedEmpUid = filteredEmpList.first.uid;
            } else if (selectedEmpUid == null && filteredEmpList.isNotEmpty) {
              selectedEmpUid = filteredEmpList.first.uid;
            }

            final validEmpUid = (selectedEmpUid != null && filteredEmpList.any((e) => e.uid == selectedEmpUid))
                ? selectedEmpUid
                : (filteredEmpList.isNotEmpty ? filteredEmpList.first.uid : null);

            final selectedEmp = validEmpUid != null
                ? filteredEmpList.firstWhere((e) => e.uid == validEmpUid)
                : null;

            final isAlreadyHR = selectedEmp != null && selectedEmp.role != UserRoles.employee;

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              backgroundColor: isDark ? Theme.of(context).cardColor : Colors.white,
              title: const Row(
                children: [
                  Icon(Icons.badge_rounded, color: Color(0xFF5B4CF0)),
                  SizedBox(width: 8),
                  Text('Assign HR System Role', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF5B4CF0).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF5B4CF0).withValues(alpha: 0.2)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline_rounded, color: Color(0xFF5B4CF0), size: 18),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Assigning a System Role grants HR access permissions. It does NOT replace or overwrite Department or Designation.',
                              style: TextStyle(fontSize: 11, color: Color(0xFF334155), fontFamily: 'Inter', fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isAlreadyHR) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'This employee is already assigned as ${UserModel.denormalizeRole(selectedEmp.role)}. You can update or remove their role below.',
                                style: const TextStyle(fontSize: 11, color: Color(0xFF92400E), fontFamily: 'Inter', fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    TextField(
                      onChanged: (val) {
                        setModalState(() {
                          searchEmpQuery = val;
                        });
                      },
                      decoration: const InputDecoration(
                        labelText: 'Search Employee',
                        prefixIcon: Icon(Icons.search_rounded),
                        hintText: 'Search by name, ID, email, dept or desig...',
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (filteredEmpList.isEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.search_off_rounded, color: Colors.orange, size: 18),
                            SizedBox(width: 8),
                            Text('No employees found.', style: TextStyle(fontSize: 13, color: Color(0xFF64748B), fontFamily: 'Inter')),
                          ],
                        ),
                      )
                    else
                      DropdownButtonFormField<String>(
                        value: validEmpUid,
                        decoration: const InputDecoration(labelText: 'Select Employee *', prefixIcon: Icon(Icons.person_outline)),
                        items: filteredEmpList.map((emp) {
                          final displayLabel = '${emp.name} (${emp.employeeId ?? emp.email})';
                          return DropdownMenuItem<String>(
                            value: emp.uid,
                            child: Text(displayLabel, style: const TextStyle(fontSize: 13, fontFamily: 'Inter')),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setModalState(() {
                              selectedEmpUid = val;
                              final newlySelected = filteredEmpList.firstWhere((e) => e.uid == val);
                              if (newlySelected.role != UserRoles.employee) {
                                selectedRole = UserModel.normalizeRole(newlySelected.role);
                              }
                            });
                          }
                        },
                      ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      value: selectedRole,
                      decoration: const InputDecoration(labelText: 'Assign System Role *', prefixIcon: Icon(Icons.admin_panel_settings_outlined)),
                      items: const [
                        DropdownMenuItem(value: UserRoles.hrAdmin, child: Text('HR Administrator', style: TextStyle(fontFamily: 'Inter', fontSize: 13))),
                        DropdownMenuItem(value: UserRoles.hrExecutive, child: Text('HR Executive', style: TextStyle(fontFamily: 'Inter', fontSize: 13))),
                        DropdownMenuItem(value: UserRoles.hr, child: Text('HR Officer', style: TextStyle(fontFamily: 'Inter', fontSize: 13))),
                        DropdownMenuItem(value: UserRoles.recruiter, child: Text('Recruiter', style: TextStyle(fontFamily: 'Inter', fontSize: 13))),
                        DropdownMenuItem(value: UserRoles.payrollExecutive, child: Text('Payroll Executive', style: TextStyle(fontFamily: 'Inter', fontSize: 13))),
                        DropdownMenuItem(value: UserRoles.manager, child: Text('Manager', style: TextStyle(fontFamily: 'Inter', fontSize: 13))),
                        DropdownMenuItem(value: UserRoles.employee, child: Text('Employee (Remove System Role)', style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: Colors.orange))),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() => selectedRole = val);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const RolePermissionsScreen()));
                        },
                        icon: const Icon(Icons.security_rounded, size: 16, color: Color(0xFF5B4CF0)),
                        label: const Text('Configure Permissions', style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF5B4CF0))),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF5B4CF0)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                  child: const Text('Cancel', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5B4CF0),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: (isSubmitting || selectedEmp == null || filteredEmpList.isEmpty)
                      ? null
                      : () async {
                          setModalState(() => isSubmitting = true);
                          try {
                            await ref.read(hrUsersProvider.notifier).assignHRRole(selectedEmp.uid, selectedRole);
                            if (context.mounted) {
                              Navigator.pop(ctx);
                              final roleLabel = selectedRole == UserRoles.employee ? 'Standard Employee' : UserModel.denormalizeRole(selectedRole);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('${selectedEmp.name} system role updated to $roleLabel successfully!'), backgroundColor: Colors.green),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              setModalState(() => isSubmitting = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Failed to assign role: $e'), backgroundColor: Colors.red),
                              );
                            }
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Assign System Role', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showCredentialsDialog(BuildContext context, String email, String password) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.vpn_key_rounded, color: Colors.green),
              SizedBox(width: 8),
              Text('User Onboarded', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'A Firebase Authentication account has been created for this user with a temporary password.',
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B), fontFamily: 'Inter'),
              ),
              const SizedBox(height: 16),
              const Text('Email Address', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF64748B), fontFamily: 'Inter')),
              const SizedBox(height: 4),
              SelectableText(
                email,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B), fontFamily: 'Inter'),
              ),
              const SizedBox(height: 12),
              const Text('Temporary Password', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF64748B), fontFamily: 'Inter')),
              const SizedBox(height: 4),
              SelectableText(
                password,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.red, fontFamily: 'Inter'),
              ),
              const SizedBox(height: 16),
              const Text(
                'Please share these credentials with the HR user.',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.green, fontFamily: 'Inter'),
              ),
            ],
          ),
          actions: [
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

  void _viewProfile(BuildContext context, UserModel user) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.account_circle_rounded, color: Color(0xFF5B4CF0), size: 28),
              const SizedBox(width: 10),
              Text(user.name, style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Inter')),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildProfileItem('Email', user.email),
                _buildProfileItem('Phone', user.phoneNumber ?? 'Not provided'),
                _buildProfileItem('Role', UserModel.denormalizeRole(user.role)),
                _buildProfileItem('Status', user.status.toUpperCase(), isStatus: true),
                _buildProfileItem('Onboarding Date', user.createdAt.toLocal().toString().split('.')[0]),
                if (user.mustChangePassword)
                  _buildProfileItem('Pending Password Reset', 'Yes (Needs to change password on first login)', color: Colors.orange),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildProfileItem(String label, String value, {bool isStatus = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.bold, fontFamily: 'Inter')),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              fontFamily: 'Inter',
              color: color ?? (isStatus ? (value.toLowerCase() == 'active' ? const Color(0xFF007834) : const Color(0xFFBA1A1A)) : const Color(0xFF1E293B)),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmToggleStatus(BuildContext context, UserModel user) {
    final isSuspending = user.status.toLowerCase() == 'active';
    bool isProcessing = false;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setConfirmState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(isSuspending ? Icons.block_rounded : Icons.check_circle_outline_rounded, color: isSuspending ? Colors.orange : Colors.green),
              const SizedBox(width: 8),
              Text(isSuspending ? 'Suspend Account' : 'Activate Account', style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text('Are you sure you want to ${isSuspending ? "suspend" : "activate"} account for "${user.name}"?', style: const TextStyle(fontFamily: 'Inter')),
          actions: [
            TextButton(onPressed: isProcessing ? null : () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isSuspending ? Colors.orange : Colors.green,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: isProcessing
                  ? null
                  : () async {
                      setConfirmState(() { isProcessing = true; });
                      try {
                        await ref.read(hrUsersProvider.notifier).toggleUserStatus(user.uid, user.status);
                        if (context.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Account status changed to ${isSuspending ? "SUSPENDED" : "ACTIVE"}.', style: const TextStyle(fontFamily: 'Inter')), backgroundColor: Colors.green),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          setConfirmState(() { isProcessing = false; });
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update status: $e', style: const TextStyle(fontFamily: 'Inter')), backgroundColor: Colors.red));
                        }
                      }
                    },
              child: isProcessing
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(isSuspending ? 'Suspend' : 'Activate', style: const TextStyle(color: Colors.white, fontFamily: 'Inter', fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmResetPassword(BuildContext context, UserModel user) {
    bool isProcessing = false;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setConfirmState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.lock_reset_rounded, color: Colors.purple),
              SizedBox(width: 8),
              Text('Reset Password', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text('Are you sure you want to reset password for user "${user.name}"? A new temporary password will be generated and updated in Firebase Authentication.', style: const TextStyle(fontFamily: 'Inter')),
          actions: [
            TextButton(onPressed: isProcessing ? null : () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: isProcessing
                  ? null
                  : () async {
                      setConfirmState(() { isProcessing = true; });
                      try {
                        final credentials = await ref.read(hrUsersProvider.notifier).resetPassword(user.uid);
                        if (context.mounted) {
                          Navigator.pop(ctx);
                          _showCredentialsDialog(context, credentials['email']!, credentials['tempPassword']!);
                        }
                      } catch (e) {
                        if (context.mounted) {
                          setConfirmState(() { isProcessing = false; });
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to reset password: $e', style: const TextStyle(fontFamily: 'Inter')), backgroundColor: Colors.red));
                        }
                      }
                    },
              child: isProcessing
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Reset', style: TextStyle(color: Colors.white, fontFamily: 'Inter', fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, String uid, String name) {
    bool isProcessing = false;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setConfirmState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.delete_rounded, color: Colors.red),
              SizedBox(width: 8),
              Text('Delete Account', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text('Are you sure you want to delete HR/Executive "$name"? This will permanently delete their account from both Firebase Authentication and Firestore.', style: const TextStyle(fontFamily: 'Inter')),
          actions: [
            TextButton(onPressed: isProcessing ? null : () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: isProcessing
                  ? null
                  : () async {
                      setConfirmState(() { isProcessing = true; });
                      try {
                        await ref.read(hrUsersProvider.notifier).deleteUser(uid);
                        if (context.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User deleted successfully.', style: TextStyle(fontFamily: 'Inter')), backgroundColor: Colors.green));
                        }
                      } catch (e) {
                        if (context.mounted) {
                          setConfirmState(() { isProcessing = false; });
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete user: $e', style: const TextStyle(fontFamily: 'Inter')), backgroundColor: Colors.red));
                        }
                      }
                    },
              child: isProcessing
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Delete', style: TextStyle(color: Colors.white, fontFamily: 'Inter', fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
