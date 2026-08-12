import 'package:flutter/material.dart';
import '../../company_admin/screens/company_admin/employee_profile_screen.dart';

/// Legacy alias forwarder for unified EmployeeProfileScreen
class ProfileDetailScreen extends StatelessWidget {
  const ProfileDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const EmployeeProfileScreen();
  }
}
