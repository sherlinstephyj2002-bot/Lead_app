import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract class EmailService {
  Future<void> sendWelcomeEmail({
    required String recipientEmail,
    required String employeeName,
    required String companyName,
    required String employeeId,
    required String companyEmail,
    required String tempPassword,
  });
}

class SimulatedEmailService implements EmailService {
  @override
  Future<void> sendWelcomeEmail({
    required String recipientEmail,
    required String employeeName,
    required String companyName,
    required String employeeId,
    required String companyEmail,
    required String tempPassword,
  }) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 1000));

    debugPrint('==================================================');
    debugPrint('📧 SIMULATED HRMS WELCOME EMAIL');
    debugPrint('Recipient: $recipientEmail');
    debugPrint('Subject: Welcome to $companyName - Your WorkTrack Credentials');
    debugPrint('Body:');
    debugPrint('Welcome to $companyName.\n');
    debugPrint('Employee ID:');
    debugPrint(employeeId);
    debugPrint('\nInternal Company Email:');
    debugPrint(companyEmail);
    debugPrint('\nTemporary Password:');
    debugPrint(tempPassword);
    debugPrint('\nLogin:');
    debugPrint('https://worktrack.app\n');
    debugPrint('Please change your password after your first login.');
    debugPrint('==================================================');
  }
}

final emailServiceProvider = Provider<EmailService>((ref) {
  return SimulatedEmailService();
});
