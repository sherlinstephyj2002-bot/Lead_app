import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

abstract class EmailService {
  Future<void> sendWelcomeEmail({
    required String recipientEmail,
    required String employeeName,
    required String companyName,
    required String employeeId,
    required String companyEmail,
    required String tempPassword,
  });

  Future<bool> sendOtpEmail({
    required String recipientEmail,
    required String otp,
  });
}

class SmtpEmailService implements EmailService {
  @override
  Future<void> sendWelcomeEmail({
    required String recipientEmail,
    required String employeeName,
    required String companyName,
    required String employeeId,
    required String companyEmail,
    required String tempPassword,
  }) async {
    try {
      final subject = 'Welcome to $companyName - Your WorkTrack Credentials';
      final html = '''
        <div style="font-family: Arial, sans-serif; padding: 20px; color: #333;">
          <h2 style="color: #4F46E5;">Welcome to $companyName!</h2>
          <p>Dear <strong>$employeeName</strong>,</p>
          <p>Your WorkTrack account has been successfully created. Below are your login credentials:</p>
          <div style="background-color: #F3F4F6; padding: 15px; border-radius: 8px; margin: 15px 0;">
            <p><strong>Employee ID:</strong> $employeeId</p>
            <p><strong>Company Email:</strong> $companyEmail</p>
            <p><strong>Temporary Password:</strong> $tempPassword</p>
          </div>
          <p>Please log in at <a href="https://worktrack.app">worktrack.app</a> and change your password immediately.</p>
        </div>
      ''';

      await _dispatchEmail(recipientEmail: recipientEmail, subject: subject, htmlContent: html, otpText: tempPassword);
    } catch (e) {
      debugPrint('[EMAIL_SERVICE_ERROR] Failed to send welcome email to $recipientEmail: $e');
    }
  }

  @override
  Future<bool> sendOtpEmail({
    required String recipientEmail,
    required String otp,
  }) async {
    final subject = 'WorkTrack - Verify Your Email';
    final html = '''
      <div style="font-family: Arial, sans-serif; padding: 24px; color: #1E293B; max-width: 500px; margin: 0 auto; border: 1px solid #E2E8F0; border-radius: 12px;">
        <h2 style="color: #4F46E5; margin-top: 0;">WorkTrack - Verify Your Email</h2>
        <p>Thank you for registering your company with <strong>WorkTrack</strong>.</p>
        <p>Your 6-digit verification code is:</p>
        <div style="background-color: #EEF2FF; border: 1px solid #C7D2FE; border-radius: 8px; padding: 16px; text-align: center; margin: 20px 0;">
          <span style="font-size: 32px; font-weight: bold; letter-spacing: 8px; color: #4338CA;">$otp</span>
        </div>
        <p style="color: #64748B; font-size: 14px;">This code is valid for <strong>10 minutes</strong>.</p>
        <p style="color: #EF4444; font-size: 13px; font-weight: bold; margin-top: 16px;">Do not share this verification code with anyone.</p>
        <p style="color: #94A3B8; font-size: 12px;">If you did not request this verification, please ignore this email.</p>
      </div>
    ''';

    return await _dispatchEmail(recipientEmail: recipientEmail, subject: subject, htmlContent: html, otpText: otp);
  }

  Future<bool> _dispatchEmail({
    required String recipientEmail,
    required String subject,
    required String htmlContent,
    required String otpText,
  }) async {
    // 1. Try Brevo / SendGrid / EmailJS / Custom HTTP REST Email API (Compatible with Flutter Web & Mobile)
    final httpSent = await _sendViaHttpApi(
      recipientEmail: recipientEmail,
      subject: subject,
      htmlContent: htmlContent,
      otpText: otpText,
    );
    if (httpSent) return true;

    // 2. Try Native SMTP Sockets via mailer package (for Native/Desktop/Mobile when raw TCP Sockets are supported)
    if (!kIsWeb) {
      final smtpSent = await _sendViaSmtpSocket(
        recipientEmail: recipientEmail,
        subject: subject,
        htmlContent: htmlContent,
      );
      if (smtpSent) return true;
    }

    debugPrint('[EMAIL_SERVICE_ERROR] All email dispatch methods failed for recipient: $recipientEmail');
    return false;
  }

