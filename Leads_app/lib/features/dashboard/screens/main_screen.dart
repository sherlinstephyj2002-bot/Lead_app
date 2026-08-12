import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dashboard_screen.dart';
import 'company_admin_dashboard.dart';
import '../../orders/screens/order_list_screen.dart';
import '../../profile/screens/more_screen.dart';
import '../../profile/screens/reports_screen.dart';
import '../../employee_self_service/screens/ess_attendance_screen.dart';
import '../../employee_self_service/screens/ess_leave_screen.dart';
import '../../employee_self_service/screens/ess_payslips_screen.dart';
import '../../company_admin/screens/company_admin/employee_management_screen.dart';
import '../../company_admin/screens/company_admin/salary_payroll_screen.dart';
import '../../company_admin/screens/company_admin/override_approval_screen.dart';
import '../../company_admin/screens/company_admin/company_admin_menu_screen.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/providers/permissions_provider.dart';
import '../../leads/screens/lead_list_screen.dart';
import '../../../constants/user_roles.dart';

class MainScreen extends ConsumerStatefulWidget {
  final int initialTab;
  const MainScreen({super.key, this.initialTab = 0});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTab.clamp(0, 8);
  }

  @override
  void didUpdateWidget(covariant MainScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialTab != oldWidget.initialTab) {
      setState(() {
        _currentIndex = widget.initialTab.clamp(0, 8);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final isAdmin = UserRoles.isAdminRole(user?.role);
    final permService = ref.watch(permissionServiceProvider);

    // Dynamic Navigation items & Screens based on Role and Permissions
    final List<Widget> screens = [];
    final List<Map<String, dynamic>> navItems = [];

    if (isAdmin) {
      // 1. Dashboard
      screens.add(const CompanyAdminDashboard());
      navItems.add({'icon': Icons.home_rounded, 'label': 'Dashboard'});

      // 2. Employee Management
      screens.add(const EmployeeManagementScreen());
      navItems.add({'icon': Icons.people_alt_rounded, 'label': 'Employees'});

      // 3. Salary / Payroll
      screens.add(const SalaryPayrollScreen());
      navItems.add({'icon': Icons.payments_rounded, 'label': 'Payroll'});

      // 4. Company Administration (Central Hub)
      screens.add(const CompanyAdminMenuScreen());
      navItems.add({'icon': Icons.admin_panel_settings_rounded, 'label': 'Company Admin'});

      // 5. Attendance
      screens.add(const OverrideApprovalScreen());
      navItems.add({'icon': Icons.fact_check_rounded, 'label': 'Attendance'});

      // 6. More (Secondary Settings & Utilities)
      screens.add(const MoreScreen());
      navItems.add({'icon': Icons.grid_view_rounded, 'label': 'More'});
    } else {
      // Standard Non-Admin User Navigation Tabs based on Permissions
      screens.add(const DashboardScreen());
      navItems.add({'icon': Icons.home_rounded, 'label': 'Home'});

      if (permService.hasPermission('employee_view')) {
        screens.add(const EmployeeManagementScreen());
        navItems.add({'icon': Icons.people_alt_rounded, 'label': 'Employees'});
      }

      if (permService.hasPermission('attendance_view')) {
        screens.add(user?.role == UserRoles.hrAdmin || user?.role == UserRoles.hrExecutive || user?.role == UserRoles.hr
            ? const OverrideApprovalScreen()
            : const ESSAttendanceScreen());
        navItems.add({'icon': Icons.fact_check_rounded, 'label': 'Attendance'});
      }

      if (permService.hasPermission('payroll_view')) {
        screens.add(user?.role == UserRoles.hrAdmin || user?.role == UserRoles.hrExecutive || user?.role == UserRoles.hr
            ? const SalaryPayrollScreen()
            : const ESSPayslipsScreen());
        navItems.add({'icon': Icons.payments_rounded, 'label': 'Payroll'});
      }

      if (permService.hasPermission('lead_view')) {
        screens.add(const LeadListScreen());
        navItems.add({'icon': Icons.emoji_people_rounded, 'label': 'Leads'});
      }

      if (permService.hasPermission('order_view')) {
        screens.add(const OrderListScreen());
        navItems.add({'icon': Icons.assignment_rounded, 'label': 'Orders'});
      }

      if (permService.hasPermission('reports_view')) {
        screens.add(const ReportsScreen());
        navItems.add({'icon': Icons.assessment_rounded, 'label': 'Reports'});
      }

      screens.add(const MoreScreen());
      navItems.add({'icon': Icons.grid_view_rounded, 'label': 'More'});
    }

    final safeIndex = _currentIndex.clamp(0, screens.length - 1);

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: IndexedStack(
            index: safeIndex,
            children: screens,
          ),
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        padding: EdgeInsets.zero,
        elevation: 10,
        shadowColor: Colors.black,
        color: Theme.of(context).cardColor,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: SizedBox(
              height: 56.0,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(navItems.length, (index) {
                    final item = navItems[index];
                    final double itemWidth = MediaQuery.of(context).size.width > 800
                        ? 800 / navItems.length
                        : (MediaQuery.of(context).size.width / (navItems.length > 5 ? 5.5 : navItems.length));
                    return SizedBox(
                      width: itemWidth < 68.0 ? 68.0 : itemWidth,
                      child: _buildNavItem(index, item['icon'] as IconData, item['label'] as String),
                    );
                  }),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final unselectedColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final color = isSelected ? Theme.of(context).colorScheme.primary : unselectedColor;

    return InkWell(
      key: ValueKey('nav_item_$index'),
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
      },
      borderRadius: BorderRadius.circular(10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
