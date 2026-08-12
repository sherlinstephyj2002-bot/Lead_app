import 'package:flutter/material.dart';
import '../screens/auth/splash_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/initial_setup_screen.dart';
import '../screens/auth/access_denied_screen.dart';
import '../screens/dashboard/dashboard_screen.dart';

class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String initialSetup = '/initial-setup';
  static const String accessDenied = '/access-denied';
  static const String dashboard = '/dashboard';

  static Map<String, WidgetBuilder> get routes => {
        splash: (context) => const SplashScreen(),
        login: (context) => const LoginScreen(),
        initialSetup: (context) => const InitialSetupScreen(),
        accessDenied: (context) => const AccessDeniedScreen(),
        dashboard: (context) => const DashboardScreen(),
      };
}

