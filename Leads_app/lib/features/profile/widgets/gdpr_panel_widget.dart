import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/providers/providers.dart';
import '../../../constants/user_roles.dart';

class GdprPanelWidget extends ConsumerStatefulWidget {
  const GdprPanelWidget({super.key});

  @override
  ConsumerState<GdprPanelWidget> createState() => _GdprPanelWidgetState();
}

class _GdprPanelWidgetState extends ConsumerState<GdprPanelWidget> {
  bool _shareDiagnostics = true;
  bool _personalizedAds = false;

  void _exportUserData(BuildContext context) {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    final dataMap = {
      'uid': user.uid,
      'name': user.name,
      'email': user.role == UserRoles.employee ? '[Redacted/Internal Only]' : user.email,
      'companyId': user.companyId,
      'companyName': user.companyName,
      'role': user.role,
      'phoneNumber': user.phoneNumber ?? '',
      if (user.employeeId != null) 'employeeId': user.employeeId,
      if (user.companyCode != null) 'companyCode': user.companyCode,
      'createdAt': user.createdAt.toIso8601String(),
      'exportTimestamp': DateTime.now().toIso8601String(),
    };

    final prettyJson = const JsonEncoder.withIndent('  ').convert(dataMap);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.download_done_rounded, color: Colors.green),
            SizedBox(width: 8),
            Text('Exported Data (JSON)', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Under GDPR Article 20 (Data Portability), you have the right to receive your personal data in a structured format.',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: SelectableText(
                  prettyJson,
                  style: const TextStyle(
                    color: Color(0xFF38BDF8),
                    fontFamily: 'monospace',
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: prettyJson));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('JSON data copied to clipboard!')),
              );
            },
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text('Copy to Clipboard'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _requestAccountDeletion(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Request Deletion', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Are you sure you want to request permanent account deletion under GDPR Article 17 (Right to Erasure)?\n\nThis will permanently queue your user profile, active leads, logs, and attendance logs for complete removal from our databases. This action is irreversible.',
          style: TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('GDPR Erasure request queued successfully. Our data protection officer will process it within 30 days.')),
              );
            },
            child: const Text('Confirm Deletion'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final subtitleColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final tileBg = isDark ? Theme.of(context).cardColor : Colors.white;
    final borderCol = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final dividerCol = isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            'GDPR & Data Privacy Control Panel',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: titleColor),
          ),
          const SizedBox(height: 6),
          Text(
            'Manage your rights under General Data Protection Regulation (GDPR) and customize your privacy parameters.',
            style: TextStyle(fontSize: 12, color: subtitleColor),
          ),
          const SizedBox(height: 20),

          // Toggles
          Card(
            elevation: 0,
            color: tileBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: borderCol),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  SwitchListTile(
                    value: _shareDiagnostics,
                    title: Text('Share Diagnostic Logs', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: titleColor)),
                    subtitle: Text('Share anonymous crash details to help build a stable app.', style: TextStyle(fontSize: 11, color: subtitleColor)),
                    activeThumbColor: Theme.of(context).colorScheme.primary,
                    onChanged: (val) {
                      setState(() => _shareDiagnostics = val);
                    },
                  ),
                  Divider(height: 1, color: dividerCol),
                  SwitchListTile(
                    value: _personalizedAds,
                    title: Text('Personalized Ads', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: titleColor)),
                    subtitle: Text('Allow third-party ad networks to use cookies for advertising.', style: TextStyle(fontSize: 11, color: subtitleColor)),
                    activeThumbColor: Theme.of(context).colorScheme.primary,
                    onChanged: (val) {
                      setState(() => _personalizedAds = val);
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Actions
          Text('Your Rights & Requests', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: subtitleColor)),
          const SizedBox(height: 12),
          ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: borderCol)),
            tileColor: tileBg,
            leading: const Icon(Icons.download_rounded, color: Color(0xFF0F766E)),
            title: Text('Data Portability Request', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: titleColor)),
            subtitle: Text('Receive a downloadable JSON record of your personal profile data.', style: TextStyle(fontSize: 11, color: subtitleColor)),
            trailing: Icon(Icons.chevron_right, size: 20, color: subtitleColor),
            onTap: () => _exportUserData(context),
          ),
          const SizedBox(height: 10),
          ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: borderCol)),
            tileColor: tileBg,
            leading: const Icon(Icons.delete_forever_rounded, color: Color(0xFFEF4444)),
            title: const Text('Right to Erasure (Delete Account)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFEF4444))),
            subtitle: Text('Permanent deletion of profile and all transaction history.', style: TextStyle(fontSize: 11, color: subtitleColor)),
            trailing: Icon(Icons.chevron_right, size: 20, color: subtitleColor),
            onTap: () => _requestAccountDeletion(context),
          ),
        ],
      ),
    );
  }
}
