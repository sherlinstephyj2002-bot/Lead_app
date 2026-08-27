import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../features/authentication/screens/splash_screen.dart';
import '../../features/authentication/screens/login_screen.dart';
import '../../features/authentication/screens/register_screen.dart';
import '../../features/authentication/screens/forgot_password_screen.dart';
import '../../features/authentication/screens/change_password_screen.dart';
import '../../features/authentication/screens/email_verification_screen.dart';
import '../../features/dashboard/screens/main_screen.dart';
import '../../features/leads/screens/lead_list_screen.dart';
import '../../features/leads/screens/lead_detail_screen.dart';
import '../../features/leads/screens/lead_form_screen.dart';
import '../../features/orders/screens/order_list_screen.dart';
import '../../features/orders/screens/order_detail_screen.dart';
import '../../features/orders/screens/order_form_screen.dart';
import '../../features/attendance/screens/attendance_screen.dart';
import '../../features/attendance/screens/leave_list_screen.dart';
import '../../features/followups/screens/followup_list_screen.dart';
import '../../features/followups/screens/followup_detail_screen.dart';
import '../../features/tasks/screens/task_list_screen.dart';
import '../../features/expenses/screens/expense_list_screen.dart';
import '../../features/profile/screens/employees_screen.dart';
import '../../features/profile/screens/employee_requests_screen.dart';
import '../../features/profile/screens/reports_screen.dart';
import '../../features/company_admin/screens/company_admin/employee_profile_screen.dart';
import '../../features/profile/screens/customer_list_screen.dart';
import '../../features/profile/screens/customer_detail_screen.dart';
import '../models/customer_model.dart';
import '../../features/profile/screens/company_profile_screen.dart';
import '../../features/profile/screens/subscription_screen.dart';
import '../../features/profile/screens/app_settings_screen.dart';
import '../models/lead_model.dart';
import '../models/order_model.dart';
import '../providers/providers.dart';
import '../widgets/permission_guard.dart';
import '../../constants/user_roles.dart';

// Notifications Screens
import '../../features/notifications/screens/notification_center_screen.dart';
import '../../features/notifications/screens/notification_detail_screen.dart';
import '../../features/notifications/screens/notification_settings_screen.dart';
import '../../features/notifications/models/notification_item_model.dart';

// Calendar Screens
import '../../features/calendar/screens/calendar_screen.dart';
import '../../features/calendar/screens/calendar_settings_screen.dart';

// Employee Self Service Screens
import '../../features/employee_self_service/screens/ess_dashboard_screen.dart';
import '../../features/employee_self_service/screens/ess_leave_screen.dart';
import '../../features/employee_self_service/screens/ess_attendance_screen.dart';
import '../../features/employee_self_service/screens/ess_payslips_screen.dart';
import '../../features/employee_self_service/screens/ess_expenses_screen.dart';
import '../../features/employee_self_service/screens/ess_documents_screen.dart';
import '../../features/employee_self_service/screens/ess_tasks_screen.dart';
import '../../features/employee_self_service/screens/ess_timeline_screen.dart';
import '../../features/employee_self_service/screens/ess_settings_screen.dart';
import '../../features/employee_self_service/screens/ess_resignation_screen.dart';

// Company Admin Screens
import '../../features/company_admin/screens/company_admin/company_admin_menu_screen.dart';
import '../../features/company_admin/screens/company_admin/hr_management_screen.dart';
import '../../features/company_admin/screens/company_admin/employee_management_screen.dart';
import '../../features/company_admin/screens/company_admin/department_management_screen.dart';
import '../../features/company_admin/screens/company_admin/designation_management_screen.dart';
import '../../features/company_admin/screens/company_admin/holiday_management_screen.dart';
import '../../features/company_admin/screens/company_admin/shift_management_screen.dart';
import '../../features/company_admin/screens/company_admin/branch_management_screen.dart';
import '../../features/company_admin/screens/company_admin/attendance_settings_screen.dart';
import '../../features/company_admin/screens/company_admin/overtime_settings_screen.dart';
import '../../features/company_admin/screens/company_admin/leave_policy_screen.dart';
import '../../features/company_admin/screens/company_admin/salary_components_screen.dart';
import '../../features/company_admin/screens/company_admin/salary_structures_screen.dart';
import '../../features/company_admin/screens/company_admin/pf_esi_tax_screen.dart';
import '../../features/company_admin/screens/company_admin/payroll_settings_screen.dart';
import '../../features/company_admin/screens/company_admin/payroll_processing_screen.dart';
import '../../features/company_admin/screens/company_admin/salary_payroll_screen.dart';
import '../../features/company_admin/screens/company_admin/override_approval_screen.dart';
import '../../features/company_admin/screens/company_admin/role_permissions_screen.dart';
import '../../features/company_admin/screens/company_admin/company_configuration_screen.dart';
import '../../features/company_admin/screens/company_admin/audit_logs_screen.dart';
import '../../features/company_admin/screens/company_admin/company_announcements_screen.dart';