  Future<bool> _sendViaHttpApi({
    required String recipientEmail,
    required String subject,
    required String htmlContent,
    required String otpText,
  }) async {
    try {
      // Environment Configs
      const brevoApiKey = String.fromEnvironment('BREVO_API_KEY', defaultValue: '');
      const sendGridApiKey = String.fromEnvironment('SENDGRID_API_KEY', defaultValue: '');
      const emailJsServiceId = String.fromEnvironment('EMAILJS_SERVICE_ID', defaultValue: '');
      const emailJsTemplateId = String.fromEnvironment('EMAILJS_TEMPLATE_ID', defaultValue: '');
      const emailJsPublicKey = String.fromEnvironment('EMAILJS_PUBLIC_KEY', defaultValue: '');
      const customWebhookUrl = String.fromEnvironment('EMAIL_WEBHOOK_URL', defaultValue: '');

      // 1. Brevo REST API (Official HTTP Mail Service)
      if (brevoApiKey.isNotEmpty) {
        final response = await http.post(
          Uri.parse('https://api.brevo.com/v3/smtp/email'),
          headers: {
            'accept': 'application/json',
            'api-key': brevoApiKey,
            'content-type': 'application/json',
          },
          body: jsonEncode({
            'sender': {'name': 'WorkTrack Verification', 'email': 'noreply@worktrack.app'},
            'to': [{'email': recipientEmail}],
            'subject': subject,
            'htmlContent': htmlContent,
          }),
        );
        if (response.statusCode >= 200 && response.statusCode < 300) {
          debugPrint('[EMAIL_SERVICE] Real email dispatched via Brevo REST API to $recipientEmail');
          return true;
        }
      }

      // 2. SendGrid REST API
      if (sendGridApiKey.isNotEmpty) {
        final response = await http.post(
          Uri.parse('https://api.sendgrid.com/v3/mail/send'),
          headers: {
            'Authorization': 'Bearer $sendGridApiKey',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'personalizations': [
              {'to': [{'email': recipientEmail}]}
            ],
            'from': {'email': 'noreply@worktrack.app', 'name': 'WorkTrack'},
            'subject': subject,
            'content': [
              {'type': 'text/html', 'value': htmlContent}
            ],
          }),
        );
        if (response.statusCode >= 200 && response.statusCode < 300) {
          debugPrint('[EMAIL_SERVICE] Real email dispatched via SendGrid REST API to $recipientEmail');
          return true;
        }
      }

      // 3. EmailJS REST API
      if (emailJsServiceId.isNotEmpty && emailJsTemplateId.isNotEmpty && emailJsPublicKey.isNotEmpty) {
        final response = await http.post(
          Uri.parse('https://api.emailjs.com/api/v1.0/email/send'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'service_id': emailJsServiceId,
            'template_id': emailJsTemplateId,
            'user_id': emailJsPublicKey,
            'template_params': {
              'to_email': recipientEmail,
              'email': recipientEmail,
              'otp_code': otpText,
              'message': 'Your verification code is $otpText',
            },
          }),
        );
        if (response.statusCode >= 200 && response.statusCode < 300) {
          debugPrint('[EMAIL_SERVICE] Real email dispatched via EmailJS REST API to $recipientEmail');
          return true;
        }
      }

