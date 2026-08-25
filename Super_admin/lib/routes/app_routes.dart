import 'package:flutter/material.dart';
import '../screens/auth/splash_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/initial_setup_screen.dart';
import '../screens/auth/access_denied_screen.dart';
import '../screens/dashboard/dashboard_screen.dart';

class AppRoutes {
  static const String splash = '/';
  static const String login = '/admin/login';
  static const String legacyLogin = '/login';
  static const String initialSetup = '/admin/initial-setup';
  static const String accessDenied = '/admin/access-denied';
  static const String dashboard = '/admin/dashboard';
  static const String legacyDashboard = '/dashboard';
  static const String users = '/admin/users';
  static const String plans = '/admin/plans';
  static const String offlineLicenses = '/admin/licenses';
  static const String messages = '/admin/messages';
  static const String reports = '/admin/reports';
  static const String broadcasts = '/admin/broadcasts';
  static const String featuresAi = '/admin/features-ai';
  static const String settings = '/admin/settings';

  static Map<String, WidgetBuilder> get routes => {
        splash: (context) => const SplashScreen(),
        login: (context) => const LoginScreen(),
        legacyLogin: (context) => const LoginScreen(),
        initialSetup: (context) => const InitialSetupScreen(),
        accessDenied: (context) => const AccessDeniedScreen(),
        dashboard: (context) => const DashboardScreen(),
        legacyDashboard: (context) => const DashboardScreen(),
      };
}