class RouterListenable extends ChangeNotifier {
  final Ref _ref;
  bool _isDisposed = false;

  RouterListenable(this._ref) {
    _ref.listen<AuthState>(
      authProvider,
      (previous, next) {
        if (_isDisposed) return;
        if (previous?.user != next.user || 
            previous?.isLoading != next.isLoading ||
            previous?.isBiometricLocked != next.isBiometricLocked) {
          notifyListeners();
        }
      },
    );
    _ref.listen<bool>(
      emailOtpVerifiedProvider,
      (previous, next) {
        if (_isDisposed) return;
        if (previous != next) {
          notifyListeners();
        }
      },
    );
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}

final routerListenableProvider = Provider<RouterListenable>((ref) {
  return RouterListenable(ref);
});

final routerProvider = Provider<GoRouter>((ref) {
  final listenable = ref.watch(routerListenableProvider);
  final firebaseInitError = ref.watch(firebaseInitErrorProvider);
  final isFirebaseInitialized = firebaseInitError == null;

  List<NavigatorObserver> observers = [];
  if (isFirebaseInitialized) {
    try {
      observers.add(FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance));
    } catch (e) {
      debugPrint('Failed to initialize Firebase Analytics: $e');
    }
  }

  return GoRouter(
    initialLocation: '/',
    refreshListenable: listenable,
    observers: observers,
    redirect: (context, state) {
      try {
        final authState = ref.read(authProvider);
        
        // Safely access current user to avoid Firebase app initialization errors crashing GoRouter
        User? fbUser;
        if (isFirebaseInitialized) {
          try {
            fbUser = ref.read(authRepositoryProvider).currentUser;
          } catch (e) {
            debugPrint('Router: Failed to access Firebase Auth currentUser: $e');
          }
        }

        final loggedIn = authState.user != null && !authState.isBiometricLocked;
        final isLoading = authState.isLoading;

        // Don't guard routes while still checking auth session on startup
        if (isLoading && authState.user == null && state.matchedLocation == '/') {
          return null;
        }

        final isLoggingIn = state.matchedLocation == '/login' ||
            state.matchedLocation == '/register' ||
            state.matchedLocation == '/forgot-password';

        if (loggedIn) {
          final mustChangePass = (authState.user!.mustChangePassword || authState.user!.firstLogin || authState.user!.temporaryPasswordRequired == true) && !authState.user!.passwordChanged;
          if (mustChangePass) {
            if (state.matchedLocation != '/change-password') {
              return '/change-password';
            }
            return null;
          }

          if (isLoggingIn) {
            return '/main';
          }

          // Check if email verification is required (ignore mobile simulated emails)
          final isCustomEmailVerified = ref.read(emailOtpVerifiedProvider);
          final needsVerification = fbUser != null &&
              !fbUser.emailVerified &&
              !isCustomEmailVerified &&
              fbUser.email != null &&
              !fbUser.email!.endsWith('@worktrack.com') &&
              !fbUser.email!.endsWith('@worktrack.internal');

          if (needsVerification) {
            if (state.matchedLocation != '/verify-email') {
              return '/verify-email';
            }
            return null;
          }

          // If email is verified but trying to access verification route, send to main
          if (state.matchedLocation == '/verify-email') {
            return '/main';
          }

          // Restrict Company Admin from personal operational attendance check-in screens
          if (authState.user?.role == UserRoles.companyAdmin) {
            final loc = state.matchedLocation;
            if (loc == '/attendance' || loc == '/ess/attendance') {
              return '/main';
            }
          }

          if (isLoggingIn) {
            return '/main';
          }
        } else {
          // If user is not logged in and not heading to login/register/forgot-password, send them to login
          if (!isLoggingIn && state.matchedLocation != '/') {
            return '/login';
          }
        }
      } catch (e) {
        debugPrint('GoRouter redirect error: $e');
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/change-password',
        builder: (context, state) => const ChangePasswordScreen(),
      ),
      GoRoute(
        path: '/verify-email',
        builder: (context, state) => const EmailVerificationScreen(),
      ),
      GoRoute(
        path: '/main',
        builder: (context, state) {
          final initialTab = state.uri.queryParameters['tab'];
          return MainScreen(initialTab: initialTab != null ? int.parse(initialTab) : 0);
        },
      ),
      GoRoute(
        path: '/leads',
        builder: (context, state) => const PermissionGuard(
          permission: 'lead_view',
          child: LeadListScreen(),
        ),
      ),
      GoRoute(
        path: '/lead-detail/:id',
        builder: (context, state) {
          final leadId = state.pathParameters['id']!;
          final lead = state.extra as LeadModel?;
          return PermissionGuard(
            permission: 'lead_view',
            child: LeadDetailScreen(leadId: leadId, initialLead: lead),
          );
        },
      ),
      GoRoute(
        path: '/lead-form',
        builder: (context, state) {
          final lead = state.extra as LeadModel?;
          final perm = lead == null ? 'lead_create' : 'lead_edit';
          return PermissionGuard(
            permission: perm,
            child: LeadFormScreen(leadToEdit: lead),
          );
        },
      ),
      GoRoute(
        path: '/orders',
        builder: (context, state) => const PermissionGuard(
          permission: 'order_view',
          child: OrderListScreen(),
        ),
      ),
      GoRoute(
        path: '/order-detail/:id',
        builder: (context, state) {
          final orderId = state.pathParameters['id']!;
          final order = state.extra as OrderModel?;
          return PermissionGuard(
            permission: 'order_view',
            child: OrderDetailScreen(orderId: orderId, initialOrder: order),
          );
        },
      ),
      GoRoute(
        path: '/order-form',
        builder: (context, state) {
          final lead = state.extra is LeadModel ? state.extra as LeadModel : null;
          final orderToEdit = state.extra is OrderModel ? state.extra as OrderModel : null;

          if (orderToEdit != null) {
            return PermissionGuard(
              permission: 'order_edit',
              child: OrderFormScreen(wonLead: lead, orderToEdit: orderToEdit),
            );
          } else if (lead != null) {
            return PermissionGuard(
              permissions: const ['lead_convert_order', 'order_create'],
              requireAll: true,
              child: OrderFormScreen(wonLead: lead, orderToEdit: orderToEdit),
            );
          } else {
            return PermissionGuard(
              permission: 'order_create',
              child: OrderFormScreen(wonLead: lead, orderToEdit: orderToEdit),
            );
          }
        },
      ),
      GoRoute(
        path: '/attendance',
        builder: (context, state) => const AttendanceScreen(),
      ),
      GoRoute(
        path: '/leaves',
        builder: (context, state) => const LeaveListScreen(),
      ),
      GoRoute(
        path: '/followups',
        builder: (context, state) => const PermissionGuard(
          permission: 'followup_view',
          child: FollowupListScreen(),
        ),
      ),
      GoRoute(
        path: '/followup-detail/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return PermissionGuard(
            permission: 'followup_view',
            child: FollowupDetailScreen(followupId: id),
          );
        },
      ),
      GoRoute(
        path: '/tasks',
        builder: (context, state) => const PermissionGuard(
          permission: 'task_view',
          child: TaskListScreen(),
        ),
      ),
      GoRoute(
        path: '/expenses',
        builder: (context, state) => const ExpenseListScreen(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationCenterScreen(),
      ),
      GoRoute(
        path: '/notification-detail',
        builder: (context, state) {
          final notification = state.extra as NotificationItemModel;
          return NotificationDetailScreen(notification: notification);
        },
      ),
      GoRoute(
        path: '/notification-settings',
        builder: (context, state) => const NotificationSettingsScreen(),
      ),
      GoRoute(
        path: '/calendar',
        builder: (context, state) => const CalendarScreen(),
      ),
      GoRoute(
        path: '/calendar/settings',
        builder: (context, state) => const CalendarSettingsScreen(),
      ),
      GoRoute(
        path: '/ess',
        builder: (context, state) => const ESSDashboardScreen(),
      ),
      GoRoute(
        path: '/ess/leave',
        builder: (context, state) => const ESSLeaveScreen(),
      ),
      GoRoute(
        path: '/ess/attendance',
        builder: (context, state) => const ESSAttendanceScreen(),
      ),
      GoRoute(
        path: '/ess/payslips',
        builder: (context, state) => const ESSPayslipsScreen(),
      ),
      GoRoute(
        path: '/ess/expenses',
        builder: (context, state) => const ESSExpensesScreen(),
      ),
      GoRoute(
        path: '/ess/documents',
        builder: (context, state) => const ESSDocumentsScreen(),
      ),
      GoRoute(
        path: '/ess/tasks',
        builder: (context, state) => const ESSTasksScreen(),
      ),
      GoRoute(
        path: '/ess/profile',
        builder: (context, state) => const EmployeeProfileScreen(),
      ),
      GoRoute(
        path: '/ess/timeline',
        builder: (context, state) => const ESSTimelineScreen(),
      ),
      GoRoute(
        path: '/ess/settings',
        builder: (context, state) => const ESSSettingsScreen(),
      ),
      GoRoute(
        path: '/ess/resignation',
        builder: (context, state) => const ESSResignationScreen(),
      ),
      GoRoute(
        path: '/employees',
        builder: (context, state) => const PermissionGuard(
          permission: 'employee.view',
          child: EmployeesScreen(),
        ),
      ),
      GoRoute(
        path: '/employee-requests',
        builder: (context, state) => const PermissionGuard(
          permission: 'settings.manage',
          child: EmployeeRequestsScreen(),
        ),
      ),
      GoRoute(
        path: '/reports',
        builder: (context, state) {
          final tabStr = state.uri.queryParameters['tab'];
          final tab = tabStr != null ? int.tryParse(tabStr) ?? 0 : 0;
          return PermissionGuard(
            permission: 'reports.view',
            child: ReportsScreen(initialTab: tab),
          );
        },
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const EmployeeProfileScreen(),
      ),
      GoRoute(
        path: '/customers',
        builder: (context, state) => const CustomerListScreen(),
      ),
      GoRoute(
        path: '/customer-detail',
        builder: (context, state) {
          final customer = state.extra as CustomerModel;
          return CustomerDetailScreen(customer: customer);
        },
      ),
      GoRoute(
        path: '/company-profile',
        builder: (context, state) => const PermissionGuard(
          permission: 'settings.manage',
          child: CompanyProfileScreen(),
        ),
      ),
      GoRoute(
        path: '/subscription',
        builder: (context, state) => const PermissionGuard(
          permission: 'settings.manage',
          child: SubscriptionScreen(),
        ),
      ),
      GoRoute(
        path: '/analytics',
        builder: (context, state) => const PermissionGuard(
          permission: 'reports.view',
          child: ReportsScreen(),
        ),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const AppSettingsScreen(),
      ),
      GoRoute(
        path: '/company-admin',
        builder: (context, state) => const PermissionGuard(
          permissions: ['employee.create', 'settings.manage', 'payroll.manage', 'reports.view', 'leave.approve'],
          child: CompanyAdminMenuScreen(),
        ),
      ),
      GoRoute(
        path: '/company-admin/hr',
        builder: (context, state) => const PermissionGuard(
          permission: 'employee.create',
          child: HRManagementScreen(),
        ),
      ),
      GoRoute(
        path: '/company-admin/employees',
        builder: (context, state) => const PermissionGuard(
          permission: 'employee.view',
          child: EmployeeManagementScreen(),
        ),
      ),
      GoRoute(
        path: '/company-admin/departments',
        builder: (context, state) => const PermissionGuard(
          permission: 'employee.view',
          child: DepartmentManagementScreen(),
        ),
      ),
      GoRoute(
        path: '/company-admin/designations',
        builder: (context, state) => const PermissionGuard(
          permission: 'settings.manage',
          child: DesignationManagementScreen(),
        ),
      ),
      GoRoute(
        path: '/company-admin/holidays',
        builder: (context, state) => const PermissionGuard(
          permission: 'settings.manage',
          child: HolidayManagementScreen(),
        ),
      ),
      GoRoute(
        path: '/company-admin/shifts',
        builder: (context, state) => const PermissionGuard(
          permission: 'settings.manage',
          child: ShiftManagementScreen(),
        ),
      ),
      GoRoute(
        path: '/company-admin/branches',
        builder: (context, state) => const PermissionGuard(
          permission: 'settings.manage',
          child: BranchManagementScreen(),
        ),
      ),
      GoRoute(
        path: '/company-admin/attendance-rules',
        builder: (context, state) => const PermissionGuard(
          permission: 'settings.manage',
          child: AttendanceSettingsScreen(),
        ),
      ),
      GoRoute(
        path: '/company-admin/overtime',
        builder: (context, state) => const PermissionGuard(
          permission: 'settings.manage',
          child: OvertimeSettingsScreen(),
        ),
      ),
      GoRoute(
        path: '/company-admin/leave-policy',
        builder: (context, state) => const PermissionGuard(
          permission: 'settings.manage',
          child: LeavePolicyScreen(),
        ),
      ),
      GoRoute(
        path: '/company-admin/salary-components',
        builder: (context, state) => const PermissionGuard(
          permission: 'payroll.manage',
          child: SalaryComponentsScreen(),
        ),
      ),
      GoRoute(
        path: '/company-admin/salary-structures',
        builder: (context, state) => const PermissionGuard(
          permission: 'payroll.manage',
          child: SalaryStructuresScreen(),
        ),
      ),
      GoRoute(
        path: '/company-admin/statutory',
        builder: (context, state) => const PermissionGuard(
          permission: 'payroll.manage',
          child: PfEsiTaxScreen(),
        ),
      ),
      GoRoute(
        path: '/company-admin/pf-esi-tax',
        builder: (context, state) => const PermissionGuard(
          permission: 'payroll.manage',
          child: PfEsiTaxScreen(),
        ),
      ),
      GoRoute(
        path: '/company-admin/payroll',
        builder: (context, state) => const PermissionGuard(
          permission: 'payroll.manage',
          child: PayrollProcessingScreen(),
        ),
      ),
      GoRoute(
        path: '/company-admin/payroll-processing',
        builder: (context, state) => const PermissionGuard(
          permission: 'payroll.manage',
          child: PayrollProcessingScreen(),
        ),
      ),
      GoRoute(
        path: '/company-admin/monthly-payroll',
        builder: (context, state) => const PermissionGuard(
          permission: 'payroll.manage',
          child: PayrollProcessingScreen(),
        ),
      ),
      GoRoute(
        path: '/company-admin/payroll-settings',
        builder: (context, state) => const PermissionGuard(
          permission: 'payroll.manage',
          child: PayrollSettingsScreen(),
        ),
      ),
      GoRoute(
        path: '/company-admin/salary-payroll',
        builder: (context, state) => const PermissionGuard(
          permission: 'payroll.manage',
          child: SalaryPayrollScreen(),
        ),
      ),
      GoRoute(
        path: '/company-admin/reports',
        builder: (context, state) {
          final tabStr = state.uri.queryParameters['tab'];
          final tab = tabStr != null ? int.tryParse(tabStr) ?? 0 : 0;
          return PermissionGuard(
            permission: 'reports.view',
            child: ReportsScreen(initialTab: tab),
          );
        },
      ),
      GoRoute(
        path: '/company-admin/approvals',
        builder: (context, state) => const PermissionGuard(
          permission: 'leave.approve',
          child: OverrideApprovalScreen(),
        ),
      ),
      GoRoute(
        path: '/company-admin/permissions',
        builder: (context, state) => const PermissionGuard(
          permission: 'settings.manage',
          child: RolePermissionsScreen(),
        ),
      ),
      GoRoute(
        path: '/company-admin/configuration',
        builder: (context, state) => const PermissionGuard(
          permission: 'settings.manage',
          child: CompanyConfigurationScreen(),
        ),
      ),
      GoRoute(
        path: '/company-admin/audit-logs',
        builder: (context, state) => const PermissionGuard(
          permission: 'settings.manage',
          child: AuditLogsScreen(),
        ),
      ),
      GoRoute(
        path: '/company-admin/announcements',
        builder: (context, state) => const PermissionGuard(
          permission: 'settings.manage',
          child: CompanyAnnouncementsScreen(),
        ),
      ),
    ],
  );
});