      // 4. Custom Webhook REST Endpoint
      if (customWebhookUrl.isNotEmpty) {
        final response = await http.post(
          Uri.parse(customWebhookUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'recipientEmail': recipientEmail,
            'subject': subject,
            'htmlContent': htmlContent,
            'otp': otpText,
          }),
        );
        if (response.statusCode >= 200 && response.statusCode < 300) {
          debugPrint('[EMAIL_SERVICE] Real email dispatched via Custom Webhook to $recipientEmail');
          return true;
        }
      }

      // 5. Query Firestore system_settings/smtp for REST / API Gateway credentials
      final doc = await FirebaseFirestore.instance.collection('system_settings').doc('smtp').get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final restApiKey = (data['apiKey'] ?? data['brevoKey'] ?? data['sendGridKey'] ?? '').toString();
        final restEndpoint = (data['endpoint'] ?? data['apiUrl'] ?? '').toString();

        if (restEndpoint.isNotEmpty) {
          final response = await http.post(
            Uri.parse(restEndpoint),
            headers: {
              'Content-Type': 'application/json',
              if (restApiKey.isNotEmpty) 'Authorization': 'Bearer $restApiKey',
              if (restApiKey.isNotEmpty) 'api-key': restApiKey,
            },
            body: jsonEncode({
              'recipientEmail': recipientEmail,
              'subject': subject,
              'htmlContent': htmlContent,
              'otp': otpText,
            }),
          );
          if (response.statusCode >= 200 && response.statusCode < 300) {
            debugPrint('[EMAIL_SERVICE] Real email dispatched via Firestore Configured REST API to $recipientEmail');
            return true;
          }
        }
      }
    } catch (e) {
      debugPrint('[EMAIL_SERVICE_ERROR] HTTP REST Dispatch Exception: $e');
    }

    return false;
  }

  Future<bool> _sendViaSmtpSocket({
    required String recipientEmail,
    required String subject,
    required String htmlContent,
  }) async {
    try {
      final smtpServer = await _getSmtpServer();
      if (smtpServer == null) return false;

      const fromEmail = String.fromEnvironment('SMTP_FROM_EMAIL', defaultValue: '');
      const fromName = String.fromEnvironment('SMTP_FROM_NAME', defaultValue: 'WorkTrack System');
      final senderEmail = fromEmail.isNotEmpty ? fromEmail : (smtpServer.username ?? 'noreply@worktrack.app');

      final message = Message()
        ..from = Address(senderEmail, fromName)
        ..recipients.add(recipientEmail)
        ..subject = subject
        ..html = htmlContent;

      await send(message, smtpServer);
      debugPrint('[EMAIL_SERVICE] Real email dispatched via Native SMTP Sockets to $recipientEmail');
      return true;
    } catch (e) {
      debugPrint('[EMAIL_SERVICE_ERROR] Native SMTP Socket Exception: $e');
      return false;
    }
  }

  Future<SmtpServer?> _getSmtpServer() async {
    const envHost = String.fromEnvironment('SMTP_HOST', defaultValue: '');
    const envPort = int.fromEnvironment('SMTP_PORT', defaultValue: 465);
    const envUsername = String.fromEnvironment('SMTP_USERNAME', defaultValue: '');
    const envPassword = String.fromEnvironment('SMTP_PASSWORD', defaultValue: '');
    const envSsl = bool.fromEnvironment('SMTP_SSL', defaultValue: true);

    if (envUsername.isNotEmpty && envPassword.isNotEmpty) {
      final host = envHost.isNotEmpty ? envHost : 'smtp.gmail.com';
      if (host.contains('gmail.com')) {
        return gmail(envUsername, envPassword);
      }
      return SmtpServer(
        host,
        port: envPort,
        ssl: envSsl,
        username: envUsername,
        password: envPassword,
      );
    }

    try {
      final doc = await FirebaseFirestore.instance.collection('system_settings').doc('smtp').get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final host = (data['host'] ?? 'smtp.gmail.com').toString();
        final port = (data['port'] as int?) ?? 465;
        final username = (data['username'] ?? data['email'] ?? '').toString();
        final password = (data['password'] ?? data['appPassword'] ?? '').toString();
        final ssl = (data['ssl'] as bool?) ?? true;

        if (username.isNotEmpty && password.isNotEmpty) {
          if (host.contains('gmail.com')) {
            return gmail(username, password);
          }
          return SmtpServer(
            host,
            port: port,
            ssl: ssl,
            username: username,
            password: password,
          );
        }
      }
    } catch (e) {
      debugPrint('[EMAIL_SERVICE] Firestore SMTP config check error: $e');
    }

    return null;
  }
}

final emailServiceProvider = Provider<EmailService>((ref) {
  return SmtpEmailService();
});
